// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'productos_screen.dart';
import 'guia_llantas_screen.dart';
import 'cascos_inventario_screen.dart';
import 'visores_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Lista de las pantallas que vamos a mostrar
  static final List<Widget> _widgetOptions = <Widget>[
    ProductosScreen(),
    const GuiaLlantasScreen(),
    const CascosInventarioScreen(),
    VisoresScreen(),
  ];

  // Lista de los títulos para cada pantalla
  static const List<String> _titles = <String>[
    'Buscador de Productos',
    'Guía de Llantas',
    'Inventario de Cascos',
    'Visores Disponibles',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.album_outlined),
            label: 'Guía Llantas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_motorsports),
            label: 'Cascos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility),
            label: 'Visores',
            ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}