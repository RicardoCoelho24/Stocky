import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  void _fazerRegisto() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; });

    final erro = await AuthService.register(
      _nameController.text.trim(),
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() { _isLoading = false; });

    if (erro == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_conta_criada', idioma)), backgroundColor: Colors.green));
      Navigator.pop(context); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.traduzir('titulo_criar_conta', idioma)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.teal,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_add, size: 60, color: Colors.teal),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_nome_completo', idioma), prefixIcon: const Icon(Icons.badge), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: AppTranslations.traduzir('nome_utilizador', idioma), prefixIcon: const Icon(Icons.account_circle), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_email', idioma), prefixIcon: const Icon(Icons.email), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_password', idioma), prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _fazerRegisto,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(AppTranslations.traduzir('btn_registar', idioma), style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}