import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

class HouseholdService {
  // 1. Obter a minha casa
  static Future<Map<String, dynamic>?> getMinhaCasa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Household/minha-casa'),
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

  // 2. Pedir para Juntar (Em vez de mudar logo, envia pedido)
  static Future<String?> pedirParaJuntar(String inviteCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/Household/juntar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'inviteCode': inviteCode}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return null; // Sucesso (null significa que não há erros)
      } else {
        return body['message'] ?? 'Erro ao enviar pedido.'; // Erro (retorna a mensagem)
      }
    } catch (e) {
      return 'Erro de ligação ao servidor.';
    }
  }

  // 3. Obter Pedidos Pendentes (Só funciona para o Dono)
  static Future<List<dynamic>> getPedidosPendentes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Household/pedidos-pendentes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 4. Responder a um pedido (Aceitar ou Rejeitar)
  static Future<String?> responderPedido(int pedidoId, bool aceitar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/Household/responder-pedido/$pedidoId?aceitar=$aceitar'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return null; // Sucesso
      }
      return 'Erro ao processar pedido.';
    } catch (e) {
      return 'Erro de ligação ao servidor.';
    }
  }
}