class ReceiptItem {
  final int id;
  String nama;
  int qty;
  int harga; // harga per satuan, dalam Rupiah

  ReceiptItem({
    required this.id,
    required this.nama,
    required this.qty,
    required this.harga,
  });

  int get total => qty * harga;
}