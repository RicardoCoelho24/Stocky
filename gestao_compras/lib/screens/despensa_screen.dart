import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/stock_service.dart';
import 'add_purchase_screen.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../services/open_food_facts_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import 'receipt_review_screen.dart';
import 'receita_chef_screen.dart'; // <-- IMPORT DO CHEF IA ADICIONADO
import '../utils/formatters.dart';
import '../utils/translations.dart';
import '../services/settings_provider.dart';
import '../services/signalr_service.dart';

class DespensaScreen extends StatefulWidget {
  const DespensaScreen({super.key});

  @override
  State<DespensaScreen> createState() => _DespensaScreenState();
}

class _DespensaScreenState extends State<DespensaScreen> {
  final StockService _stockService = StockService();
  late Future<List<dynamic>> _stockFuture;
  
  String _categoriaSelecionada = 'Todas';
  String _ordenacaoSelecionada = 'Nome'; 
  String _searchQuery = ''; 

  bool _isProcessingImage = false;

  final List<String> _listaCategoriasOficiais = [
    'Laticínios', 'Frutaria e Legumes', 'Talho', 'Peixaria', 'Padaria e Pastelaria', 'Mercearia', 'Bebidas', 'Limpeza e Higiene', 'Outros'
  ];

  @override
  void initState() {
    super.initState();
    _recarregarDespensa();
    
    // Começa a escutar o rádio!
    SignalRService().addListener(_onSignalRUpdate);
  }

  @override
  void dispose() {
    // Desliga o rádio ao sair do ecrã
    SignalRService().removeListener(_onSignalRUpdate);
    super.dispose();
  }

  // A função que é disparada quando chega a notificação fantasma
  void _onSignalRUpdate() {
    if (mounted) {
      _recarregarDespensa(); // Recarrega a lista sem o utilizador pedir!
    }
  }

  void _recarregarDespensa() {
    setState(() {
      _stockFuture = _stockService.getMyStock();
    });
  }

  void _consumirProduto(int produtoId) async {
    final erro = await _stockService.consumeProduct(produtoId, 1); 
    if (!mounted) return;
    
    if (erro == null) {
      _recarregarDespensa();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
    }
  }

  void _removerProdutoTotalmente(int produtoId) async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.traduzir('titulo_apagar_produto', idioma)),
        content: Text(AppTranslations.traduzir('msg_apagar_produto', idioma)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppTranslations.traduzir('btn_cancelar', idioma))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppTranslations.traduzir('btn_apagar', idioma)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final sucesso = await _stockService.removeProduct(produtoId);
      if (!mounted) return;
      if (sucesso) _recarregarDespensa();
    }
  }

  Future<void> _processarFatura(ImageSource fonte) async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    final picker = ImagePicker();
    final XFile? fotoEscolhida = await picker.pickImage(source: fonte);

    if (fotoEscolhida == null) return; 

    setState(() => _isProcessingImage = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppTranslations.traduzir('msg_ia_analisar', idioma)), duration: const Duration(seconds: 4)),
    );

    final respostaIa = await OcrService.analisarFatura(fotoEscolhida);

    if (!mounted) return;
    setState(() => _isProcessingImage = false);

    if (respostaIa != null && !respostaIa.containsKey('erro')) {
      final sucesso = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ReceiptReviewScreen(ocrData: respostaIa)),
      );
      if (sucesso == true) _recarregarDespensa();
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
            const Divider(),
            ListTile(leading: const Icon(Icons.edit_note), title: Text(AppTranslations.traduzir('btn_inserir_manualmente', idioma)), onTap: () async { Navigator.pop(context); await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPurchaseScreen())); _recarregarDespensa(); }),
          ],
        ),
      ),
    );
  }

  Future<void> _iniciarLeituraDeCodigoGlobal() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    
    String? barcode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()),
    );

    if (barcode == null || barcode == '-1') return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            const SizedBox(width: 16),
            Text('${AppTranslations.traduzir('msg_procurar_codigo', idioma)} $barcode...'),
          ],
        ),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2), 
      ),
    );

    String? nomeEncontrado = await OpenFoodFactsService.getProductName(barcode);

    if (!mounted) return;

    if (nomeEncontrado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppTranslations.traduzir('msg_encontrado', idioma)} $nomeEncontrado!'), backgroundColor: Colors.green),
      );
      _mostrarDialogoAdicionarDireto(initialName: nomeEncontrado);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.traduzir('msg_produto_nao_reconhecido', idioma)), backgroundColor: Colors.orange),
      );
      _mostrarDialogoAdicionarDireto();
    }
  }

  void _mostrarDialogoEditarProduto(dynamic item) {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    final nomeController = TextEditingController(text: item['nomeProduto'].toString());
    final medidaController = TextEditingController(text: item['medida']?.toString() ?? '');
    final qtdController = TextEditingController(text: item['quantidadeAtual'].toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.traduzir('titulo_editar_produto', idioma)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: InputDecoration(labelText: AppTranslations.traduzir('hint_nome_produto', idioma), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: medidaController,
              decoration: InputDecoration(labelText: AppTranslations.traduzir('hint_peso_capacidade', idioma), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtdController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppTranslations.traduzir('hint_qtd_atual', idioma), 
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.traduzir('btn_cancelar', idioma))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              if (nomeController.text.trim().isEmpty) return;
              
              Navigator.pop(dialogContext);
              
              await _stockService.updateProductDetails(
                item['produtoId'], 
                nomeController.text, 
                medidaController.text.trim().isEmpty ? null : medidaController.text.trim()
              );

              final novaQtd = double.tryParse(qtdController.text.replaceAll(',', '.'));
              if (novaQtd != null && novaQtd != item['quantidadeAtual']) {
                await _stockService.updateProductQuantity(item['produtoId'], novaQtd);
              }
              
              if (!mounted) return;
              _recarregarDespensa();
            },
            child: Text(AppTranslations.traduzir('btn_guardar', idioma)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarValidade(dynamic item) {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    DateTime? dataAtual = item['expirationDate'] != null ? DateTime.parse(item['expirationDate']) : null;
    final diasController = TextEditingController(text: item['daysToAlertBeforeExpiration']?.toString() ?? '3');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${AppTranslations.traduzir('lbl_validade', idioma)}: ${item['nomeProduto']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Colors.teal),
                title: Text(dataAtual == null ? AppTranslations.traduzir('lbl_definir_validade', idioma) : '${AppTranslations.traduzir('lbl_validade', idioma)}: ${Formatters.formatarData(dataAtual!)}'),
                subtitle: Text(AppTranslations.traduzir('lbl_toca_alterar', idioma)),
                onTap: () async {
                  final data = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2035));
                  if (data != null) setDialogState(() => dataAtual = data);
                },
              ),
              if (dataAtual != null)
                TextField(controller: diasController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppTranslations.traduzir('hint_avisar_dias', idioma), border: const OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async { Navigator.pop(dialogContext); await _stockService.updateExpiration(item['produtoId'], null, null); if (mounted) _recarregarDespensa(); }, 
              child: Text(AppTranslations.traduzir('btn_remover_validade', idioma), style: const TextStyle(color: Colors.red))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final sucesso = await _stockService.updateExpiration(item['produtoId'], dataAtual, int.tryParse(diasController.text));
                if (!context.mounted) return;
                if (sucesso) _recarregarDespensa();
              },
              child: Text(AppTranslations.traduzir('btn_guardar', idioma)),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoAlerta(dynamic item) {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    final controller = TextEditingController(text: item['alertaMinimo'].toString());
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${AppTranslations.traduzir('titulo_alerta_minimo', idioma)}: ${item['nomeProduto']}'),
        content: TextField(
          controller: controller, 
          keyboardType: TextInputType.number, 
          decoration: InputDecoration(
            labelText: AppTranslations.traduzir('hint_avisar_stock', idioma), 
            border: const OutlineInputBorder(),
            helperText: AppTranslations.traduzir('hint_zero_lista', idioma),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final sucesso = await _stockService.updateThreshold(item['produtoId'], 0);
              if (!context.mounted) return;
              if (sucesso) _recarregarDespensa(); 
            }, 
            child: Text(AppTranslations.traduzir('btn_desligar', idioma), style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              final novoValor = int.tryParse(controller.text) ?? 1; 
              Navigator.pop(dialogContext);
              final sucesso = await _stockService.updateThreshold(item['produtoId'], novoValor);
              if (!context.mounted) return;
              if (sucesso) _recarregarDespensa(); 
            },
            child: Text(AppTranslations.traduzir('btn_guardar', idioma)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarCategoria(dynamic item) {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    String categoriaTemporaria = _listaCategoriasOficiais.contains(item['categoria']) ? item['categoria'] : 'Outros';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${AppTranslations.traduzir('titulo_categoria', idioma)}: ${item['nomeProduto']}'),
        content: DropdownButtonFormField<String>(
          initialValue: categoriaTemporaria,
          decoration: InputDecoration(border: const OutlineInputBorder(), labelText: AppTranslations.traduzir('titulo_categoria', idioma)),
          items: _listaCategoriasOficiais.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
          onChanged: (val) { if (val != null) categoriaTemporaria = val; },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.traduzir('btn_cancelar', idioma))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final sucesso = await _stockService.updateProductCategory(item['produtoId'], categoriaTemporaria);
              if (!context.mounted) return;
              if (sucesso) _recarregarDespensa();
            },
            child: Text(AppTranslations.traduzir('btn_gravar', idioma)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAdicionarDireto({String? initialName}) {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    final nomeController = TextEditingController(text: initialName ?? '');
    final qtdController = TextEditingController();
    final diasAvisoController = TextEditingController(text: '3');
    final alertaMinimoController = TextEditingController(text: '1'); 
    DateTime? dataValidadeEscolhida;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(children: [const Icon(Icons.playlist_add, color: Colors.teal), const SizedBox(width: 8), Text(AppTranslations.traduzir('titulo_entrada_direta', idioma))]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController, 
                  decoration: InputDecoration(
                    labelText: AppTranslations.traduzir('hint_nome_produto', idioma), 
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                      onPressed: () async {
                        String? res = await Navigator.push(context, MaterialPageRoute(builder: (context) => SimpleBarcodeScannerPage(key: UniqueKey())));
                        if (res != null && res != '-1') {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_procurar_bd', idioma))));
                          String? nomeProduto = await OpenFoodFactsService.getProductName(res);
                          if (nomeProduto != null) {
                            setDialogState(() { nomeController.text = nomeProduto; });
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_produto_nao_encontrado', idioma)), backgroundColor: Colors.orange));
                          }
                        }
                      },
                    ),
                  )
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: qtdController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_qtd', idioma), border: const OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: alertaMinimoController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_aviso_min', idioma), border: const OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.date_range, color: Colors.teal),
                  title: Text(dataValidadeEscolhida == null ? AppTranslations.traduzir('lbl_definir_validade', idioma) : '${AppTranslations.traduzir('lbl_validade', idioma)}: ${Formatters.formatarData(dataValidadeEscolhida!)}'),
                  subtitle: Text(AppTranslations.traduzir('lbl_opcional', idioma)),
                  onTap: () async {
                    final data = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2035));
                    if (data != null) setDialogState(() => dataValidadeEscolhida = data);
                  },
                ),
                if (dataValidadeEscolhida != null) ...[
                  const SizedBox(height: 8),
                  TextField(controller: diasAvisoController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: AppTranslations.traduzir('hint_avisar_dias', idioma), border: const OutlineInputBorder())),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.traduzir('btn_cancelar', idioma))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                if (nomeController.text.isEmpty || qtdController.text.isEmpty) return;
                Navigator.pop(dialogContext);
                
                await _stockService.addStockDirectly(
                  productName: nomeController.text, 
                  quantity: double.tryParse(qtdController.text) ?? 1.0,
                  minAlertThreshold: int.tryParse(alertaMinimoController.text) ?? 1, 
                  expirationDate: dataValidadeEscolhida, 
                  daysToAlert: int.tryParse(diasAvisoController.text),
                );
                _recarregarDespensa(); 
              },
              child: Text(AppTranslations.traduzir('btn_adicionar', idioma)),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatarData(String? dataIso, String idioma) {
    if (dataIso == null) return AppTranslations.traduzir('lbl_nao_definida', idioma);
    final data = DateTime.parse(dataIso);
    return Formatters.formatarData(data); 
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.traduzir('titulo_minha_despensa', idioma)),
        backgroundColor: Colors.transparent,
        actions: [
          // <-- BOTÃO DO CHEF IA ADICIONADO AQUI -->
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.deepOrange),
            tooltip: 'Chef IA - Sugestão de Receita',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReceitaChefScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
            tooltip: AppTranslations.traduzir('tooltip_escanear_rapido', idioma),
            onPressed: _iniciarLeituraDeCodigoGlobal,
          ),
          Row(
            children: [
              const Icon(Icons.sort, size: 20, color: Colors.grey),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: _ordenacaoSelecionada,
                underline: const SizedBox(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                items: [
                  DropdownMenuItem(value: 'Nome', child: Text(AppTranslations.traduzir('ordenar_por_nome', idioma))),
                  DropdownMenuItem(value: 'Validade', child: Text(AppTranslations.traduzir('ordenar_por_validade', idioma))),
                  DropdownMenuItem(value: 'Stock', child: Text(AppTranslations.traduzir('ordenar_por_stock', idioma))),
                ],
                onChanged: (val) { if (val != null) setState(() => _ordenacaoSelecionada = val); },
              ),
              const SizedBox(width: 12),
            ],
          )
        ],
      ),
      
      body: Stack(
        children: [
          FutureBuilder<List<dynamic>>(
            future: _stockFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              if (snapshot.hasError) return Center(child: Text(AppTranslations.traduzir('msg_erro_carregar_despensa', idioma)));
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text(AppTranslations.traduzir('msg_despensa_vazia', idioma), style: const TextStyle(fontSize: 18, color: Colors.grey)));
              }

              List<dynamic> stockOriginal = List.from(snapshot.data!);
              List<dynamic> stock = List.from(stockOriginal);

              final categoriasUnicas = stockOriginal.map((item) => item['categoria']?.toString() ?? AppTranslations.traduzir('categoria_outros', idioma)).toSet().toList();
              categoriasUnicas.sort();
              final listaFiltros = ['Todas', 'Com Stock', 'Esgotados', ...categoriasUnicas];

              if (_searchQuery.trim().isNotEmpty) {
                stock = stock.where((item) => 
                  (item['nomeProduto'] ?? '').toString().toLowerCase().contains(_searchQuery.trim().toLowerCase())
                ).toList();
              }

              if (_categoriaSelecionada == 'Com Stock') {
                stock = stock.where((item) => (item['quantidadeAtual'] ?? 0) > 0).toList();
              } else if (_categoriaSelecionada == 'Esgotados') {
                stock = stock.where((item) => (item['quantidadeAtual'] ?? 0) <= 0).toList();
              } else if (_categoriaSelecionada != 'Todas') {
                stock = stock.where((item) => (item['categoria'] ?? AppTranslations.traduzir('categoria_outros', idioma)) == _categoriaSelecionada).toList();
              }

              if (_ordenacaoSelecionada == 'Nome') {
                stock.sort((a, b) => (a['nomeProduto'] ?? '').toString().compareTo((b['nomeProduto'] ?? '').toString()));
              } else if (_ordenacaoSelecionada == 'Validade') {
                 stock.sort((a, b) {
                  if (a['expirationDate'] == null && b['expirationDate'] == null) return 0;
                  if (a['expirationDate'] == null) return 1; 
                  if (b['expirationDate'] == null) return -1;
                  return DateTime.parse(a['expirationDate']).compareTo(DateTime.parse(b['expirationDate']));
                });
              } else if (_ordenacaoSelecionada == 'Stock') {
                stock.sort((a, b) => (a['quantidadeAtual'] ?? 0).compareTo(b['quantidadeAtual'] ?? 0));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: AppTranslations.traduzir('hint_pesquisar_produto', idioma),
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),

                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: listaFiltros.length,
                      itemBuilder: (context, index) {
                        final filtro = listaFiltros[index];
                        String nomeFiltro = filtro;
                        if (filtro == 'Todas') nomeFiltro = AppTranslations.traduzir('filtro_todas', idioma);
                        else if (filtro == 'Com Stock') nomeFiltro = AppTranslations.traduzir('filtro_com_stock', idioma);
                        else if (filtro == 'Esgotados') nomeFiltro = AppTranslations.traduzir('filtro_esgotados', idioma);
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(nomeFiltro),
                            selected: _categoriaSelecionada == filtro,
                            selectedColor: Colors.teal.shade100,
                            onSelected: (bool selected) { setState(() => _categoriaSelecionada = filtro); },
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: stock.isEmpty 
                      ? Center(child: Text(AppTranslations.traduzir('msg_nenhum_produto_encontrado', idioma), style: const TextStyle(color: Colors.grey)))
                      : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: stock.length,
                      itemBuilder: (context, index) {
                        final item = stock[index];
                        final currentQuantity = item['quantidadeAtual'] ?? 0; 
                        final alertThreshold = item['alertaMinimo'] ?? 1;
                        
                        bool stockBaixo = currentQuantity <= alertThreshold;
                        bool expirado = false;
                        bool emAlertaValidade = false;

                        if (item['expirationDate'] != null) {
                          final dataVal = DateTime.parse(item['expirationDate']);
                          final hoje = DateTime.now();
                          final diasAviso = item['daysToAlertBeforeExpiration'] ?? 3;
                          if (dataVal.isBefore(hoje)) expirado = true;
                          else if (dataVal.difference(hoje).inDays <= diasAviso) emAlertaValidade = true;
                        }

                        Color corBorda = Colors.teal.shade100;
                        if (expirado) corBorda = Colors.red.shade700;
                        else if (emAlertaValidade) corBorda = Colors.amber.shade700;
                        else if (stockBaixo) corBorda = Colors.orange.shade400; 

                        String tituloProduto = item['nomeProduto'].toString();
                        if (item['medida'] != null && item['medida'].toString().isNotEmpty) {
                          tituloProduto += ' (${item['medida']})';
                        }

                        return Card(
                          elevation: 0.5,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: corBorda, width: (expirado || emAlertaValidade || stockBaixo) ? 2 : 1),
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: expirado ? Colors.red.shade50 : (emAlertaValidade ? Colors.amber.shade50 : (stockBaixo ? Colors.orange.shade50 : Colors.teal.shade50)),
                              child: Icon(
                                expirado ? Icons.gpp_bad : (emAlertaValidade ? Icons.running_with_errors : (stockBaixo ? Icons.warning_amber_rounded : Icons.inventory_2_outlined)),
                                color: expirado ? Colors.red.shade800 : (emAlertaValidade ? Colors.amber.shade900 : (stockBaixo ? Colors.orange.shade800 : Colors.teal)),
                              ),
                            ),
                            title: Text(tituloProduto, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${AppTranslations.traduzir('lbl_qtd_short', idioma)} $currentQuantity (${AppTranslations.traduzir('lbl_min', idioma)} $alertThreshold) | ${item['categoria'] ?? AppTranslations.traduzir('categoria_outros', idioma)}\n${AppTranslations.traduzir('lbl_validade', idioma)}: ${_formatarData(item['expirationDate'], idioma)}', style: const TextStyle(fontSize: 13)),
                            
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (stockBaixo && !expirado) Text(AppTranslations.traduzir('lbl_stock_baixo', idioma), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20), tooltip: AppTranslations.traduzir('tooltip_editar_produto', idioma), onPressed: () => _mostrarDialogoEditarProduto(item)),
                                IconButton(icon: const Icon(Icons.edit_calendar, color: Colors.blueGrey, size: 20), tooltip: AppTranslations.traduzir('tooltip_mudar_validade', idioma), onPressed: () => _mostrarDialogoEditarValidade(item)),
                                IconButton(icon: const Icon(Icons.label_outline, color: Colors.teal, size: 20), tooltip: AppTranslations.traduzir('tooltip_mudar_categoria', idioma), onPressed: () => _mostrarDialogoEditarCategoria(item)),
                                IconButton(icon: const Icon(Icons.notifications_active_outlined, color: Colors.blue, size: 20), tooltip: AppTranslations.traduzir('tooltip_alerta_minimo', idioma), onPressed: () => _mostrarDialogoAlerta(item)),
                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 20), tooltip: AppTranslations.traduzir('tooltip_consumir', idioma), onPressed: currentQuantity > 0 ? () => _consumirProduto(item['produtoId']) : null),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), tooltip: AppTranslations.traduzir('tooltip_apagar', idioma), onPressed: () => _removerProdutoTotalmente(item['produtoId'])),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 16),
                    Text(AppTranslations.traduzir('msg_ia_analisar', idioma), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text(AppTranslations.traduzir('titulo_entrada_direta', idioma)),
                  onPressed: _isProcessingImage ? null : _mostrarDialogoAdicionarDireto,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(AppTranslations.traduzir('btn_nova_compra', idioma)),
                  onPressed: _isProcessingImage ? null : () => _mostrarMenuDeOpcoes(idioma),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}