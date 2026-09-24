import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../utils/api_constants.dart';
import '../utils/translations.dart'; 
import '../services/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/signalr_service.dart'; // NOVO IMPORT
import 'household_screen.dart'; 
import 'settings_screen.dart';
import 'login_screen.dart'; // NOVO IMPORT

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nome = "A carregar...";
  String _username = "carregando..."; 
  String _email = "A carregar...";
  String? _fotoBase64; 
  Uint8List? _fotoBytes; 
  
  Map<String, dynamic>? _estatisticas;

  bool _isEditing = false;
  bool _isSaving = false;
  final TextEditingController _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarDadosDoToken();
    _carregarEstatisticas();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosDoToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      
      if (mounted) {
        setState(() {
          _nome = decodedToken['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ?? "Sem Nome";
          _email = decodedToken['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] ?? "Sem Email";
          _username = decodedToken['username'] ?? "utilizador"; 
          _nomeController.text = _nome;
          
          _fotoBase64 = decodedToken['profilePicture']; 
          if (_fotoBase64 != null && _fotoBase64!.isNotEmpty) {
            _fotoBytes = base64Decode(_fotoBase64!);
          }
        });
      }
    }
  }

  Future<void> _carregarEstatisticas() async {
    try {
      final stats = await AuthService.getProfileStats();
      if (mounted) {
        setState(() {
          _estatisticas = stats ?? {
            'produtosDespensa': 0,
            'gastosPessoais': 0.0,
            'gastosCasa': 0.0
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estatisticas = {
            'produtosDespensa': 0,
            'gastosPessoais': 0.0,
            'gastosCasa': 0.0
          };
        });
      }
    }
  }

  Future<void> _alterarFotoPerfil() async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (foto == null) return;

    final bytes = await foto.readAsBytes();
    setState(() {
      _fotoBytes = bytes;
      _fotoBase64 = base64Encode(bytes);
    });

    _gravarAlteracoesNoServidor();
  }

  Future<void> _gravarAlteracoesNoServidor() async {
    setState(() => _isSaving = true);
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = Uri.parse('${ApiConstants.baseUrl}/api/Auth/update-profile');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nome': _nomeController.text,
          'fotoBase64': _fotoBase64,
        }),
      );

      if (response.statusCode == 200) {
        final respostaBody = jsonDecode(response.body);
        final novoToken = respostaBody['token'] ?? respostaBody['Token'];
        if (novoToken != null) await prefs.setString('jwt_token', novoToken);

        setState(() {
          _nome = _nomeController.text;
          _isEditing = false;
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_sucesso', idioma)), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gravar: ${response.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_erro_servidor', idioma)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // FUNÇÃO DE TERMINAR SESSÃO CORRIGIDA
  Future<void> _terminarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Apagar token
    await prefs.remove('jwt_token');
    
    // 2. Desligar SignalR
    SignalRService().stopConnection();
    
    if (!mounted) return;
    
    // 3. Navegação direta e forçada para o Ecrã de Login
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (context) => const LoginScreen()), 
      (route) => false,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;
    String inicial = _nome.isNotEmpty && _nome != "A carregar..." ? _nome[0].toUpperCase() : "U";

    int totalProdutos = 0;
    double meusGastos = 0.0;
    double gastosCasa = 0.0;

    if (_estatisticas != null) {
      totalProdutos = _estatisticas!['produtosDespensa'] ?? _estatisticas!['totalProdutos'] ?? 0;
      meusGastos = (_estatisticas!['gastosPessoais'] ?? _estatisticas!['gastosMeus'] ?? 0.0).toDouble();
      gastosCasa = (_estatisticas!['gastosCasa'] ?? 0.0).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.traduzir('titulo_perfil', idioma)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Definições',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.teal.shade100,
                    backgroundImage: _fotoBytes != null ? MemoryImage(_fotoBytes!) : null,
                    child: _fotoBytes == null
                        ? Text(inicial, style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.teal.shade800))
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.teal, radius: 20,
                      child: IconButton(icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white), onPressed: _alterarFotoPerfil),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (!_isEditing)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_nome, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.teal, size: 20), onPressed: () => setState(() => _isEditing = true))
                      ],
                    ),
                    Text('@$_username', style: TextStyle(fontSize: 16, color: Colors.teal.shade700, fontWeight: FontWeight.w500)),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nomeController,
                        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: AppTranslations.traduzir('nome_utilizador', idioma)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSaving 
                      ? const CircularProgressIndicator(color: Colors.teal)
                      : IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 32), onPressed: _gravarAlteracoesNoServidor),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                      onPressed: () => setState(() { _isEditing = false; _nomeController.text = _nome; }),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(_email, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(AppTranslations.traduzir('lbl_estatisticas', idioma), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              
              if (_estatisticas == null)
                const CircularProgressIndicator(color: Colors.teal)
              else
                Row(
                  children: [
                    _buildStatCard(
                      AppTranslations.traduzir('lbl_produtos_despensa', idioma), 
                      '$totalProdutos', 
                      Icons.inventory_2_outlined, 
                      Colors.teal
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      AppTranslations.traduzir('lbl_meus_gastos', idioma), 
                      '${meusGastos.toStringAsFixed(2)}€', 
                      Icons.account_balance_wallet_outlined, 
                      Colors.orange
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      AppTranslations.traduzir('lbl_gastos_casa', idioma), 
                      '${gastosCasa.toStringAsFixed(2)}€', 
                      Icons.home_work_outlined, 
                      Colors.blue
                    ),
                  ],
                ),
              
              const SizedBox(height: 32),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.teal),
                    const SizedBox(width: 12),
                    Expanded(child: Text(AppTranslations.traduzir('aviso_conta', idioma), style: const TextStyle(color: Colors.teal))),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.home),
                  label: Text(AppTranslations.traduzir('btn_gerir_casa', idioma), style: const TextStyle(fontSize: 16)),
                  onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const HouseholdScreen())); },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.logout),
                  label: Text(AppTranslations.traduzir('btn_terminar_sessao', idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _terminarSessao,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}