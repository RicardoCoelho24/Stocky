import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

class PurchaseService {
  // 1. Ir buscar a lista de Supermercados para o Dropdown
  Future<List<dynamic>> getSupermarkets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/Supermarkets'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      debugPrint('Erro supermercados: $e');
      return [];
    }
  }

  // 2. Ir buscar a lista de Produtos para o Dropdown
  Future<List<dynamic>> getProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Products'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      debugPrint('Erro produtos: $e');
      return [];
    }
  }

  // 3. Enviar a Fatura/Compra final para o C#
  Future<String?> createPurchase(Map<String, dynamic> purchaseData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/Purchases'), // Confirma se esta é a tua rota no C#
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(purchaseData),
      );

      // 200 (OK) ou 201 (Created) significam sucesso
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; 
      } else {
        return 'Erro ao guardar compra. Verifica os dados.';
      }
    } catch (e) {
      debugPrint('Erro ao criar compra: $e');
      return 'Erro de ligação ao servidor.';
    }
  }
  // NOVO MÉTODO: Vai buscar o histórico de faturas
  Future<List<dynamic>> getPurchaseHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/Purchases'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
      return [];
    }
  }
}