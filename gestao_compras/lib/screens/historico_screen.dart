import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';
import '../services/ocr_service.dart';
import '../services/settings_provider.dart';
import '../services/report_service.dart'; // <-- IMPORT ADICIONADO
import '../utils/translations.dart';
import 'receipt_review_screen.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final PurchaseService _service = PurchaseService();
  final ReportService _reportService = ReportService(); // <-- SERVIÇO DE RELATÓRIO
  late Future<List<dynamic>> _historicoFuture;
  
  bool _isProcessingImage = false;
  bool _aDescarregar = false; // <-- ESTADO DE DOWNLOAD

  @override
  void initState() {
    super.initState();
    _recarregarHistorico();
  }

  void _recarregarHistorico() {
    setState(() { _historicoFuture = _service.getPurchaseHistory(); });
  }

  // <-- FUNÇÃO DE EXPORTAÇÃO ADICIONADA -->
  Future<void> _exportarRelatorio() async {
    setState(() {
      _aDescarregar = true;
    });

    final dataAtual = DateTime.now();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A gerar ficheiro Excel...'), duration: Duration(seconds: 2)),
      );

      // Exporta sempre os dados do mês atual no ecrã de histórico
      await _reportService.descarregarEAbriExcel(dataAtual.year, dataAtual.month);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _aDescarregar = false;
      });
    }
  }

  String _formatarData(String dataIso) {
    try {
      final data = DateTime.parse(dataIso);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    } catch (e) { return dataIso; }
  }

  Future<void> _processarFatura(ImageSource fonte) async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    final picker = ImagePicker();
    final XFile? fotoEscolhida = await picker.pickImage(source: fonte);

    if (fotoEscolhida == null) return; 

    setState(() => _isProcessingImage = true);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_ia_ler_talao', idioma)), duration: const Duration(seconds: 4)));

    final respostaIa = await OcrService.analisarFatura(fotoEscolhida);

    if (!mounted) return;
    setState(() => _isProcessingImage = false);

    if (respostaIa != null && !respostaIa.containsKey('erro')) {
      final sucesso = await Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptReviewScreen(ocrData: respostaIa)));
      if (sucesso == true) _recarregarHistorico();
    } else {
      final erro = respostaIa?['erro'] ?? AppTranslations.traduzir('msg_erro_ler_fatura', idioma);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    }
  }

  void _mostrarMenuDeOpcoes(String idioma) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: Text(AppTranslations.traduzir('btn_tirar_foto', idioma)), onTap: () { Navigator.pop(context); _processarFatura(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: Text(AppTranslations.traduzir('btn_escolher_galeria', idioma)), onTap: () { Navigator.pop(context); _processarFatura(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.traduzir('titulo_historico', idioma)),
        backgroundColor: Colors.transparent,
        actions: [
          // <-- BOTÃO DE EXPORTAÇÃO ADICIONADO AQUI -->
          _aDescarregar 
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(color: Colors.teal, strokeWidth: 2)
                ),
              )
            : IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Exportar Excel',
                onPressed: _exportarRelatorio,
              ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recarregarHistorico)
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<dynamic>>(
            future: _historicoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              else if (snapshot.hasError) return Center(child: Text(AppTranslations.traduzir('msg_erro_carregar_historico', idioma)));
              else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(AppTranslations.traduzir('msg_sem_historico', idioma), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)));
              }

              final historico = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 80),
                itemCount: historico.length,
                itemBuilder: (context, index) {
                  final fatura = historico[index];
                  final superName = fatura['supermarketName'] ?? AppTranslations.traduzir('lbl_desconhecido', idioma);
                  final data = _formatarData(fatura['purchaseDate'] ?? '');
                  final total = (fatura['totalAmount'] ?? 0.0) * 1.0; 
                  final totalDesconto = (fatura['totalDiscount'] ?? 0.0) * 1.0; 
                  final itens = fatura['items'] as List<dynamic>? ?? [];

                  return Card(
                    elevation: 2, margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(backgroundColor: totalDesconto > 0 ? Colors.green.shade600 : Colors.teal, child: Icon(totalDesconto > 0 ? Icons.savings : Icons.receipt, color: Colors.white)),
                      title: Text(superName.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data),
                          if (totalDesconto > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(4)),
                                child: Text('${AppTranslations.traduzir('lbl_poupaste', idioma)} ${totalDesconto.toStringAsFixed(2)}€! 🎉', style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      trailing: Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                      children: [
                        const Divider(height: 1),
                        Container(
                          color: Colors.grey.shade50, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            children: itens.map((item) {
                              final pName = item['productName'] ?? AppTranslations.traduzir('msg_produto_desconhecido', idioma);
                              final qty = item['quantity'] ?? 1;
                              final price = item['unitPrice'] ?? 0.0;
                              final totalLinha = qty * price;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('${qty}x $pName', style: const TextStyle(fontSize: 14))),
                                    Text('${price.toStringAsFixed(2)}€', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                    const SizedBox(width: 16),
                                    Text('${totalLinha.toStringAsFixed(2)}€', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (_isProcessingImage)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.teal), const SizedBox(height: 16),
                    Text(AppTranslations.traduzir('msg_ia_analisar', idioma), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessingImage ? null : () => _mostrarMenuDeOpcoes(idioma),
        backgroundColor: Colors.teal, foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner),
        label: Text(AppTranslations.traduzir('btn_ler_talao', idioma)),
      ),
    );
  }
}