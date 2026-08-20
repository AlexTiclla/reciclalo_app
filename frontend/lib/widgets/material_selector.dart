import 'package:flutter/material.dart';

import '../models/solicitud.dart';

class MaterialSelector extends StatelessWidget {
  const MaterialSelector({
    super.key,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final TipoMaterial? seleccionado;
  final ValueChanged<TipoMaterial> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: TipoMaterial.values.map((tipo) {
        final activo = tipo == seleccionado;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSeleccionar(tipo),
          child: Container(
            decoration: BoxDecoration(
              color: activo
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Colors.white,
              border: Border.all(
                color: activo ? primary : Colors.grey.shade300,
                width: activo ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tipo.icon, size: 28, color: activo ? primary : Colors.grey.shade700),
                const SizedBox(height: 8),
                Text(
                  tipo.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: activo ? primary : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
