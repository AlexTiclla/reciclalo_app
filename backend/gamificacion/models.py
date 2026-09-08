from django.conf import settings
from django.db import models


class TipoTransaccion(models.TextChoices):
    ACREDITACION = 'acreditacion', 'Acreditación por reciclaje'
    BONO_RACHA = 'bono_racha', 'Bono de racha'
    CANJE = 'canje', 'Canje de recompensa'


class RolRacha(models.TextChoices):
    CIUDADANO = 'ciudadano', 'Ciudadano'
    RECOLECTOR = 'recolector', 'Recolector'


class SaldoEcoPuntos(models.Model):
    """Saldo vigente de EcoPuntos de un usuario (cualquiera de los dos roles)."""

    usuario = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='saldo_ecopuntos'
    )
    saldo = models.PositiveIntegerField(default=0)
    actualizado_en = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.usuario} — {self.saldo} pts'

    @classmethod
    def para_usuario(cls, usuario):
        saldo, _ = cls.objects.get_or_create(usuario=usuario)
        return saldo


class Recompensa(models.Model):
    class Categoria(models.TextChoices):
        DESCUENTOS = 'descuentos', 'Descuentos'
        PRODUCTOS = 'productos', 'Productos'
        SERVICIOS = 'servicios', 'Servicios'

    nombre = models.CharField(max_length=120)
    descripcion = models.TextField(blank=True)
    imagen = models.ImageField(upload_to='recompensas/', null=True, blank=True)
    costo_puntos = models.PositiveIntegerField()
    categoria = models.CharField(
        max_length=20, choices=Categoria.choices, default=Categoria.PRODUCTOS
    )
    comercio_nombre = models.CharField(max_length=120, blank=True)
    activa = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['costo_puntos']

    def __str__(self):
        return f'{self.nombre} ({self.costo_puntos} pts)'


class Canje(models.Model):
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='canjes'
    )
    recompensa = models.ForeignKey(
        Recompensa, on_delete=models.PROTECT, related_name='canjes'
    )
    puntos_gastados = models.PositiveIntegerField()
    codigo = models.CharField(max_length=20, unique=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-creado_en']

    def __str__(self):
        return f'{self.usuario} — {self.recompensa} ({self.codigo})'


class TransaccionEcoPuntos(models.Model):
    """Historial (ledger) de movimientos de puntos — nunca se edita, solo se agrega."""

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transacciones_ecopuntos',
    )
    tipo = models.CharField(max_length=20, choices=TipoTransaccion.choices)
    # Positivo para acreditación/bono, negativo para canje.
    puntos = models.IntegerField()
    solicitud = models.ForeignKey(
        'solicitudes.SolicitudRetiro',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='transacciones_ecopuntos',
    )
    racha_semanas = models.PositiveIntegerField(null=True, blank=True)
    canje = models.ForeignKey(
        Canje, on_delete=models.SET_NULL, null=True, blank=True, related_name='transaccion'
    )
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-creado_en']

    def __str__(self):
        return f'{self.usuario} — {self.tipo} ({self.puntos:+d} pts)'


class ProgresoRacha(models.Model):
    """
    Resultado persistido de evaluar la racha semana a semana para un rol.

    No es la "fuente de verdad" de qué semanas se cumplieron (eso vive en
    `SolicitudRetiro`/`AsignacionRetiro`); es el resultado idempotente de
    haber cerrado cada semana: cuántos protectores quedan, si ya se acreditó
    el bono de tal hito, y si hay un hito pendiente de mostrar en un modal.
    """

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='progresos_racha'
    )
    rol = models.CharField(max_length=20, choices=RolRacha.choices)
    racha_actual = models.PositiveIntegerField(default=0)
    racha_maxima = models.PositiveIntegerField(default=0)
    protectores_disponibles = models.PositiveSmallIntegerField(default=2)
    # Primer día del mes calendario de la última recarga de protectores.
    mes_protectores = models.DateField()
    # Lunes de la última semana ya cerrada por `cerrar_semana_racha`.
    semana_evaluada_hasta = models.DateField(null=True, blank=True)
    ultimo_hito_acreditado = models.PositiveIntegerField(default=0)
    hito_pendiente_de_mostrar = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['usuario', 'rol'], name='progreso_racha_unico_por_rol')
        ]
        verbose_name = 'Progreso de racha'
        verbose_name_plural = 'Progresos de racha'

    def __str__(self):
        return f'{self.usuario} ({self.rol}) — racha {self.racha_actual}'


class EventoPendiente(models.Model):
    """
    Cola simple de eventos in-app que un rol aún no vio: acreditación de
    puntos tras un retiro (para el Ciudadano) o hito de racha (para
    cualquiera). El frontend la consulta al abrir la pantalla raíz del rol.
    """

    class Tipo(models.TextChoices):
        ACREDITACION = 'acreditacion', 'Acreditación de EcoPuntos'
        HITO_RACHA = 'hito_racha', 'Hito de racha'

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='eventos_pendientes'
    )
    tipo = models.CharField(max_length=20, choices=Tipo.choices)
    payload = models.JSONField()
    creado_en = models.DateTimeField(auto_now_add=True)
    visto_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['creado_en']

    def __str__(self):
        return f'{self.usuario} — {self.tipo} ({"visto" if self.visto_en else "pendiente"})'
