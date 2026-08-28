import 'package:flutter/foundation.dart';

/// Avisa cuando una solicitud cambia de estado (aceptada o completada) para
/// que Mis Rutas e Historial se refresquen aunque ya estén construidas
/// dentro del `IndexedStack` del shell del recolector, que no las reconstruye
/// solo por cambiar de pestaña.
class PickerEvents extends ChangeNotifier {
  PickerEvents._();

  static final PickerEvents instance = PickerEvents._();

  void notificarCambio() => notifyListeners();
}
