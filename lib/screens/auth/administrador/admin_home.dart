import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHome extends StatefulWidget {
  final String empresaCodigo;

  const AdminHome({Key? key, required this.empresaCodigo}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController precioCtrl = TextEditingController();
  final TextEditingController stockCtrl = TextEditingController();

  /// 📌 Agregar producto
  Future<void> _agregarProducto() async {
    if (nombreCtrl.text.isEmpty || precioCtrl.text.isEmpty || stockCtrl.text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaCodigo)
        .collection('productos')
        .add({
      "nombre": nombreCtrl.text,
      "descripcion": descCtrl.text,
      "precio": double.tryParse(precioCtrl.text) ?? 0,
      "stock": int.tryParse(stockCtrl.text) ?? 0,
      "unidad": "pieza",
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "activo": true,
    });

    nombreCtrl.clear();
    descCtrl.clear();
    precioCtrl.clear();
    stockCtrl.clear();
  }

  /// 📌 Editar producto
  Future<void> _editarProducto(String id, Map<String, dynamic> data) async {
    nombreCtrl.text = data["nombre"];
    descCtrl.text = data["descripcion"];
    precioCtrl.text = data["precio"].toString();
    stockCtrl.text = data["stock"].toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar producto"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl, decoration: InputDecoration(labelText: "Nombre")),
            TextField(controller: descCtrl, decoration: InputDecoration(labelText: "Descripción")),
            TextField(controller: precioCtrl, decoration: InputDecoration(labelText: "Precio"), keyboardType: TextInputType.number),
            TextField(controller: stockCtrl, decoration: InputDecoration(labelText: "Stock"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaCodigo)
                  .collection('productos')
                  .doc(id)
                  .update({
                "nombre": nombreCtrl.text,
                "descripcion": descCtrl.text,
                "precio": double.tryParse(precioCtrl.text) ?? 0,
                "stock": int.tryParse(stockCtrl.text) ?? 0,
                "updatedAt": FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: Text("Guardar"),
          ),
        ],
      ),
    );
  }

  /// 📌 Eliminar producto
  Future<void> _eliminarProducto(String id) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaCodigo)
        .collection('productos')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final productosRef = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaCodigo)
        .collection('productos');

    return Scaffold(
      appBar: AppBar(title: Text("Panel de Administrador")),
      body: Column(
        children: [
          /// 👉 Formulario para agregar productos
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text("Agregar Producto", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: nombreCtrl, decoration: InputDecoration(labelText: "Nombre")),
                TextField(controller: descCtrl, decoration: InputDecoration(labelText: "Descripción")),
                TextField(controller: precioCtrl, decoration: InputDecoration(labelText: "Precio"), keyboardType: TextInputType.number),
                TextField(controller: stockCtrl, decoration: InputDecoration(labelText: "Stock"), keyboardType: TextInputType.number),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _agregarProducto,
                  child: Text("Guardar Producto"),
                ),
              ],
            ),
          ),

          Divider(),

          /// 👉 Lista de productos existentes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productosRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final productos = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final doc = productos[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data["nombre"] ?? "Sin nombre"),
                      subtitle: Text("Stock: ${data["stock"]} | \$${data["precio"]}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editarProducto(doc.id, data),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarProducto(doc.id),
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
      ),
    );
  }
}
