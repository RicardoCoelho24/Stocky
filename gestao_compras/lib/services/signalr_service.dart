import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';

// Usamos o ChangeNotifier para que vários ecrãs possam "escutar" ao mesmo tempo
class SignalRService extends ChangeNotifier {
  // Singleton: garante que só existe UMA ligação aberta em toda a app
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _hubConnection;

  Future<void> startConnection() async {
    if (_hubConnection != null && _hubConnection!.state == HubConnectionState.Connected) {
      return; // Já está ligado!
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return;

    // A tua baseUrl já não contém "/api" no final (vimos no api_constants.dart), 
    // logo podemos chamar diretamente o Hub!
    final hubUrl = '${ApiConstants.baseUrl}/householdHub';

    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl, options: HttpConnectionOptions(
          // LER SEMPRE O TOKEN MAIS RECENTE DIRETAMENTE DO FACTORY
          accessTokenFactory: () async {
             final prefsAtual = await SharedPreferences.getInstance();
             // Adicionámos o ?? "" para garantir que nunca devolve nulo
             return prefsAtual.getString('jwt_token') ?? ""; 
          },
        ))
        .withAutomaticReconnect()
        .build();

    // ======================================================
    // OUVIR O GRITO DO SERVIDOR!
    // ======================================================
    _hubConnection?.on('UpdateStock', (arguments) {
      debugPrint('🔔 [SIGNALR] Alguém alterou a despensa! A atualizar ecrãs...');
      notifyListeners(); // Apita para a Despensa e Compras se atualizarem!
    });

    try {
      await _hubConnection?.start();
      debugPrint('✅ [SIGNALR] Ligado com sucesso à Casa!');
    } catch (e) {
      debugPrint('❌ [SIGNALR] Erro ao ligar: $e');
    }
  }

  Future<void> stopConnection() async {
    await _hubConnection?.stop();
    _hubConnection = null;
    debugPrint('🛑 [SIGNALR] Desligado.');
  }
}