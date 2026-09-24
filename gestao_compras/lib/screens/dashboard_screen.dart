import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_service.dart';
import '../services/settings_provider.dart';
import '../services/report_service.dart'; // <-- IMPORT ADICIONADO
import '../utils/translations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  final ReportService _reportService = ReportService(); // <-- SERVIÇO DE RELATÓRIO
  
  late Future<Map<String, dynamic>?> _dashboardFuture;
  DateTime _dateReferencia = DateTime.now();
  bool _aDescarregar = false; // <-- ESTADO DE DOWNLOAD

  @override
  void initState() {
    super.initState();
    _recarregarDashboard();
  }

  void _recarregarDashboard() {
    setState(() {
      _dashboardFuture = _service.getSummary(date: _dateReferencia);
    });
  }

  // <-- FUNÇÃO DE EXPORTAÇÃO ADICIONADA -->
  Future<void> _exportarRelatorio() async {
    setState(() {
      _aDescarregar = true;
    });

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A gerar ficheiro Excel...'), duration: Duration(seconds: 2)),
      );

      // Usa a data que está atualmente selecionada no Dashboard
      await _reportService.descarregarEAbriExcel(_dateReferencia.year, _dateReferencia.month);

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

  void _escolherPeriodo() async {
    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dateReferencia,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), 
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null) {
      setState(() {
        _dateReferencia = dataEscolhida;
      });
      _recarregarDashboard(); 
    }
  }

  IconData _obterIconeCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'laticínios': return Icons.icecream;
      case 'frutaria e legumes': return Icons.apple;
      case 'talho': return Icons.set_meal;
      case 'padaria e pastelaria': return Icons.bakery_dining;
      case 'bebidas': return Icons.local_drink;
      case 'limpeza e higiene': return Icons.cleaning_services;
      default: return Icons.shopping_bag;
    }
  }

  Widget _buildResumoCard(String titulo, double valor, Color cor, IconData icone) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: cor.withValues(alpha: 0.1), 
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cor.withValues(alpha: 0.4), width: 1.5), 
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
          child: Column(
            children: [
              Icon(icone, color: cor, size: 28),
              const SizedBox(height: 8),
              Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                '${valor.toStringAsFixed(2)}€',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
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
    
    final mesesExtenso = [
      AppTranslations.traduzir('mes_1', idioma), AppTranslations.traduzir('mes_2', idioma), 
      AppTranslations.traduzir('mes_3', idioma), AppTranslations.traduzir('mes_4', idioma), 
      AppTranslations.traduzir('mes_5', idioma), AppTranslations.traduzir('mes_6', idioma), 
      AppTranslations.traduzir('mes_7', idioma), AppTranslations.traduzir('mes_8', idioma), 
      AppTranslations.traduzir('mes_9', idioma), AppTranslations.traduzir('mes_10', idioma), 
      AppTranslations.traduzir('mes_11', idioma), AppTranslations.traduzir('mes_12', idioma)
    ];

    final mesesCurto = [
      AppTranslations.traduzir('mes_curto_1', idioma), AppTranslations.traduzir('mes_curto_2', idioma), 
      AppTranslations.traduzir('mes_curto_3', idioma), AppTranslations.traduzir('mes_curto_4', idioma), 
      AppTranslations.traduzir('mes_curto_5', idioma), AppTranslations.traduzir('mes_curto_6', idioma), 
      AppTranslations.traduzir('mes_curto_7', idioma), AppTranslations.traduzir('mes_curto_8', idioma), 
      AppTranslations.traduzir('mes_curto_9', idioma), AppTranslations.traduzir('mes_curto_10', idioma), 
      AppTranslations.traduzir('mes_curto_11', idioma), AppTranslations.traduzir('mes_curto_12', idioma)
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.traduzir('titulo_dashboard', idioma)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // <-- BOTÃO DE EXPORTAÇÃO ADICIONADO AQUI -->
          _aDescarregar 
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                ),
              )
            : IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Exportar Excel',
                onPressed: _exportarRelatorio,
              ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: AppTranslations.traduzir('tooltip_mudar_periodo', idioma),
            onPressed: _escolherPeriodo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recarregarDashboard,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          } else if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(AppTranslations.traduzir('msg_erro_estatisticas', idioma)));
          }

          final dados = snapshot.data!;
          
          final gastoSemana = (dados['gastoSemana'] ?? 0).toDouble();
          final gastoMes = (dados['gastoMes'] ?? 0).toDouble();
          final gastoAno = (dados['gastoAno'] ?? 0).toDouble();
          
          final mediaSemana = (dados['mediaSemana'] ?? 0).toDouble();
          final mediaMes = (dados['mediaMes'] ?? 0).toDouble();
          final mediaAno = (dados['mediaAno'] ?? 0).toDouble();

          final gastosPorMes = dados['gastosPorMes'] as List<dynamic>? ?? [];
          final top10Produtos = dados['top10Produtos'] as List<dynamic>? ?? [];
          final gastosPorCategoria = dados['gastosPorCategoria'] as List<dynamic>? ?? [];

          List<BarChartGroupData> barGroups = [];
          double maxGasto = 0;
          for (var item in gastosPorMes) {
            int mes = item['mes'];
            double total = (item['total'] ?? 0).toDouble();
            if (total > maxGasto) maxGasto = total;

            barGroups.add(
              BarChartGroupData(
                x: mes,
                barRods: [
                  BarChartRodData(
                    toY: total,
                    color: Colors.teal,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }
          if (maxGasto == 0) maxGasto = 100;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: Colors.teal.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${AppTranslations.traduzir('lbl_analisar_dados', idioma)} ${mesesExtenso[_dateReferencia.month - 1]} ${_dateReferencia.year}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppTranslations.traduzir('lbl_gastos_periodo', idioma), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              setState(() => _dateReferencia = DateTime.now());
                              _recarregarDashboard();
                            }, 
                            child: Text(AppTranslations.traduzir('btn_voltar_hoje', idioma))
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildResumoCard(AppTranslations.traduzir('lbl_naquela_semana', idioma), gastoSemana, Colors.blue, Icons.view_week),
                          const SizedBox(width: 8),
                          _buildResumoCard(AppTranslations.traduzir('lbl_naquele_mes', idioma), gastoMes, Colors.orange, Icons.calendar_month),
                          const SizedBox(width: 8),
                          _buildResumoCard(AppTranslations.traduzir('lbl_naquele_ano', idioma), gastoAno, Colors.green, Icons.emoji_events),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      Text(AppTranslations.traduzir('lbl_medias_gerais', idioma), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildResumoCard(AppTranslations.traduzir('lbl_media_semanal', idioma), mediaSemana, Colors.purple, Icons.auto_graph),
                          const SizedBox(width: 8),
                          _buildResumoCard(AppTranslations.traduzir('lbl_media_mensal', idioma), mediaMes, Colors.pink, Icons.analytics),
                          const SizedBox(width: 8),
                          _buildResumoCard(AppTranslations.traduzir('lbl_media_anual', idioma), mediaAno, Colors.indigo, Icons.account_balance),
                        ],
                      ),
                      
                      const SizedBox(height: 32),

                      Text('${AppTranslations.traduzir('lbl_evolucao_mensal', idioma)} (${_dateReferencia.year})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 230,
                        child: barGroups.isEmpty 
                          ? Center(child: Text(AppTranslations.traduzir('msg_sem_compras_ano', idioma), style: const TextStyle(color: Colors.grey)))
                          : BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxGasto * 1.2,
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        int index = value.toInt() - 1;
                                        if (index >= 0 && index < 12) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(mesesCurto[index], style: const TextStyle(fontSize: 12)),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: barGroups,
                              ),
                            ),
                      ),
                      
                      const SizedBox(height: 32),

                      // --- GASTOS POR CATEGORIA ---
                      Text('${AppTranslations.traduzir('lbl_gastos_categoria_em', idioma)} ${_dateReferencia.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (gastosPorCategoria.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(AppTranslations.traduzir('msg_sem_categorias_ano', idioma), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        )
                      else
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.teal.shade50),
                            columnSpacing: 20,
                            horizontalMargin: 16,
                            columns: [
                              DataColumn(label: Text(AppTranslations.traduzir('lbl_categoria', idioma), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                              DataColumn(label: Text(AppTranslations.traduzir('lbl_total', idioma), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)), numeric: true),
                            ],
                            rows: gastosPorCategoria.map((gasto) {
                              String categoria = gasto['categoria']?.toString() ?? AppTranslations.traduzir('categoria_outros', idioma);
                              double total = (gasto['total'] ?? 0).toDouble();
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Icon(_obterIconeCategoria(categoria), size: 18, color: Colors.grey.shade700),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(categoria, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text('${total.toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 32),

                      Text('${AppTranslations.traduzir('lbl_top_10_produtos', idioma)} ${_dateReferencia.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (top10Produtos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                          AppTranslations.traduzir('msg_sem_produtos_ano', idioma),
                          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic), 
                        ),
                      ),
                      ...top10Produtos.asMap().entries.map((entry) {
                        int index = entry.key;
                        var p = entry.value;
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index < 3 ? Colors.amber : Colors.teal.shade100,
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: index < 3 ? Colors.white : Colors.teal.shade800),
                              ),
                            ),
                            title: Text(p['nome'] ?? AppTranslations.traduzir('msg_produto_desconhecido', idioma), style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text(
                              '${p['quantidade']} ${AppTranslations.traduzir('lbl_unidades', idioma)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}