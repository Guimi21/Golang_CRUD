// main.dart
import 'package:flutter/material.dart';
import 'screens/usuarios_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRUD Flutter Offline-First',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UsuariosPage(),
    );
  }
}

