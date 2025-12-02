import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'package:goldventory/features/inventory/view/receive_order_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // simpler: use a StreamBuilder<QuerySnapshot> directly
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Orders')),
      body: Padding(
        padding: Responsive.screenPadding(context),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('status', whereIn: ['pending', 'partial'])
              .snapshots(includeMetadataChanges: true),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error loading orders: ${snap.error}'));
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final qs = snap.data;
            final docs = qs?.docs ?? [];
            // Sort documents by human-friendly orderName if present, otherwise by createdAt
            docs.sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aName = (aData['orderName'] as String?) ?? '';
              final bName = (bData['orderName'] as String?) ?? '';
              if (aName.isNotEmpty || bName.isNotEmpty) {
                return aName.compareTo(bName);
              }
              final aDate = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              return aDate.compareTo(bDate);
            });
            final meta = qs?.metadata;
            final isFromCache = meta?.isFromCache ?? false;
            final hasPendingWrites = meta?.hasPendingWrites ?? false;

            // If there are no docs and this state is from server (not cache) and there are no pending writes,
            // show 'No pending orders'. If it's from cache or has pending writes, briefly show the list or a notice.
            if (docs.isEmpty && !isFromCache && !hasPendingWrites) {
              return const Center(child: Text('No pending orders'));
            }

            if (docs.isEmpty && (isFromCache || hasPendingWrites)) {
              // show a subtle indicator that we are waiting for server sync but show nothing yet
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No pending orders (waiting for server sync)'),
                  if (hasPendingWrites) const SizedBox(height: 8),
                  if (hasPendingWrites) const Text('Local writes pending...'),
                  if (isFromCache) const Text('Showing cached data'),
                ],
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final d = docs[index];
                final data = d.data();
                final created = (data['createdAt'] as Timestamp?)?.toDate();
                final expected = (data['expectedDelivery'] as Timestamp?)?.toDate();
                // prefer friendly orderName if present
                final displayOrderTitle = (data['orderName'] as String?) ?? (created != null ? '${created.day.toString().padLeft(2,'0')}-${created.month.toString().padLeft(2,'0')}-${created.year} ${created.hour.toString().padLeft(2,'0')}:${created.minute.toString().padLeft(2,'0')}' : 'Order ${d.id}');
                return ListTile(
                  title: Text(displayOrderTitle),
                  subtitle: Text(
                      'Created: ${created != null ? created.toLocal().toString().split('.')[0] : '—'}\nStatus: ${data['status'] ?? '—'}\n${expected != null ? 'Expected: ${expected.toLocal().toString().split(' ')[0]}' : ''}'),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () {
                      // navigate to receive screen, pass doc id
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReceiveOrderScreen(orderId: d.id),
                        ),
                      );
                    },
                    child: const Text('Receive'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}