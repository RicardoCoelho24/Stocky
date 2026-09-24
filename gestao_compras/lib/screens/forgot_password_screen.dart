import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../utils/api_constants.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart'; 

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key}); 

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isPinSent = false; 
  bool _isLoading = false;

  Future<void> _requestResetPin() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_inserir_email', idioma))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/Auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _isPinSent = true); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_codigo_enviado', idioma)), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_erro_codigo_recuperacao', idioma)), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.traduzir('msg_erro_ligacao', idioma)}$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    if (_pinController.text.isEmpty || _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_preenche_codigo_password', idioma))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/Auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': _pinController.text.trim(), 'newPassword': _newPasswordController.text.trim()}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_password_alterada', idioma)), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_codigo_invalido', idioma)), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.traduzir('msg_erro_ligacao', idioma)}$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.traduzir('titulo_recuperar_password', idioma)), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(_isPinSent ? Icons.mark_email_read_outlined : Icons.lock_reset, size: 80, color: Colors.teal),
            const SizedBox(height: 24),
            Text(
              _isPinSent ? AppTranslations.traduzir('msg_instrucoes_pin_enviado', idioma) : AppTranslations.traduzir('msg_instrucoes_email', idioma),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),

            if (!_isPinSent) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_email', idioma), prefixIcon: const Icon(Icons.email), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.teal),
                onPressed: _isLoading ? null : _requestResetPin,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(AppTranslations.traduzir('btn_enviar_codigo', idioma), style: const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],

            if (_isPinSent) ...[
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_codigo_pin', idioma), border: const OutlineInputBorder(), counterText: ""),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_nova_password', idioma), prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.teal),
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(AppTranslations.traduzir('btn_alterar_password', idioma), style: const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}