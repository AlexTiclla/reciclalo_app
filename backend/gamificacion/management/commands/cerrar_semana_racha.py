"""
Cierra la última semana completa transcurrida para cada racha (ciudadano y
recolector), aplicando protectores automáticos y bonos de hito.

IMPORTANTE sobre `--fecha`: el comando cierra la semana ANTERIOR a la fecha
indicada (o a hoy, si no se pasa `--fecha`) — igual que un cron que corre
cada lunes para evaluar la semana que recién terminó. Si acabas de completar
un retiro HOY y quieres ver su efecto, `--fecha` debe ser una fecha de AL
MENOS 7 DÍAS DESPUÉS de hoy (la semana siguiente), no la fecha de hoy —
de lo contrario el comando evalúa una semana anterior que no incluye esa
actividad y no vas a ver ningún cambio.

    python manage.py cerrar_semana_racha
    # Probar el efecto de actividad de HOY (ej. hoy = 2026-09-07):
    python manage.py cerrar_semana_racha --fecha 2026-09-14

No hay scheduler configurado todavía en el proyecto (ver plan de
implementación): en desarrollo se corre a mano o vía cron del sistema
apuntando a este comando, idealmente cada lunes.
"""

from datetime import date, timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from gamificacion.services import cerrar_semana_para_todos


class Command(BaseCommand):
    help = (
        'Cierra la semana de racha ANTERIOR a --fecha (o a hoy). Para ver el '
        'efecto de actividad de hoy, usa una --fecha de al menos 7 días después.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--fecha', type=str, default=None,
            help=(
                'Fecha simulada (YYYY-MM-DD) desde la que se calcula la semana '
                'ANTERIOR a cerrar. Por defecto, hoy.'
            ),
        )

    def handle(self, *args, **opciones):
        hoy = date.fromisoformat(opciones['fecha']) if opciones['fecha'] else timezone.localdate()
        lunes_actual = hoy - timedelta(days=hoy.weekday())
        lunes_a_cerrar = lunes_actual - timedelta(days=7)

        cerrar_semana_para_todos(hoy=hoy)

        self.stdout.write(self.style.SUCCESS(
            f'Semana de racha cerrada: {lunes_a_cerrar} al '
            f'{lunes_a_cerrar + timedelta(days=6)}.'
        ))
