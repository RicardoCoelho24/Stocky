import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';

class PurchaseItemRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController alertCtrl = TextEditingController(text: '1'); 
  
  DateTime? expirationDate;
  final TextEditingController daysToAlertCtrl = TextEditingController(text: '3');

  double get totalLine {
    final q = double.tryParse(quantityCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final p = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    return q * p;
  }
}

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final PurchaseService _service = PurchaseService();
  final TextEditingController _supermarketCtrl = TextEditingController();
  DateTime _purchaseDate = DateTime.now();
  
  final List<PurchaseItemRow> _items = [PurchaseItemRow()]; 
  bool _isSaving = false;

  double get _totalGeral {
    return _items.fold(0.0, (sum, item) => sum + item.totalLine);
  }

  void _guardarFatura() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    
    final superName = _supermarketCtrl.text.trim();
    if (superName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_erro_supermercado', idioma)), backgroundColor: Colors.red));
      return;
    }
    
    final linhasValidas = _items.where((i) => i.nameCtrl.text.trim().isNotEmpty && i.totalLine > 0).toList();
    
    if (linhasValidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_erro_produto_invalido', idioma)), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);

    final jsonPayload = {
      'supermarketName': superName,
      'purchaseDate': _purchaseDate.toIso8601String(), 
      'items': linhasValidas.map((item) => {
        'productName': item.nameCtrl.text.trim(),
        'quantity': double.tryParse(item.quantityCtrl.text.replaceAll(',', '.')) ?? 1.0,
        'unitPrice': double.tryParse(item.priceCtrl.text.replaceAll(',', '.')) ?? 0.0,
        'minAlertThreshold': double.tryParse(item.alertCtrl.text.replaceAll(',', '.')) ?? 1.0,
        'expirationDate': item.expirationDate?.toIso8601String(),
        'daysToAlertBeforeExpiration': int.tryParse(item.daysToAlertCtrl.text) ?? 3,
      }).toList(),
    };

    final erro = await _service.createPurchase(jsonPayload);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (erro == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_sucesso_compra', idioma)), backgroundColor: Colors.green));
      Navigator.pop(context); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.traduzir('titulo_registo_compra', idioma)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _supermarketCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: AppTranslations.traduzir('hint_supermercado', idioma), 
                      prefixIcon: const Icon(Icons.storefront),
                      border: const OutlineInputBorder()
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text("${_purchaseDate.day}/${_purchaseDate.month}"),
                    onPressed: () async {
                      final dataEscolhida = await showDatePicker(
                        context: context,
                        initialDate: _purchaseDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (dataEscolhida != null) setState(() => _purchaseDate = dataEscolhida);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),

          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final linha = _items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: linha.nameCtrl,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(labelText: AppTranslations.traduzir('hint_nome_produto', idioma)),
                              ),
                            ),
                            if (_items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setState(() => _items.removeAt(index)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: linha.quantityCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_qtd', idioma)),
                                onChanged: (val) => setState(() {}), 
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: linha.priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_preco_un', idioma)),
                                onChanged: (val) => setState(() {}), 
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: linha.alertCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_alerta_min', idioma), prefixIcon: const Icon(Icons.notifications_active, size: 14, color: Colors.amber)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(AppTranslations.traduzir('lbl_total', idioma), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('${linha.totalLine.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: Colors.teal, padding: EdgeInsets.zero),
                                icon: const Icon(Icons.calendar_month, size: 20),
                                label: Text(linha.expirationDate == null 
                                    ? AppTranslations.traduzir('btn_add_validade', idioma) 
                                    : '${AppTranslations.traduzir('lbl_validade', idioma)}: ${linha.expirationDate!.day}/${linha.expirationDate!.month}/${linha.expirationDate!.year}'),
                                onPressed: () async {
                                  final data = await showDatePicker(
                                    context: context, 
                                    initialDate: DateTime.now(), 
                                    firstDate: DateTime.now(), 
                                    lastDate: DateTime(2035)
                                  );
                                  if (data != null) {
                                    setState(() { linha.expirationDate = data; });
                                  }
                                },
                              ),
                            ),
                            if (linha.expirationDate != null)
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: linha.daysToAlertCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_avisar_dias', idioma)),
                                ),
                              )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          TextButton.icon(
            onPressed: () => setState(() => _items.add(PurchaseItemRow())),
            icon: const Icon(Icons.add),
            label: Text(AppTranslations.traduzir('btn_add_produto', idioma)),
          ),

          Container(
            color: Colors.teal.shade50,
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.traduzir('lbl_total_geral', idioma), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                    Text('${_totalGeral.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  onPressed: _isSaving ? null : _guardarFatura,
                  icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
                  label: Text(AppTranslations.traduzir('btn_guardar', idioma), style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}