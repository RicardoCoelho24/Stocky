import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

class StockService {
  
  // 1. Vai buscar a despensa atual
  Future<List<dynamic>> getMyStock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) return [];

      final url = Uri.parse('${ApiConstants.baseUrl}/api/Stocks');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Erro na API: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Erro fatal ao carregar despensa: $e');
      return [];
    }
  }

  // 2. Atualiza o limite de alerta de um produto
  Future<bool> updateThreshold(int productId, int novoLimite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final url = Uri.parse('${ApiConstants.baseUrl}/api/Stocks/threshold/$productId'); 
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'newThreshold': novoLimite 
        }), 
      );

      return response.statusCode == 200 || response.statusCode == 204; 
    } catch (e) {
      debugPrint('Erro ao atualizar alerta: $e');
      return false;
    }
  }

  // 3. Desconta unidades ao stock na base de dados
  // 3. Desconta unidades ao stock na base de dados
  Future<String?> consumeProduct(int productId, int quantity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return 'Sessão expirada.';

      final url = Uri.parse('${ApiConstants.baseUrl}/api/Stocks/consume/$productId');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'quantityToConsume': quantity
        }),
      );

      // Se o C# devolver 200 (OK) ou 204 (No Content), foi sucesso!
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null; 
      } else if (response.statusCode == 404) {
        return 'Erro 404: Rota não encontrada. Apagaste o código no C# sem querer?';
      } else {
        return 'Erro (${response.statusCode}): O servidor rejeitou o consumo.';
      }
    } catch (e) {
      debugPrint('Erro ao consumir produto: $e');
      return 'Erro de ligação ao servidor.';
    }
  }

  // 4. Vai buscar a lista de compras gerada automaticamente
  Future<List<dynamic>> getShoppingList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return [];

      final url = Uri.parse('${ApiConstants.baseUrl}/Stocks/shopping-list');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data is Map && data.containsKey('message')) {
          return []; 
        } else if (data is List) {
          return data; 
        }
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao carregar lista de compras: $e');
      return [];
    }
  }

  // 5. NOVO: Altera a categoria de um produto específico (Manual/IA)
  Future<bool> updateProductCategory(int produtoId, String novaCategoria) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/Products/$produtoId/category'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'category': novaCategoria}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao atualizar categoria: $e');
      return false;
    }
  }

  // 6. NOVO: Adiciona stock diretamente sem passar por faturas financeiras
  Future<bool> addStockDirectly({
    required String productName,
    required double quantity,
    DateTime? expirationDate,
    int? daysToAlert,
    int minAlertThreshold = 1, // <-- AGORA RECEBE O ALERTA (por defeito é 1)
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/Stocks/direct-add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'productName': productName,
          'quantity': quantity,
          'minAlertThreshold': minAlertThreshold, // <-- AGORA ENVIA O VALOR REAL PARA O C#
          'expirationDate': expirationDate?.toIso8601String(),
          'daysToAlertBeforeExpiration': daysToAlert,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao adicionar direto: $e');
      return false;
    }
  }

  // ==========================================
  // APAGAR PRODUTO TOTALMENTE
  // ==========================================
  Future<bool> removeProduct(int productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/Stocks/$productId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao remover produto: $e');
      return false;
    }
  }

  // ==========================================
  // ATUALIZAR DATA DE VALIDADE E AVISO
  // ==========================================
  Future<bool> updateExpiration(int productId, DateTime? expirationDate, int? daysToAlert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final String link = '${ApiConstants.baseUrl}/api/Stocks/expiration/$productId';

      final response = await http.put(
        Uri.parse(link),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'expirationDate': expirationDate?.toIso8601String(),
          'daysToAlertBeforeExpiration': daysToAlert,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao atualizar validade: $e');
      return false;
    }
  }

  // ==========================================
  // EDITAR DETALHES DO PRODUTO (NOME E MEDIDA)
  // ==========================================
  Future<bool> updateProductDetails(int productId, String newName, String? newMeasure) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final String link = '${ApiConstants.baseUrl}/api/Products/$productId/edit';

      final response = await http.put(
        Uri.parse(link),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': newName,
          'measure': newMeasure,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao editar produto: $e');
      return false;
    }
  }
  // ==========================================
  // ATUALIZAR QUANTIDADE DIRETAMENTE
  // ==========================================
  Future<bool> updateProductQuantity(int productId, double newQuantity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return false;

      final String link = '${ApiConstants.baseUrl}/api/Stocks/quantity/$productId';

      final response = await http.put(
        Uri.parse(link),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'newQuantity': newQuantity,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Erro ao atualizar quantidade: $e');
      return false;
    }
  }
}