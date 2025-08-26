import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Asegúrate de que esta importación esté presente

class ProductosScreen extends StatefulWidget {
  @override
  _ProductosScreenState createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _productos = FirebaseFirestore.instance.collection('productos');

  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _productos.orderBy('nombre').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay productos disponibles'));
                }

                var productosFiltrados = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = data['nombre']?.toString().toLowerCase() ?? '';
                  return nombre.contains(_searchQuery);
                }).toList();

                if (productosFiltrados.isEmpty) {
                  return const Center(child: Text('No se encontraron productos'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: productosFiltrados.length,
                  itemBuilder: (context, index) {
                    final doc = productosFiltrados[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final nombre = data['nombre'] ?? 'Sin Nombre';
                    final precio = (data['precio'] ?? 0.0).toStringAsFixed(2);
                    final cantidad = data['cantidad'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // --- TÉRMINO CORREGIDO ---
                        subtitle: Text('Precio: \$${precio} - Cantidad: ${cantidad}'),
                        leading: const Icon(Icons.shopping_bag_outlined),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              // *** AHORA LLAMA AL DIÁLOGO DE EDICIÓN MEJORADO ***
                              onPressed: () => _mostrarDialogoEditarProducto(doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _eliminarProducto(doc.id, nombre),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // *** AHORA LLAMA A TU DIÁLOGO ORIGINAL PARA AGREGAR ***
        onPressed: () => _mostrarDialogoAgregarProducto(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- FUNCIÓN DE EDICIÓN MEJORADA Y DEDICADA ---
  Future<void> _mostrarDialogoEditarProducto(DocumentSnapshot productoDoc) async {
    final _formKey = GlobalKey<FormState>();
    final data = productoDoc.data() as Map<String, dynamic>;

    // Controladores con los datos existentes del producto
    final nombreController = TextEditingController(text: data['nombre'] ?? '');
    final precioController = TextEditingController(text: (data['precio'] ?? 0.0).toString());
    final cantidadController = TextEditingController(text: (data['cantidad'] ?? 0).toString());
    
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            
            Future<void> guardarCambios() async {
              if (_formKey.currentState!.validate()) {
                setState(() => isLoading = true);
                
                final datosParaActualizar = {
                  'nombre': nombreController.text.trim(),
                  'precio': double.tryParse(precioController.text.trim()) ?? 0.0,
                  'cantidad': int.tryParse(cantidadController.text.trim()) ?? 0,
                };
                
                try {
                  await _productos.doc(productoDoc.id).update(datosParaActualizar);
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  // Manejo de errores
                } finally {
                  if(mounted) setState(() => isLoading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Editar Producto'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'El nombre es obligatorio' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: precioController,
                        decoration: const InputDecoration(labelText: 'Precio'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        validator: (value) => (double.tryParse(value ?? '') ?? -1) <= 0 ? 'Precio inválido' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: cantidadController,
                        // --- TÉRMINO CORREGIDO ---
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (value) => (int.tryParse(value ?? '') ?? -1) < 0 ? 'Cantidad inválida' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : guardarCambios,
                  child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  // --- TUS FUNCIONES ORIGINALES PARA AGREGAR PRODUCTO ---
  void _mostrarDialogoAgregarProducto() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController precioController = TextEditingController();
    final TextEditingController cantidadController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: precioController, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
              TextField(controller: cantidadController, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                _agregarProducto(
                  nombreController.text,
                  double.tryParse(precioController.text) ?? 0.0,
                  int.tryParse(cantidadController.text) ?? 0,
                );
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _agregarProducto(String nombre, double precio, int cantidad) {
    if (nombre.isNotEmpty && precio > 0 && cantidad >= 0) { // Permitimos cantidad 0
      _productos.add({'nombre': nombre, 'precio': precio, 'cantidad': cantidad});
    }
  }


  // --- TU FUNCIÓN ORIGINAL PARA ELIMINAR (SIN CAMBIOS) ---
  void _eliminarProducto(String id, String nombreProducto) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Producto'),
          content: Text('¿Está seguro de que desea eliminar el producto "$nombreProducto"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _productos.doc(id).delete();
                Navigator.pop(context);
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}