class InventoryItem {
  final String id;
  final String name;
  final int type; // 1 - Вещь, 2 - Инвентарь
  final Map<String, int> sizes; // Например: {"XL": 5, "M": 2}

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.sizes,
  });

  // Превращаем данные из Supabase (JSON) в объект Dart
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      type: json['item_type'] ?? 1,
      sizes: Map<String, int>.from(json['sizes'] ?? {}),
    );
  }
}
