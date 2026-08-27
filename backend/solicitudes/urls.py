from rest_framework.routers import DefaultRouter

from .views import RecolectorViewSet, SolicitudRetiroViewSet

router = DefaultRouter()
router.register('solicitudes', SolicitudRetiroViewSet, basename='solicitud')
router.register('recolector', RecolectorViewSet, basename='recolector')

urlpatterns = router.urls
