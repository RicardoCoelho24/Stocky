import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';
import '../services/settings_provider.dart';
import '../utils/translations.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final Map<String, dynamic> ocrData;
  const ReceiptReviewScreen({super.key, required this.ocrData});

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late TextEditingController _supermarketController;
  late TextEditingController _discountController; 
  List<dynamic> _items = [];
  bool _isSaving = false;
  final PurchaseService _purchaseService = PurchaseService();

  @override
  void initState() {
    super.initState();
    _supermarketController = TextEditingController(text: widget.ocrData['supermarketName'] ?? '');
    final descontoIa = widget.ocrData['totalDiscount'] ?? 0.0;
    _discountController = TextEditingController(text: descontoIa.toStringAsFixed(2));
    _items = List.from(widget.ocrData['items'] ?? []).map((item) {
      if (item is Map<String, dynamic>) { item['minAlertThreshold'] ??= 1; }
      return item;
    }).toList();
  }

  void _removerItem(int index) { setState(() { _items.removeAt(index); }); }

  void _mostrarDialogoEditarAlerta(int index) {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    final item = _items[index];
    final controller = TextEditingController(text: item['minAlertThreshold'].toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${AppTranslations.traduzir('titulo_alerta_minimo', idioma)}: ${item['productName']}'),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.traduzir('btn_cancelar', idioma))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              final novoValor = int.tryParse(controller.text) ?? 1;
              setState(() { _items[index]['minAlertThreshold'] = novoValor; });
              Navigator.pop(dialogContext);
            },
            child: Text(AppTranslations.traduzir('btn_guardar', idioma)),
          ),
        ],
      ),
    );
  }

  void _guardarFatura() async {
    final idioma = Provider.of<SettingsProvider>(context, listen: false).idioma;
    if (_supermarketController.text.isEmpty || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_faltam_dados', idioma))));
      return;
    }

    setState(() => _isSaving = true);
    final dadosCompra = {
      "supermarketName": _supermarketController.text.trim(),
      "purchaseDate": DateTime.now().toIso8601String(),
      "totalDiscount": double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0.0, 
      "items": _items.map((item) => {
        "productName": item['productName'].toString().trim(),
        "quantity": (item['quantity'] ?? 1).toDouble(),
        "unitPrice": (item['unitPrice'] ?? 0).toDouble(),
        "minAlertThreshold": (item['minAlertThreshold'] ?? 1).toInt() 
      }).toList()
    };

    final erro = await _purchaseService.createPurchase(dadosCompra);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (erro == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.traduzir('msg_fatura_guardada', idioma)), backgroundColor: Colors.green));
      Navigator.pop(context, true); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final idioma = Provider.of<SettingsProvider>(context).idioma;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.traduzir('titulo_rever_fatura', idioma)), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: TextField(controller: _supermarketController, decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_supermercado', idioma), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.store)))),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: TextField(controller: _discountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: AppTranslations.traduzir('lbl_poupanca', idioma), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.savings, color: Colors.green), filled: true, fillColor: Colors.green.shade50))),
              ],
            ),
            const SizedBox(height: 16),
            Text(AppTranslations.traduzir('lbl_produtos_identificados', idioma), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.shopping_bag, color: Colors.white, size: 20)),
                      title: Text(item['productName']),
                      subtitle: Text('${AppTranslations.traduzir('lbl_qtd_short', idioma)} ${item['quantity']}  |  ${AppTranslations.traduzir('lbl_preco_un_short', idioma)}: ${item['unitPrice']}€\n${AppTranslations.traduzir('lbl_alerta_config', idioma)}: ${item['minAlertThreshold']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.notifications_active_outlined, color: Colors.blue), tooltip: AppTranslations.traduzir('tooltip_alterar_alerta', idioma), onPressed: () => _mostrarDialogoEditarAlerta(index)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: AppTranslations.traduzir('tooltip_remover_fatura', idioma), onPressed: () => _removerItem(index)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _guardarFatura,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save),
                label: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(AppTranslations.traduzir('btn_confirmar_guardar', idioma), style: const TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}