import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Casillas de un código OTP (una por dígito), con avance automático de foco
/// y soporte para pegar el código completo desde el portapapeles en
/// cualquiera de las casillas.
class OtpInput extends StatefulWidget {
  const OtpInput({super.key, this.length = 6, required this.onChanged});

  final int length;

  /// Se llama con el string concatenado cada vez que cambia el contenido de
  /// alguna casilla; la pantalla decide cuándo se considera "completo"
  /// (`valor.length == length`).
  final ValueChanged<String> onChanged;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controladores;
  late final List<FocusNode> _focos;

  @override
  void initState() {
    super.initState();
    _controladores = List.generate(widget.length, (_) => TextEditingController());
    _focos = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controlador in _controladores) {
      controlador.dispose();
    }
    for (final foco in _focos) {
      foco.dispose();
    }
    super.dispose();
  }

  /// Limpia todas las casillas y devuelve el foco a la primera — se usa al
  /// mostrar un error de código incorrecto, para que el usuario reintente.
  void limpiar() {
    for (final controlador in _controladores) {
      controlador.clear();
    }
    _focos.first.requestFocus();
    _emitir();
  }

  void _emitir() {
    widget.onChanged(_controladores.map((c) => c.text).join());
  }

  void _distribuirPegado(String texto) {
    final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return;
    for (var i = 0; i < widget.length; i++) {
      _controladores[i].text = i < digitos.length ? digitos[i] : '';
    }
    final ultimaCasillaLlena = (digitos.length - 1).clamp(0, widget.length - 1);
    _focos[ultimaCasillaLlena].requestFocus();
    _emitir();
  }

  void _onChanged(int indice, String valor) {
    if (valor.length > 1) {
      // El usuario pegó el código completo en esta casilla.
      _distribuirPegado(valor);
      return;
    }
    if (valor.isNotEmpty && indice < widget.length - 1) {
      _focos[indice + 1].requestFocus();
    }
    _emitir();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (indice) {
        return SizedBox(
          width: 48,
          height: 56,
          child: TextField(
            controller: _controladores[indice],
            focusNode: _focos[indice],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: widget.length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(EcoRadius.xl)),
                borderSide: BorderSide(color: EcoColors.leafDark, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(EcoRadius.xl)),
                borderSide: BorderSide(color: EcoColors.leafDark, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(EcoRadius.xl)),
                borderSide: BorderSide(color: EcoColors.leafDark, width: 2),
              ),
            ),
            onChanged: (valor) => _onChanged(indice, valor),
          ),
        );
      }),
    );
  }
}
