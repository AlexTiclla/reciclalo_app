"""Lógica de negocio de EcoPuntos, racha y canjes.

Mantiene a `solicitudes` desacoplado del modelo de puntos: esa app solo
llama a `acreditar_por_completado` desde su acción `completar`.
"""

import secrets
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from .models import (
    Canje,
    EventoPendiente,
    ProgresoRacha,
    Recompensa,
    RolRacha,
    SaldoEcoPuntos,
    TipoTransaccion,
    TransaccionEcoPuntos,
)
from .utils import calcular_impacto

# Tabla de hitos de racha -> bono de EcoPuntos, por rol (ver especificación
# funcional en docs/flujo-3-fidelizacion-gamificacion/).
HITOS_PUNTOS = {
    RolRacha.CIUDADANO: {2: 10, 4: 25, 8: 50, 12: 75, 26: 150, 52: 300},
    RolRacha.RECOLECTOR: {2: 5, 4: 12, 8: 25, 12: 40, 26: 75, 52: 150},
}
PROTECTORES_POR_MES = 2


class SaldoInsuficienteError(Exception):
    pass


def acreditar_por_completado(asignacion):
    """Acredita EcoPuntos al ciudadano dueño de la solicitud que se completó."""
    solicitud = asignacion.solicitud
    if solicitud.peso_kg is None:
        return

    puntos, co2_kg, agua_l = calcular_impacto(solicitud.tipo_material, solicitud.peso_kg)

    with transaction.atomic():
        saldo = SaldoEcoPuntos.para_usuario(solicitud.usuario)
        saldo = SaldoEcoPuntos.objects.select_for_update().get(pk=saldo.pk)
        saldo.saldo += puntos
        saldo.save(update_fields=['saldo', 'actualizado_en'])

        TransaccionEcoPuntos.objects.create(
            usuario=solicitud.usuario,
            tipo=TipoTransaccion.ACREDITACION,
            puntos=puntos,
            solicitud=solicitud,
        )
        EventoPendiente.objects.create(
            usuario=solicitud.usuario,
            tipo=EventoPendiente.Tipo.ACREDITACION,
            payload={
                'puntos': puntos,
                'saldo_total': saldo.saldo,
                'tipo_material': solicitud.tipo_material,
                'co2_kg': str(co2_kg),
                'agua_l': str(agua_l),
            },
        )


def _lunes_de(fecha):
    return fecha - timedelta(days=fecha.weekday())


def _primer_dia_del_mes(fecha):
    return fecha.replace(day=1)


def _progresos_a_evaluar():
    """
    Un `ProgresoRacha` por (usuario, rol) que tenga al menos una actividad
    relevante. Se crea bajo demanda, igual que `Recolector.para_usuario`.
    """
    from solicitudes.models import AsignacionRetiro, EstadoSolicitud, SolicitudRetiro

    hoy = timezone.localdate()

    usuarios_ciudadano = (
        SolicitudRetiro.objects.filter(estado=EstadoSolicitud.COMPLETADA)
        .values_list('usuario_id', flat=True)
        .distinct()
    )
    for usuario_id in usuarios_ciudadano:
        progreso, _ = ProgresoRacha.objects.get_or_create(
            usuario_id=usuario_id,
            rol=RolRacha.CIUDADANO,
            defaults={'mes_protectores': _primer_dia_del_mes(hoy)},
        )
        yield progreso

    usuarios_recolector = (
        AsignacionRetiro.objects.filter(estado=AsignacionRetiro.Estado.COMPLETADA)
        .values_list('recolector__usuario_id', flat=True)
        .distinct()
    )
    for usuario_id in usuarios_recolector:
        progreso, _ = ProgresoRacha.objects.get_or_create(
            usuario_id=usuario_id,
            rol=RolRacha.RECOLECTOR,
            defaults={'mes_protectores': _primer_dia_del_mes(hoy)},
        )
        yield progreso


def _hubo_actividad_en_semana(progreso, inicio_semana, fin_semana):
    from solicitudes.models import AsignacionRetiro, EstadoSolicitud, SolicitudRetiro

    if progreso.rol == RolRacha.CIUDADANO:
        return SolicitudRetiro.objects.filter(
            usuario_id=progreso.usuario_id,
            estado=EstadoSolicitud.COMPLETADA,
            actualizado_en__date__gte=inicio_semana,
            actualizado_en__date__lte=fin_semana,
        ).exists()

    return AsignacionRetiro.objects.filter(
        recolector__usuario_id=progreso.usuario_id,
        estado=AsignacionRetiro.Estado.COMPLETADA,
        completada_en__date__gte=inicio_semana,
        completada_en__date__lte=fin_semana,
    ).exists()


def _recargar_protectores_si_toca(progreso, hoy):
    mes_actual = _primer_dia_del_mes(hoy)
    if progreso.mes_protectores < mes_actual:
        progreso.protectores_disponibles = PROTECTORES_POR_MES
        progreso.mes_protectores = mes_actual


def _evaluar_hito(progreso):
    tabla = HITOS_PUNTOS[RolRacha(progreso.rol)]
    hitos_cruzados = sorted(
        h for h in tabla if progreso.ultimo_hito_acreditado < h <= progreso.racha_actual
    )
    if not hitos_cruzados:
        return

    hito = hitos_cruzados[-1]
    puntos = tabla[hito]

    saldo, _ = SaldoEcoPuntos.objects.get_or_create(usuario_id=progreso.usuario_id)
    saldo = SaldoEcoPuntos.objects.select_for_update().get(pk=saldo.pk)
    saldo.saldo += puntos
    saldo.save(update_fields=['saldo', 'actualizado_en'])

    TransaccionEcoPuntos.objects.create(
        usuario_id=progreso.usuario_id,
        tipo=TipoTransaccion.BONO_RACHA,
        puntos=puntos,
        racha_semanas=hito,
    )
    EventoPendiente.objects.create(
        usuario_id=progreso.usuario_id,
        tipo=EventoPendiente.Tipo.HITO_RACHA,
        payload={'racha_semanas': hito, 'puntos': puntos, 'saldo_total': saldo.saldo},
    )

    progreso.ultimo_hito_acreditado = hito
    progreso.hito_pendiente_de_mostrar = hito


def cerrar_semana(progreso, hoy=None):
    """
    Evalúa y cierra la última semana completa transcurrida para `progreso`.
    Idempotente: si `semana_evaluada_hasta` ya cubre la semana en cuestión,
    no vuelve a aplicar sus efectos.
    """
    hoy = hoy or timezone.localdate()
    lunes_actual = _lunes_de(hoy)
    lunes_semana_a_cerrar = lunes_actual - timedelta(days=7)

    if progreso.semana_evaluada_hasta and progreso.semana_evaluada_hasta >= lunes_semana_a_cerrar:
        return  # Ya evaluada.

    with transaction.atomic():
        progreso = ProgresoRacha.objects.select_for_update().get(pk=progreso.pk)
        if (
            progreso.semana_evaluada_hasta
            and progreso.semana_evaluada_hasta >= lunes_semana_a_cerrar
        ):
            return

        domingo_semana_a_cerrar = lunes_semana_a_cerrar + timedelta(days=6)
        _recargar_protectores_si_toca(progreso, hoy)

        semana_cumplida = _hubo_actividad_en_semana(
            progreso, lunes_semana_a_cerrar, domingo_semana_a_cerrar
        )

        if semana_cumplida:
            progreso.racha_actual += 1
            progreso.racha_maxima = max(progreso.racha_maxima, progreso.racha_actual)
        elif progreso.protectores_disponibles > 0:
            progreso.protectores_disponibles -= 1
        else:
            progreso.racha_actual = 0

        _evaluar_hito(progreso)
        progreso.semana_evaluada_hasta = lunes_semana_a_cerrar
        progreso.save()


def cerrar_semana_para_todos(hoy=None):
    for progreso in _progresos_a_evaluar():
        cerrar_semana(progreso, hoy=hoy)


def proximo_hito(rol, racha_actual):
    tabla = HITOS_PUNTOS[RolRacha(rol)]
    pendientes = sorted(h for h in tabla if h > racha_actual)
    if not pendientes:
        return None, None
    hito = pendientes[0]
    return hito, tabla[hito]


def canjear_recompensa(usuario, recompensa_id):
    with transaction.atomic():
        recompensa = Recompensa.objects.select_for_update().filter(
            pk=recompensa_id, activa=True
        ).first()
        if recompensa is None:
            raise Recompensa.DoesNotExist('Recompensa no encontrada')

        saldo = SaldoEcoPuntos.para_usuario(usuario)
        saldo = SaldoEcoPuntos.objects.select_for_update().get(pk=saldo.pk)
        if saldo.saldo < recompensa.costo_puntos:
            raise SaldoInsuficienteError('Saldo insuficiente para este canje')

        saldo.saldo -= recompensa.costo_puntos
        saldo.save(update_fields=['saldo', 'actualizado_en'])

        canje = Canje.objects.create(
            usuario=usuario,
            recompensa=recompensa,
            puntos_gastados=recompensa.costo_puntos,
            codigo=_generar_codigo_canje(),
        )
        TransaccionEcoPuntos.objects.create(
            usuario=usuario,
            tipo=TipoTransaccion.CANJE,
            puntos=-recompensa.costo_puntos,
            canje=canje,
        )

    return canje, saldo.saldo


def _generar_codigo_canje():
    while True:
        codigo = f'ECO-{secrets.randbelow(9000) + 1000}'
        if not Canje.objects.filter(codigo=codigo).exists():
            return codigo


def obtener_impacto(usuario, rol):
    from solicitudes.models import AsignacionRetiro, EstadoSolicitud, SolicitudRetiro

    if rol == RolRacha.RECOLECTOR:
        retiros_completados = AsignacionRetiro.objects.filter(
            recolector__usuario=usuario, estado=AsignacionRetiro.Estado.COMPLETADA
        ).count()
        return {
            'co2_kg': '0.00',
            'agua_l': '0.00',
            'total_reciclado_kg': '0.00',
            'retiros_completados': retiros_completados,
        }

    solicitudes = SolicitudRetiro.objects.filter(
        usuario=usuario, estado=EstadoSolicitud.COMPLETADA, peso_kg__isnull=False
    )

    total_kg = 0
    co2_total = 0
    agua_total = 0
    for solicitud in solicitudes:
        _, co2_kg, agua_l = calcular_impacto(solicitud.tipo_material, solicitud.peso_kg)
        total_kg += solicitud.peso_kg
        co2_total += co2_kg
        agua_total += agua_l

    return {
        'co2_kg': str(co2_total),
        'agua_l': str(agua_total),
        'total_reciclado_kg': str(total_kg),
        'retiros_completados': solicitudes.count(),
    }
