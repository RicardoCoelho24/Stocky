import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/household_service.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _codigoController = TextEditingController();
  
  String _nomeCasa = "A carregar...";
  String _codigoConvite = "";
  bool _souODono = false; 
  bool _temCasa = false; 
  List<dynamic> _moradores = []; 
  List<dynamic> _pedidosPendentes = []; 
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosDaCasa();
  }

  Future<void> _carregarDadosDaCasa() async {
    setState(() => _isLoading = true);
    final dados = await HouseholdService.getMinhaCasa();
    
    if (dados != null && mounted) {
      setState(() {
        _temCasa = true;
        _nomeCasa = dados['nomeCasa'] ?? dados['name'] ?? dados['Name'] ?? "Sem Nome";
        _codigoConvite = dados['codigoConvite'] ?? dados['inviteCode'] ?? dados['InviteCode'] ?? "";
        _souODono = dados['souODono'] ?? dados['isOwner'] ?? false;
        _moradores = dados['moradores'] ?? dados['members'] ?? dados['Members'] ?? [];
      });

      if (_souODono) {
        final pedidos = await HouseholdService.getPedidosPendentes();
        if (mounted) setState(() { _pedidosPendentes = pedidos; });
      }
      if (mounted) setState(() => _isLoading = false);
    } else if (mounted) {
      setState(() { 
        _temCasa = false; 
        _isLoading = false; 
      });
    }
  }

  void _pedirParaJuntar() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    if (_codigoController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final erro = await HouseholdService.pedirParaJuntar(_codigoController.text.trim());

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (erro == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_pedido_enviado', idioma)), backgroundColor: Colors.green));
      _codigoController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    }
  }

  void _responderPedido(int pedidoId, bool aceitar) async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    setState(() => _isActionLoading = true);
    
    final erro = await HouseholdService.responderPedido(pedidoId, aceitar);

    if (!mounted) return;
    setState(() => _isActionLoading = false);

    if (erro == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aceitar ? AppTranslations.traduzir('msg_utilizador_aceite', idioma) : AppTranslations.traduzir('msg_pedido_rejeitado', idioma)), backgroundColor: aceitar ? Colors.green : Colors.orange));
      _carregarDadosDaCasa(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.traduzir('titulo_gerir_casa', idioma)), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal)) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                if (_temCasa) ...[
                  Card(
                    elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.home_work, size: 50, color: Colors.teal),
                          const SizedBox(height: 12),
                          Text(_nomeCasa, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          if (_souODono) ...[
                            const SizedBox(height: 4),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)), child: Text(AppTranslations.traduzir('lbl_es_administrador', idioma), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade800))),
                          ],
                          const SizedBox(height: 16),
                          Text(AppTranslations.traduzir('lbl_codigo_convite', idioma), style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.shade200)), child: Text(_codigoConvite, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: 2))),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Colors.teal),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _codigoConvite));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_codigo_copiado', idioma))));
                                },
                              )
                            ],
                          ),
                          Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(AppTranslations.traduzir('msg_dar_codigo', idioma), style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_souODono && _pedidosPendentes.isNotEmpty) ...[
                    Card(
                      elevation: 2, shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.orange, width: 1.5), borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [const Icon(Icons.notification_important, color: Colors.orange), const SizedBox(width: 8), Text(AppTranslations.traduzir('lbl_pedidos_pendentes', idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange))]),
                            const Divider(),
                            ..._pedidosPendentes.map((pedido) {
                              // LEITURA BLINDADA PARA OS PEDIDOS
                              String nomePedido = pedido['name'] ?? pedido['Name'] ?? pedido['nome'] ?? "Utilizador";
                              int idPedido = pedido['id'] ?? pedido['Id'] ?? 0;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(nomePedido, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(AppTranslations.traduzir('msg_quer_entrar', idioma)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 30), onPressed: _isActionLoading ? null : () => _responderPedido(idPedido, true)),
                                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 30), onPressed: _isActionLoading ? null : () => _responderPedido(idPedido, false)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.traduzir('lbl_membros_casa', idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                          const Divider(),
                          ..._moradores.map((morador) {
                            // LEITURA BLINDADA PARA OS MORADORES
                            String? fotoBase64 = morador['profilePictureBase64'] ?? morador['foto'];
                            String nome = morador['name'] ?? morador['Name'] ?? morador['nome'] ?? "Membro";
                            String username = morador['username'] ?? morador['userName'] ?? morador['Username'] ?? "user";

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                backgroundImage: (fotoBase64 != null && fotoBase64.isNotEmpty) ? MemoryImage(base64Decode(fotoBase64)) : null,
                                child: (fotoBase64 == null || fotoBase64.isEmpty) ? Text(nome[0].toUpperCase(), style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold)) : null,
                              ),
                              title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('@$username'),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] 
                else ...[
                  Card(
                    elevation: 3, 
                    color: Colors.orange.shade50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 50, color: Colors.orange),
                          SizedBox(height: 12),
                          Text("Ainda não tens uma Casa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          SizedBox(height: 8),
                          Text("Podes pedir para te juntares à casa de alguém usando um código de convite abaixo.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppTranslations.traduzir('lbl_juntar_outra_casa', idioma), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(AppTranslations.traduzir('msg_aguardar_aprovacao', idioma), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 16),
                        TextField(controller: _codigoController, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: AppTranslations.traduzir('hint_insere_codigo', idioma), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.vpn_key))),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 45,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _pedirParaJuntar,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                            child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppTranslations.traduzir('btn_enviar_pedido', idioma)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}