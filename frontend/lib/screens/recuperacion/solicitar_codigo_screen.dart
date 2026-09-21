import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/recuperacion_service.dart';
import '../../theme/app_theme.dart';
import 'verificar_codigo_screen.dart';

/// Flujo 5 — Paso 1: pide el usuario o correo para enviar el código OTP.
class SolicitarCodigoScreen extends StatefulWidget {
  const SolicitarCodigoScreen({super.key});

  @override
  State<SolicitarCodigoScreen> createState() => _SolicitarCodigoScreenState();
}

class _SolicitarCodigoScreenState extends State<SolicitarCodigoScreen> {
  final _recuperacionService = RecuperacionService(ApiClient.instance);
  final _identificadorController = TextEditingController();

  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _identificadorController.dispose();
    super.dispose();
  }

  bool get _puedeEnviar =>
      !_cargando && _identificadorController.text.trim().isNotEmpty;

  Future<void> _enviarCodigo() async {
    final identificador = _identificadorController.text.trim();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _recuperacionService.solicitarCodigo(identificador);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificarCodigoScreen(identificador: identificador),
        ),
      );
    } catch (_) {
      setState(() => _error = 'No pudimos enviar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpacing.container),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: EcoSpacing.section),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: EcoColors.mintLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mail_outline,
                    size: 36,
                    color: EcoColors.leafDark,
                  ),
                ),
              ),
              const SizedBox(height: EcoSpacing.container),
              Text(
                'Recupera tu contraseña',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: EcoSpacing.element),
              Text(
                'Te enviaremos un código de verificación a tu correo registrado.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: EcoColors.onSurfaceVariant),
              ),
              const SizedBox(height: EcoSpacing.section),
              TextField(
                controller: _identificadorController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Usuario o correo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: EcoSpacing.stack),
                Text(
                  _error!,
                  style: const TextStyle(color: EcoColors.dangerRed),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: EcoSpacing.container),
              FilledButton(
                onPressed: _puedeEnviar ? _enviarCodigo : null,
                child: _cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar código'),
              ),
              const SizedBox(height: EcoSpacing.container),
            ],
          ),
        ),
      ),
    );
  }
}
