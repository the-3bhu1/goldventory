// ignore_for_file: deprecated_member_use


import 'package:flutter/material.dart';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:goldventory/app/routes.dart';

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(alpha, (red * f).round(), (green * f).round(), (blue * f).round());
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  final Map<String, List<String>> items = const {
    'Matils': ['Round Matil', 'Gajje Matil', 'Full Balls (Plain)', 'Full Balls (Stone)', 'Full Balls (Enamel)'],
    'BS & LWCH': ['BS Item 1', 'LWCH Item 2'],
    'HWCH & FCH': ['HWCH Item 1', 'FCH Item 2'],
    'Teeka Chains': ['Teeka Item 1', 'Teeka Item 2'],
    'KCH & DCBL': ['KCH Item 1', 'DCBL Item 2'],
    'Jhumkis': ['Jhumki Item 1', 'Jhumki Item 2'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
        child: LayoutBuilder(builder: (context, constraints) {
          final maxContentWidth = constraints.maxWidth;

          return ListView(
            children: items.entries.map((entry) {
              final itemName = entry.key;
              final subItems = entry.value;

              return SizedBox(
                width: maxContentWidth,
                child: Card(
                  color: Color(0xFFC6E6DA),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    childrenPadding: const EdgeInsets.only(left: 20, right: 12, bottom: 12),
                    backgroundColor: Color(0xFFF0F8F3),
                    title: Text(
                      itemName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    children: subItems.map((subItem) {
                      return ListTile(
                        title: Text(subItem),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          if (itemName == 'Matils' && subItem == 'Round Matil') {
                            Navigator.pushNamed(context, AppRoutes.roundMatil);
                          } else if (itemName == 'Matils' && subItem == 'Gajje Matil') {
                            Navigator.pushNamed(context, AppRoutes.gajjeMatil);
                          } else {
                            Helpers.showSnackBar('$subItem page not implemented yet', backgroundColor: Theme.of(context).primaryColor);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ),
    );
  }
}