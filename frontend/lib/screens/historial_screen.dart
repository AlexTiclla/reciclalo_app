import 'package:flutter/material.dart';

import '../models/solicitud.dart';
import '../services/api_client.dart';
import '../services/solicitudes_service.dart';
import '../widgets/solicitud_card.dart';
import 'solicitud_detalle_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _service = SolicitudesService(ApiClient.instance);
  late Future<List<Solicitud>> _completadas;

  @override
  void initState() {
    super.initState();
    _completadas = _service.listarCompletadas();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _completadas = _service.listarCompletadas());
        await _completadas;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Historial de Reciclaje', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Tus contribuciones recientes', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          FutureBuilder<List<Solicitud>>(
            future: _completadas,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('No pudimos cargar el historial.\n${snapshot.error}');
              }
              final solicitudes = snapshot.data ?? [];
              if (solicitudes.isEmpty) {
                return Text(
                  'Aún no tienes retiros completados.',
                  style: TextStyle(color: Colors.grey.shade600),
                );
              }
              return Column(
                children: solicitudes
                    .map(
                      (solicitud) => SolicitudCard(
                        solicitud: solicitud,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SolicitudDetalleScreen(solicitudId: solicitud.id),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
