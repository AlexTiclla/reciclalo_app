"""
Datos de prueba para el flujo de fidelización y gamificación.

    python manage.py seed_gamificacion_demo

Crea un catálogo de recompensas de ejemplo y otorga un saldo inicial a
`ciudadano_demo`/`recolector_demo` (ver `seed_picker_demo`) para poder ver
las pantallas de Recompensas/Impacto pobladas sin completar retiros reales.
"""

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from gamificacion.models import Recompensa, SaldoEcoPuntos

CLAVE_DEMO = 'demo12345'

RECOMPENSAS = [
    {
        'nombre': '20% en Cafetería Orgánica',
        'descripcion': 'Café de especialidad en tostadores locales seleccionados.',
        'costo_puntos': 150,
        'categoria': Recompensa.Categoria.DESCUENTOS,
        'comercio_nombre': 'Cafetería Orgánica',
    },
    {
        'nombre': 'EcoBolsa de Algodón',
        'descripcion': 'Bolsa reutilizable fabricada con 100% fibra orgánica y tintes naturales.',
        'costo_puntos': 300,
        'categoria': Recompensa.Categoria.PRODUCTOS,
        'comercio_nombre': 'EcoTienda',
    },
    {
        'nombre': '10% en pago de servicios',
        'descripcion': 'Descuento aplicable al pago de agua o luz del mes.',
        'costo_puntos': 500,
        'categoria': Recompensa.Categoria.SERVICIOS,
        'comercio_nombre': 'Alianza Municipal',
    },
]


class Command(BaseCommand):
    help = 'Crea recompensas de ejemplo y saldo inicial para los usuarios demo.'

    def handle(self, *args, **opciones):
        creadas = 0
        for datos in RECOMPENSAS:
            _, creada = Recompensa.objects.get_or_create(nombre=datos['nombre'], defaults=datos)
            creadas += int(creada)

        for username, saldo_inicial in (('ciudadano_demo', 365), ('recolector_demo', 80)):
            usuario = User.objects.filter(username=username).first()
            if usuario is None:
                continue
            saldo = SaldoEcoPuntos.para_usuario(usuario)
            saldo.saldo = saldo_inicial
            saldo.save(update_fields=['saldo', 'actualizado_en'])

        self.stdout.write(self.style.SUCCESS(f'Listo: {creadas} recompensas nuevas.'))
