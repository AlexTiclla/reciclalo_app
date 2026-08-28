import 'package:flutter/material.dart';

import '../models/solicitud.dart';

class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          color: estado.color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class SolicitudCard extends StatelessWidget {
  const SolicitudCard({super.key, required this.solicitud, required this.onTap});

  final Solicitud solicitud;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitulo = solicitud.recolector != null
        ? 'Recolector: ${solicitud.recolector!.nombre}'
        : (solicitud.direccionReferencia.isNotEmpty
            ? solicitud.direccionReferencia
            : 'Publicado ${_formatFecha(solicitud.creadoEn)}');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(solicitud.tipoMaterial.icon,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.tipoMaterial.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EstadoChip(estado: solicitud.estado),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
