import 'package:flutter/material.dart';

import '../models/solicitud.dart';
import '../services/api_client.dart';
import '../services/solicitudes_service.dart';
import '../widgets/solicitud_card.dart';
import 'historial_screen.dart';
import 'solicitud_detalle_screen.dart';
import 'solicitud_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [const _HomeTab(), const HistorialScreen()];

    return Scaffold(
      body: SafeArea(child: tabs[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex == 1 ? 2 : _tabIndex,
        onDestinationSelected: (index) async {
          if (index == 1) {
            final creado = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const SolicitudFormScreen()),
            );
            if (creado == true) setState(() => _tabIndex = 0);
            return;
          }
          setState(() => _tabIndex = index == 2 ? 1 : 0);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Nuevo'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _service = SolicitudesService(ApiClient.instance);
  late Future<List<Solicitud>> _activas;

  @override
  void initState() {
    super.initState();
    _activas = _service.listarActivas();
  }

  Future<void> _recargar() async {
    setState(() => _activas = _service.listarActivas());
    await _activas;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hola', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '¿Qué vamos a reciclar hoy?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mis Solicitudes Activas', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Solicitud>>(
            future: _activas,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No pudimos cargar tus solicitudes.\n${snapshot.error}'),
                );
              }
              final solicitudes = snapshot.data ?? [];
              if (solicitudes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No tienes solicitudes activas. Toca "+ Publicar Reciclaje" para crear una.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
              return Column(
                children: solicitudes
                    .map(
                      (solicitud) => SolicitudCard(
                        solicitud: solicitud,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SolicitudDetalleScreen(solicitudId: solicitud.id),
                            ),
                          );
                          _recargar();
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final creado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SolicitudFormScreen()),
              );
              if (creado == true) _recargar();
            },
            icon: const Icon(Icons.add),
            label: const Text('Publicar Reciclaje'),
          ),
        ],
      ),
    );
  }
}
