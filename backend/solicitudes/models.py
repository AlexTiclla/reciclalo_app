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
    estado = models.CharField(
        max_length=20,
        choices=EstadoSolicitud.choices,
        default=EstadoSolicitud.PENDIENTE,
    )
    recolector = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name='retiros_asignados',
        null=True,
        blank=True,
    )
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-creado_en']

    def __str__(self):
        return f'{self.get_tipo_material_display()} — {self.usuario} ({self.estado})'
