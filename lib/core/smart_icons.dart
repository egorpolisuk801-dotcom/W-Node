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

    if (name.contains('генератор') ||
        name.contains('станці') ||
        name.contains('лопата') ||
        name.contains('пила') ||
        name.contains('дрон') ||
        name.contains('інструмент')) {
      return Icons.handyman_rounded;
    }
    if (name.contains('черевик') ||
        name.contains('берц') ||
        name.contains('кросів') ||
        name.contains('взутт')) {
      return Icons.hiking_rounded;
    }
    if (name.contains('куртк') ||
        name.contains('бушлат') ||
        name.contains('кофт') ||
        name.contains('футболка') ||
        name.contains('штани') ||
        name.contains('брюк')) {
      return Icons.checkroom_rounded;
    }
    if (name.contains('шапк') ||
        name.contains('каск') ||
        name.contains('феск') ||
        name.contains('панам')) {
      return Icons.sports_hockey_rounded;
    }
    if (name.contains('рюкзак') || name.contains('баул')) {
      return Icons.backpack_rounded;
    }

    return Icons.inventory_2_rounded;
  }

  static Color getColorForIcon(IconData icon) {
    if (icon == Icons.handyman_rounded) {
      return const Color(0xFFF57F17); // Цвет инвентаря
    }
    return const Color(0xFF607D8B); // Цвет вещей
  }
}
