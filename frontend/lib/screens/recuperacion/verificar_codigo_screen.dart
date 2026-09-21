import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/recuperacion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/otp_input.dart';
import 'contingencia_screen.dart';
import 'nueva_password_screen.dart';

/// Flujo 5 — Paso 2: verifica el código OTP de 6 dígitos.
class VerificarCodigoScreen extends StatefulWidget {
  const VerificarCodigoScreen({super.key, required this.identificador});

  final String identificador;

  @override
  State<VerificarCodigoScreen> createState() => _VerificarCodigoScreenState();
}

class _VerificarCodigoScreenState extends State<VerificarCodigoScreen> {
  static const _duracionExpiracion = Duration(minutes: 10);
  static const _duracionCooldownReenvio = Duration(seconds: 30);

  final _recuperacionService = RecuperacionService(ApiClient.instance);
  final _otpKey = GlobalKey<OtpInputState>();

  String _codigo = '';
  bool _verificando = false;
  bool _reenviando = false;
  String? _error;

  Duration _restanteExpiracion = _duracionExpiracion;
  Duration _restanteReenvio = _duracionCooldownReenvio;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTemporizador();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarTemporizador() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_restanteExpiracion.inSeconds > 0) {
          _restanteExpiracion -= const Duration(seconds: 1);
        }
        if (_restanteReenvio.inSeconds > 0) {
          _restanteReenvio -= const Duration(seconds: 1);
        }
      });
    });
  }

  String _formatear(Duration duracion) {
    final minutos = duracion.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = duracion.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }

  bool get _puedeVerificar => !_verificando && _codigo.length == 6;

  bool get _puedeReenviar => !_reenviando && _restanteReenvio.inSeconds == 0;

  Future<void> _verificar() async {
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      final token = await _recuperacionService.verificarCodigo(
        widget.identificador,
        _codigo,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NuevaPasswordScreen(token: token)),
      );
    } on CodigoInvalidoException catch (e) {
      _otpKey.currentState?.limpiar();
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No pudimos verificar el código. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _reenviar() async {
    setState(() => _reenviando = true);
    try {
      await _recuperacionService.solicitarCodigo(widget.identificador);
      if (!mounted) return;
      setState(() {
        _restanteExpiracion = _duracionExpiracion;
        _restanteReenvio = _duracionCooldownReenvio;
      });
      _otpKey.currentState?.limpiar();
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos reenviar el código.');
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  String _correoEnmascarado() {
    if (!widget.identificador.contains('@')) {
      return 'tu correo registrado';
    }
    final partes = widget.identificador.split('@');
    final usuario = partes.first;
    final inicial = usuario.isNotEmpty ? usuario.substring(0, 1) : '';
    return '$inicial***@${partes.last}';
  }

  @override
  Widget build(BuildContext context) {
    final expirado = _restanteExpiracion.inSeconds == 0;

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
                'Ingresa el código',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: EcoSpacing.element),
              Text(
                'Enviamos un código de 6 dígitos a ${_correoEnmascarado()}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: EcoColors.onSurfaceVariant),
              ),
              const SizedBox(height: EcoSpacing.section),
              OtpInput(
                key: _otpKey,
                onChanged: (valor) => setState(() => _codigo = valor),
              ),
              const SizedBox(height: EcoSpacing.stack),
              Text(
                expirado
                    ? 'El código expiró.'
                    : 'El código expira en ${_formatear(_restanteExpiracion)}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: EcoColors.onSurfaceVariant),
              ),
              const SizedBox(height: EcoSpacing.element),
              TextButton(
                onPressed: _puedeReenviar ? _reenviar : null,
                child: Text(
                  _puedeReenviar
                      ? 'Reenviar código'
                      : 'Reenviar en ${_formatear(_restanteReenvio)}',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: EcoSpacing.element),
                Text(
                  _error!,
                  style: const TextStyle(color: EcoColors.dangerRed),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: EcoSpacing.stack),
              FilledButton(
                onPressed: _puedeVerificar ? _verificar : null,
                child: _verificando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verificar'),
              ),
              const SizedBox(height: EcoSpacing.stack),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContingenciaScreen()),
                    );
                  },
                  child: const Text('¿No te llegó el código? ¿Problemas con tu correo?'),
                ),
              ),
              const SizedBox(height: EcoSpacing.container),
            ],
          ),
        ),
      ),
    );
  }
}
