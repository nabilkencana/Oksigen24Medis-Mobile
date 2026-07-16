class ReceiptItem {
  final String name;
  final int price;
  final int quantity;
  final String? subtitle;

  const ReceiptItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.subtitle,
  });
}
