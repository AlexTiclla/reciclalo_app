from decimal import Decimal

from django.contrib.auth.models import Group, User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from .models import (
    AsignacionRetiro,
    EstadoCoordinacion,
    EstadoSolicitud,
    Recolector,
    SolicitudRetiro,
)

# Plaza 24 de Septiembre, Cochabamba — punto de referencia de las pruebas.
CENTRO = (Decimal('-17.393700'), Decimal('-66.157000'))

# GIF de 1x1 px: evita depender de Pillow para generar imágenes en los tests.
GIF_1PX = (
    b'GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!'
    b'\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;'
)


def foto():
    return SimpleUploadedFile('material.gif', GIF_1PX, content_type='image/gif')


class PickerAPITestCase(APITestCase):
    """Base con un ciudadano, un recolector y una solicitud pendiente."""

    def setUp(self):
        self.ciudadano = User.objects.create_user('vecina', password='clave12345')
        self.ciudadano.groups.add(Group.objects.get_or_create(name='Ciudadano')[0])

        self.usuario_recolector = User.objects.create_user('reco', password='clave12345')
        self.usuario_recolector.groups.add(
            Group.objects.get_or_create(name='Recolector')[0]
        )

        self.solicitud = self.crear_solicitud()

    def crear_solicitud(self, latitud=CENTRO[0], longitud=CENTRO[1], **extra):
        campos = {
            'usuario': self.ciudadano,
            'tipo_material': 'carton',
            'foto': foto(),
            'latitud': latitud,
            'longitud': longitud,
            'direccion_referencia': 'Av. Siempre Viva 742',
            'precio': Decimal('5.00'),
            'telefono_contacto': '+59170000000',
        }
        campos.update(extra)
        return SolicitudRetiro.objects.create(**campos)

    def autenticar_recolector(self):
        self.client.force_authenticate(self.usuario_recolector)

    def autenticar_ciudadano(self):
        self.client.force_authenticate(self.ciudadano)

    def avanzar_a_en_camino(self, solicitud):
        """
        `completar()` exige `estado == EN_CAMINO` — recorre coordinación de
        franja + `en-camino` para dejar la solicitud en condiciones de
        completarse. Asume que ya está `aceptada` por `self.usuario_recolector`.
        Deja autenticado al recolector al salir.
        """
        inicio, fin = _franja()
        self.autenticar_recolector()
        self.client.post(
            f'/api/solicitudes/{solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin},
            format='json',
        )
        self.autenticar_ciudadano()
        self.client.post(f'/api/solicitudes/{solicitud.id}/aceptar-franja/', {}, format='json')
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{solicitud.id}/en-camino/', {}, format='json')


class TestRecolectorPerfil(PickerAPITestCase):
    def test_perfil_se_crea_bajo_demanda(self):
        self.autenticar_recolector()

        respuesta = self.client.get('/api/recolector/perfil/')

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['usuario_nombre'], 'reco')
        self.assertEqual(respuesta.data['total_completadas'], 0)
        self.assertTrue(Recolector.objects.filter(usuario=self.usuario_recolector).exists())

    def test_ciudadano_no_accede_al_perfil_de_recolector(self):
        self.autenticar_ciudadano()

        respuesta = self.client.get('/api/recolector/perfil/')

        self.assertEqual(respuesta.status_code, status.HTTP_403_FORBIDDEN)

    def test_actualizar_ubicacion(self):
        self.autenticar_recolector()

        respuesta = self.client.post(
            '/api/recolector/ubicacion/',
            {'latitud': '-17.393700', 'longitud': '-66.157000'},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        perfil = Recolector.objects.get(usuario=self.usuario_recolector)
        self.assertEqual(perfil.latitud_actual, CENTRO[0])

    def test_ubicacion_sin_coordenadas_es_400(self):
        self.autenticar_recolector()

        respuesta = self.client.post('/api/recolector/ubicacion/', {}, format='json')

        self.assertEqual(respuesta.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cambiar_disponibilidad(self):
        self.autenticar_recolector()

        respuesta = self.client.post(
            '/api/recolector/disponibilidad/', {'es_activo': True}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertTrue(respuesta.data['es_activo'])
        self.assertTrue(Recolector.objects.get(usuario=self.usuario_recolector).es_activo)


class TestSolicitudesCercanas(PickerAPITestCase):
    def consultar(self, radio_km=5):
        return self.client.get(
            '/api/solicitudes/cercanas/',
            {'latitud': str(CENTRO[0]), 'longitud': str(CENTRO[1]), 'radio_km': radio_km},
        )

    def test_devuelve_pendientes_con_distancia(self):
        self.autenticar_recolector()

        respuesta = self.consultar()

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(len(respuesta.data), 1)
        item = respuesta.data[0]
        self.assertEqual(item['id'], self.solicitud.id)
        self.assertEqual(item['tipo_material_display'], 'Cartón')
        self.assertEqual(item['distancia_km'], 0.0)
        self.assertEqual(item['telefono_contacto'], '+59170000000')

    def test_excluye_solicitudes_fuera_del_radio(self):
        # ~11 km al norte: fuera de un radio de 5 km.
        self.crear_solicitud(latitud=Decimal('-17.293700'))
        self.autenticar_recolector()

        respuesta = self.consultar(radio_km=5)

        self.assertEqual([s['id'] for s in respuesta.data], [self.solicitud.id])

    def test_ordena_de_mas_cercana_a_mas_lejana(self):
        lejana = self.crear_solicitud(latitud=Decimal('-17.410700'))  # ~1.9 km
        self.autenticar_recolector()

        respuesta = self.consultar()

        self.assertEqual(
            [s['id'] for s in respuesta.data], [self.solicitud.id, lejana.id]
        )

    def test_excluye_solicitudes_ya_asignadas(self):
        self.solicitud.recolector = Recolector.para_usuario(self.usuario_recolector)
        self.solicitud.estado = EstadoSolicitud.ACEPTADA
        self.solicitud.save()
        self.autenticar_recolector()

        respuesta = self.consultar()

        self.assertEqual(respuesta.data, [])

    def test_no_reofrece_lo_que_el_recolector_rechazo(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/rechazar/', {}, format='json')

        respuesta = self.consultar()

        self.assertEqual(respuesta.data, [])

    def test_sin_coordenadas_es_400(self):
        self.autenticar_recolector()

        respuesta = self.client.get('/api/solicitudes/cercanas/')

        self.assertEqual(respuesta.status_code, status.HTTP_400_BAD_REQUEST)

    def test_ciudadano_no_puede_consultar_cercanas(self):
        self.autenticar_ciudadano()

        respuesta = self.consultar()

        self.assertEqual(respuesta.status_code, status.HTTP_403_FORBIDDEN)


class TestAceptarSolicitud(PickerAPITestCase):
    def test_aceptar_asigna_y_crea_asignacion(self):
        self.autenticar_recolector()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_201_CREATED)
        self.assertEqual(respuesta.data['estado'], 'aceptada')
        self.assertEqual(respuesta.data['solicitud']['id'], self.solicitud.id)

        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado, EstadoSolicitud.ACEPTADA)
        self.assertEqual(self.solicitud.recolector.usuario, self.usuario_recolector)

    def test_segundo_recolector_recibe_conflicto(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

        otro = User.objects.create_user('reco2', password='clave12345')
        otro.groups.add(Group.objects.get(name='Recolector'))
        self.client.force_authenticate(otro)

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)

    def test_rechazar_no_cambia_el_estado_de_la_solicitud(self):
        self.autenticar_recolector()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/rechazar/',
            {'motivo': 'Muy lejos de mi ruta'},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_201_CREATED)
        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado, EstadoSolicitud.PENDIENTE)
        self.assertIsNone(self.solicitud.recolector)

        asignacion = AsignacionRetiro.objects.get(solicitud=self.solicitud)
        self.assertEqual(asignacion.estado, AsignacionRetiro.Estado.RECHAZADA)
        self.assertEqual(asignacion.notas, 'Muy lejos de mi ruta')


class TestCompletarSolicitud(PickerAPITestCase):
    def test_completar_actualiza_estado_y_contador(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(self.solicitud)

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['estado'], 'completada')
        self.assertIsNotNone(respuesta.data['completada_en'])

        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado, EstadoSolicitud.COMPLETADA)

        perfil = Recolector.objects.get(usuario=self.usuario_recolector)
        self.assertEqual(perfil.total_completadas, 1)

    def test_no_se_puede_completar_una_solicitud_ajena(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

        otro = User.objects.create_user('reco2', password='clave12345')
        otro.groups.add(Group.objects.get(name='Recolector'))
        self.client.force_authenticate(otro)

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_403_FORBIDDEN)

    def test_completar_dos_veces_es_conflicto(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(self.solicitud)
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)

    def test_completar_sin_peso_es_error(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(self.solicitud)

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_400_BAD_REQUEST)

    def test_no_se_puede_completar_antes_de_estar_en_camino(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)
        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado, EstadoSolicitud.ACEPTADA)


class TestListadosDelRecolector(PickerAPITestCase):
    def test_aceptadas_y_completadas_se_separan(self):
        self.autenticar_recolector()
        otra = self.crear_solicitud()

        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.client.post(f'/api/solicitudes/{otra.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(otra)
        self.client.post(
            f'/api/solicitudes/{otra.id}/completar/', {'peso_kg': '2.0'}, format='json'
        )

        aceptadas = self.client.get('/api/recolector/solicitudes-aceptadas/')
        completadas = self.client.get('/api/recolector/solicitudes-completadas/')

        self.assertEqual(
            [a['solicitud']['id'] for a in aceptadas.data], [self.solicitud.id]
        )
        self.assertEqual([a['solicitud']['id'] for a in completadas.data], [otra.id])


class TestDetalleSolicitud(PickerAPITestCase):
    def test_recolector_ve_el_detalle_de_una_solicitud_ajena_disponible(self):
        self.autenticar_recolector()

        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['ciudadano_nombre'], 'vecina')
        self.assertEqual(respuesta.data['precio'], '5.00')

    def test_ciudadano_no_ve_solicitudes_de_otro_ciudadano(self):
        otro_ciudadano = User.objects.create_user('otra', password='clave12345')
        self.client.force_authenticate(otro_ciudadano)

        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertEqual(respuesta.status_code, status.HTTP_404_NOT_FOUND)

    def test_el_ciudadano_ve_al_recolector_asignado(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

        self.autenticar_ciudadano()
        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['recolector']['nombre'], 'reco')


class TestPerfilActual(PickerAPITestCase):
    def test_me_devuelve_el_rol_del_usuario(self):
        self.autenticar_recolector()

        respuesta = self.client.get('/api/auth/me/')

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['rol'], 'Recolector')
        self.assertEqual(respuesta.data['username'], 'reco')

    def test_me_requiere_autenticacion(self):
        respuesta = self.client.get('/api/auth/me/')

        self.assertEqual(respuesta.status_code, status.HTTP_401_UNAUTHORIZED)


def _franja(horas_desde_ahora=24, duracion_horas=3):
    inicio = timezone.now() + timezone.timedelta(hours=horas_desde_ahora)
    fin = inicio + timezone.timedelta(hours=duracion_horas)
    return inicio.isoformat(), fin.isoformat()


class TestCoordinacionFranja(PickerAPITestCase):
    """Flujo 4 — propuesta/contrapropuesta/confirmación de franja horaria."""

    def setUp(self):
        super().setUp()
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

    def test_ciudadano_propone_franja(self):
        inicio, fin = _franja()
        self.autenticar_ciudadano()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin, 'notas_entrega': 'Tocar timbre'},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['estado_coordinacion'], 'propuesta_ciudadano')
        self.assertEqual(respuesta.data['notas_entrega'], 'Tocar timbre')

        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado_coordinacion, EstadoCoordinacion.PROPUESTA_CIUDADANO)

    def test_recolector_propone_franja(self):
        inicio, fin = _franja()
        self.autenticar_recolector()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado_coordinacion, EstadoCoordinacion.PROPUESTA_RECOLECTOR)
        # Solo el ciudadano puede fijar las indicaciones de entrega.
        self.assertEqual(self.solicitud.notas_entrega, '')

    def test_tercero_no_puede_proponer_franja(self):
        # Un usuario sin rol de Recolector ni dueño de la solicitud ni
        # siquiera la encuentra — mismo criterio que `PuedeVerSolicitud` en
        # el resto de la API (no revela que el recurso existe).
        inicio, fin = _franja()
        otro = User.objects.create_user('otra', password='clave12345')
        self.client.force_authenticate(otro)

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_404_NOT_FOUND)

    def test_rechaza_ventana_invertida(self):
        inicio, fin = _franja()
        self.autenticar_ciudadano()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': fin, 'ventana_fin': inicio},
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_400_BAD_REQUEST)

    def test_aceptar_franja_propia_es_conflicto(self):
        inicio, fin = _franja()
        self.autenticar_ciudadano()
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin},
            format='json',
        )

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/aceptar-franja/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)

    def test_recolector_acepta_la_propuesta_del_ciudadano(self):
        inicio, fin = _franja()
        self.autenticar_ciudadano()
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin},
            format='json',
        )

        self.autenticar_recolector()
        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/aceptar-franja/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['estado_coordinacion'], 'confirmada')
        self.solicitud.refresh_from_db()
        self.assertIsNotNone(self.solicitud.franja_confirmada_en)


class TestEnCamino(PickerAPITestCase):
    def setUp(self):
        super().setUp()
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

    def _confirmar_franja(self):
        inicio, fin = _franja()
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/proponer-franja/',
            {'ventana_inicio': inicio, 'ventana_fin': fin},
            format='json',
        )
        self.autenticar_ciudadano()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar-franja/', {}, format='json')
        self.autenticar_recolector()

    def test_sin_franja_confirmada_es_conflicto(self):
        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/en-camino/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)

    def test_con_franja_confirmada_pasa_a_en_camino(self):
        self._confirmar_franja()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/en-camino/', {}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['estado'], 'en_camino')

        self.solicitud.refresh_from_db()
        self.assertEqual(self.solicitud.estado, EstadoSolicitud.EN_CAMINO)
        asignacion = AsignacionRetiro.objects.get(solicitud=self.solicitud)
        self.assertIsNotNone(asignacion.en_camino_en)


class TestCalificar(PickerAPITestCase):
    def setUp(self):
        super().setUp()
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(self.solicitud)
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

    def test_no_se_puede_calificar_antes_de_completar(self):
        otra = self.crear_solicitud()
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{otra.id}/aceptar/', {}, format='json')

        self.autenticar_ciudadano()
        respuesta = self.client.post(
            f'/api/solicitudes/{otra.id}/calificar/', {'calificacion': 5}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)

    def test_calificacion_fuera_de_rango_es_400(self):
        self.autenticar_ciudadano()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/calificar/', {'calificacion': 6}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_400_BAD_REQUEST)

    def test_califica_correctamente_y_no_bloquea_los_ecopuntos(self):
        self.autenticar_ciudadano()

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/calificar/',
            {
                'calificacion': 5,
                'etiquetas': ['Puntual', 'Amable y respetuoso'],
                'comentario': 'Excelente atención',
            },
            format='json',
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['calificacion'], 5)
        self.assertEqual(respuesta.data['calificacion_etiquetas'], ['Puntual', 'Amable y respetuoso'])

        asignacion = AsignacionRetiro.objects.get(solicitud=self.solicitud)
        self.assertEqual(asignacion.calificacion, 5)

        # Los EcoPuntos ya se acreditaron al completar, no dependen de esto.
        from gamificacion.models import TransaccionEcoPuntos
        self.assertTrue(TransaccionEcoPuntos.objects.filter(solicitud=self.solicitud).exists())

    def test_no_se_puede_calificar_dos_veces(self):
        self.autenticar_ciudadano()
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/calificar/', {'calificacion': 4}, format='json'
        )

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/calificar/', {'calificacion': 2}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_409_CONFLICT)

    def test_otro_usuario_no_puede_calificar(self):
        otro = User.objects.create_user('otra', password='clave12345')
        self.client.force_authenticate(otro)

        respuesta = self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/calificar/', {'calificacion': 5}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_404_NOT_FOUND)


class TestRecolectorResumenCalificacionPromedio(PickerAPITestCase):
    def test_sin_calificaciones_es_none(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

        self.autenticar_ciudadano()
        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertIsNone(respuesta.data['recolector']['calificacion_promedio'])

    def test_promedio_correcto_con_varias_calificaciones(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(self.solicitud)
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        otra = self.crear_solicitud()
        self.client.post(f'/api/solicitudes/{otra.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(otra)
        self.client.post(f'/api/solicitudes/{otra.id}/completar/', {'peso_kg': '1.0'}, format='json')

        self.autenticar_ciudadano()
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/calificar/', {'calificacion': 5}, format='json'
        )
        self.client.post(f'/api/solicitudes/{otra.id}/calificar/', {'calificacion': 3}, format='json')

        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertEqual(respuesta.data['recolector']['calificacion_promedio'], 4.0)


class TestPuntosAcreditados(PickerAPITestCase):
    def test_ciudadano_ve_los_puntos_acreditados_por_su_retiro(self):
        self.autenticar_recolector()
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')
        self.avanzar_a_en_camino(self.solicitud)
        self.client.post(
            f'/api/solicitudes/{self.solicitud.id}/completar/', {'peso_kg': '3.5'}, format='json'
        )

        self.autenticar_ciudadano()
        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        from gamificacion.models import TransaccionEcoPuntos
        transaccion = TransaccionEcoPuntos.objects.get(solicitud=self.solicitud)
        self.assertEqual(respuesta.data['puntos_acreditados'], transaccion.puntos)

    def test_null_antes_de_completar(self):
        self.autenticar_ciudadano()

        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertIsNone(respuesta.data['puntos_acreditados'])


class TestTelefonoRecolector(PickerAPITestCase):
    def test_recolector_registra_su_telefono(self):
        self.autenticar_recolector()

        respuesta = self.client.post(
            '/api/recolector/telefono/', {'telefono': '+59170000001'}, format='json'
        )

        self.assertEqual(respuesta.status_code, status.HTTP_200_OK)
        self.assertEqual(respuesta.data['telefono'], '+59170000001')

        perfil = Recolector.objects.get(usuario=self.usuario_recolector)
        self.assertEqual(perfil.telefono, '+59170000001')

    def test_el_ciudadano_ve_el_telefono_del_recolector_asignado(self):
        self.autenticar_recolector()
        self.client.post('/api/recolector/telefono/', {'telefono': '+59170000001'}, format='json')
        self.client.post(f'/api/solicitudes/{self.solicitud.id}/aceptar/', {}, format='json')

        self.autenticar_ciudadano()
        respuesta = self.client.get(f'/api/solicitudes/{self.solicitud.id}/')

        self.assertEqual(respuesta.data['recolector']['telefono'], '+59170000001')
