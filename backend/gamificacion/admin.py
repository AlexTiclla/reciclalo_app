from django.contrib import admin

from .models import Canje, EventoPendiente, ProgresoRacha, Recompensa, SaldoEcoPuntos, TransaccionEcoPuntos


@admin.register(Recompensa)
class RecompensaAdmin(admin.ModelAdmin):
    list_display = ['nombre', 'costo_puntos', 'categoria', 'comercio_nombre', 'activa']
    list_filter = ['categoria', 'activa']
    search_fields = ['nombre', 'comercio_nombre']


@admin.register(SaldoEcoPuntos)
class SaldoEcoPuntosAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'saldo', 'actualizado_en']
    search_fields = ['usuario__username']
    readonly_fields = ['actualizado_en']


@admin.register(TransaccionEcoPuntos)
class TransaccionEcoPuntosAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'tipo', 'puntos', 'creado_en']
    list_filter = ['tipo', 'creado_en']
    search_fields = ['usuario__username']
    readonly_fields = [f.name for f in TransaccionEcoPuntos._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(Canje)
class CanjeAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'recompensa', 'puntos_gastados', 'codigo', 'creado_en']
    search_fields = ['usuario__username', 'codigo']
    readonly_fields = [f.name for f in Canje._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(ProgresoRacha)
class ProgresoRachaAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'rol', 'racha_actual', 'racha_maxima', 'protectores_disponibles']
    list_filter = ['rol']
    search_fields = ['usuario__username']


@admin.register(EventoPendiente)
class EventoPendienteAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'tipo', 'creado_en', 'visto_en']
    list_filter = ['tipo']
    search_fields = ['usuario__username']
