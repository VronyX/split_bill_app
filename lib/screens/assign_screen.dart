import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../theme/app_theme.dart';
import 'summary_screen.dart';

class AssignScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<String> people;
  final double pajakPersen;
  final int serviceTotal;

  const AssignScreen({
    super.key,
    required this.items,
    required this.people,
    required this.pajakPersen,
    required this.serviceTotal,
  });

  @override
  State<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<AssignScreen> {
  // key: item.id, value: set nama orang yang makan item itu
  final Map<int, Set<String>> _assignments = {};

  void _toggle(int itemId, String name) {
    setState(() {
      final set = _assignments.putIfAbsent(itemId, () => {});
      if (set.contains(name)) {
        set.remove(name);
      } else {
        set.add(name);
      }
    });
  }

  int get _unassignedCount =>
      widget.items.where((it) => (_assignments[it.id] ?? {}).isEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bagi Item'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final assigned = _assignments[item.id] ?? {};
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paperDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.nama}${item.qty > 1 ? " x${item.qty}" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Text('Rp ${item.total}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.people.map((name) {
                    final isActive = assigned.contains(name);
                    return ChoiceChip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      selected: isActive,
                      onSelected: (_) => _toggle(item.id, name),
                      selectedColor: AppColors.stamp,
                      labelStyle: TextStyle(
                        color: isActive ? AppColors.paper : AppColors.ink,
                      ),
                    );
                  }).toList(),
                ),
                if (assigned.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Dibagi ${assigned.length} orang, masing-masing Rp ${(item.total / assigned.length).round()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SummaryScreen(
                  items: widget.items,
                  people: widget.people,
                  assignments: _assignments,
                  pajakPersen: widget.pajakPersen,
                  serviceTotal: widget.serviceTotal,
                ),
              ),
            );
          },
          child: Text(
            _unassignedCount > 0
                ? 'Lihat ringkasan (${_unassignedCount} item belum dipilih)'
                : 'Lihat ringkasan',
          ),
        ),
      ),
    );
  }
}