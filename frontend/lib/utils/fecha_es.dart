/// Formato de fechas en español para el Flujo 4 (coordinación y seguimiento),
/// sin depender del paquete `intl` — el resto del proyecto tampoco lo usa
/// (ver `SolicitudCard._formatFecha`).
library;

const _diasAbrev = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _diasCompletos = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String diaSemanaAbrev(DateTime fecha) => _diasAbrev[fecha.weekday - 1];

String diaSemanaCompleto(DateTime fecha) => _diasCompletos[fecha.weekday - 1];

String mesCompleto(DateTime fecha) => _meses[fecha.month - 1];

String horaCorta(DateTime fecha) {
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$hora:$minuto';
}

/// "Jueves 12 de Octubre" (Screen 2).
String fechaLarga(DateTime fecha) {
  final mes = mesCompleto(fecha);
  final mesCapitalizado = mes[0].toUpperCase() + mes.substring(1);
  return '${diaSemanaCompleto(fecha)} ${fecha.day} de $mesCapitalizado';
}

/// "Jue 12 · 16:20" (Screen 4).
String fechaHoraCorta(DateTime fecha) {
  return '${diaSemanaAbrev(fecha)[0].toUpperCase()}${diaSemanaAbrev(fecha).substring(1)} '
      '${fecha.day} · ${horaCorta(fecha)}';
}

/// Etiqueta relativa de día para chips ("Hoy, jue 12"), solo para hoy/mañana;
/// cualquier otro día usa el nombre completo abreviado ("Sáb 14").
String etiquetaDia(DateTime fecha, DateTime hoy) {
  final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final diferencia = soloFecha.difference(soloHoy).inDays;

  final abrev = diaSemanaAbrev(fecha);
  if (diferencia == 0) return 'Hoy, $abrev ${fecha.day}';
  if (diferencia == 1) return 'Mañana, $abrev ${fecha.day}';
  return '${abrev[0].toUpperCase()}${abrev.substring(1)} ${fecha.day}';
}

/// "hace 3 min" / "hace 2 h" — usado en Screen 3 ("Actualizado hace 3 min").
String haceTiempo(DateTime fecha, {DateTime? ahora}) {
  final referencia = ahora ?? DateTime.now();
  final diferencia = referencia.difference(fecha);
  if (diferencia.inMinutes < 1) return 'hace un momento';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  return 'hace ${diferencia.inDays} d';
}
