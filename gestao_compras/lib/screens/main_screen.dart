import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';

import 'dashboard_screen.dart';
import 'despensa_screen.dart';
import 'compras_screen.dart';
import 'historico_screen.dart';
import 'promocoes_screen.dart'; // <-- NOVO ECRÃ IMPORTADO AQUI
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'household_screen.dart';
import 'profile_screen.dart';
import '../services/notification_service.dart';
import '../services/stock_service.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';
import '../services/signalr_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _indiceAtual = 0;
  String _nomeUtilizador = "";

  @override
  void initState() {
    super.initState();
    _carregarNomeDoToken(); 
    NotificationService.initialize(); 
    _verificarProdutosAExpirar(); 
    SignalRService().startConnection(); // Inicia os WebSockets
  }

  Future<void> _verificarProdutosAExpirar() async {
    try {
      final stockService = StockService();
      final produtos = await stockService.getMyStock(); 

      int produtosEmRisco = 0;
      DateTime hoje = DateTime.now();
      DateTime daquiA3Dias = hoje.add(const Duration(days: 3));

      for (var p in produtos) {
        final String? dataValidade = p['expirationDate'] ?? p['validade'];
        if (dataValidade != null) {
          DateTime validade = DateTime.parse(dataValidade);
          if (validade.isBefore(daquiA3Dias) && validade.isAfter(hoje.subtract(const Duration(days: 1)))) {
            produtosEmRisco++;
          }
        }
      }

      if (produtosEmRisco > 0) {
        final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
        await NotificationService.showNotification(
          title: AppTranslations.traduzir('lbl_alerta_despensa', idioma),
          body: '$produtosEmRisco ${AppTranslations.traduzir('msg_produtos_expirar', idioma)}',
        );

        if (!mounted) return; 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.traduzir('msg_atencao_expirar', idioma)),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao verificar validades: $e');
    }
  }

  Future<void> _carregarNomeDoToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      setState(() {
        _nomeUtilizador = decodedToken['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;
    final larguraEcra = MediaQuery.of(context).size.width;
    final isDesktop = larguraEcra >= 600;

    // ADICIONAMOS O TÍTULO PARA A NOVA TAB
    final List<String> titulos = [
      AppTranslations.traduzir('titulo_dashboard', idioma),
      AppTranslations.traduzir('titulo_minha_despensa', idioma),
      AppTranslations.traduzir('titulo_lista_compras', idioma),
      AppTranslations.traduzir('titulo_historico', idioma),
      'Promoções Diárias', // Em breve passamos para o translations.dart
    ];

    String tituloApp = titulos[_indiceAtual];
    if (_indiceAtual == 0 && _nomeUtilizador.isNotEmpty) {
      tituloApp = '${AppTranslations.traduzir('lbl_ola', idioma)}, ${_nomeUtilizador.split(' ')[0]}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tituloApp, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.teal)),
            onSelected: (value) async {
              if (value == 'perfil') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              } else if (value == 'casa') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HouseholdScreen()));
              } else if (value == 'logout') {
                await SignalRService().stopConnection();
                await AuthService.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'perfil',
                child: ListTile(leading: const Icon(Icons.account_circle, color: Colors.teal), title: Text(AppTranslations.traduzir('nav_perfil', idioma)), contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem<String>(
                value: 'casa',
                child: ListTile(leading: const Icon(Icons.home_work, color: Colors.teal), title: Text(AppTranslations.traduzir('titulo_gerir_casa', idioma)), contentPadding: EdgeInsets.zero),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: Text(AppTranslations.traduzir('btn_terminar_sessao', idioma), style: const TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _indiceAtual,
              onDestinationSelected: (int index) { setState(() { _indiceAtual = index; }); },
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: Colors.teal),
              selectedLabelTextStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
              destinations: [
                NavigationRailDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: Text(AppTranslations.traduzir('nav_dashboard', idioma))),
                NavigationRailDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: Text(AppTranslations.traduzir('nav_despensa', idioma))),
                NavigationRailDestination(icon: const Icon(Icons.shopping_bag_outlined), selectedIcon: const Icon(Icons.shopping_bag), label: Text(AppTranslations.traduzir('nav_compras', idioma))),
                NavigationRailDestination(icon: const Icon(Icons.history), selectedIcon: const Icon(Icons.history), label: Text(AppTranslations.traduzir('nav_historico', idioma))),
                const NavigationRailDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer, color: Colors.orange), label: Text('Promoções')),
              ],
            ),
          if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _indiceAtual,
              // ADICIONAMOS O ECRÃ AQUI NO FIM
              children: const [DashboardScreen(), DespensaScreen(), ComprasScreen(), HistoricoScreen(), PromocoesScreen()],
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: isDesktop ? null : BottomNavigationBar(
        currentIndex: _indiceAtual,
        type: BottomNavigationBarType.fixed, // Permite ter mais de 4 itens sem bugar
        onTap: (int index) { setState(() { _indiceAtual = index; }); },
        selectedItemColor: Colors.teal, unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard), label: AppTranslations.traduzir('nav_dashboard', idioma)),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2), label: AppTranslations.traduzir('nav_despensa', idioma)),
          BottomNavigationBarItem(icon: const Icon(Icons.shopping_bag), label: AppTranslations.traduzir('nav_compras', idioma)),
          BottomNavigationBarItem(icon: const Icon(Icons.history), label: AppTranslations.traduzir('nav_historico', idioma)),
          const BottomNavigationBarItem(icon: Icon(Icons.local_offer), label: 'Promoções'),
        ],
      ),
    );
  }
}