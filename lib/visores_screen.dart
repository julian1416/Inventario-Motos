// lib/visores_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- PANTALLA PRINCIPAL DE VISORES ---
class VisoresScreen extends StatefulWidget {
  @override
  _VisoresScreenState createState() => _VisoresScreenState();
}

class _VisoresScreenState extends State<VisoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _productos = FirebaseFirestore.instance.collection('productos');
  String _searchQuery = "";

  // --- El diálogo avanzado para agregar/editar visores ---
  Future<void> _mostrarDialogoVisor({DocumentSnapshot? documentSnapshot}) async {
    final bool isEditing = documentSnapshot != null;
    final data = documentSnapshot?.data() as Map<String, dynamic>?;

    final TextEditingController nombreController = TextEditingController(text: data?['nombre'] ?? '');
    final TextEditingController precioController = TextEditingController(text: data?['precio']?.toString() ?? '');
    
    List<Map<String, TextEditingController>> colorControllers = [];

    if (isEditing && data?['colores'] != null) {
      final Map<String, dynamic> colores = data!['colores'];
      colores.forEach((key, value) {
        colorControllers.add({
          'nombre': TextEditingController(text: key),
          'cantidad': TextEditingController(text: value.toString()),
        });
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Visor' : 'Agregar Nuevo Visor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre del Visor')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: precioController,
                      decoration: const InputDecoration(labelText: 'Precio', prefixIcon: Icon(Icons.attach_money)),
                      keyboardType: TextInputType.number,
                    ),
                    const Divider(height: 30, thickness: 1),
                    const Text('Inventario por Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),

                    if (colorControllers.isEmpty) const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Añada un color para empezar.', style: TextStyle(color: Colors.grey)),
                    ),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: colorControllers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Expanded(child: TextField(controller: colorControllers[index]['nombre'], decoration: const InputDecoration(labelText: 'Color'))),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline), color: Colors.red, visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  int currentValue = int.tryParse(colorControllers[index]['cantidad']!.text) ?? 0;
                                  if (currentValue > 0) dialogSetState(() => colorControllers[index]['cantidad']!.text = (currentValue - 1).toString());
                                },
                              ),
                              SizedBox(width: 40, child: TextField(controller: colorControllers[index]['cantidad'], textAlign: TextAlign.center, keyboardType: TextInputType.number)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline), color: Colors.green, visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  int currentValue = int.tryParse(colorControllers[index]['cantidad']!.text) ?? 0;
                                  dialogSetState(() => colorControllers[index]['cantidad']!.text = (currentValue + 1).toString());
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Añadir Color'),
                      onPressed: () {
                        dialogSetState(() => colorControllers.add({'nombre': TextEditingController(), 'cantidad': TextEditingController(text: '0')}));
                      },
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    final Map<String, int> coloresFinal = {};
                    for (var controllerMap in colorControllers) {
                      final String nombreColor = controllerMap['nombre']!.text.trim().toLowerCase();
                      final int cantidadColor = int.tryParse(controllerMap['cantidad']!.text) ?? 0;
                      if (nombreColor.isNotEmpty) coloresFinal[nombreColor] = cantidadColor;
                    }
                    
                    final String nombre = nombreController.text;
                    final double precio = double.tryParse(precioController.text) ?? 0.0;

                    if (nombre.isNotEmpty) {
                      final dataToSave = {'nombre': nombre, 'precio': precio, 'categoria': 'visor', 'colores': coloresFinal};
                      if (isEditing) {
                        await _productos.doc(documentSnapshot.id).update(dataToSave);
                      } else {
                        await _productos.add(dataToSave);
                      }
                    }
                    Navigator.pop(context);
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar visor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _productos.where('categoria', isEqualTo: 'visor').orderBy('nombre').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay visores. Agrega uno con el botón "+".'));

                var productosFiltrados = snapshot.data!.docs.where((doc) {
                  return (doc.data() as Map<String, dynamic>)['nombre'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                if (productosFiltrados.isEmpty) return const Center(child: Text('No se encontraron visores'));

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: productosFiltrados.length,
                  itemBuilder: (context, index) {
                    return VisorExpansionCard(
                      document: productosFiltrados[index],
                      onEdit: () => _mostrarDialogoVisor(documentSnapshot: productosFiltrados[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoVisor(),
        child: const Icon(Icons.add),
        tooltip: 'Agregar nuevo estilo de visor',
      ),
    );
  }
}

// --- WIDGET PARA LA TARJETA EXPANDIBLE ---
class VisorExpansionCard extends StatelessWidget {
  final DocumentSnapshot document;
  final VoidCallback onEdit;

  const VisorExpansionCard({Key? key, required this.document, required this.onEdit}) : super(key: key);

  // <<< LA FUNCIÓN DE ELIMINAR AHORA ESTÁ COMPLETA Y CORRECTA >>>
  Future<void> _eliminarVisor(BuildContext context, String nombreVisor) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Está seguro de que desea eliminar el estilo "$nombreVisor" y todo su stock?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmar) {
      await document.reference.delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$nombreVisor" fue eliminado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = document.data() as Map<String, dynamic>;
    final Map<String, dynamic> colores = data['colores'] ?? {};
    final String subtitulo = colores.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
    final double precio = (data['precio'] ?? 0.0).toDouble();

    final formatoPrecio = NumberFormat.decimalPattern('es_CO').format(precio);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.visibility_outlined, size: 40, color: Colors.teal.shade400),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(data['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            Text('\$$formatoPrecio', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Text(subtitulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: onEdit,
          tooltip: 'Editar visor, colores y stock',
        ),
        
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...colores.entries.map((entry) {
                  String color = entry.key;
                  int cantidad = entry.value;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(color[0].toUpperCase() + color.substring(1), style: const TextStyle(fontSize: 16)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => document.reference.update({'colores.$color': FieldValue.increment(1)})),
                          Text(cantidad.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () { if (cantidad > 0) document.reference.update({'colores.$color': FieldValue.increment(-1)}); }),
                        ],
                      )
                    ],
                  );
                }).toList(),
                
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => _eliminarVisor(context, data['nombre']),
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      tooltip: 'Eliminar estilo completo',
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}