import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart'; 
import 'services/settings_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Garante que o motor do Flutter está pronto antes de inicializar pacotes
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // Carrega as regras de datas para Portugal!
  await initializeDateFormatting('pt_PT', null); 
  
  runApp(
    // Envolve a app no Provider para as definições estarem disponíveis em todo o lado
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Fica à escuta das alterações nas definições (Tema e Idioma)
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Stocky',
      debugShowCheckedModeBanner: false,
      
      // Controlado pelo utilizador no ecrã de Definições!
      themeMode: settings.themeMode, 
      
      // TEMA CLARO
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      
      // TEMA ESCURO
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212), // Fundo escuro clássico
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal.shade900,
          foregroundColor: Colors.white,
        ),
        // Removido o cardTheme para corrigir o erro. O colorScheme já escurece os cards!
      ),
      
      home: const SplashScreen(),
    );
  }
}