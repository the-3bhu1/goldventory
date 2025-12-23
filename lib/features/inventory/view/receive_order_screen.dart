import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:goldventory/data/repositories/product_repository.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'dart:async';

class ReceiveOrderScreen extends StatefulWidget {
  final String orderId;
  const ReceiveOrderScreen({required this.orderId, super.key});

  @override
  State<ReceiveOrderScreen> createState() => _ReceiveOrderScreenState();
}

class _ReceiveOrderScreenState extends State<ReceiveOrderScreen> {
  Map<int, TextEditingController> _controllers = {};
  Map<int, int> _maxAllowed = {}; // idx -> remaining pending
  Map<int, Map<String, dynamic>> _orderItemsIndexed = {};
  bool _loading = true;
  Map<String, dynamic>? _orderData;
  StreamSubscription<DocumentSnapshot>? _orderSub;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    // cancel existing subscription if any
    await _orderSub?.cancel();

    _loading = true;
    setState(() {});

    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) {
        Helpers.showSnackBar('Order not found');
        Navigator.of(context).pop();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      // rebuild indexed items and controllers based on current outstanding
      _orderItemsIndexed = {};
      _controllers.forEach((_, c) => c.dispose());
      _controllers = {};
      _maxAllowed = {};

      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final qtyOrdered = (it['qtyOrdered'] ?? 0) as int;
        final qtyReceived = (it['qtyReceived'] ?? 0) as int;
        final remaining = qtyOrdered - qtyReceived;
        _orderItemsIndexed[i] = it;
        _maxAllowed[i] = remaining;
        // prefill the receive-now field with remaining (0 if none)
        _controllers[i] = TextEditingController(text: remaining > 0 ? remaining.toString() : '0');
      }

      setState(() {
        _orderData = data;
        _loading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      Helpers.showSnackBar('Failed to load order: $e');
      setState(() { _loading = false; });
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _orderSub?.cancel();
    super.dispose();
  }

  Future<void> _submitReceive() async {
    // build receivedItems list in the expected shape for receiveShipment
    final List<Map<String, dynamic>> receivedItems = [];
    for (final entry in _orderItemsIndexed.entries) {
      final idx = entry.key;
      final item = entry.value;
      final maxAllowed = _maxAllowed[idx] ?? 0;
      final txt = _controllers[idx]?.text ?? '0';
      final qtyNow = int.tryParse(txt) ?? 0;
      final toSubmit = qtyNow < 0 ? 0 : (qtyNow > maxAllowed ? maxAllowed : qtyNow);
      if (toSubmit > 0) {
        receivedItems.add({
          'orderId': widget.orderId,
          'productId': item['productId'],
          'weightKey': item['weightKey'],
          'qtyReceivedNow': toSubmit,
        });
      }
    }

    if (receivedItems.isEmpty) {
      Helpers.showSnackBar('Enter quantities to receive');
      return;
    }

    setState(() { _loading = true; });

    try {
      final repo = ProductRepository(); // adjust ctor depending on your repo pattern
      await repo.receiveShipment(receivedItems);
      Helpers.showSnackBar('Received and recorded successfully');
      Navigator.of(context).pop(); // go back to orders list
    } catch (e) {
      Helpers.showSnackBar('Receive failed: $e');
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Receive Order')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final created = (_orderData?['createdAt'] as Timestamp?)?.toDate();

    // prefer human-friendly orderName if present, otherwise fall back to createdAt formatting
    String formatDateDdMmYyyyHm(DateTime d) {
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yyyy = d.year.toString();
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$dd-$mm-$yyyy $hh:$min';
    }

    final orderName = (_orderData?['orderName'] as String?) ?? (created != null ? formatDateDdMmYyyyHm(created) : 'Order ${widget.orderId}');

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Order')),
      body: Padding(
        padding: Responsive.screenPadding(context),
        child: Column(
          children: [
            ListTile(
              title: Text(orderName),
              subtitle: Text('Created: ${created != null ? created.toLocal().toString().split('.')[0] : '—'}'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _orderItemsIndexed.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = _orderItemsIndexed[index]!;
                  final qtyOrdered = (item['qtyOrdered'] ?? 0) as int;
                  final qtyReceived = (item['qtyReceived'] ?? 0) as int;
                  final remaining = (qtyOrdered - qtyReceived);
                  final productId = item['productId'] ?? '';
                  final encoded = item['weightKey'] ?? '';
                  final parts = encoded.split('|');
                  final weightKey =
                      '${parts[0] == '__shared__' ? '' : parts[0].replaceAll('_', '.')}|${parts[1].replaceAll('_', '.')}';
                  // prefer productName stored on the order item, otherwise derive from productId
                  String titleCase(String s) => s.split(' ').map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1)) : w).join(' ');
                  final displayNameRaw = (item['productName'] as String?) ?? (productId as String);
                  final displayName = titleCase(displayNameRaw.replaceAll('_', ' '));
                  return ListTile(
                    title: Text(
                      '$displayName - ${weightKey.split('|')[0].replaceAll('_', ' ')} - ${weightKey.split('|')[1].replaceAll('_', '').trim()}g',
                    ),
                    subtitle: Text('Ordered: $qtyOrdered  •  Received: $qtyReceived  •  Pending: $remaining'),
                    trailing: SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _controllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Receive now',
                          hintText: '0',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submitReceive,
              icon: const Icon(Icons.download_done),
              label: const Text('Submit Receive'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}