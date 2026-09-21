import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/recuperacion_service.dart';
import '../../theme/app_theme.dart';
import 'confirmacion_screen.dart';

/// Flujo 5 — Paso 3A: fija la nueva contraseña usando el token emitido al
/// verificar el código OTP (Paso 2). No vuelve a pedir el código.
class NuevaPasswordScreen extends StatefulWidget {
  const NuevaPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<NuevaPasswordScreen> createState() => _NuevaPasswordScreenState();
}

class _NuevaPasswordScreenState extends State<NuevaPasswordScreen> {
  final _recuperacionService = RecuperacionService(ApiClient.instance);
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _ocultarPassword = true;
  bool _ocultarConfirmar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  bool get _longitudValida => _passwordController.text.length >= 8;

  bool get _coinciden =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmarController.text;

  bool get _puedeGuardar => !_cargando && _longitudValida && _coinciden;

  Future<void> _guardar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _recuperacionService.restablecerPassword(
        widget.token,
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConfirmacionScreen()),
        (route) => route.isFirst,
      );
    } on TokenExpiradoException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No pudimos actualizar tu contraseña. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _itemChecklist(String texto, bool cumplido) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          cumplido ? Icons.check : Icons.circle,
          size: cumplido ? 16 : 6,
          color: cumplido ? EcoColors.leafDark : EcoColors.onSurfaceVariant,
        ),
        const SizedBox(width: EcoSpacing.element),
        Text(
          texto,
          style: TextStyle(
            color: cumplido ? EcoColors.leafDark : EcoColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
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
              const SizedBox(height: EcoSpacing.container),
              Text(
                'Crea tu nueva contraseña',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: EcoSpacing.element),
              Text(
                'Debe ser distinta a tu contraseña anterior.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: EcoColors.onSurfaceVariant),
              ),
              const SizedBox(height: EcoSpacing.section),
              TextField(
                controller: _passwordController,
                obscureText: _ocultarPassword,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                  ),
                ),
              ),
              const SizedBox(height: EcoSpacing.stack),
              TextField(
                controller: _confirmarController,
                obscureText: _ocultarConfirmar,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarConfirmar ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                  ),
                ),
              ),
              const SizedBox(height: EcoSpacing.stack),
              _itemChecklist('Mínimo 8 caracteres', _longitudValida),
              const SizedBox(height: 4),
              _itemChecklist('Las contraseñas coinciden', _coinciden),
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
                onPressed: _puedeGuardar ? _guardar : null,
                child: _cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar contraseña'),
              ),
              const SizedBox(height: EcoSpacing.container),
            ],
          ),
        ),
      ),
    );
  }
}
