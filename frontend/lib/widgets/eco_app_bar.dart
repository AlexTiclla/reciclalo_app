import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header compartido por las pantallas raíz de ambos roles: título + ícono
/// de perfil arriba a la derecha (el perfil ya no es una pestaña del navbar).
class EcoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EcoAppBar({super.key, required this.titulo, required this.onAbrirPerfil});

  final String titulo;
  final VoidCallback onAbrirPerfil;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titulo),
      actions: [
        IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          color: EcoColors.primary,
          tooltip: 'Perfil',
          onPressed: onAbrirPerfil,
        ),
        const SizedBox(width: EcoSpacing.element),
      ],
    );
  }
}
