import 'api_client.dart';

class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  Future<void> login(String username, String password) async {
    final data = await _client.postJson('/api/auth/login/', {
      'username': username,
      'password': password,
    });
    _client.setToken(data['token'] as String);
  }

  void logout() {
    _client.setToken(null);
  }

  bool get isAuthenticated => _client.isAuthenticated;
}
