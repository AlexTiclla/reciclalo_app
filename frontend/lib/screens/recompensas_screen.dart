import 'package:flutter/material.dart';

import '../models/recompensa.dart';
import '../services/api_client.dart';
import '../services/gamificacion_service.dart';
import '../theme/app_theme.dart';
import '../widgets/eco_app_bar.dart';

/// Catálogo de recompensas y canje de EcoPuntos, compartido por ambos roles
/// (ver `recompensas_y_canje_equilibrado` en stitch_ecorecicla_ciudadano/).
class RecompensasScreen extends StatefulWidget {
  const RecompensasScreen({super.key, required this.onAbrirPerfil});

  final VoidCallback onAbrirPerfil;

  @override
  State<RecompensasScreen> createState() => _RecompensasScreenState();
}

class _RecompensasScreenState extends State<RecompensasScreen> {
  final _service = GamificacionService(ApiClient.instance);

  int _saldo = 0;
  List<Recompensa> _catalogo = [];
  String? _categoria;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final saldo = await _service.obtenerSaldo();
      final catalogo = await _service.catalogoRecompensas(categoria: _categoria);
      if (!mounted) return;
      setState(() {
        _saldo = saldo.saldo;
        _catalogo = catalogo;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _canjear(Recompensa recompensa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Confirmas el canje?'),
        content: Text(
          '${recompensa.nombre}\n${recompensa.costoPuntos} pts — '
          'saldo restante: ${_saldo - recompensa.costoPuntos} pts',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, EcoSpacing.touchTarget)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, canjear'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final canje = await _service.canjear(recompensa.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcoRadius.x2l)),
          title: const Text('¡Canje exitoso!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Muestra este código en el establecimiento:'),
              const SizedBox(height: EcoSpacing.stack),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(EcoSpacing.stack),
                decoration: BoxDecoration(
                  color: EcoColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(EcoRadius.lg),
                ),
                child: Text(
                  canje.codigo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: EcoColors.primary,
                        letterSpacing: 2,
                      ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, EcoSpacing.touchTarget)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      _cargar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EcoAppBar(titulo: 'Recompensas', onAbrirPerfil: widget.onAbrirPerfil),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _error != null
            ? ListView(
                padding: const EdgeInsets.all(EcoSpacing.container),
                children: [Text(_error!)],
              )
            : _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(EcoSpacing.container),
                    children: [
                      _Saldo(saldo: _saldo),
                      const SizedBox(height: EcoSpacing.container),
                      _Filtros(
                        categoria: _categoria,
                        onCambiar: (categoria) {
                          setState(() => _categoria = categoria);
                          _cargar();
                        },
                      ),
                      const SizedBox(height: EcoSpacing.container),
                      if (_catalogo.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: EcoSpacing.section),
                          child: Text(
                            'Todavía no hay recompensas disponibles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: EcoColors.onSurfaceVariant),
                          ),
                        )
                      else
                        ..._catalogo.map(
                          (recompensa) => Padding(
                            padding: const EdgeInsets.only(bottom: EcoSpacing.stack),
                            child: _RecompensaCard(
                              recompensa: recompensa,
                              saldo: _saldo,
                              onCanjear: () => _canjear(recompensa),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _Saldo extends StatelessWidget {
  const _Saldo({required this.saldo});

  final int saldo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$saldo',
              style: textos.headlineLarge?.copyWith(fontSize: 44, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: EcoSpacing.element),
            Text(
              'EcoPuntos',
              style: textos.labelLarge?.copyWith(
                color: EcoColors.primary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: EcoSpacing.element),
        Text(
          'Saldo disponible para canjear',
          style: textos.bodySmall?.copyWith(color: EcoColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({required this.categoria, required this.onCambiar});

  final String? categoria;
  final ValueChanged<String?> onCambiar;

  @override
  Widget build(BuildContext context) {
    final opciones = <String?, String>{
      null: 'Todos',
      'descuentos': 'Descuentos',
      'productos': 'Productos',
      'servicios': 'Servicios',
    };

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: EcoSpacing.element,
      children: opciones.entries.map((entry) {
        final seleccionado = categoria == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: seleccionado,
          onSelected: (_) => onCambiar(entry.key),
          selectedColor: EcoColors.primary,
          labelStyle: TextStyle(
            color: seleccionado ? EcoColors.onPrimary : EcoColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: EcoColors.surfaceContainer,
          shape: const StadiumBorder(),
        );
      }).toList(),
    );
  }
}

class _RecompensaCard extends StatelessWidget {
  const _RecompensaCard({
    required this.recompensa,
    required this.saldo,
    required this.onCanjear,
  });

  final Recompensa recompensa;
  final int saldo;
  final VoidCallback onCanjear;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final alcanza = saldo >= recompensa.costoPuntos;

    return Opacity(
      opacity: alcanza ? 1 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recompensa.imagenUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(recompensa.imagenUrl, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(EcoSpacing.stack),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recompensa.nombre, style: textos.headlineMedium),
                  if (recompensa.descripcion.isNotEmpty) ...[
                    const SizedBox(height: EcoSpacing.element),
                    Text(recompensa.descripcion, style: textos.bodySmall),
                  ],
                  const SizedBox(height: EcoSpacing.stack),
                  Row(
                    children: [
                      const Icon(Icons.eco, size: 18, color: EcoColors.primary),
                      const SizedBox(width: EcoSpacing.element),
                      Text(
                        '${recompensa.costoPuntos} pts',
                        style: textos.bodyLarge?.copyWith(
                          color: EcoColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: alcanza ? onCanjear : null,
                        // El tema global fija minimumSize a ancho completo
                        // (Size.fromHeight) para los botones de pantalla
                        // completa; aquí el botón vive dentro de un Row y
                        // necesita un ancho acotado a su contenido.
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, EcoSpacing.touchTarget),
                        ),
                        child: Text(alcanza ? 'Canjear' : 'Te faltan ${recompensa.costoPuntos - saldo} pts'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
