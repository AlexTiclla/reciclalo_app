from django.conf import settings
from django.db import models
from django.utils import timezone


class CodigoRecuperacion(models.Model):
    """Código OTP de un solo uso para recuperar contraseña por correo (Flujo 5)."""

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='codigos_recuperacion'
    )
    # Hash del código de 6 dígitos (mismo mecanismo que las contraseñas,
    # `make_password`/`check_password`) — el código en texto plano nunca se
    # persiste, solo vive en memoria al generarlo y en el cuerpo del email.
    codigo_hash = models.CharField(max_length=128)
    creado_en = models.DateTimeField(auto_now_add=True)
    expira_en = models.DateTimeField()
    intentos_fallidos = models.PositiveSmallIntegerField(default=0)
    usado_en = models.DateTimeField(null=True, blank=True)
    # `usado_en` marca que el CÓDIGO OTP ya fue verificado (Paso 2); este
    # flag marca que el TOKEN de reseteo emitido a partir de él ya se
    # consumió (Paso 3A), para que el mismo token no pueda cambiar la
    # contraseña dos veces mientras siga vigente su firma.
    token_consumido = models.BooleanField(default=False)

    class Meta:
        ordering = ['-creado_en']

    @property
    def expirado(self):
        return timezone.now() >= self.expira_en

    @property
    def bloqueado(self):
        return self.intentos_fallidos >= settings.RECUPERACION_OTP_MAX_INTENTOS

    @property
    def vigente(self):
        return self.usado_en is None and not self.expirado and not self.bloqueado
