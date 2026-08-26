"""
Datos de prueba para recorrer el flujo del recolector de punta a punta.

    python manage.py seed_picker_demo --lat -17.7833 --lng -63.1821

Crea (si no existen) un ciudadano y un recolector de prueba y siembra varias
solicitudes pendientes alrededor del punto indicado, para que el mapa del
recolector tenga pines con los que trabajar. Por defecto usa el centro de
Santa Cruz de la Sierra (Plaza 24 de Septiembre).
"""

from decimal import Decimal

from django.contrib.auth.models import Group, User
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand

from solicitudes.models import EstadoSolicitud, Recolector, SolicitudRetiro

CLAVE_DEMO = 'demo12345'

# GIF de 1x1 px: `foto` es obligatorio y no vale la pena arrastrar imágenes.
GIF_1PX = (
    b'GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!'
    b'\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;'
)

# (material, precio, referencia, desplazamiento norte/este en grados)
# Referencias de Santa Cruz de la Sierra, repartidas por varios anillos para
# probar distintas distancias desde el centro.
MUESTRAS = [
    ('carton', Decimal('5.00'), 'Av. Monseñor Rivero, cerca del 2do anillo', (0.004, 0.001)),
    ('plastico', Decimal('3.50'), 'Calle Junín, casco viejo', (-0.003, 0.004)),
    ('vidrio', None, 'Mercado Los Pozos', (0.002, -0.005)),
    ('metal', Decimal('12.00'), 'Parque Urbano, portón norte', (-0.006, -0.002)),
    ('carton', Decimal('7.00'), 'Av. Banzer, 3er anillo', (0.010, 0.008)),
    ('plastico', Decimal('4.00'), 'Av. San Martín, Equipetrol', (0.008, -0.012)),
    ('vidrio', Decimal('2.50'), 'Av. Cristo Redentor, 4to anillo', (-0.012, 0.006)),
    ('metal', Decimal('9.50'), 'Doble Vía a La Guardia, km 4', (-0.018, -0.015)),
    ('plastico', Decimal('1.50'), 'Av. Alemana, cerca del Ventura Mall', (0.014, -0.004)),
    ('carton', None, 'Barrio Las Palmas, calle 5', (-0.007, 0.014)),
]


class Command(BaseCommand):
    help = 'Crea usuarios y solicitudes de prueba para el flujo del recolector.'

    def add_arguments(self, parser):
        parser.add_argument('--lat', type=float, default=-17.7833,
                            help='Latitud del centro (por defecto, Santa Cruz de la Sierra).')
        parser.add_argument('--lng', type=float, default=-63.1821,
                            help='Longitud del centro.')

    def handle(self, *args, **opciones):
        ciudadano = self._usuario('ciudadano_demo', 'Ciudadano')
        recolector_usuario = self._usuario('recolector_demo', 'Recolector')
        Recolector.para_usuario(recolector_usuario)

        centro_lat = Decimal(str(opciones['lat']))
        centro_lng = Decimal(str(opciones['lng']))

        creadas = 0
        for material, precio, referencia, (delta_lat, delta_lng) in MUESTRAS:
            _, creada = SolicitudRetiro.objects.get_or_create(
                usuario=ciudadano,
                direccion_referencia=referencia,
                defaults={
                    'tipo_material': material,
                    'precio': precio,
                    'telefono_contacto': '+59170000000',
                    'estado': EstadoSolicitud.PENDIENTE,
                    'latitud': centro_lat + Decimal(str(delta_lat)),
                    'longitud': centro_lng + Decimal(str(delta_lng)),
                    'foto': ContentFile(GIF_1PX, name=f'demo_{material}.gif'),
                },
            )
            creadas += int(creada)

        self.stdout.write(self.style.SUCCESS(
            f'Listo: {creadas} solicitudes nuevas alrededor de '
            f'({centro_lat}, {centro_lng}).'
        ))
        self.stdout.write(
            f'Usuarios de prueba (contraseña "{CLAVE_DEMO}"): '
            'ciudadano_demo, recolector_demo'
        )

    def _usuario(self, username, rol):
        usuario, creado = User.objects.get_or_create(
            username=username,
            defaults={'email': f'{username}@example.com'},
        )
        if creado:
            usuario.set_password(CLAVE_DEMO)
            usuario.save(update_fields=['password'])

        usuario.groups.add(Group.objects.get_or_create(name=rol)[0])
        return usuario
