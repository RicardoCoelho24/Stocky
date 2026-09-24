import 'package:flutter/material.dart';
import '../services/signalr_service.dart';
import '../services/promotion_service.dart';

class PromocoesScreen extends StatefulWidget {
  const PromocoesScreen({super.key});

  @override
  State<PromocoesScreen> createState() => _PromocoesScreenState();
}

class _PromocoesScreenState extends State<PromocoesScreen> {
  List<Map<String, dynamic>> _promocoes = [];
  bool _aCarregar = true;
  String _filtroAtual = 'Todos'; // Controla qual supermercado estamos a ver

  @override
  void initState() {
    super.initState();
    _carregarDados();
    SignalRService().addListener(_onSignalRUpdate);
  }

  @override
  void dispose() {
    SignalRService().removeListener(_onSignalRUpdate);
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _aCarregar = true);
    
    final service = PromotionService();
    final dados = await service.getPromocoesAtivas();
    
    if (mounted) {
      setState(() {
        _promocoes = dados;
        _aCarregar = false;
      });
    }
  }

  void _onSignalRUpdate() {
    if (mounted) {
      _carregarDados();
    }
  }

  // Descobre todos os supermercados únicos que vieram da Base de Dados
  List<String> get _supermercadosDisponiveis {
    final Set<String> mercados = {'Todos'};
    for (var promo in _promocoes) {
      mercados.add(promo['supermercado'] ?? 'Desconhecido');
    }
    return mercados.toList();
  }

  // Agrupa os produtos por supermercado e aplica o filtro selecionado
  Map<String, List<Map<String, dynamic>>> get _promocoesAgrupadas {
    Map<String, List<Map<String, dynamic>>> agrupadas = {};
    
    for (var promo in _promocoes) {
      String mercado = promo['supermercado'] ?? 'Desconhecido';
      
      // Se tivermos um filtro ativo e não for este mercado, ignora o produto
      if (_filtroAtual != 'Todos' && mercado != _filtroAtual) {
        continue;
      }
      
      if (!agrupadas.containsKey(mercado)) {
        agrupadas[mercado] = [];
      }
      agrupadas[mercado]!.add(promo);
    }
    
    return agrupadas;
  }

  // Função ninja para dar as cores reais às marcas!
  Color _obterCorSupermercado(String nome) {
    if (nome.toLowerCase().contains('pingo doce')) return Colors.green.shade700;
    if (nome.toLowerCase().contains('continente')) return Colors.red.shade700;
    if (nome.toLowerCase().contains('auchan')) return Colors.redAccent.shade700;
    if (nome.toLowerCase().contains('mercadona')) return Colors.green.shade900;
    if (nome.toLowerCase().contains('aldi')) return Colors.blue.shade800;
    if (nome.toLowerCase().contains('lidl')) return Colors.blue.shade600;
    return Colors.teal; // Cor por defeito
  }

  @override
  Widget build(BuildContext context) {
    final mercados = _supermercadosDisponiveis;
    final promocoesAgrupadas = _promocoesAgrupadas;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _aCarregar
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _promocoes.isEmpty
              ? const Center(
                  child: Text(
                    "Não há promoções ativas hoje.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // 1. BARRA DE FILTROS (SCROLL HORIZONTAL)
                    // ==========================================
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: mercados.map((mercado) {
                            final isSelected = _filtroAtual == mercado;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(
                                  mercado,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.teal,
                                backgroundColor: Colors.grey.shade200,
                                checkmarkColor: Colors.white,
                                onSelected: (bool value) {
                                  setState(() {
                                    _filtroAtual = mercado;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    
                    // ==========================================
                    // 2. LISTA DE PROMOÇÕES AGRUPADAS
                    // ==========================================
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: promocoesAgrupadas.keys.length,
                        itemBuilder: (context, index) {
                          String mercadoAtual = promocoesAgrupadas.keys.elementAt(index);
                          List<Map<String, dynamic>> produtosDoMercado = promocoesAgrupadas[mercadoAtual]!;
                          Color corMercado = _obterCorSupermercado(mercadoAtual);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título da Secção (Ex: Continente)
                              Padding(
                                padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 24),
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront, color: corMercado, size: 28),
                                    const SizedBox(width: 8),
                                    Text(
                                      mercadoAtual,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: corMercado,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${produtosDoMercado.length} itens',
                                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Grelha de produtos deste Supermercado
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(), // Desativa scroll interno (a ListView já faz scroll)
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.8,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: produtosDoMercado.length,
                                itemBuilder: (context, prodIndex) {
                                  final promo = produtosDoMercado[prodIndex];
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: corMercado.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              mercadoAtual,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: corMercado,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Center(
                                            child: Icon(Icons.local_offer, size: 36, color: corMercado),
                                          ),
                                          const Spacer(),
                                          Text(
                                            promo['nome'] ?? 'Produto',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${promo['preco'].toStringAsFixed(2)} €',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}