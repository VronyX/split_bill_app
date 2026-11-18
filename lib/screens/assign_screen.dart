import 'package:flutter/material.dart';

import '../models/bill_charges.dart';
import '../models/receipt_item.dart';
import '../models/split.dart';
import '../theme/app_route.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'summary_screen.dart';

/// Langkah 3: siapa makan apa.
///
/// Ketuk nama di tiap item. Kalau beberapa orang dipilih, item dibagi rata.
/// "Atur porsi" untuk pembagian tidak rata (mis. Es Teh x3: Andi 1, Budi 2).
class AssignScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<String> people;
  final BillCharges charges;

  const AssignScreen({
    super.key,
    required this.items,
    required this.people,
    required this.charges,
  });

  @override
  State<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<AssignScreen> {
  final Portions _portions = {};

  Map<String, int> _of(ReceiptItem item) => _portions.putIfAbsent(item.id, () => {});

  bool _isAssigned(ReceiptItem item) => (_portions[item.id] ?? {}).values.any((v) => v > 0);

  int get _assignedCount => widget.items.where(_isAssigned).length;

  Color _colorOf(String name) => AppColors.person(widget.people.indexOf(name));

  void _toggle(ReceiptItem item, String name) {
    setState(() {
      final map = _of(item);
      if ((map[name] ?? 0) > 0) {
        map.remove(name);
      } else {
        map[name] = 1;
      }
    });
  }

  void _selectAll(ReceiptItem item) {
    setState(() {
      final map = _of(item);
      final allSelected = widget.people.every((p) => (map[p] ?? 0) > 0);
      if (allSelected) {
        map.clear();
      } else {
        for (final p in widget.people) {
          map[p] = (map[p] ?? 0) > 0 ? map[p]! : 1;
        }
      }
    });
  }

  void _splitRemainingEvenly() {
    setState(() {
      for (final item in widget.items.where((it) => !_isAssigned(it))) {
        _of(item)
          ..clear()
          ..addAll({for (final p in widget.people) p: 1});
      }
    });
  }

  Future<void> _editPortions(ReceiptItem item) async {
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PortionEditor(
        item: item,
        people: widget.people,
        initial: Map.of(_of(item)),
        colorOf: _colorOf,
      ),
    );
    if (result == null) return;
    setState(() {
      _of(item)
        ..clear()
        ..addAll(Map.fromEntries(result.entries.where((e) => e.value > 0)));
    });
  }

  Future<void> _lihatHasil() async {
    final sisa = widget.items.length - _assignedCount;
    if (sisa > 0) {
      final pilihan = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$sisa item belum dibagi'),
          content: const Text('Item yang belum dibagi bisa dibagi rata ke semua orang.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Pilih sendiri'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bagi rata'),
            ),
          ],
        ),
      );
      if (pilihan != true || !mounted) return;
      _splitRemainingEvenly();
    }
    if (!mounted) return;
    Navigator.of(context).push(slideRoute(SummaryScreen(
      items: widget.items,
      people: widget.people,
      portions: {for (final e in _portions.entries) e.key: Map.of(e.value)},
      charges: widget.charges,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final done = _assignedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siapa makan apa?'),
        bottom: const StepIndicator(current: 2),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: total + 1,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 14 : 10),
        itemBuilder: (context, index) {
          if (index == 0) return _progressHeader(done, total);
          return _itemCard(widget.items[index - 1]);
        },
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _lihatHasil,
          child: Text(done == total ? 'Lihat hasil' : 'Lihat hasil ($done/$total dibagi)'),
        ),
      ),
    );
  }

  Widget _progressHeader(int done, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ketuk nama di tiap menu. Pilih beberapa orang = patungan rata.',
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  color: done == total ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$done/$total', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        if (done < total)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: _splitRemainingEvenly,
              icon: const Icon(Icons.groups_2_outlined, size: 18),
              label: const Text('Bagi rata semua yang belum dipilih'),
            ),
          ),
      ],
    );
  }

  Widget _itemCard(ReceiptItem item) {
    final map = _portions[item.id] ?? const <String, int>{};
    final selected = widget.people.where((p) => (map[p] ?? 0) > 0).toList();
    final totalPorsi = selected.fold<int>(0, (s, p) => s + map[p]!);
    final rata = selected.every((p) => map[p] == map[selected.first]);
    final semua = selected.length == widget.people.length;

    String? keterangan;
    if (selected.length == 1) {
      keterangan = '${selected.first} bayar ${formatRupiah(item.total)}';
    } else if (selected.length > 1 && rata) {
      keterangan = '${selected.length} orang · ${formatRupiah(item.total / selected.length)}/orang';
    } else if (selected.length > 1) {
      keterangan = selected
          .map((p) => '${p.split(' ').first} ${formatRupiah(item.total * map[p]! / totalPorsi)}')
          .join(' · ');
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected.isEmpty ? AppColors.border : AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected.isEmpty ? Icons.radio_button_unchecked : Icons.check_circle,
                  size: 20,
                  color: selected.isEmpty ? AppColors.border : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.qty > 1 ? '${item.nama} ×${item.qty}' : item.nama,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Text(formatRupiah(item.total), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in widget.people)
                  _PersonChip(
                    name: name,
                    color: _colorOf(name),
                    selected: (map[name] ?? 0) > 0,
                    portions: rata ? null : map[name],
                    onTap: () => _toggle(item, name),
                  ),
                if (widget.people.length > 1)
                  ActionChip(
                    onPressed: () => _selectAll(item),
                    avatar: Icon(semua ? Icons.close_rounded : Icons.done_all_rounded, size: 18),
                    label: Text(semua ? 'Kosongkan' : 'Semua'),
                    shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                    backgroundColor: AppColors.surface,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    keterangan ?? 'Belum dipilih',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: keterangan == null ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                ),
                if (selected.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _editPortions(item),
                    child: const Text('Atur porsi'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final int? portions;
  final VoidCallback onTap;

  const _PersonChip({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    this.portions,
  });

  @override
  Widget build(BuildContext context) {
    final label = selected && portions != null ? '$name ×$portions' : name;
    return Material(
      color: selected ? color : AppColors.fill,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              selected
                  ? Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    )
                  : PersonAvatar(name: name, color: color, size: 26),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortionEditor extends StatefulWidget {
  final ReceiptItem item;
  final List<String> people;
  final Map<String, int> initial;
  final Color Function(String) colorOf;

  const _PortionEditor({
    required this.item,
    required this.people,
    required this.initial,
    required this.colorOf,
  });

  @override
  State<_PortionEditor> createState() => _PortionEditorState();
}

class _PortionEditorState extends State<_PortionEditor> {
  late final Map<String, int> _map = {for (final p in widget.people) p: widget.initial[p] ?? 0};

  @override
  Widget build(BuildContext context) {
    final total = _map.values.fold<int>(0, (s, v) => s + v);
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Atur porsi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${widget.item.nama}${widget.item.qty > 1 ? ' ×${widget.item.qty}' : ''} · ${formatRupiah(widget.item.total)}\n'
            'Harga dibagi sesuai jumlah porsi tiap orang.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in widget.people)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        PersonAvatar(name: p, color: widget.colorOf(p), size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                total == 0 || _map[p] == 0
                                    ? '—'
                                    : formatRupiah(widget.item.total * _map[p]! / total),
                                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        QtyStepper(value: _map[p]!, onChanged: (v) => setState(() => _map[p] = v)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.item.qty > 1 && total > 0 && total != widget.item.qty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoBanner(
                text: 'Total porsi $total, sedangkan jumlah item ${widget.item.qty}. '
                    'Tidak apa-apa, harga tetap dibagi sesuai perbandingan porsi.',
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _map),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
