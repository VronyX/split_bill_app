import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bill_charges.dart';
import '../models/receipt_item.dart';
import '../services/receipt_parser_core.dart';
import '../theme/app_route.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'people_screen.dart';

/// Langkah 1: cek & rapikan hasil baca struk.
class ReviewScreen extends StatefulWidget {
  final ReceiptParseResult result;

  const ReviewScreen({super.key, required this.result});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<ReceiptItem> _items;
  late double _pajakPersen;
  late double _servicePersen;
  late bool _pajakDenganService;
  late int _diskonTotal;

  @override
  void initState() {
    super.initState();
    final r = widget.result;
    _items = List.of(r.items);
    _pajakPersen = r.pajakPersenSaran;
    _servicePersen = r.servicePersenSaran;
    // Kalau struk tidak jelas, pakai kebiasaan umum: pajak setelah service.
    _pajakDenganService = r.pajakDenganService || r.serviceNominal == null;
    _diskonTotal = r.diskonTotal;
  }

  int get _subtotal => _items.fold(0, (sum, it) => sum + it.total);

  BillCharges get _charges => BillCharges(
        pajakPersen: _pajakPersen,
        servicePersen: _servicePersen,
        pajakDenganService: _pajakDenganService,
        diskonTotal: _diskonTotal,
      );

  ChargeBreakdown get _rincian =>
      _charges.hitung(_subtotal.toDouble(), subtotalSemua: _subtotal.toDouble());

  int get _nextId =>
      _items.isEmpty ? 1 : _items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

  static String _persen(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');

  List<String> get _peringatan {
    final r = widget.result;
    final out = <String>[];
    if (r.subtotalStruk != null &&
        (r.subtotalStruk! - _subtotal).abs() > 2 &&
        (r.subtotalStruk! - (_subtotal - _diskonTotal)).abs() > 2) {
      out.add('Subtotal di struk ${formatRupiah(r.subtotalStruk!)}, di sini ${formatRupiah(_subtotal)}. '
          'Mungkin ada item yang terlewat atau salah baca.');
    } else if (r.subtotalStruk == null &&
        r.totalStruk != null &&
        (r.totalStruk! - _rincian.total).abs() > 100) {
      out.add('Total di struk ${formatRupiah(r.totalStruk!)}, di sini ${formatRupiah(_rincian.total)}. '
          'Cek lagi item, pajak & service.');
    }
    if (_items.any((it) => it.nama.trim().isEmpty || it.harga <= 0)) {
      out.add('Ada item tanpa nama atau harga. Ketuk item untuk melengkapi.');
    }
    return out;
  }

  // ---------------------------------------------------------------- actions

  Future<void> _editItem([ReceiptItem? item]) async {
    final isNew = item == null;
    final edited = await showModalBottomSheet<_ItemEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemEditor(item: item),
    );
    if (edited == null || !mounted) return;
    setState(() {
      if (edited.delete) {
        _items.remove(item);
        return;
      }
      if (isNew) {
        _items.add(ReceiptItem(id: _nextId, nama: edited.nama, qty: edited.qty, harga: edited.harga));
      } else {
        item.nama = edited.nama;
        item.qty = edited.qty;
        item.harga = edited.harga;
      }
    });
  }

  void _removeWithUndo(ReceiptItem item) {
    final index = _items.indexOf(item);
    setState(() => _items.remove(item));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('"${item.nama}" dihapus'),
        action: SnackBarAction(
          label: 'Batal',
          textColor: AppColors.accentSoft,
          onPressed: () => setState(() => _items.insert(index.clamp(0, _items.length), item)),
        ),
      ));
  }

  Future<void> _editCharges() async {
    final res = await showModalBottomSheet<BillCharges>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChargesEditor(initial: _charges, subtotal: _subtotal),
    );
    if (res == null) return;
    setState(() {
      _pajakPersen = res.pajakPersen;
      _servicePersen = res.servicePersen;
      _pajakDenganService = res.pajakDenganService;
      _diskonTotal = res.diskonTotal;
    });
  }

  void _lanjut() {
    Navigator.of(context).push(slideRoute(PeopleScreen(items: _items, charges: _charges)));
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final r = _rincian;
    final peringatan = _peringatan;
    final adaItem = _items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cek item'),
        bottom: const StepIndicator(current: 0),
      ),
      body: !adaItem
          ? _EmptyItems(onAdd: () => _editItem())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (widget.result.pajakTermasuk) ...[
                  const InfoBanner(
                    text: 'Harga di struk sudah termasuk pajak, jadi pajak tidak ditambahkan lagi.',
                    icon: Icons.check_circle_outline,
                    warning: false,
                  ),
                  const SizedBox(height: 10),
                ],
                for (final p in peringatan) ...[
                  InfoBanner(text: p, icon: Icons.warning_amber_rounded),
                  const SizedBox(height: 10),
                ],
                Text('${_items.length} item',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Text('Ketuk untuk ubah, geser ke kiri untuk hapus',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        _itemTile(_items[i]),
                      ],
                      const Divider(),
                      ListTile(
                        onTap: () => _editItem(),
                        leading: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                        title: const Text('Tambah item',
                            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _chargesCard(r),
              ],
            ),
      bottomNavigationBar: adaItem
          ? BottomActionBar(
              top: Row(
                children: [
                  const Text('Total tagihan', style: TextStyle(color: AppColors.muted)),
                  const Spacer(),
                  Text(formatRupiah(r.total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              child: FilledButton(
                onPressed: _lanjut,
                child: const Text('Lanjut: siapa saja yang ikut?'),
              ),
            )
          : null,
    );
  }

  Widget _itemTile(ReceiptItem item) {
    final kosong = item.nama.trim().isEmpty || item.harga <= 0;
    return Dismissible(
      key: ObjectKey(item),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _removeWithUndo(item),
      child: InkWell(
        onTap: () => _editItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nama.trim().isEmpty ? 'Tanpa nama' : item.nama,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: item.nama.trim().isEmpty ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${item.qty} × ${formatRupiah(item.harga)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              if (kosong)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.error_outline, size: 18, color: AppColors.warningInk),
                ),
              Text(formatRupiah(item.total),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chargesCard(ChargeBreakdown r) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _editCharges,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Biaya tambahan',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  TextButton(onPressed: _editCharges, child: const Text('Ubah')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    AmountRow(label: 'Subtotal', value: formatRupiah(r.subtotal)),
                    if (r.diskon > 0)
                      AmountRow(
                          label: 'Diskon',
                          value: '-${formatRupiah(r.diskon)}',
                          valueColor: AppColors.success),
                    AmountRow(label: 'Service ${_persen(_servicePersen)}%', value: formatRupiah(r.service)),
                    AmountRow(
                      label: 'Pajak ${_persen(_pajakPersen)}%'
                          '${_pajakDenganService && _servicePersen > 0 ? ' (setelah service)' : ''}',
                      value: formatRupiah(r.pajak),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------

class _EmptyItems extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyItems({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.fill, shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined, size: 30, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            const Text('Belum ada item',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'Tambahkan menu satu per satu. Kalau tadi pakai foto, coba foto ulang dengan lebih terang & lurus.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Tambah item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemEditResult {
  final String nama;
  final int qty;
  final int harga;
  final bool delete;
  const _ItemEditResult({this.nama = '', this.qty = 1, this.harga = 0, this.delete = false});
}

int _parseRupiah(String v) => int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// "25000" -> "25.000" selagi diketik.
String _ribuan(int v) => v <= 0 ? '' : formatRupiah(v).replaceFirst('Rp ', '');

class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = _ribuan(_parseRupiah(newValue.text));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _ItemEditor extends StatefulWidget {
  final ReceiptItem? item;
  const _ItemEditor({this.item});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _nama = TextEditingController(text: widget.item?.nama ?? '');
  late final _harga = TextEditingController(
      text: _ribuan(widget.item?.harga ?? 0));
  late int _qty = widget.item?.qty ?? 1;

  @override
  void dispose() {
    _nama.dispose();
    _harga.dispose();
    super.dispose();
  }

  bool get _valid => _nama.text.trim().isNotEmpty && _parseRupiah(_harga.text) > 0;

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    final harga = _parseRupiah(_harga.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isNew ? 'Tambah item' : 'Ubah item', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nama,
            autofocus: isNew,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama menu'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _harga,
            keyboardType: TextInputType.number,
            inputFormatters: [_RupiahInputFormatter()],
            decoration: const InputDecoration(labelText: 'Harga satuan', prefixText: 'Rp '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Jumlah', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              QtyStepper(value: _qty, min: 1, onChanged: (v) => setState(() => _qty = v)),
            ],
          ),
          const SizedBox(height: 8),
          AmountRow(label: 'Total item', value: formatRupiah(harga * _qty), bold: true),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isNew) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => Navigator.pop(context, const _ItemEditResult(delete: true)),
                    child: const Text('Hapus'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _valid
                      ? () => Navigator.pop(
                            context,
                            _ItemEditResult(nama: _nama.text.trim(), qty: _qty, harga: harga),
                          )
                      : null,
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChargesEditor extends StatefulWidget {
  final BillCharges initial;
  final int subtotal;
  const _ChargesEditor({required this.initial, required this.subtotal});

  @override
  State<_ChargesEditor> createState() => _ChargesEditorState();
}

class _ChargesEditorState extends State<_ChargesEditor> {
  late final _diskon = TextEditingController(
      text: _ribuan(widget.initial.diskonTotal));
  late final _service = TextEditingController(text: _ReviewScreenState._persen(widget.initial.servicePersen));
  late final _pajak = TextEditingController(text: _ReviewScreenState._persen(widget.initial.pajakPersen));
  late bool _setelahService = widget.initial.pajakDenganService;

  static double _parsePersen(String v) => double.tryParse(v.replaceAll(',', '.')) ?? 0;

  BillCharges get _current => BillCharges(
        diskonTotal: _parseRupiah(_diskon.text),
        servicePersen: _parsePersen(_service.text),
        pajakPersen: _parsePersen(_pajak.text),
        pajakDenganService: _setelahService,
      );

  @override
  void dispose() {
    _diskon.dispose();
    _service.dispose();
    _pajak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _current.hitung(widget.subtotal.toDouble(), subtotalSemua: widget.subtotal.toDouble());
    final persenFormatter = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Biaya tambahan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _service,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: persenFormatter,
                  decoration: const InputDecoration(labelText: 'Service', suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pajak,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: persenFormatter,
                  decoration: const InputDecoration(labelText: 'Pajak', suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diskon,
            keyboardType: TextInputType.number,
            inputFormatters: [_RupiahInputFormatter()],
            decoration: const InputDecoration(labelText: 'Diskon total (opsional)', prefixText: 'Rp '),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _setelahService,
            onChanged: (v) => setState(() => _setelahService = v),
            title: const Text('Pajak dihitung setelah service', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Umumnya begitu di restoran (PB1 dari subtotal + service)',
                style: TextStyle(fontSize: 12)),
          ),
          const Divider(),
          const SizedBox(height: 8),
          AmountRow(label: 'Service', value: formatRupiah(r.service)),
          AmountRow(label: 'Pajak', value: formatRupiah(r.pajak)),
          AmountRow(label: 'Total tagihan', value: formatRupiah(r.total), bold: true),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _current),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
