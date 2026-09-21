from django.contrib import admin

from .models import CodigoRecuperacion


@admin.register(CodigoRecuperacion)
class CodigoRecuperacionAdmin(admin.ModelAdmin):
    list_display = ['usuario', 'creado_en', 'expira_en', 'intentos_fallidos', 'usado_en']
    search_fields = ['usuario__username', 'usuario__email']
    readonly_fields = [f.name for f in CodigoRecuperacion._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
