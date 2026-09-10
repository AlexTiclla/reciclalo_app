import 'package:flutter/material.dart';

import '../models/evento_pendiente.dart';
import '../models/solicitud.dart';
import '../routing_coordinacion.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/gamificacion_service.dart';
import '../services/solicitudes_service.dart';
import '../widgets/eco_app_bar.dart';
import '../widgets/ecopuntos_modal.dart';
import '../widgets/hito_racha_modal.dart';
import '../widgets/solicitud_card.dart';
import 'auth/login_screen.dart';
import 'historial_screen.dart';
import 'perfil_ciudadano_screen.dart';
import 'recompensas_screen.dart';
import 'solicitud_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Las pestañas reales (Inicio, Historial, Recompensas); "Nuevo" no es una
// pestaña, solo abre el formulario como pantalla independiente. El Perfil ya
// no es pestaña: se accede desde el ícono de la esquina superior derecha.
const _destinoInicio = 0;
const _destinoNuevo = 1;
const _destinoHistorial = 2;
const _destinoRecompensas = 3;

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = _destinoInicio;
  final _gamificacionService = GamificacionService(ApiClient.instance);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarEventosPendientes());
  }

  Future<void> _mostrarEventosPendientes() async {
    List<EventoPendiente> eventos;
    try {
      eventos = await _gamificacionService.eventosPendientes();
    } catch (_) {
      return;
    }

    for (final evento in eventos) {
      if (!mounted) return;
      if (evento.tipo == TipoEventoPendiente.acreditacion) {
        await EcoPuntosModal.mostrar(
          context,
          puntos: evento.payload['puntos'] as int,
          saldoTotal: evento.payload['saldo_total'] as int,
          onVerRecompensas: () => setState(() => _tabIndex = _destinoRecompensas),
        );
      } else {
        await HitoRachaModal.mostrar(
          context,
          rachaSemanas: evento.payload['racha_semanas'] as int,
          puntos: evento.payload['puntos'] as int,
          onExplorarRecompensas: () => setState(() => _tabIndex = _destinoRecompensas),
        );
      }
      await _gamificacionService.marcarEventoVisto(evento.id);
    }
  }

  void _cerrarSesion() {
    AuthService(ApiClient.instance).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _abrirPerfil() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerfilCiudadanoScreen(onCerrarSesion: _cerrarSesion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      _destinoInicio: const _HomeTab(),
      _destinoHistorial: const HistorialScreen(),
      _destinoRecompensas: RecompensasScreen(onAbrirPerfil: _abrirPerfil),
    };

    // RecompensasScreen ya trae su propio EcoAppBar; el resto comparte uno.
    final mostrarAppBarPropio = _tabIndex != _destinoRecompensas;

    return Scaffold(
      appBar: mostrarAppBarPropio
          ? EcoAppBar(
              titulo: _tabIndex == _destinoHistorial ? 'Historial' : 'Inicio',
              onAbrirPerfil: _abrirPerfil,
            )
          : null,
      body: SafeArea(child: tabs[_tabIndex]!),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) async {
          if (index == _destinoNuevo) {
            final creado = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const SolicitudFormScreen()),
            );
            if (creado == true) setState(() => _tabIndex = _destinoInicio);
            return;
          }
          setState(() => _tabIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Nuevo'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), label: 'Recompensas'),
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
    setState(() {
      _activas = _service.listarActivas();
    });
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
                          await abrirCoordinacion(context, solicitud);
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
