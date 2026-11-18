import 'package:flutter/material.dart';
import '../models/bill_charges.dart';
import '../models/receipt_item.dart';
import '../services/receipt_parser_core.dart';
import '../theme/app_theme.dart';
import 'people_screen.dart';

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
    _items = List.from(r.items);
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

  double get _grandTotal => _rincian.total;

  static double _parsePersen(String v) => double.tryParse(v.replaceAll(',', '.')) ?? 0;

  static String _formatPersen(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');

  /// Pesan bantu: bandingkan hasil baca dengan subtotal/total yang tertera di struk.
  Widget? _buildInfoBanner() {
    final r = widget.result;
    final pesan = <String>[];
    if (r.pajakTermasuk) {
      pesan.add('Harga di struk sudah termasuk pajak, jadi pajak diisi 0%.');
    }
    if (r.subtotalStruk != null && (r.subtotalStruk! - _subtotal).abs() > 2 &&
        (r.subtotalStruk! - (_subtotal - _diskonTotal)).abs() > 2) {
      pesan.add('Subtotal di struk ${formatRupiah(r.subtotalStruk!)}, tapi total item di sini '
          '${formatRupiah(_subtotal)}. Cek apakah ada item yang terlewat atau salah baca.');
    } else if (r.subtotalStruk == null && r.totalStruk != null &&
        (r.totalStruk! - _grandTotal).abs() > 100) {
      pesan.add('Total di struk ${formatRupiah(r.totalStruk!)}, hitungan di sini '
          '${formatRupiah(_grandTotal)}. Cek lagi item, pajak & service.');
    }
    if (pesan.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6E3D6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(pesan.join('\n'),
            style: const TextStyle(color: AppColors.ink, fontSize: 12)),
      ),
    );
  }

  void _addItem() {
    setState(() {
      final newId = _items.isEmpty
          ? 1
          : _items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
      _items.add(ReceiptItem(id: newId, nama: '', qty: 1, harga: 0));
    });
  }

  void _removeItem(int id) {
    setState(() => _items.removeWhere((it) => it.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Item'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
      ),
      body: Column(
        children: [
          ?_buildInfoBanner(),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E3D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Tidak ada item terdeteksi otomatis. Tambahkan item manual di bawah.',
                  style: TextStyle(color: AppColors.ink, fontSize: 12.5),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: item.nama,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Nama item',
                              hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) => item.nama = v,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: TextFormField(
                          initialValue: item.qty.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(border: InputBorder.none),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) =>
                              setState(() => item.qty = int.tryParse(v) ?? item.qty),
                        ),
                      ),
                      const Text('x', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      SizedBox(
                        width: 75,
                        child: TextFormField(
                          initialValue: item.harga == 0 ? '' : item.harga.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) =>
                              setState(() => item.harga = int.tryParse(v) ?? item.harga),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFB4463A)),
                        onPressed: () => _removeItem(item.id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah item'),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.paperDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _chargeRow('Subtotal', null, _rincian.subtotal),
                _chargeRow(
                  'Diskon (Rp)',
                  _numberField(
                    initial: _diskonTotal.toString(),
                    width: 80,
                    onChanged: (v) => _diskonTotal = int.tryParse(v.replaceAll('.', '')) ?? 0,
                  ),
                  -_rincian.diskon,
                ),
                _chargeRow(
                  'Service (%)',
                  _numberField(
                    initial: _formatPersen(_servicePersen),
                    onChanged: (v) => _servicePersen = _parsePersen(v),
                  ),
                  _rincian.service,
                ),
                _chargeRow(
                  'Pajak (%)',
                  _numberField(
                    initial: _formatPersen(_pajakPersen),
                    onChanged: (v) => _pajakPersen = _parsePersen(v),
                  ),
                  _rincian.pajak,
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Pajak dihitung dari subtotal + service',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                    Switch(
                      value: _pajakDenganService,
                      activeThumbColor: AppColors.stamp,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _pajakDenganService = v),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      formatRupiah(_rincian.total),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton(
              onPressed: _items.isEmpty
                  ? null
                  : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PeopleScreen(items: _items, charges: _charges),
                  ),
                );
              },
              child: const Text('Lanjut'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chargeRow(String label, Widget? field, double nominal) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          ?field,
          SizedBox(
            width: 100,
            child: Text(
              formatRupiah(nominal),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required String initial,
    required void Function(String) onChanged,
    double width = 52,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: initial,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(isDense: true),
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }
}
