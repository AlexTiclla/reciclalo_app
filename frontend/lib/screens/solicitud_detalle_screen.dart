import 'package:flutter/material.dart';

import '../models/solicitud.dart';
import '../services/api_client.dart';
import '../services/solicitudes_service.dart';
import '../widgets/solicitud_card.dart';

class SolicitudDetalleScreen extends StatefulWidget {
  const SolicitudDetalleScreen({super.key, required this.solicitudId});

  final int solicitudId;

  @override
  State<SolicitudDetalleScreen> createState() => _SolicitudDetalleScreenState();
}

class _SolicitudDetalleScreenState extends State<SolicitudDetalleScreen> {
  late final Future<Solicitud> _solicitud;

  @override
  void initState() {
    super.initState();
    _solicitud = SolicitudesService(ApiClient.instance).obtener(widget.solicitudId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: SafeArea(
        child: FutureBuilder<Solicitud>(
          future: _solicitud,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('No pudimos cargar la solicitud.\n${snapshot.error}'));
            }
            final solicitud = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: solicitud.fotoUrl.isNotEmpty
                        ? Image.network(solicitud.fotoUrl, fit: BoxFit.cover)
                        : Container(color: Colors.grey.shade200),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(solicitud.tipoMaterial.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                    EstadoChip(estado: solicitud.estado),
                  ],
                ),
                Text('Solicitud #${solicitud.id}', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                if (solicitud.recolector != null) ...[
                  const Text('Recolector asignado', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Text(solicitud.recolector!.nombre),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                const Text('Ubicación de retiro', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  solicitud.direccionReferencia.isNotEmpty
                      ? solicitud.direccionReferencia
                      : '${solicitud.latitud}, ${solicitud.longitud}',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
