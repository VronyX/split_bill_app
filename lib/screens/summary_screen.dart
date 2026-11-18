import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bill_charges.dart';
import '../models/receipt_item.dart';
import '../models/split.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Langkah 4: hasil akhir per orang.
class SummaryScreen extends StatelessWidget {
  final List<ReceiptItem> items;
  final List<String> people;
  final Portions portions;
  final BillCharges charges;

  const SummaryScreen({
    super.key,
    required this.items,
    required this.people,
    required this.portions,
    required this.charges,
  });

  SplitSummary get _summary =>
      hitungPembagian(items: items, people: people, portions: portions, charges: charges);

  Future<void> _salin(BuildContext context, SplitSummary s) async {
    await Clipboard.setData(ClipboardData(text: ringkasanTeks(s)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Ringkasan disalin. Tempel di grup chat ya!')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final t = s.tagihan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil'),
        bottom: const StepIndicator(current: 3),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _TotalCard(tagihan: t, jumlahOrang: people.length),
          const SizedBox(height: 16),
          if (s.unassigned.isNotEmpty) ...[
            InfoBanner(
              text: '${s.unassigned.length} item belum dibagi '
                  '(${s.unassigned.map((e) => e.nama).join(', ')}). '
                  'Kembali untuk memilih siapa yang bayar.',
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
          ],
          for (final p in s.people) ...[
            _PersonCard(share: p),
            const SizedBox(height: 10),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Selesai'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _salin(context, s),
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: const Text('Salin ringkasan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final ChargeBreakdown tagihan;
  final int jumlahOrang;
  const _TotalCard({required this.tagihan, required this.jumlahOrang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total tagihan · $jumlahOrang orang',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(formatRupiah(tagihan.total),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _mini('Subtotal', formatRupiah(tagihan.subtotal)),
              if (tagihan.diskon > 0) _mini('Diskon', '-${formatRupiah(tagihan.diskon)}'),
              if (tagihan.service > 0) _mini('Service', formatRupiah(tagihan.service)),
              if (tagihan.pajak > 0) _mini('Pajak', formatRupiah(tagihan.pajak)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label ', style: const TextStyle(color: Colors.white60)),
          TextSpan(text: value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
        style: const TextStyle(fontSize: 12.5),
      );
}

class _PersonCard extends StatelessWidget {
  final PersonShare share;
  const _PersonCard({required this.share});

  @override
  Widget build(BuildContext context) {
    final r = share.rincian;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: PersonAvatar(name: share.name, color: AppColors.person(share.index), size: 38),
          title: Text(share.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            share.lines.isEmpty ? 'Tidak pesan apa-apa' : '${share.lines.length} item',
            style: const TextStyle(fontSize: 12.5),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatRupiah(share.total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, color: AppColors.muted),
            ],
          ),
          children: [
            const Divider(),
            const SizedBox(height: 6),
            for (final l in share.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: l.itemName),
                        if (l.keterangan.isNotEmpty)
                          TextSpan(
                            text: '  ${l.keterangan}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                      ])),
                    ),
                    Text(formatRupiah(l.amount)),
                  ],
                ),
              ),
            if (r.diskon > 0)
              AmountRow(label: 'Diskon', value: '-${formatRupiah(r.diskon)}', valueColor: AppColors.success),
            if (r.service > 0) AmountRow(label: 'Service', value: formatRupiah(r.service)),
            if (r.pajak > 0) AmountRow(label: 'Pajak', value: formatRupiah(r.pajak)),
          ],
        ),
      ),
    );
  }
}
