from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import RegistroView, GroupViewSet

router = DefaultRouter()
router.register(r'grupos', GroupViewSet, basename='grupo')

urlpatterns = [
    path('registro/', RegistroView.as_view(), name='registro-usuario'),
    path('', include(router.urls)),
]