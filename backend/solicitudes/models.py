from django.conf import settings
from django.db import models


class TipoMaterial(models.TextChoices):
    PLASTICO = 'plastico', 'Plástico'
    CARTON = 'carton', 'Cartón'
    VIDRIO = 'vidrio', 'Vidrio'
    METAL = 'metal', 'Metal'


class EstadoSolicitud(models.TextChoices):
    PENDIENTE = 'pendiente', 'Pendiente'
    ACEPTADA = 'aceptada', 'Aceptada'
    EN_CAMINO = 'en_camino', 'En camino'
    COMPLETADA = 'completada', 'Completada'


class Recolector(models.Model):
    """
    Perfil extendido del usuario que actúa como recolector: disponibilidad,
    última ubicación conocida y estadísticas básicas.

    El perfil se crea bajo demanda (`para_usuario`) la primera vez que un
    usuario del grupo `Recolector` usa un endpoint del flujo de recolección,
    de modo que los usuarios registrados antes de esta versión no queden fuera.
    """

    usuario = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='perfil_recolector',
    )
    es_activo = models.BooleanField(default=False)
    # Última ubicación reportada por el cliente (ping periódico).
    latitud_actual = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True
    )
    longitud_actual = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True
    )
    ultimo_ping = models.DateTimeField(auto_now=True)
    total_completadas = models.PositiveIntegerField(default=0)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Recolector'
        verbose_name_plural = 'Recolectores'

    def __str__(self):
        nombre = self.usuario.get_full_name() or self.usuario.username
        return f'{nombre} (Recolector)'

    @classmethod
    def para_usuario(cls, usuario):
        perfil, _ = cls.objects.get_or_create(usuario=usuario)
        return perfil


class SolicitudRetiro(models.Model):
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='solicitudes',
    )
    tipo_material = models.CharField(max_length=20, choices=TipoMaterial.choices)
    foto = models.ImageField(upload_to='solicitudes/')
    latitud = models.DecimalField(max_digits=9, decimal_places=6)
    longitud = models.DecimalField(max_digits=9, decimal_places=6)
    direccion_referencia = models.CharField(max_length=255, blank=True)
    # Recompensa ofrecida al recolector. Nulo = el material se entrega gratis.
    precio = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True
    )
    # Teléfono al que el recolector escribe por WhatsApp (formato internacional).
    telefono_contacto = models.CharField(max_length=20, blank=True)
    estado = models.CharField(
        max_length=20,
        choices=EstadoSolicitud.choices,
        default=EstadoSolicitud.PENDIENTE,
    )
    recolector = models.ForeignKey(
        Recolector,
        on_delete=models.SET_NULL,
        related_name='solicitudes_asignadas',
        null=True,
        blank=True,
    )
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-creado_en']

    def __str__(self):
        return f'{self.get_tipo_material_display()} — {self.usuario} ({self.estado})'


class AsignacionRetiro(models.Model):
    """
    Historia de aceptaciones/rechazos de una solicitud por parte de los
    recolectores. Un rechazo no cambia el estado de la `SolicitudRetiro`:
    solo deja constancia para no volver a ofrecérsela al mismo recolector.
    """

    class Estado(models.TextChoices):
        ACEPTADA = 'aceptada', 'Aceptada'
        COMPLETADA = 'completada', 'Completada'
        RECHAZADA = 'rechazada', 'Rechazada'

    solicitud = models.ForeignKey(
        SolicitudRetiro,
        on_delete=models.CASCADE,
        related_name='asignaciones',
    )
    recolector = models.ForeignKey(
        Recolector,
        on_delete=models.CASCADE,
        related_name='asignaciones',
    )
    estado = models.CharField(
        max_length=20,
        choices=Estado.choices,
        default=Estado.ACEPTADA,
    )
    aceptada_en = models.DateTimeField(auto_now_add=True)
    completada_en = models.DateTimeField(null=True, blank=True)
    notas = models.TextField(blank=True)

    class Meta:
        ordering = ['-aceptada_en']
        verbose_name = 'Asignación de Retiro'
        verbose_name_plural = 'Asignaciones de Retiro'

    def __str__(self):
        return f'{self.recolector.usuario} — solicitud {self.solicitud_id} ({self.estado})'
