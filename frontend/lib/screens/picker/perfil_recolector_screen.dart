import 'package:flutter/material.dart';

import '../../models/perfil_recolector.dart';
import '../../services/api_client.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/asignacion_card.dart';

/// Perfil del recolector: disponibilidad, retiros completados y cierre de sesión.
class PerfilRecolectorScreen extends StatefulWidget {
  const PerfilRecolectorScreen({super.key, required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  State<PerfilRecolectorScreen> createState() => _PerfilRecolectorScreenState();
}

class _PerfilRecolectorScreenState extends State<PerfilRecolectorScreen> {
  final _pickerService = PickerService(ApiClient.instance);

  PerfilRecolector? _perfil;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final perfil = await _pickerService.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _cambiarDisponibilidad(bool esActivo) async {
    setState(() => _guardando = true);
    try {
      await _pickerService.cambiarDisponibilidad(esActivo);
      await _cargar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar tu disponibilidad: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _error != null
            ? ListaVacia(icono: Icons.error_outline, mensaje: _error!)
            : perfil == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(EcoSpacing.container),
                    children: [
                      _Cabecera(perfil: perfil),
                      const SizedBox(height: EcoSpacing.section),
                      Card(
                        child: SwitchListTile(
                          value: perfil.esActivo,
                          onChanged: _guardando ? null : _cambiarDisponibilidad,
                          activeThumbColor: EcoColors.primary,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: EcoSpacing.stack,
                            vertical: EcoSpacing.element,
                          ),
                          title: Text('Disponible para recolectar',
                              style: textos.labelLarge
                                  ?.copyWith(color: EcoColors.onSurface)),
                          subtitle: Text(
                            perfil.esActivo
                                ? 'Estás recibiendo solicitudes cercanas.'
                                : 'No aparecerás como disponible.',
                            style: textos.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: EcoSpacing.section),
                      OutlinedButton.icon(
                        onPressed: widget.onCerrarSesion,
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.perfil});

  final PerfilRecolector perfil;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: EcoColors.secondaryContainer,
          ),
          child: const Icon(
            Icons.person,
            size: 40,
            color: EcoColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: EcoSpacing.stack),
        Text(perfil.usuarioNombre, style: textos.headlineMedium),
        const SizedBox(height: EcoSpacing.element),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: EcoSpacing.stack,
            vertical: EcoSpacing.element,
          ),
          decoration: BoxDecoration(
            color: EcoColors.mintLight,
            borderRadius: BorderRadius.circular(EcoRadius.lg),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.recycling, size: 18, color: EcoColors.primary),
              const SizedBox(width: EcoSpacing.element),
              Text(
                '${perfil.totalCompletadas} '
                '${perfil.totalCompletadas == 1 ? "retiro completado" : "retiros completados"}',
                style: textos.labelMedium?.copyWith(color: EcoColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
