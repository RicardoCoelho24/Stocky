import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

class DashboardService {
  Future<Map<String, dynamic>?> getSummary({DateTime? date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return null;

      // Adicionado o /api/ ao caminho
      String urlString = '${ApiConstants.baseUrl}/api/Dashboard/summary';
      
      if (date != null) {
        urlString += '?date=${date.toIso8601String().split('T')[0]}';
      }

      final response = await http.get(
        Uri.parse(urlString),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Erro no dashboard: $e');
      return null;
    }
  }
}