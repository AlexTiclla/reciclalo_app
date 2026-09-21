from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    GroupViewSet,
    RegistroView,
    RestablecerPasswordView,
    SolicitarCodigoView,
    VerificarCodigoView,
)

router = DefaultRouter()
router.register(r'grupos', GroupViewSet, basename='grupo')

urlpatterns = [
    path('registro/', RegistroView.as_view(), name='registro-usuario'),
    path('recuperacion/solicitar/', SolicitarCodigoView.as_view(), name='recuperacion-solicitar'),
    path('recuperacion/verificar/', VerificarCodigoView.as_view(), name='recuperacion-verificar'),
    path('recuperacion/restablecer/', RestablecerPasswordView.as_view(), name='recuperacion-restablecer'),
    path('', include(router.urls)),
]