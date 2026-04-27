import "package:flutter/material.dart";

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(title: const Text("TEST SCREEN")),
      body: const Center(
        child: Text("TEST - APP WORKING", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
