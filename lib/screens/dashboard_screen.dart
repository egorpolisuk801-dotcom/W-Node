import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("COMMAND CENTER",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0B1120),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "СИСТЕМА ГОТОВА ДО РОБОТИ ЗІ СКЛАДАМИ",
          style:
              TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
