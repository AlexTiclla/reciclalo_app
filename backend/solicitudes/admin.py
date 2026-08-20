from django.contrib import admin

from .models import SolicitudRetiro


@admin.register(SolicitudRetiro)
class SolicitudRetiroAdmin(admin.ModelAdmin):
    list_display = ['id', 'usuario', 'tipo_material', 'estado', 'recolector', 'creado_en']
    list_filter = ['estado', 'tipo_material']
    search_fields = ['usuario__username', 'direccion_referencia']
