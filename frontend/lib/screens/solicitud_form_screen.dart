import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/solicitud.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../services/solicitudes_service.dart';
import '../widgets/material_selector.dart';
import 'confirmacion_screen.dart';

class SolicitudFormScreen extends StatefulWidget {
  const SolicitudFormScreen({super.key});

  @override
  State<SolicitudFormScreen> createState() => _SolicitudFormScreenState();
}

class _SolicitudFormScreenState extends State<SolicitudFormScreen> {
  final _service = SolicitudesService(ApiClient.instance);
  final _locationService = LocationService();
  final _picker = ImagePicker();
  final _direccionController = TextEditingController();

  int _paso = 0;
  TipoMaterial? _tipoMaterial;
  XFile? _foto;
  double? _latitud;
  double? _longitud;
  bool _obteniendoUbicacion = false;
  bool _publicando = false;
  String? _error;

  bool get _puedeContinuar {
    switch (_paso) {
      case 0:
        return _tipoMaterial != null;
      case 1:
        return _foto != null;
      case 2:
        return _latitud != null && _longitud != null;
      default:
        return false;
    }
  }

  Future<void> _tomarFoto(ImageSource source) async {
    final foto = await _picker.pickImage(source: source, imageQuality: 85);
    if (foto != null) setState(() => _foto = foto);
  }

  Future<void> _confirmarUbicacion() async {
    setState(() {
      _obteniendoUbicacion = true;
      _error = null;
    });
    try {
      final posicion = await _locationService.obtenerUbicacionActual();
      setState(() {
        _latitud = posicion.latitude;
        _longitud = posicion.longitude;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _publicar() async {
    setState(() {
      _publicando = true;
      _error = null;
    });
    try {
      await _service.publicar(
        tipoMaterial: _tipoMaterial!,
        fotoPath: _foto!.path,
        latitud: _latitud!,
        longitud: _longitud!,
        direccionReferencia: _direccionController.text.trim(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConfirmacionScreen()),
      );
    } catch (e) {
      setState(() => _error = 'No pudimos publicar tu solicitud. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  void _siguiente() {
    if (_paso < 2) {
      setState(() => _paso += 1);
    } else {
      _publicar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar Reciclaje')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PasosIndicador(paso: _paso),
              const SizedBox(height: 24),
              Expanded(child: _pasoActual()),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: (_puedeContinuar && !_publicando && !_obteniendoUbicacion)
                    ? _siguiente
                    : null,
                child: _publicando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_paso < 2 ? 'Continuar' : 'Publicar Retiro'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pasoActual() {
    switch (_paso) {
      case 0:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('¿Qué vas a reciclar?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              MaterialSelector(
                seleccionado: _tipoMaterial,
                onSeleccionar: (tipo) => setState(() => _tipoMaterial = tipo),
              ),
            ],
          ),
        );
      case 1:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Toma o sube una foto del paquete',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _tomarFoto(ImageSource.camera),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                  ),
                  child: _foto == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade500),
                            const SizedBox(height: 8),
                            Text('Toca para tomar una foto', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_foto!.path), fit: BoxFit.cover, width: double.infinity),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _tomarFoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Subir desde galería'),
              ),
            ],
          ),
        );
      case 2:
      default:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Confirma tu ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _latitud != null
                              ? 'Ubicación GPS confirmada\n(${_latitud!.toStringAsFixed(5)}, ${_longitud!.toStringAsFixed(5)})'
                              : 'Aún no confirmas tu ubicación',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _obteniendoUbicacion ? null : _confirmarUbicacion,
                icon: _obteniendoUbicacion
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.gps_fixed),
                label: Text(_latitud != null ? 'Actualizar ubicación GPS' : 'Usar mi ubicación GPS'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: 'Referencia de dirección (opcional)',
                  prefixIcon: Icon(Icons.edit_location_alt_outlined),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _PasosIndicador extends StatelessWidget {
  const _PasosIndicador({required this.paso});

  final int paso;

  static const _titulos = ['Materiales', 'Evidencia', 'Ubicación'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_titulos.length, (i) {
        final activo = i <= paso;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: activo
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(color: activo ? Colors.white : Colors.grey.shade700, fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              Text(_titulos[i], style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      }),
    );
  }
}
