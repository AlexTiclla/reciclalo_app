import secrets

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import User
from django.core import signing
from django.core.mail import send_mail
from django.utils import timezone

from .models import CodigoRecuperacion

TOKEN_SALT = 'roles.recuperacion-password'


def solicitar_codigo(identificador: str) -> None:
    """Genera y envía un código OTP por correo si el usuario existe.

    Nunca revela si `identificador` corresponde a una cuenta real: si no
    existe o no tiene correo, simplemente no hace nada (ver design prompt,
    principio de no enumeración de usuarios).
    """
    usuario = _buscar_usuario(identificador)
    if usuario is None or not usuario.email:
        return

    codigo = f'{secrets.randbelow(1_000_000):06d}'
    CodigoRecuperacion.objects.create(
        usuario=usuario,
        codigo_hash=make_password(codigo),
        expira_en=timezone.now() + timezone.timedelta(minutes=settings.RECUPERACION_OTP_EXPIRA_MINUTOS),
    )
    send_mail(
        subject='Tu código de recuperación de EcoRecicla',
        message=(
            f'Tu código de verificación es: {codigo}\n'
            f'Vence en {settings.RECUPERACION_OTP_EXPIRA_MINUTOS} minutos.\n\n'
            'Si no solicitaste este código, puedes ignorar este correo.'
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[usuario.email],
    )


def verificar_codigo(identificador: str, codigo: str) -> str | None:
    """Valida el código OTP más reciente sin usar de `identificador`.

    Retorna un token firmado (de corta duración) que autoriza el cambio de
    contraseña en `restablecer_password`, o `None` si el código es
    incorrecto, ya fue usado, expiró o está bloqueado por intentos.
    """
    usuario = _buscar_usuario(identificador)
    if usuario is None:
        return None

    intento = (
        CodigoRecuperacion.objects.filter(usuario=usuario, usado_en__isnull=True)
        .order_by('-creado_en')
        .first()
    )
    if intento is None or not intento.vigente:
        return None

    if not check_password(codigo, intento.codigo_hash):
        intento.intentos_fallidos += 1
        intento.save(update_fields=['intentos_fallidos'])
        return None

    intento.usado_en = timezone.now()
    intento.save(update_fields=['usado_en'])
    return signing.dumps({'usuario_id': usuario.id, 'codigo_id': intento.id}, salt=TOKEN_SALT)


def restablecer_password(token: str, nueva_password: str) -> bool:
    """Cambia la contraseña si `token` es un token de verificación vigente."""
    try:
        datos = signing.loads(
            token, salt=TOKEN_SALT, max_age=settings.RECUPERACION_OTP_EXPIRA_MINUTOS * 60
        )
    except signing.BadSignature:
        return False

    try:
        usuario = User.objects.get(pk=datos['usuario_id'])
    except User.DoesNotExist:
        return False

    # El código referenciado por el token debe seguir marcado como usado por
    # ESTE flujo de verificación (evita que un token viejo siga sirviendo si
    # el usuario pidió y usó un código nuevo después), y el token en sí no
    # debe haberse consumido ya (evita reusar el mismo token dos veces
    # mientras su firma siga vigente).
    intento = CodigoRecuperacion.objects.filter(
        pk=datos['codigo_id'], usuario=usuario, usado_en__isnull=False, token_consumido=False
    ).first()
    if intento is None:
        return False

    intento.token_consumido = True
    intento.save(update_fields=['token_consumido'])

    usuario.set_password(nueva_password)
    usuario.save(update_fields=['password'])
    return True


def _buscar_usuario(identificador: str) -> User | None:
    return (
        User.objects.filter(username__iexact=identificador).first()
        or User.objects.filter(email__iexact=identificador).first()
    )
