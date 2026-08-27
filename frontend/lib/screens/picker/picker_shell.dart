import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'historial_recolector_screen.dart';
import 'mis_rutas_screen.dart';
import 'perfil_recolector_screen.dart';
import 'picker_map_screen.dart';

/// Contenedor con la barra inferior del recolector (Mapa / Mis Rutas /
/// Historial / Perfil). Es la pantalla raíz tras el login de un Recolector.
class PickerShell extends StatefulWidget {
  const PickerShell({super.key});

  @override
  State<PickerShell> createState() => _PickerShellState();
}

class _PickerShellState extends State<PickerShell> {
  int _indice = 0;


  void _cerrarSesion() {
    AuthService(ApiClient.instance).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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
          const PickerMapScreen(),
          const MisRutasScreen(),
          const HistorialRecolectorScreen(),
          PerfilRecolectorScreen(onCerrarSesion: _cerrarSesion),
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
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: EcoColors.onSecondaryContainer),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
