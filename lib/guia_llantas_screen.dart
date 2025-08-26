import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GuiaLlantasScreen extends StatefulWidget {
  const GuiaLlantasScreen({Key? key}) : super(key: key);

  @override
  State<GuiaLlantasScreen> createState() => _GuiaLlantasScreenState();
}

class _GuiaLlantasScreenState extends State<GuiaLlantasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTableHeader(BuildContext context) {
    final headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: Theme.of(context).primaryColorDark,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 2.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Moto', style: headerStyle)),
          Expanded(flex: 2, child: Text('Delantera', style: headerStyle, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Trasera', style: headerStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              // <<< CAMBIO AQUÍ
              labelText: 'Buscar por modelo...',
              hintText: 'Ej: NKD 125, Gixxer, FZ...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
            ),
          ),
        ),
        _buildTableHeader(context),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('motos').orderBy('marca').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay motos en la guía.'));
              }

              final allMotos = snapshot.data!.docs;
              final filteredMotos = _searchQuery.isEmpty
                  ? allMotos
                  : allMotos.where((doc) {
                      // <<< CAMBIO CLAVE AQUÍ: Se busca en 'modelo' en lugar de 'marca'
                      String modelo = doc['modelo'].toString().toLowerCase();
                      String marca = doc['marca'].toString().toLowerCase();
                      
                      // Buscamos tanto en marca como en modelo para una mejor experiencia
                      return modelo.contains(_searchQuery.toLowerCase()) || 
                             marca.contains(_searchQuery.toLowerCase());
                    }).toList();

              if (filteredMotos.isEmpty) {
                return Center(
                  child: Text(
                    'No se encontraron resultados para "$_searchQuery"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredMotos.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> moto = filteredMotos[index].data()! as Map<String, dynamic>;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      color: index.isEven ? Colors.white : Colors.black.withOpacity(0.02),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moto['marca'] ?? 'Sin Marca',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                moto['modelo'] ?? 'Sin Modelo',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            moto['llantaDelantera'] ?? '-',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            moto['llantaTrasera'] ?? '-',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}