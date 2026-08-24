from rest_framework.routers import DefaultRouter

from .views import SolicitudRetiroViewSet

router = DefaultRouter()
router.register('solicitudes', SolicitudRetiroViewSet, basename='solicitud')

urlpatterns = router.urls
