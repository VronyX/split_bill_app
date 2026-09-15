import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../models/assign_group.dart';
import '../theme/app_theme.dart';

class SummaryScreen extends StatelessWidget {
  final List<ReceiptItem> items;
  final List<String> people;
  final Map<int, List<AssignGroup>> assignments;
  final double pajakPersen;
  final int serviceTotal;

  const SummaryScreen({
    super.key,
    required this.items,
    required this.people,
    required this.assignments,
    required this.pajakPersen,
    required this.serviceTotal,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold(0, (sum, it) => sum + it.total);
    final pajakTotal = subtotal * (pajakPersen / 100);
    final grandTotal = subtotal + pajakTotal + serviceTotal;
    final serviceEach = people.isEmpty ? 0 : serviceTotal / people.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const Text('Total tagihan', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(
                  'Rp ${grandTotal.round()}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...people.map((name) {
            final lines = <String>[];
            double mySubtotal = 0;

            for (final it in items) {
              final groups = assignments[it.id] ?? [];
              final totalUnits = groups.fold(0, (s, g) => s + g.units);
              if (totalUnits == 0) continue;
              final pricePerUnit = it.total / totalUnits;

              for (final g in groups) {
                if (!g.people.contains(name)) continue;
                final groupCost = g.units * pricePerUnit;
                final share = groupCost / g.people.length;
                mySubtotal += share;

                final qtyLabel = it.qty > 1 ? " x${it.qty}" : "";
                final shareLabel = g.people.length > 1 ? ' (patungan berdua)' : '';
                lines.add('${it.nama}$qtyLabel$shareLabel  —  Rp ${share.round()}');
              }
            }

            final myPajak = mySubtotal * (pajakPersen / 100);
            final myTotal = mySubtotal + myPajak + serviceEach;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paperDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.stamp,
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: AppColors.paper, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Text('Rp ${myTotal.round()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (lines.isEmpty)
                    const Text('Tidak pesan apa-apa',
                        style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.muted, fontSize: 12)),
                  ...lines.map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(l, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  )),
                  const Divider(height: 16),
                  Text('Pajak: Rp ${myPajak.round()}   •   Service: Rp ${serviceEach.round()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}