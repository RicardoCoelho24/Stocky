import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodFactsService {
  /// Procura um produto pelo código de barras e devolve o nome dele (ou null se não encontrar)
  static Future<String?> getProductName(String barcode) async {
    try {
      // Endpoint público e gratuito da Open Food Facts
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // O status == 1 significa que o produto existe na base de dados deles
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          
          // Tenta buscar o nome em Português primeiro, se não encontrar tenta o nome global
          return product['product_name_pt'] ?? product['product_name'];
        }
      }
      return null; // Produto não encontrado
    } catch (e) {
      return null; // Erro de ligação (sem internet, etc.)
    }
  }
}