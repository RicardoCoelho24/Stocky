import 'package:intl/intl.dart';

class Formatters {
  // Exemplo de saída: "9 de junho de 2026"
  static String formatarData(DateTime data) {
    return DateFormat("d 'de' MMMM 'de' yyyy", "pt_PT").format(data);
  }

  // Exemplo de saída: "09/06/2026" (versão mais curta, boa para listas apertadas)
  static String formatarDataCurta(DateTime data) {
    return DateFormat("dd/MM/yyyy", "pt_PT").format(data);
  }
}