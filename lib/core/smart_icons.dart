import 'package:flutter/material.dart';

class SmartIcons {
  // --- НОВАЯ ЛОГИКА (Строгое разделение по категории) ---
  static IconData getIcon(bool isInventory) {
    if (isInventory) {
      return Icons
          .handyman_rounded; // Иконка для Инвентаря (Инструменты/Техника)
    } else {
      return Icons
          .inventory_2_rounded; // Иконка для Вещей (Классический складской ящик)
    }
  }

  static Color getColor(bool isInventory) {
    if (isInventory) {
      return const Color(0xFFF57F17); // Оранжевый для Инвентаря
    } else {
      return const Color(0xFF607D8B); // Сине-серый (Wolf Grey) для Вещей
    }
  }

  // --- СОВМЕСТИМОСТЬ СО СТАРЫМИ ЭКРАНАМИ (Экран добавления) ---
  static IconData getIconForName(String itemName) {
    String name = itemName.toLowerCase().trim();

    // Если при добавлении в названии есть что-то из инвентаря — покажем инструмент
    if (name.contains('генератор') ||
        name.contains('станция') ||
        name.contains('лопата') ||
        name.contains('пила') ||
        name.contains('дрон')) {
      return Icons.handyman_rounded;
    }

    // По умолчанию для всего остального (вещевое имущество) — ящик
    return Icons.inventory_2_rounded;
  }

  static Color getColorForIcon(IconData icon) {
    if (icon == Icons.handyman_rounded) {
      return const Color(0xFFF57F17); // Цвет инвентаря
    }
    return const Color(0xFF607D8B); // Цвет вещей
  }
}
