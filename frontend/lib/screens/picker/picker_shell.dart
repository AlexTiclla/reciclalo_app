import 'package:flutter/material.dart';

import '../../models/evento_pendiente.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/gamificacion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ecopuntos_modal.dart';
import '../../widgets/hito_racha_modal.dart';
import '../auth/login_screen.dart';
import '../recompensas_screen.dart';
import 'historial_recolector_screen.dart';
import 'mis_rutas_screen.dart';
import 'perfil_recolector_screen.dart';
import 'picker_map_screen.dart';

const _indiceMapa = 0;
const _indiceRecompensas = 3;

/// Contenedor con la barra inferior del recolector (Mapa / Mis Rutas /
/// Historial / Recompensas). Es la pantalla raíz tras el login de un
/// Recolector. El Perfil ya no es pestaña: se accede desde el ícono de
/// perfil de cada pantalla.
class PickerShell extends StatefulWidget {
  const PickerShell({super.key});

  @override
  State<PickerShell> createState() => _PickerShellState();
}

class _PickerShellState extends State<PickerShell> {
  int _indice = _indiceMapa;
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
          onVerRecompensas: () => setState(() => _indice = _indiceRecompensas),
        );
      } else {
        await HitoRachaModal.mostrar(
          context,
          rachaSemanas: evento.payload['racha_semanas'] as int,
          puntos: evento.payload['puntos'] as int,
          onExplorarRecompensas: () => setState(() => _indice = _indiceRecompensas),
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
        builder: (_) => PerfilRecolectorScreen(onCerrarSesion: _cerrarSesion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene vivas las pestañas: cambiar de sección no
      // reinicia el mapa ni vuelve a pedir el GPS.
      body: IndexedStack(
        index: _indice,
        children: [
          PickerMapScreen(onAbrirPerfil: _abrirPerfil),
          MisRutasScreen(onAbrirPerfil: _abrirPerfil),
          HistorialRecolectorScreen(onAbrirPerfil: _abrirPerfil),
          RecompensasScreen(onAbrirPerfil: _abrirPerfil),
        ],
      ),
      bottomNavigationBar: _BarraRecolector(
        indice: _indice,
        onSeleccionar: (indice) => setState(() => _indice = indice),
      ),
    );
  }
}

class _BarraRecolector extends StatelessWidget {
  const _BarraRecolector({
    required this.indice,
    required this.onSeleccionar,
  });

  final int indice;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EcoColors.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
        boxShadow: EcoShadows.sheet,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(EcoRadius.xl),
        ),
        child: NavigationBar(
          selectedIndex: indice,
          onDestinationSelected: onSeleccionar,
          backgroundColor: EcoColors.surfaceContainer,
          indicatorColor: EcoColors.secondaryContainer,
          surfaceTintColor: Colors.transparent,
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map, color: EcoColors.onSecondaryContainer),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_run_outlined),
              selectedIcon: Icon(
                Icons.directions_run,
                color: EcoColors.onSecondaryContainer,
              ),
              label: 'Mis Rutas',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: EcoColors.onSecondaryContainer),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.card_giftcard_outlined),
              selectedIcon: Icon(Icons.card_giftcard, color: EcoColors.onSecondaryContainer),
              label: 'Recompensas',
            ),
          ],
        ),
      ),
    );
  }
}
