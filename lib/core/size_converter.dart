class SizeConverter {
  // Перевод размера (Ширина груди/талии)
  static String getLetterSize(int sizeNum) {
    if (sizeNum <= 42) return 'XS';
    if (sizeNum == 44 || sizeNum == 46) return 'S';
    if (sizeNum == 48) return 'M';
    if (sizeNum == 50 || sizeNum == 52) return 'L'; // И 50, и 52 станут L
    if (sizeNum == 54 || sizeNum == 56) return 'XL';
    if (sizeNum == 58 || sizeNum == 60) return '2XL';
    if (sizeNum == 62 || sizeNum == 64) return '3XL';
    if (sizeNum == 66 || sizeNum == 68) return '4XL';
    if (sizeNum >= 70) return '5XL';
    return '?';
  }

  // Перевод роста (Длина рукава/штанины)
  static String getLetterHeight(int heightNum) {
    if (heightNum == 1 || heightNum == 2) return 'S';
    if (heightNum == 3 || heightNum == 4) return 'R'; // И 3, и 4 станут R
    if (heightNum == 5 || heightNum == 6) return 'L';
    if (heightNum >= 7) return 'XL';
    return '?';
  }

  // 🔥 ГОЛОВНИЙ МОЗОК: Розуміє будь-який формат і зводить до стандарту
  static String normalize(String sizeString) {
    // 1. Прибираємо зайві пробіли і робимо всі букви великими
    String s = sizeString.trim().toUpperCase();

    // 2. Уніфікуємо ікси (щоб машина не плутала XXL та 2XL)
    s = s.replaceAll('XXXXL', '4XL');
    s = s.replaceAll('XXXL', '3XL');
    s = s.replaceAll('XXL', '2XL');

    // Прибираємо пробіли біля слеша (якщо хтось написав "L / R")
    s = s.replaceAll(RegExp(r'\s+/\s+'), '/');
    s = s.replaceAll(RegExp(r'\s+/'), '/');
    s = s.replaceAll(RegExp(r'/\s+'), '/');

    // 3. РОЗПІЗНАВАННЯ ЦИФР: Шукаємо формати "50/3", "52/4", або навіть криві "50-52/3-4"
    // Програма витягне ПЕРШЕ число розміру і ПЕРШЕ число росту.
    RegExp regex = RegExp(r'(\d+).*?\/.*?(\d+)');
    Match? match = regex.firstMatch(s);

    if (match != null) {
      try {
        int size = int.parse(match.group(1)!); // дістає 50 або 52
        int height = int.parse(match.group(2)!); // дістає 3 або 4

        // Якщо це справді розміри одягу (а не 100500)
        if (size >= 42 && size <= 74 && height >= 1 && height <= 8) {
          // МІГІЯ ТУТ: Перетворюємо цифри у букви!
          return '${getLetterSize(size)}/${getLetterHeight(height)}';
        }
      } catch (e) {
        // Якщо щось пішло не так, не падаємо
      }
    }

    // 4. Якщо вказаний тільки розмір БЕЗ росту (наприклад просто "50" або "52")
    RegExp singleNumRegex = RegExp(r'^(\d+)$');
    Match? singleMatch = singleNumRegex.firstMatch(s);
    if (singleMatch != null) {
      int size = int.parse(singleMatch.group(1)!);
      if (size >= 42 && size <= 74) {
        return getLetterSize(size); // 50 стане просто "L"
      }
    }

    // Якщо нічого не підійшло (це вже літери, наприклад "L/R"), повертаємо як є
    return s;
  }
}
