import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ¡Importante! Asegúrate de que esta línea esté presente
import 'main_screen.dart';     // Importa la nueva pantalla con los botones de navegación

void main() async {
  // Asegura que todos los bindings de Flutter estén listos antes de ejecutar código nativo
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Firebase usando las opciones específicas de tu plataforma (Android/iOS)
  // que están definidas en firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicia la aplicación
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      
      title: 'Moto Shop',
      theme: ThemeData(
        primarySwatch: Colors.teal, 
        useMaterial3: true, 
      ),
      home: const MainScreen(),
    );
  }
}
