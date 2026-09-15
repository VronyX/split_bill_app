import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../theme/app_theme.dart';
import 'assign_screen.dart';

class PeopleScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final double pajakPersen;
  final int serviceTotal;

  const PeopleScreen({
    super.key,
    required this.items,
    required this.pajakPersen,
    required this.serviceTotal,
  });

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final List<String> _people = [];
  final _controller = TextEditingController();

  void _addPerson() {
    final name = _controller.text.trim();
    if (name.isEmpty || _people.contains(name)) return;
    setState(() {
      _people.add(name);
      _controller.clear();
    });
  }

  void _removePerson(String name) {
    setState(() => _people.remove(name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siapa Saja?'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Nama orang'),
                    onSubmitted: (_) => _addPerson(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addPerson,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: AppColors.stamp),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _people.length,
                itemBuilder: (context, index) {
                  final name = _people[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.paperDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.stamp,
                          child: Text(
                            name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: AppColors.paper, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                          onPressed: () => _removePerson(name),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _people.isEmpty
                  ? null
                  : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssignScreen(
                      items: widget.items,
                      people: _people,
                      pajakPersen: widget.pajakPersen,
                      serviceTotal: widget.serviceTotal,
                    ),
                  ),
                );
              },
              child: const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
  }
}