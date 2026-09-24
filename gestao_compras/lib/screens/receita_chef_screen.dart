import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/api_constants.dart'; // <-- IMPORTANTE: Novo import adicionado

class ReceitaChefScreen extends StatefulWidget {
  const ReceitaChefScreen({super.key});

  @override
  State<ReceitaChefScreen> createState() => _ReceitaChefScreenState();
}

class _ReceitaChefScreenState extends State<ReceitaChefScreen> {
  String _receitaMarkdown = "";
  bool _aCozinhar = true;

  @override
  void initState() {
    super.initState();
    _pedirSugestaoAoChef();
  }

  Future<void> _pedirSugestaoAoChef() async {
    setState(() {
      _aCozinhar = true;
    });

    try {
      // Ajustado para usar a baseUrl do Azure com o /api/ incluído
      final url = Uri.parse('${ApiConstants.baseUrl}/api/Chef/sugerir-jantar');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _receitaMarkdown = data['receita'];
        });
      } else {
        setState(() {
          _receitaMarkdown = "### Erro na cozinha 🍳\nNão consegui contactar o Chef. Tenta novamente mais tarde.";
        });
      }
    } catch (e) {
      setState(() {
        _receitaMarkdown = "### Falha de Ignição 🔥\nErro de ligação: $e";
      });
    } finally {
      setState(() {
        _aCozinhar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Chef IA - Anti Desperdício'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: _aCozinhar
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.orange.shade300),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    "A analisar a tua despensa...\nO Chef está a criar algo delicioso!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Markdown(
                    data: _receitaMarkdown,
                    styleSheet: MarkdownStyleSheet(
                      h1: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 24),
                      h2: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 20),
                      h3: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                      p: const TextStyle(fontSize: 16, height: 1.5),
                      listBullet: const TextStyle(color: Colors.orange, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _aCozinhar ? null : _pedirSugestaoAoChef,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.refresh),
        label: const Text('Nova Receita'),
      ),
    );
  }
}