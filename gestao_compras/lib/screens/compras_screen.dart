import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/stock_service.dart';
import '../services/ocr_service.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';
import 'receipt_review_screen.dart';
import '../services/signalr_service.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  final StockService _stockService = StockService();
  late Future<List<dynamic>> _comprasFuture;

  bool _isProcessingImage = false;

  String _categoriaSelecionada = 'Todas';
  String _ordenacaoSelecionada = 'Nome';
  String _searchQuery = '';

  final Set<int> _produtosNoCarrinho = {};

  @override
  void initState() {
    super.initState();
    _recarregarLista();
    
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
      _recarregarLista(); // Recarrega a lista sem o utilizador pedir!
    }
  }

  void _recarregarLista() {
    setState(() {
      _comprasFuture = _stockService.getShoppingList();
      _produtosNoCarrinho.clear(); 
    });
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
        MaterialPageRoute(
          builder: (context) => ReceiptReviewScreen(ocrData: respostaIa),
        ),
      );

      if (sucesso == true) {
        _recarregarLista();
      }
    } else {
      final erro = respostaIa?['erro'] ?? AppTranslations.traduzir('msg_erro_ler_fatura', idioma);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro), backgroundColor: Colors.red),
      );
    }
  }

  void _mostrarMenuDeOpcoes(String idioma) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppTranslations.traduzir('btn_tirar_foto', idioma)),
              onTap: () {
                Navigator.pop(context);
                _processarFatura(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppTranslations.traduzir('btn_escolher_galeria', idioma)),
              onTap: () {
                Navigator.pop(context);
                _processarFatura(ImageSource.gallery);
              },
            ),
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
        title: Text(AppTranslations.traduzir('titulo_lista_compras', idioma)),
        backgroundColor: Colors.transparent,
        actions: [
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
                  DropdownMenuItem(value: 'Stock', child: Text(AppTranslations.traduzir('ordenar_por_stock', idioma))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _ordenacaoSelecionada = val);
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recarregarLista,
            tooltip: AppTranslations.traduzir('tooltip_atualizar_lista', idioma),
          ),
          const SizedBox(width: 8),
        ],
      ),
      
      body: Stack(
        children: [
          FutureBuilder<List<dynamic>>(
            future: _comprasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              } else if (snapshot.hasError) {
                return Center(child: Text(AppTranslations.traduzir('msg_erro_carregar_lista', idioma)));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      Text(
                        AppTranslations.traduzir('msg_despensa_em_dia', idioma),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              List<dynamic> stockOriginal = List.from(snapshot.data!);
              List<dynamic> stock = List.from(stockOriginal);
              
              final categoriasUnicas = stockOriginal.map((item) => item['categoria']?.toString() ?? AppTranslations.traduzir('categoria_outros', idioma)).toSet().toList();
              categoriasUnicas.sort();
              final listaFiltros = ['Todas', ...categoriasUnicas];

              if (_searchQuery.trim().isNotEmpty) {
                stock = stock.where((item) => 
                  (item['nomeProduto'] ?? '').toString().toLowerCase().contains(_searchQuery.trim().toLowerCase())
                ).toList();
              }

              if (_categoriaSelecionada != 'Todas') {
                stock = stock.where((item) {
                  String cat = item['categoria'] ?? AppTranslations.traduzir('categoria_outros', idioma);
                  return cat == _categoriaSelecionada;
                }).toList();
              }

              if (_ordenacaoSelecionada == 'Nome') {
                stock.sort((a, b) => (a['nomeProduto'] ?? '').toString().compareTo((b['nomeProduto'] ?? '').toString()));
              } else if (_ordenacaoSelecionada == 'Stock') {
                stock.sort((a, b) => (a['quantidadeAtual'] ?? 0).compareTo(b['quantidadeAtual'] ?? 0));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: AppTranslations.traduzir('hint_pesquisar_lista', idioma),
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
                        String nomeFiltro = filtro == 'Todas' ? AppTranslations.traduzir('filtro_todas', idioma) : filtro;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(nomeFiltro),
                            selected: _categoriaSelecionada == filtro,
                            selectedColor: Colors.teal.shade100,
                            onSelected: (bool selected) { 
                              setState(() => _categoriaSelecionada = filtro); 
                            },
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
                          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
                          itemCount: stock.length,
                          itemBuilder: (context, index) {
                            final item = stock[index];
                            
                            final produtoId = item['produtoId'];
                            final productName = item['nomeProduto'] ?? AppTranslations.traduzir('msg_produto_desconhecido', idioma);
                            final currentQuantity = item['quantidadeAtual'] ?? 0;
                            final alertThreshold = item['alertaMinimo'] ?? 1;

                            String tituloProduto = productName.toString();
                            if (item['medida'] != null && item['medida'].toString().isNotEmpty) {
                              tituloProduto += ' (${item['medida']})';
                            }

                            final isMarcado = _produtosNoCarrinho.contains(produtoId);
                            final lblRestam = AppTranslations.traduzir('lbl_restam', idioma);
                            final lblAlerta = AppTranslations.traduzir('lbl_alerta', idioma);
                            final lblCat = item['categoria'] ?? AppTranslations.traduzir('categoria_outros', idioma);

                            return Card(
                              elevation: 0,
                              color: isMarcado ? Colors.grey.shade100 : Colors.orange.shade50,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: isMarcado ? Colors.grey.shade300 : Colors.orange.shade200, 
                                  width: 1
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(
                                  isMarcado ? Icons.shopping_cart : Icons.shopping_cart_checkout, 
                                  color: isMarcado ? Colors.grey : Colors.orange
                                ),
                                title: Text(
                                  tituloProduto,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16,
                                    decoration: isMarcado ? TextDecoration.lineThrough : null,
                                    color: isMarcado ? Colors.grey : Colors.black,
                                  ),
                                ),
                                subtitle: Text(
                                  '$lblRestam: $currentQuantity  ($lblAlerta: $alertThreshold) | $lblCat',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                trailing: Checkbox(
                                  value: isMarcado,
                                  activeColor: Colors.teal,
                                  onChanged: (bool? valor) {
                                    setState(() {
                                      if (valor == true) {
                                        _produtosNoCarrinho.add(produtoId);
                                      } else {
                                        _produtosNoCarrinho.remove(produtoId);
                                      }
                                    });
                                  },
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
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessingImage ? null : () => _mostrarMenuDeOpcoes(idioma),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner),
        label: Text(AppTranslations.traduzir('btn_ler_talao', idioma)),
      ),
    );
  }
}