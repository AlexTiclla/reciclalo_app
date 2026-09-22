import 'package:flutter/material.dart';

import '../../models/perfil_recolector.dart';
import '../../models/user_model.dart';
import '../../services/api_client.dart';
import '../../services/picker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/picker/asignacion_card.dart';
import '../mi_impacto_screen.dart';

/// Perfil del recolector: disponibilidad, retiros completados y cierre de sesión.
class PerfilRecolectorScreen extends StatefulWidget {
  const PerfilRecolectorScreen({super.key, required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  State<PerfilRecolectorScreen> createState() => _PerfilRecolectorScreenState();
}

class _PerfilRecolectorScreenState extends State<PerfilRecolectorScreen> {
  final _pickerService = PickerService(ApiClient.instance);
  final _telefonoController = TextEditingController();

  PerfilRecolector? _perfil;
  String? _error;
  bool _guardando = false;
  bool _guardandoTelefono = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardarTelefono() async {
    setState(() => _guardandoTelefono = true);
    try {
      final perfil = await _pickerService.actualizarTelefono(_telefonoController.text.trim());
      if (!mounted) return;
      setState(() => _perfil = perfil);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teléfono actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el teléfono: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardandoTelefono = false);
    }
  }

  Future<void> _cargar() async {
    try {
      final perfil = await _pickerService.obtenerPerfil();
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _error = null;
        _telefonoController.text = perfil.telefono;
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(EcoSpacing.stack),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Teléfono de contacto', style: textos.labelLarge),
                              const SizedBox(height: EcoSpacing.element),
                              Text(
                                'El ciudadano lo usa para contactarte por WhatsApp o llamada '
                                'mientras coordinan el retiro.',
                                style: textos.bodySmall,
                              ),
                              const SizedBox(height: EcoSpacing.stack),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _telefonoController,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(hintText: '+591 70000000'),
                                    ),
                                  ),
                                  const SizedBox(width: EcoSpacing.stack),
                                  FilledButton(
                                    onPressed: _guardandoTelefono ? null : _guardarTelefono,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, EcoSpacing.touchTarget),
                                    ),
                                    child: _guardandoTelefono
                                        ? const SizedBox(
                                            width: 18, height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2, color: EcoColors.onPrimary,
                                            ),
                                          )
                                        : const Text('Guardar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: EcoSpacing.section),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.eco, color: EcoColors.primary),
                          title: const Text('Mi Impacto y Racha'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MiImpactoScreen(rol: RolUsuario.recolector),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: EcoSpacing.stack),
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
