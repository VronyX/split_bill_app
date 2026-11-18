import 'package:flutter/material.dart';

import '../models/bill_charges.dart';
import '../models/receipt_item.dart';
import '../theme/app_route.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'assign_screen.dart';

/// Langkah 2: siapa saja yang ikut makan.
class PeopleScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final BillCharges charges;

  const PeopleScreen({super.key, required this.items, required this.charges});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final List<String> _people = [];
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addPerson() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    if (_people.any((p) => p.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$name sudah ada di daftar')));
      return;
    }
    setState(() {
      _people.add(name);
      _controller.clear();
    });
    _focus.requestFocus(); // keyboard tetap terbuka untuk nama berikutnya
  }

  void _removePerson(String name) => setState(() => _people.remove(name));

  void _lanjut() {
    Navigator.of(context).push(slideRoute(
      AssignScreen(items: widget.items, people: List.of(_people), charges: widget.charges),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siapa saja yang ikut?'),
        bottom: const StepIndicator(current: 1),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Ketik nama, lalu Enter',
                    prefixIcon: Icon(Icons.person_add_alt_1_outlined, color: AppColors.muted),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _addPerson(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _controller.text.trim().isEmpty ? null : _addPerson,
                tooltip: 'Tambah',
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.border,
                  fixedSize: const Size(52, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_people.isEmpty)
            const _EmptyPeople()
          else ...[
            Text('${_people.length} orang',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _people.length; i++) ...[
                    if (i > 0) const Divider(indent: 60),
                    ListTile(
                      leading: PersonAvatar(name: _people[i], color: AppColors.person(i), size: 36),
                      title: Text(_people[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                        onPressed: () => _removePerson(_people[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: _people.isEmpty ? null : _lanjut,
          child: Text(_people.isEmpty ? 'Tambah minimal 1 orang' : 'Lanjut: bagi item'),
        ),
      ),
    );
  }
}

class _EmptyPeople extends StatelessWidget {
  const _EmptyPeople();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.groups_2_outlined, size: 48, color: AppColors.border),
          SizedBox(height: 12),
          Text('Belum ada yang ditambahkan', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Jangan lupa masukkan namamu sendiri juga.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
