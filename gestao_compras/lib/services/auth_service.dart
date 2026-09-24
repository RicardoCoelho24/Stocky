import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

class AuthService {
  // ==========================================
  // LOGIN
  // ==========================================
  static Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/Auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['Token'];
        
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return null; // null significa Sucesso (sem erro)
        }
        return 'Token não recebido do servidor.';
      } else {
        try {
          final data = jsonDecode(response.body);
          return data['message'] ?? 'Credenciais inválidas.';
        } catch (_) {
          return 'Erro no login. Verifica as tuas credenciais.';
        }
      }
    } catch (e) {
      return 'Erro de ligação. Verifica a tua internet.';
    }
  }

  // ==========================================
  // REGISTAR
  // ==========================================
  static Future<String?> register(String name, String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/Auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Sucesso
      } else {
        try {
          final data = jsonDecode(response.body);
          return data['message'] ?? 'Não foi possível criar a conta.';
        } catch (_) {
          return 'Erro ao criar conta.';
        }
      }
    } catch (e) {
      return 'Erro de ligação ao servidor.';
    }
  }

  // ==========================================
  // LOGOUT
  // ==========================================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
  // ==========================================
  // ESTATÍSTICAS DO PERFIL
  // ==========================================
  static Future<Map<String, dynamic>?> getProfileStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Auth/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}