"""Utilidades geográficas compartidas por el flujo del recolector."""

from decimal import Decimal
from math import cos, radians

from geopy.distance import geodesic

# Aproximación suficiente para el prefiltro por bounding box.
KM_POR_GRADO_LATITUD = 111.0


def distancia_km(origen, destino):
    """Distancia geodésica en km entre dos pares (latitud, longitud)."""
    return round(geodesic(_a_float(origen), _a_float(destino)).kilometers, 2)


def bounding_box(latitud, longitud, radio_km):
    """
    Rectángulo (lat_min, lat_max, lng_min, lng_max) que contiene el círculo de
    `radio_km` alrededor del punto. Sirve como prefiltro barato en la BD antes
    de calcular la distancia real; nunca descarta un punto dentro del radio.
    """
    lat = float(latitud)
    lng = float(longitud)

    delta_lat = radio_km / KM_POR_GRADO_LATITUD
    # Los meridianos se juntan cerca de los polos: 1° de longitud vale menos km.
    km_por_grado_lng = KM_POR_GRADO_LATITUD * max(cos(radians(lat)), 0.01)
    delta_lng = radio_km / km_por_grado_lng

    return (
        Decimal(str(lat - delta_lat)),
        Decimal(str(lat + delta_lat)),
        Decimal(str(lng - delta_lng)),
        Decimal(str(lng + delta_lng)),
    )


def _a_float(punto):
    return (float(punto[0]), float(punto[1]))
