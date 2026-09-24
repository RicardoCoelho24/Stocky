import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _idioma = 'pt';

  ThemeMode get themeMode => _themeMode;
  String get idioma => _idioma;

  SettingsProvider() {
    _carregarDefinicoes();
  }

  // Vai à memória do telemóvel ver o que o utilizador escolheu da última vez
  Future<void> _carregarDefinicoes() async {
    final prefs = await SharedPreferences.getInstance();
    
    final isDark = prefs.getBool('isDarkMode');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }

    _idioma = prefs.getString('idioma') ?? 'pt';
    
    notifyListeners(); // Avisa a app toda para se atualizar!
  }

  // Função para o ecrã de definições alterar o Tema
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  // Função para o ecrã de definições alterar a Língua
  Future<void> changeLanguage(String novoIdioma) async {
    _idioma = novoIdioma;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idioma', novoIdioma);
    notifyListeners();
  }
}