import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CascosInventarioScreen extends StatefulWidget {
  const CascosInventarioScreen({Key? key}) : super(key: key);

  @override
  State<CascosInventarioScreen> createState() => _CascosInventarioScreenState();
}

class _CascosInventarioScreenState extends State<CascosInventarioScreen> {
  final TextEditingController _searchController = TextEditingController();
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
                labelText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cascos').orderBy('nombre').snapshots(),
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error al cargar datos'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allCascos = snapshot.data!.docs;
                final filteredCascos = _searchQuery.isEmpty
                    ? allCascos
                    : allCascos.where((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final nombre = data['nombre'] as String? ?? '';
                        return nombre.toLowerCase().contains(_searchQuery);
                      }).toList();

                if (filteredCascos.isEmpty) {
                  return const Center(child: Text('No se encontraron resultados.'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 80.0),
                  child: Wrap(
                    spacing: 12.0,
                    runSpacing: 12.0,
                    children: filteredCascos.map((DocumentSnapshot document) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final cardWidth = (screenWidth - 36) / 2;

                      return SizedBox(
                        width: cardWidth,
                        child: CascoInventarioCard(document: document),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoAgregar(context),
        child: const Icon(Icons.add),
        tooltip: 'Agregar Nuevo Estilo de Casco',
      ),
    );
  }
}

class CascoInventarioCard extends StatelessWidget {
  final DocumentSnapshot document;
  const CascoInventarioCard({Key? key, required this.document}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = document.data() as Map<String, dynamic>? ?? {};
    final String nombre = data['nombre'] ?? 'Sin Nombre';
    final String imageUrl = data['imagenURL'] ?? '';
    final Map<String, dynamic> tallas = data['tallas'] as Map<String, dynamic>? ?? {};

    final List<String> ordenTallas = ['XS', 'S', 'M', 'L', 'XL'];
    final List<MapEntry<String, dynamic>> tallasOrdenadas = tallas.entries.toList()
      ..sort((a, b) => ordenTallas.indexOf(a.key).compareTo(ordenTallas.indexOf(b.key)));

    final List<MapEntry<String, dynamic>> tallasEnStock = tallasOrdenadas.where((entry) => (entry.value as int? ?? 0) > 0).toList();

    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            color: Colors.grey.shade200,
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error))
                : const Center(child: Icon(Icons.no_photography_outlined, size: 40, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1, indent: 8, endIndent: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              children: tallasEnStock.map((entry) {
                final String talla = entry.key;
                final int cantidad = entry.value as int? ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Text(talla, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () { if (cantidad > 0) document.reference.update({'tallas.$talla': FieldValue.increment(-1)}); },
                      ),
                      Text(cantidad.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: () => document.reference.update({'tallas.$talla': FieldValue.increment(1)}),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(onPressed: () => _mostrarDialogoAgregar(context, documentSnapshot: document), child: const Text('Editar')),
              TextButton(onPressed: () => _eliminar(context, document.id, imageUrl), child: Text('Eliminar', style: TextStyle(color: Colors.red.shade700))),
            ],
          )
        ],
      ),
    );
  }
}

Future<void> _mostrarDialogoAgregar(BuildContext context, {DocumentSnapshot? documentSnapshot}) async {
  final data = documentSnapshot?.data() as Map<String, dynamic>?;
  final tallas = data?['tallas'] as Map<String, dynamic>? ?? {};

  final TextEditingController nombreController = TextEditingController(text: data?['nombre'] ?? '');
  final Map<String, TextEditingController> tallaControllers = {
    'XS': TextEditingController(text: tallas['XS']?.toString() ?? ''),
    'S': TextEditingController(text: tallas['S']?.toString() ?? ''),
    'M': TextEditingController(text: tallas['M']?.toString() ?? ''),
    'L': TextEditingController(text: tallas['L']?.toString() ?? ''),
    'XL': TextEditingController(text: tallas['XL']?.toString() ?? ''),
  };
  
  File? imagenParaSubir;
  String? urlImagenExistente = data?['imagenURL'];

  await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            
            Future<void> seleccionarImagen() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
              if (pickedFile != null) dialogSetState(() => imagenParaSubir = File(pickedFile.path));
            }

            return AlertDialog(
              title: Text(documentSnapshot != null ? 'Editar Estilo' : 'Agregar Nuevo Estilo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: seleccionarImagen,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                        child: imagenParaSubir != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(imagenParaSubir!, fit: BoxFit.cover))
                            : (urlImagenExistente != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(urlImagenExistente!, fit: BoxFit.cover))
                                : const Icon(Icons.camera_alt, color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre del Estilo')),
                    const SizedBox(height: 10),
                    const Text("Cantidades por Talla", style: TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: tallaControllers['XS'], decoration: const InputDecoration(labelText: 'XS'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 5),
                        Expanded(child: TextField(controller: tallaControllers['S'], decoration: const InputDecoration(labelText: 'S'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: tallaControllers['M'], decoration: const InputDecoration(labelText: 'M'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 5),
                        Expanded(child: TextField(controller: tallaControllers['L'], decoration: const InputDecoration(labelText: 'L'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 5),
                        Expanded(child: TextField(controller: tallaControllers['XL'], decoration: const InputDecoration(labelText: 'XL'), keyboardType: TextInputType.number)),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    final String nombre = nombreController.text.trim();
                    if (nombre.isEmpty) return;

                    String imageUrl = urlImagenExistente ?? '';
                    if (imagenParaSubir != null) {
                      final ref = FirebaseStorage.instance.ref().child('cascos/${DateTime.now().millisecondsSinceEpoch}.png');
                      await ref.putFile(imagenParaSubir!);
                      imageUrl = await ref.getDownloadURL();
                    }

                    Map<String, int> tallasFinales = {};
                    tallaControllers.forEach((talla, controller) {
                      final cantidad = int.tryParse(controller.text);
                      if (cantidad != null && cantidad >= 0) {
                        tallasFinales[talla] = cantidad;
                      }
                    });
                    
                    Map<String, dynamic> dataToSave = {"nombre": nombre, "imagenURL": imageUrl, "tallas": tallasFinales};

                    if (documentSnapshot != null) {
                      await FirebaseFirestore.instance.collection('cascos').doc(documentSnapshot.id).update(dataToSave);
                    } else {
                      await FirebaseFirestore.instance.collection('cascos').add(dataToSave);
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      });
}

Future<void> _eliminar(BuildContext context, String docId, String imageUrl) async {
  bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Está seguro de que desea eliminar este estilo de casco y todo su inventario?'),
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
      await FirebaseFirestore.instance.collection('cascos').doc(docId).delete();
      if(imageUrl.isNotEmpty) {
        try { await FirebaseStorage.instance.refFromURL(imageUrl).delete(); }
        catch (e) { print("Error borrando imagen de Storage: $e"); }
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estilo eliminado con éxito')));
    }
}
