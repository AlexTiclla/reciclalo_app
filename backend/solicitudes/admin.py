from django.contrib import admin

from .models import AsignacionRetiro, Recolector, SolicitudRetiro


@admin.register(SolicitudRetiro)
class SolicitudRetiroAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'usuario', 'tipo_material', 'precio', 'estado', 'recolector', 'creado_en'
    ]
    list_filter = ['estado', 'tipo_material']
    search_fields = ['usuario__username', 'direccion_referencia']
    readonly_fields = ['creado_en', 'actualizado_en']


@admin.register(Recolector)
class RecolectorAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'es_activo', 'total_completadas', 'ultimo_ping']
    list_filter = ['es_activo', 'creado_en']
    search_fields = ['usuario__username', 'usuario__email']
    readonly_fields = ['ultimo_ping', 'creado_en', 'total_completadas']


@admin.register(AsignacionRetiro)
class AsignacionRetiroAdmin(admin.ModelAdmin):
    list_display = ['id', 'recolector', 'solicitud', 'estado', 'aceptada_en', 'completada_en']
    list_filter = ['estado', 'aceptada_en']
    search_fields = ['recolector__usuario__username', 'solicitud__id']
    readonly_fields = ['aceptada_en', 'completada_en']
