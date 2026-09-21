import 'package:flutter/material.dart';

import '../models/impacto.dart';
import '../models/progreso_racha.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/gamificacion_service.dart';
import '../theme/app_theme.dart';

/// Panel de impacto ambiental y racha de constancia (Flujo 3, Paso 4).
/// Ver `mi_impacto_y_racha_equilibrado` en stitch_ecorecicla_ciudadano/.
class MiImpactoScreen extends StatefulWidget {
  const MiImpactoScreen({super.key, required this.rol});

  final RolUsuario rol;

  @override
  State<MiImpactoScreen> createState() => _MiImpactoScreenState();
}

class _MiImpactoScreenState extends State<MiImpactoScreen> {
  final _service = GamificacionService(ApiClient.instance);

  ProgresoRacha? _racha;
  Impacto? _impacto;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final racha = await _service.obtenerRacha();
      final impacto = await _service.obtenerImpacto();
      if (!mounted) return;
      setState(() {
        _racha = racha;
        _impacto = impacto;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final racha = _racha;
    final impacto = _impacto;
    final esRecolector = widget.rol == RolUsuario.recolector;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Impacto')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _error != null
            ? ListView(
                padding: const EdgeInsets.all(EcoSpacing.container),
                children: [Text(_error!)],
              )
            : racha == null || impacto == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(EcoSpacing.container),
                    children: [
                      _TarjetaRacha(racha: racha),
                      const SizedBox(height: EcoSpacing.section),
                      if (esRecolector)
                        _TarjetaMetrica(
                          icono: Icons.local_shipping_outlined,
                          valor: '${impacto.retirosCompletados}',
                          etiqueta: 'Retiros completados este mes',
                        )
                      else ...[
                        Text(
                          'HUELLA AMBIENTAL EVITADA',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: EcoColors.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                        ),
                        const SizedBox(height: EcoSpacing.stack),
                        Row(
                          children: [
                            Expanded(
                              child: _TarjetaMetrica(
                                icono: Icons.co2_outlined,
                                valor: '${impacto.co2Kg.toStringAsFixed(1)} kg',
                                etiqueta: 'CO₂ evitado',
                              ),
                            ),
                            const SizedBox(width: EcoSpacing.stack),
                            Expanded(
                              child: _TarjetaMetrica(
                                icono: Icons.water_drop_outlined,
                                valor: '${impacto.aguaL.toStringAsFixed(0)} L',
                                etiqueta: 'Agua ahorrada',
                                color: EcoColors.statusBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: EcoSpacing.stack),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(EcoSpacing.stack),
                            child: Row(
                              children: [
                                const Icon(Icons.recycling, color: EcoColors.primary),
                                const SizedBox(width: EcoSpacing.stack),
                                Expanded(
                                  child: Text(
                                    '${impacto.totalRecicladoKg.toStringAsFixed(1)} kg reciclados',
                                    style: Theme.of(context).textTheme.headlineMedium,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: EcoSpacing.stack,
                                    vertical: EcoSpacing.element,
                                  ),
                                  decoration: BoxDecoration(
                                    color: EcoColors.secondaryContainer,
                                    borderRadius: BorderRadius.all(EcoRadius.full),
                                  ),
                                  child: Text(
                                    '${impacto.retirosCompletados} retiros',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: EcoColors.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _TarjetaRacha extends StatelessWidget {
  const _TarjetaRacha({required this.racha});

  final ProgresoRacha racha;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EcoSpacing.container),
      decoration: BoxDecoration(
        color: EcoColors.leafDark,
        borderRadius: BorderRadius.circular(EcoRadius.x2l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RACHA ACTIVA',
                      style: textos.labelSmall?.copyWith(
                        color: EcoColors.mintLight.withValues(alpha: 0.8),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: EcoSpacing.element),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${racha.rachaActual}',
                          style: textos.headlineLarge?.copyWith(
                            color: EcoColors.mintLight,
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(width: EcoSpacing.element),
                        Text(
                          'semanas de racha',
                          style: textos.headlineMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: EcoSpacing.element),
                    Text(
                      'Tu mejor racha: ${racha.rachaMaxima} semanas',
                      style: textos.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(EcoRadius.lg),
                ),
                child: const Icon(Icons.eco, color: EcoColors.mintLight),
              ),
            ],
          ),
          const SizedBox(height: EcoSpacing.stack),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: EcoSpacing.stack),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Protectores de racha',
                style: textos.labelSmall?.copyWith(color: Colors.white70),
              ),
              Row(
                children: List.generate(racha.protectoresTotales, (i) {
                  final activo = i < racha.protectoresDisponibles;
                  return Padding(
                    padding: const EdgeInsets.only(left: EcoSpacing.element),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activo
                            ? EcoColors.mintLight.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.all(EcoRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield,
                            size: 14,
                            color: activo ? EcoColors.mintLight : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activo ? 'activo' : 'usado',
                            style: textos.labelSmall?.copyWith(
                              color: activo ? EcoColors.mintLight : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  const _TarjetaMetrica({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.color = EcoColors.primary,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcoSpacing.stack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(EcoRadius.lg),
              ),
              child: Icon(icono, size: 20, color: color),
            ),
            const SizedBox(height: EcoSpacing.stack),
            Text(valor, style: textos.headlineLarge?.copyWith(fontSize: 26)),
            const SizedBox(height: 2),
            Text(etiqueta, style: textos.bodySmall),
          ],
        ),
      ),
    );
  }
}
