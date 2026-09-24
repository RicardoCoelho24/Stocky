import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final idioma = settings.idioma;
    final isDarkMode = settings.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.traduzir('titulo_definicoes', idioma))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppTranslations.traduzir('lbl_aparencia', idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 8),
          
          SwitchListTile(
            title: Text(AppTranslations.traduzir('lbl_modo_escuro', idioma)),
            subtitle: Text(AppTranslations.traduzir('desc_modo_escuro', idioma)),
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.teal),
            value: isDarkMode,
            activeColor: Colors.teal,
            onChanged: (bool valor) { settings.toggleTheme(valor); },
          ),
          
          const Divider(height: 32),
          
          Text(AppTranslations.traduzir('lbl_internacionalizacao', idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.language, color: Colors.teal),
            title: Text(AppTranslations.traduzir('lbl_idioma_app', idioma)),
            subtitle: Text(AppTranslations.traduzir('desc_idioma_app', idioma)),
            trailing: DropdownButton<String>(
              value: settings.idioma,
              underline: const SizedBox(), 
              items: const [
                DropdownMenuItem(value: 'pt', child: Text('Português')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
              ],
              onChanged: (String? novoIdioma) {
                if (novoIdioma != null) {
                  settings.changeLanguage(novoIdioma);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_idioma_alterado', novoIdioma))));
                }
              },
            ),
          ),
          
          const Divider(height: 32),
          Center(child: Text('${AppTranslations.traduzir('lbl_versao', idioma)} 1.0.0', style: const TextStyle(color: Colors.grey)))
        ],
      ),
    );
  }
}