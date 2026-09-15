import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../models/assign_group.dart';
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
  // key: item.id, value: daftar grup (orang + jumlah unit) yang makan item itu
  final Map<int, List<AssignGroup>> _assignments = {};

  // mode "gabung/patungan" sedang aktif untuk item id berapa (null = tidak aktif)
  int? _linkingItemId;
  final Set<String> _pendingLink = {};

  static const _groupColors = [
    Color(0xFFC1440E),
    Color(0xFF4B7B5B),
    Color(0xFF3D6B99),
    Color(0xFF9A5EB5),
    Color(0xFFB48A2E),
    Color(0xFFB4463A),
  ];

  AssignGroup? _findGroup(int itemId, String name) {
    final groups = _assignments[itemId] ?? [];
    for (final g in groups) {
      if (g.people.contains(name)) return g;
    }
    return null;
  }

  void _removeFromGroups(int itemId, String name) {
    final groups = _assignments[itemId];
    if (groups == null) return;
    for (final g in List.of(groups)) {
      if (g.people.contains(name)) {
        g.people.remove(name);
        if (g.people.isEmpty) groups.remove(g);
      }
    }
  }

  void _tapPerson(int itemId, String name) {
    setState(() {
      if (_linkingItemId == itemId) {
        // mode gabung aktif: tap = toggle pending selection
        if (_pendingLink.contains(name)) {
          _pendingLink.remove(name);
        } else {
          _pendingLink.add(name);
        }
        return;
      }
      final existing = _findGroup(itemId, name);
      if (existing != null) {
        _removeFromGroups(itemId, name);
      } else {
        final groups = _assignments.putIfAbsent(itemId, () => []);
        groups.add(AssignGroup(people: {name}, units: 1));
      }
    });
  }

  void _toggleLinkMode(int itemId) {
    setState(() {
      if (_linkingItemId == itemId) {
        // selesai mode gabung -> finalisasi grup kalau minimal 2 orang dipilih
        if (_pendingLink.length >= 2) {
          for (final name in _pendingLink) {
            _removeFromGroups(itemId, name);
          }
          final groups = _assignments.putIfAbsent(itemId, () => []);
          groups.add(AssignGroup(people: Set.of(_pendingLink), units: 1));
        }
        _linkingItemId = null;
        _pendingLink.clear();
      } else {
        _linkingItemId = itemId;
        _pendingLink.clear();
      }
    });
  }

  Future<void> _editUnits(int itemId, AssignGroup group) async {
    int temp = group.units;
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setLocal) {
          return AlertDialog(
            title: Text('Jumlah pesanan\n${group.people.join(", ")}'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: temp > 1 ? () => setLocal(() => temp--) : null,
                ),
                Text('$temp', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setLocal(() => temp++),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 0),
                child: const Text('Hapus', style: TextStyle(color: Color(0xFFB4463A))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, temp),
                child: const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
    if (result == null) return;
    setState(() {
      if (result <= 0) {
        _assignments[itemId]?.remove(group);
      } else {
        group.units = result;
      }
    });
  }

  int _totalUnits(int itemId) =>
      (_assignments[itemId] ?? []).fold(0, (s, g) => s + g.units);

  Color _colorForGroup(AssignGroup group) {
    final key = (group.people.toList()..sort()).join(',');
    final idx = key.hashCode.abs() % _groupColors.length;
    return _groupColors[idx];
  }

  int get _unassignedCount =>
      widget.items.where((it) => (_assignments[it.id] ?? []).isEmpty).length;

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
          final groups = _assignments[item.id] ?? [];
          final totalUnits = _totalUnits(item.id);
          final pricePerUnit = totalUnits > 0 ? item.total / totalUnits : 0.0;
          final isLinking = _linkingItemId == item.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paperDark,
              borderRadius: BorderRadius.circular(10),
              border: isLinking ? Border.all(color: AppColors.stamp, width: 1.4) : null,
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
                    IconButton(
                      icon: Icon(Icons.link,
                          size: 18, color: isLinking ? AppColors.stamp : AppColors.muted),
                      tooltip: 'Gabung/patungan',
                      onPressed: () => _toggleLinkMode(item.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (isLinking)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Pilih orang yang patungan, lalu tap ikon 🔗 lagi untuk selesai.',
                      style: TextStyle(fontSize: 11, color: AppColors.stamp),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.people.map((name) {
                    final group = _findGroup(item.id, name);
                    final isPending = isLinking && _pendingLink.contains(name);
                    final isSelected = group != null || isPending;
                    final isShared = group != null && group.people.length > 1;

                    Color? bgColor;
                    Color textColor = AppColors.ink;
                    if (isPending) {
                      bgColor = AppColors.stamp.withValues(alpha: 0.5);
                      textColor = AppColors.paper;
                    } else if (group != null) {
                      bgColor = isShared ? _colorForGroup(group) : AppColors.stamp;
                      textColor = AppColors.paper;
                    }

                    var label = name;
                    if (group != null && group.people.length == 1 && group.units > 1) {
                      label = '$name x${group.units}';
                    } else if (isShared) {
                      label = '$name 🔗';
                    }

                    return GestureDetector(
                      onLongPress: group != null ? () => _editUnits(item.id, group) : null,
                      child: ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (_) => _tapPerson(item.id, name),
                        selectedColor: bgColor,
                        backgroundColor: AppColors.paper,
                        labelStyle: TextStyle(color: isSelected ? textColor : AppColors.ink),
                      ),
                    );
                  }).toList(),
                ),
                if (groups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: groups.map((g) {
                        final groupCost = g.units * pricePerUnit;
                        final perPerson = groupCost / g.people.length;
                        final names = g.people.join(' & ');
                        final unitLabel = g.people.length == 1 && g.units > 1 ? ' x${g.units}' : '';
                        final shareLabel = g.people.length > 1
                            ? ' (patungan, @Rp ${perPerson.round()})'
                            : '';
                        return Text(
                          '$names$unitLabel — Rp ${groupCost.round()}$shareLabel',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        );
                      }).toList(),
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
                ? 'Lihat ringkasan ($_unassignedCount item belum dipilih)'
                : 'Lihat ringkasan',
          ),
        ),
      ),
    );
  }
}