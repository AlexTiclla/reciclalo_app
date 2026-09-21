import re
from unittest.mock import patch

from django.contrib.auth.hashers import check_password
from django.contrib.auth.models import User
from django.core import mail, signing
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework.throttling import ScopedRateThrottle

from .models import CodigoRecuperacion
from .serializers import RegistroUsuarioSerializer
from .services import TOKEN_SALT, restablecer_password, solicitar_codigo, verificar_codigo


class TestRegistroUsuarioSerializer(TestCase):
    def test_rechaza_email_duplicado_sin_importar_mayusculas(self):
        User.objects.create_user('juan', email='Juan@Ejemplo.com', password='clave12345')

        serializer = RegistroUsuarioSerializer(data={
            'username': 'juan2',
            'email': 'juan@ejemplo.com',
            'password': 'clave12345',
            'rol': 'Ciudadano',
        })

        self.assertFalse(serializer.is_valid())
        self.assertIn('email', serializer.errors)

    def test_acepta_email_nuevo(self):
        serializer = RegistroUsuarioSerializer(data={
            'username': 'nuevo',
            'email': 'nuevo@ejemplo.com',
            'password': 'clave12345',
            'rol': 'Ciudadano',
        })
        self.assertTrue(serializer.is_valid(), serializer.errors)


class RecuperacionServiceTestCase(TestCase):
    def setUp(self):
        self.usuario = User.objects.create_user(
            'ciudadano1', email='ciudadano1@ejemplo.com', password='vieja12345'
        )


class TestSolicitarCodigo(RecuperacionServiceTestCase):
    def test_usuario_inexistente_no_crea_codigo_ni_envia_correo(self):
        solicitar_codigo('no-existe')

        self.assertEqual(CodigoRecuperacion.objects.count(), 0)
        self.assertEqual(len(mail.outbox), 0)

    def test_usuario_valido_crea_codigo_y_envia_correo_sin_texto_plano(self):
        solicitar_codigo('ciudadano1')

        self.assertEqual(CodigoRecuperacion.objects.count(), 1)
        self.assertEqual(len(mail.outbox), 1)

        enviado = mail.outbox[0]
        self.assertEqual(enviado.to, ['ciudadano1@ejemplo.com'])
        codigo_texto_plano = re.search(r'\d{6}', enviado.body).group()

        codigo = CodigoRecuperacion.objects.get()
        self.assertNotEqual(codigo.codigo_hash, codigo_texto_plano)
        self.assertTrue(check_password(codigo_texto_plano, codigo.codigo_hash))

    def test_funciona_buscando_por_correo(self):
        solicitar_codigo('ciudadano1@ejemplo.com')
        self.assertEqual(CodigoRecuperacion.objects.count(), 1)


class TestVerificarCodigo(RecuperacionServiceTestCase):
    def _codigo_valido(self):
        solicitar_codigo('ciudadano1')
        cuerpo = mail.outbox[-1].body
        return re.search(r'\d{6}', cuerpo).group()

    def test_codigo_correcto_retorna_token_y_marca_usado(self):
        codigo_texto = self._codigo_valido()

        token = verificar_codigo('ciudadano1', codigo_texto)

        self.assertIsNotNone(token)
        intento = CodigoRecuperacion.objects.get()
        self.assertIsNotNone(intento.usado_en)

    def test_codigo_incorrecto_incrementa_intentos_y_no_da_token(self):
        self._codigo_valido()

        token = verificar_codigo('ciudadano1', '000000')

        self.assertIsNone(token)
        intento = CodigoRecuperacion.objects.get()
        self.assertEqual(intento.intentos_fallidos, 1)
        self.assertIsNone(intento.usado_en)

    def test_bloqueado_tras_maximo_de_intentos_incluso_con_codigo_correcto(self):
        codigo_texto = self._codigo_valido()
        intento = CodigoRecuperacion.objects.get()
        intento.intentos_fallidos = 5  # RECUPERACION_OTP_MAX_INTENTOS
        intento.save(update_fields=['intentos_fallidos'])

        token = verificar_codigo('ciudadano1', codigo_texto)

        self.assertIsNone(token)

    def test_codigo_expirado_falla_incluso_siendo_correcto(self):
        codigo_texto = self._codigo_valido()
        intento = CodigoRecuperacion.objects.get()
        intento.expira_en = timezone.now() - timezone.timedelta(minutes=1)
        intento.save(update_fields=['expira_en'])

        token = verificar_codigo('ciudadano1', codigo_texto)

        self.assertIsNone(token)

    def test_usuario_inexistente_no_da_token(self):
        self.assertIsNone(verificar_codigo('no-existe', '123456'))


class TestRestablecerPassword(RecuperacionServiceTestCase):
    def _token_valido(self):
        solicitar_codigo('ciudadano1')
        codigo_texto = re.search(r'\d{6}', mail.outbox[-1].body).group()
        return verificar_codigo('ciudadano1', codigo_texto)

    def test_token_valido_cambia_la_password(self):
        token = self._token_valido()

        ok = restablecer_password(token, 'nuevaPassword123')

        self.assertTrue(ok)
        self.usuario.refresh_from_db()
        self.assertTrue(self.usuario.check_password('nuevaPassword123'))

    def test_token_corrupto_falla(self):
        self.assertFalse(restablecer_password('token-invalido', 'nuevaPassword123'))

    def test_token_con_salt_equivocado_falla(self):
        token = signing.dumps({'usuario_id': self.usuario.id, 'codigo_id': 1}, salt='otro-salt')
        self.assertFalse(restablecer_password(token, 'nuevaPassword123'))

    def test_reusar_el_mismo_token_dos_veces_falla_la_segunda(self):
        token = self._token_valido()

        self.assertTrue(restablecer_password(token, 'nuevaPassword123'))
        # El primer cambio ya ocurrió; reintentar con el mismo token no debe
        # volver a autorizar un segundo cambio silenciosamente.
        ok_segunda_vez = restablecer_password(token, 'otraPasswordMas')
        self.assertFalse(ok_segunda_vez)


class TestEndpointsRecuperacion(APITestCase):
    def setUp(self):
        # ScopedRateThrottle guarda su historial en el cache por defecto
        # (proceso-global, no se resetea solo entre tests) — limpiarlo evita
        # que las cuotas de un test contaminen el conteo de otro.
        cache.clear()
        self.usuario = User.objects.create_user(
            'ciudadano1', email='ciudadano1@ejemplo.com', password='vieja12345'
        )

    def test_solicitar_responde_200_exista_o_no_el_usuario(self):
        respuesta_existente = self.client.post(
            '/api/roles/recuperacion/solicitar/', {'identificador': 'ciudadano1'}, format='json'
        )
        respuesta_inexistente = self.client.post(
            '/api/roles/recuperacion/solicitar/', {'identificador': 'no-existe'}, format='json'
        )

        self.assertEqual(respuesta_existente.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta_inexistente.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta_existente.data, respuesta_inexistente.data)

    def test_verificar_con_codigo_incorrecto_responde_400(self):
        self.client.post('/api/roles/recuperacion/solicitar/', {'identificador': 'ciudadano1'}, format='json')

        respuesta = self.client.post(
            '/api/roles/recuperacion/verificar/',
            {'identificador': 'ciudadano1', 'codigo': '000000'},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_400_BAD_REQUEST)

    def test_flujo_completo_solicitar_verificar_restablecer(self):
        self.client.post('/api/roles/recuperacion/solicitar/', {'identificador': 'ciudadano1'}, format='json')
        codigo_texto = re.search(r'\d{6}', mail.outbox[-1].body).group()

        verificar_resp = self.client.post(
            '/api/roles/recuperacion/verificar/',
            {'identificador': 'ciudadano1', 'codigo': codigo_texto},
            format='json',
        )
        self.assertEqual(verificar_resp.status_code, status.HTTP_200_OK)
        token = verificar_resp.data['token']

        restablecer_resp = self.client.post(
            '/api/roles/recuperacion/restablecer/',
            {'token': token, 'nueva_password': 'contraNueva123'},
            format='json',
        )
        self.assertEqual(restablecer_resp.status_code, status.HTTP_200_OK)

        self.usuario.refresh_from_db()
        self.assertTrue(self.usuario.check_password('contraNueva123'))

    def test_throttling_bloquea_solicitudes_excesivas(self):
        # `ScopedRateThrottle.THROTTLE_RATES` se congela como atributo de
        # clase al importar `rest_framework.throttling` — `override_settings`
        # sobre `REST_FRAMEWORK` no lo refresca. Para bajar la tasa en el
        # test sin esperar una hora real hay que parchear el atributo
        # directamente en vez de la setting de Django.
        with patch.object(
            ScopedRateThrottle,
            'THROTTLE_RATES',
            {'recuperacion-solicitar': '1/hour', 'recuperacion-verificar': '20/hour'},
        ):
            primera = self.client.post(
                '/api/roles/recuperacion/solicitar/', {'identificador': 'ciudadano1'}, format='json'
            )
            segunda = self.client.post(
                '/api/roles/recuperacion/solicitar/', {'identificador': 'ciudadano1'}, format='json'
            )

        self.assertEqual(primera.status_code, status.HTTP_200_OK)
        self.assertEqual(segunda.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
