from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    EventoPendienteListView,
    EventoPendienteMarcarVistoView,
    ImpactoView,
    ProgresoRachaView,
    RecompensaViewSet,
    SaldoEcoPuntosView,
    TransaccionEcoPuntosListView,
)

router = DefaultRouter()
router.register('gamificacion/recompensas', RecompensaViewSet, basename='recompensa')

urlpatterns = router.urls + [
    path('gamificacion/saldo/', SaldoEcoPuntosView.as_view(), name='gamificacion-saldo'),
    path(
        'gamificacion/transacciones/',
        TransaccionEcoPuntosListView.as_view(),
        name='gamificacion-transacciones',
    ),
    path('gamificacion/racha/', ProgresoRachaView.as_view(), name='gamificacion-racha'),
    path('gamificacion/impacto/', ImpactoView.as_view(), name='gamificacion-impacto'),
    path(
        'gamificacion/eventos-pendientes/',
        EventoPendienteListView.as_view(),
        name='gamificacion-eventos-pendientes',
    ),
    path(
        'gamificacion/eventos-pendientes/<int:pk>/marcar-visto/',
        EventoPendienteMarcarVistoView.as_view(),
        name='gamificacion-evento-marcar-visto',
    ),
]
