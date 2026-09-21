from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth.models import Group, User
from django.core.files.base import ContentFile
from django.test import TestCase
from django.utils import timezone

from solicitudes.models import AsignacionRetiro, EstadoSolicitud, Recolector, SolicitudRetiro

from .models import ProgresoRacha, Recompensa, RolRacha, SaldoEcoPuntos, TipoTransaccion
from .services import (
    SaldoInsuficienteError,
    acreditar_por_completado,
    canjear_recompensa,
    cerrar_semana,
    proximo_hito,
)
from .utils import calcular_impacto

GIF_1PX = (
    b'GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!'
    b'\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;'
)


class TestCalcularImpacto(TestCase):
    def test_calcula_puntos_y_huella_proporcional_al_peso(self):
        puntos, co2_kg, agua_l = calcular_impacto('plastico', Decimal('2'))
        self.assertEqual(puntos, 30)
        self.assertEqual(co2_kg, Decimal('3.00'))
        self.assertEqual(agua_l, Decimal('6.00'))

    def test_material_desconocido_usa_factor_por_defecto(self):
        puntos, _, _ = calcular_impacto('desconocido', Decimal('1'))
        self.assertEqual(puntos, 10)


class GamificacionTestCase(TestCase):
    def setUp(self):
        self.ciudadano = User.objects.create_user('ciudadano1', password='clave12345')
        self.ciudadano.groups.add(Group.objects.get_or_create(name='Ciudadano')[0])

        self.recolector_usuario = User.objects.create_user('recolector1', password='clave12345')
        self.recolector_usuario.groups.add(Group.objects.get_or_create(name='Recolector')[0])
        self.recolector = Recolector.para_usuario(self.recolector_usuario)

    def crear_solicitud_completada(self, peso_kg='3.0', material='plastico'):
        solicitud = SolicitudRetiro.objects.create(
            usuario=self.ciudadano,
            tipo_material=material,
            foto=ContentFile(GIF_1PX, name='demo.gif'),
            latitud=Decimal('-17.78'),
            longitud=Decimal('-63.18'),
            estado=EstadoSolicitud.COMPLETADA,
            peso_kg=Decimal(peso_kg),
            recolector=self.recolector,
        )
        asignacion = AsignacionRetiro.objects.create(
            solicitud=solicitud,
            recolector=self.recolector,
            estado=AsignacionRetiro.Estado.COMPLETADA,
            completada_en=timezone.now(),
        )
        return asignacion


class TestAcreditarPorCompletado(GamificacionTestCase):
    def test_acredita_saldo_y_crea_transaccion_y_evento(self):
        asignacion = self.crear_solicitud_completada(peso_kg='2.0', material='plastico')

        acreditar_por_completado(asignacion)

        saldo = SaldoEcoPuntos.para_usuario(self.ciudadano)
        self.assertEqual(saldo.saldo, 30)

        transaccion = self.ciudadano.transacciones_ecopuntos.get()
        self.assertEqual(transaccion.tipo, TipoTransaccion.ACREDITACION)
        self.assertEqual(transaccion.puntos, 30)

        evento = self.ciudadano.eventos_pendientes.get()
        self.assertEqual(evento.payload['puntos'], 30)


class TestCerrarSemana(GamificacionTestCase):
    def _progreso(self, usuario, rol, **overrides):
        defaults = {'mes_protectores': date(2026, 1, 1)}
        defaults.update(overrides)
        return ProgresoRacha.objects.create(usuario=usuario, rol=rol, **defaults)

    def test_semana_cumplida_incrementa_racha(self):
        # Lunes de "la semana pasada" respecto al 2026-01-19 (lunes) es 2026-01-12.
        self.crear_solicitud_completada()
        self.ciudadano.solicitudes.update(actualizado_en=timezone.make_aware(
            timezone.datetime(2026, 1, 14)
        ))
        progreso = self._progreso(self.ciudadano, RolRacha.CIUDADANO)

        cerrar_semana(progreso, hoy=date(2026, 1, 19))
        progreso.refresh_from_db()

        self.assertEqual(progreso.racha_actual, 1)
        self.assertEqual(progreso.racha_maxima, 1)
        self.assertEqual(progreso.semana_evaluada_hasta, date(2026, 1, 12))

    def test_semana_vacia_con_protector_no_rompe_la_racha(self):
        progreso = self._progreso(
            self.ciudadano, RolRacha.CIUDADANO, racha_actual=3, racha_maxima=3,
            protectores_disponibles=2,
        )

        cerrar_semana(progreso, hoy=date(2026, 1, 19))
        progreso.refresh_from_db()

        self.assertEqual(progreso.racha_actual, 3)
        self.assertEqual(progreso.protectores_disponibles, 1)

    def test_semana_vacia_sin_protector_resetea_racha_sin_tocar_maxima(self):
        progreso = self._progreso(
            self.ciudadano, RolRacha.CIUDADANO, racha_actual=3, racha_maxima=5,
            protectores_disponibles=0,
        )

        cerrar_semana(progreso, hoy=date(2026, 1, 19))
        progreso.refresh_from_db()

        self.assertEqual(progreso.racha_actual, 0)
        self.assertEqual(progreso.racha_maxima, 5)

    def test_cerrar_semana_es_idempotente_para_el_bono_de_hito(self):
        self.crear_solicitud_completada()
        self.ciudadano.solicitudes.update(actualizado_en=timezone.make_aware(
            timezone.datetime(2026, 1, 14)
        ))
        progreso = self._progreso(self.ciudadano, RolRacha.CIUDADANO, racha_actual=1, racha_maxima=1)

        cerrar_semana(progreso, hoy=date(2026, 1, 19))
        cerrar_semana(progreso, hoy=date(2026, 1, 19))  # Mismo lunes: no debe reevaluarse.
        progreso.refresh_from_db()

        self.assertEqual(progreso.racha_actual, 2)
        transacciones_bono = self.ciudadano.transacciones_ecopuntos.filter(
            tipo=TipoTransaccion.BONO_RACHA
        )
        self.assertEqual(transacciones_bono.count(), 1)
        self.assertEqual(transacciones_bono.get().puntos, 10)  # Hito de 2 semanas, tabla Ciudadano.

    def test_proximo_hito_recolector_usa_tabla_mas_baja(self):
        hito, puntos = proximo_hito(RolRacha.RECOLECTOR, racha_actual=0)
        self.assertEqual(hito, 2)
        self.assertEqual(puntos, 5)


class TestCanjearRecompensa(GamificacionTestCase):
    def test_rechaza_canje_si_el_saldo_no_alcanza(self):
        recompensa = Recompensa.objects.create(nombre='Café', costo_puntos=150)

        with self.assertRaises(SaldoInsuficienteError):
            canjear_recompensa(self.ciudadano, recompensa.id)

    def test_canje_exitoso_descuenta_saldo_y_genera_codigo(self):
        saldo = SaldoEcoPuntos.para_usuario(self.ciudadano)
        saldo.saldo = 200
        saldo.save()
        recompensa = Recompensa.objects.create(nombre='Café', costo_puntos=150)

        canje, saldo_restante = canjear_recompensa(self.ciudadano, recompensa.id)

        self.assertEqual(saldo_restante, 50)
        self.assertTrue(canje.codigo.startswith('ECO-'))
        transaccion = self.ciudadano.transacciones_ecopuntos.get(tipo=TipoTransaccion.CANJE)
        self.assertEqual(transaccion.puntos, -150)
