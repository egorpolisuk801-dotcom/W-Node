import 'package:flutter/foundation.dart';

class ShellController {
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);

  static void go(int index) => tab.value = index;
}
