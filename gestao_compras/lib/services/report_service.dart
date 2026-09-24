import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ReportService {
  // Nota: Usa 10.0.2.2 se estiveres no emulador Android, ou o teu IP local se for dispositivo físico
  static const String baseUrl = 'http://10.0.2.2:5000/api/Relatorios';

  Future<void> descarregarEAbriExcel(int ano, int mes, {String? token}) async {
    try {
      final uri = Uri.parse('$baseUrl/mensal/excel?ano=$ano&mes=$mes');
      
      final headers = <String, String>{
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // 1. Encontrar o caminho seguro no telemóvel
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/Relatorio_Compras_${mes}_$ano.xlsx';
        
        // 2. Criar e guardar o ficheiro com os bytes recebidos do C#
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // 3. Abrir o ficheiro no telemóvel
        final result = await OpenFilex.open(filePath);
        
        if (result.type != ResultType.done) {
          throw Exception("Não tens nenhuma aplicação para abrir ficheiros Excel instalada.");
        }
      } else {
        throw Exception('Erro no servidor: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao processar o relatório: $e');
    }
  }
}