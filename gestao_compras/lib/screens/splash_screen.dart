import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';

import 'main_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animacaoFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animacaoFade = Tween<double>(begin: 0.0, end: 1.0).animate(_animController);
    _animController.forward();
    _verificarSessao();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _verificarSessao() async {
    await Future.delayed(const Duration(seconds: 3));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (!mounted) return;

    if (token != null && !JwtDecoder.isExpired(token)) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MainScreen()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      backgroundColor: Colors.teal, 
      body: Center(
        child: FadeTransition(
          opacity: _animacaoFade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2_rounded, size: 80, color: Colors.teal),
              ),
              const SizedBox(height: 24),
              const Text('Stocky', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2.0)),
              const SizedBox(height: 8),
              Text(AppTranslations.traduzir('lbl_slogan', idioma), style: const TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic)),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}