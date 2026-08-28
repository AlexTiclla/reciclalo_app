import 'package:flutter/material.dart';

import '../../models/asignacion_retiro.dart';
import '../../services/api_client.dart';
import '../../services/picker_events.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/asignacion_card.dart';
import 'post_accept_screen.dart';

/// Retiros que el recolector aceptó y todavía no cierra.
class MisRutasScreen extends StatefulWidget {
  const MisRutasScreen({super.key});

  @override
  State<MisRutasScreen> createState() => _MisRutasScreenState();
}

class _MisRutasScreenState extends State<MisRutasScreen> {
  final _pickerService = PickerService(ApiClient.instance);
  late Future<List<AsignacionRetiro>> _futuro = _pickerService.solicitudesAceptadas();

  @override
  void initState() {
    super.initState();
    // El IndexedStack del shell mantiene esta pantalla viva entre pestañas,
    // así que sin este aviso no se entera cuando se acepta o completa una
    // solicitud desde el mapa o el detalle.
    PickerEvents.instance.addListener(_recargar);
  }

  @override
  void dispose() {
    PickerEvents.instance.removeListener(_recargar);
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _futuro = _pickerService.solicitudesAceptadas();
    });
    await _futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Rutas')),
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
                mensaje: 'No se pudieron cargar tus rutas.\n${snapshot.error}',
              );
            }

            final asignaciones = snapshot.data ?? const [];
            if (asignaciones.isEmpty) {
              return const _ListaDesplazable(
                child: ListaVacia(
                  icono: Icons.directions_run_outlined,
                  mensaje: 'No tienes retiros pendientes.\n'
                      'Acepta una solicitud desde el mapa para empezar.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(EcoSpacing.container),
              itemCount: asignaciones.length,
              separatorBuilder: (_, _) => const SizedBox(height: EcoSpacing.element),
              itemBuilder: (context, indice) {
                final asignacion = asignaciones[indice];
                return AsignacionCard(
                  asignacion: asignacion,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostAcceptScreen(
                          solicitud: asignacion.solicitud,
                        ),
                      ),
                    );
                    await _recargar();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Envuelve el estado vacío para que `RefreshIndicator` siga funcionando.
class _ListaDesplazable extends StatelessWidget {
  const _ListaDesplazable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: restricciones.maxHeight, child: child),
      ),
    );
  }
}
