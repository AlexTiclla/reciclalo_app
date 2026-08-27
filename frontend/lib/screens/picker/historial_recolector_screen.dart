import 'package:flutter/material.dart';

import '../../models/asignacion_retiro.dart';
import '../../services/api_client.dart';
import '../../services/picker_events.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/asignacion_card.dart';

/// Retiros ya completados por el recolector, del más reciente al más antiguo.
class HistorialRecolectorScreen extends StatefulWidget {
  const HistorialRecolectorScreen({super.key});

  @override
  State<HistorialRecolectorScreen> createState() =>
      _HistorialRecolectorScreenState();
}

class _HistorialRecolectorScreenState extends State<HistorialRecolectorScreen> {
  final _pickerService = PickerService(ApiClient.instance);
  late Future<List<AsignacionRetiro>> _futuro = _pickerService.historial();

  @override
  void initState() {
    super.initState();
    // El IndexedStack del shell mantiene esta pantalla viva entre pestañas,
    // así que sin este aviso no se entera cuando se completa una solicitud.
    PickerEvents.instance.addListener(_recargar);
  }

  @override
  void dispose() {
    PickerEvents.instance.removeListener(_recargar);
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _futuro = _pickerService.historial();
    });
    await _futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: FutureBuilder<List<AsignacionRetiro>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListaVacia(
                icono: Icons.error_outline,
                mensaje: 'No se pudo cargar tu historial.\n${snapshot.error}',
              );
            }

            final asignaciones = snapshot.data ?? const [];
            if (asignaciones.isEmpty) {
              return const ListaVacia(
                icono: Icons.history_outlined,
                mensaje: 'Todavía no completaste ningún retiro.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(EcoSpacing.container),
              itemCount: asignaciones.length,
              separatorBuilder: (_, _) => const SizedBox(height: EcoSpacing.element),
              itemBuilder: (context, indice) =>
                  AsignacionCard(asignacion: asignaciones[indice]),
            );
          },
        ),
      ),
    );
  }
}
