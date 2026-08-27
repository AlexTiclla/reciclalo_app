import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Perfil del ciudadano: datos de cuenta y cierre de sesión.
class PerfilCiudadanoScreen extends StatefulWidget {
  const PerfilCiudadanoScreen({super.key, required this.onCerrarSesion});

  final VoidCallback onCerrarSesion;

  @override
  State<PerfilCiudadanoScreen> createState() => _PerfilCiudadanoScreenState();
}

class _PerfilCiudadanoScreenState extends State<PerfilCiudadanoScreen> {
  final _authService = AuthService(ApiClient.instance);

  Usuario? _usuario;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final usuario = await _authService.usuarioActual();
      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(Icons.error_outline, color: Colors.grey.shade600, size: 32),
                  const SizedBox(height: 8),
                  Text(_error!),
                ],
              )
            : usuario == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(usuario.username, style: textos.headlineMedium),
                          const SizedBox(height: 4),
                          if (usuario.email.isNotEmpty)
                            Text(usuario.email, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 32),
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
