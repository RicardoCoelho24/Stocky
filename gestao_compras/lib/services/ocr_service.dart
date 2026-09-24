import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // NOVO IMPORT
import '../utils/api_constants.dart';

class OcrService {
  // ==========================================
  // ENVIAR IMAGEM PARA A INTELIGÊNCIA ARTIFICIAL
  // ==========================================
  
  // Alterado de 'File imagem' para 'XFile imagem'
  static Future<Map<String, dynamic>?> analisarFatura(XFile imagem) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      if (token == null) {
        return {'erro': 'Sessão expirada. Faz login novamente.'};
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/ReceiptOcr/analyze');
      final request = http.MultipartRequest('POST', url);

      request.headers['Authorization'] = 'Bearer $token';

      // A MAGIA PARA FUNCIONAR NA WEB:
      // Lemos os "bytes" brutos da imagem em vez de tentar aceder ao caminho do disco
      final bytes = await imagem.readAsBytes();
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image', 
          bytes,
          filename: imagem.name.isNotEmpty ? imagem.name : 'fatura.jpg', // C# precisa de um nome com extensão
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'erro': response.body};
      }
    } catch (e) {
      return {'erro': 'Erro ao comunicar com o servidor. O ficheiro pode ser muito grande ou a net falhou.'};
    }
  }
}