// movimientos_repartidor.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MovimientosRepartidorPage extends StatefulWidget {
  final String empresaCodigo;
  const MovimientosRepartidorPage({Key? key, required this.empresaCodigo}) : super(key: key);

  @override
  State<MovimientosRepartidorPage> createState() => _MovimientosRepartidorPageState();
}

class _MovimientosRepartidorPageState extends State<MovimientosRepartidorPage> {
  final TextEditingController buscarCtrl = TextEditingController();

  int parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  double parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  CollectionReference movimientosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos');

  CollectionReference productosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('productos');

  Future<void> _eliminarMovimiento(DocumentSnapshot movDoc) async {
    final d = movDoc.data() as Map<String, dynamic>;
    final productoNombre = d['producto'] ?? '';
    final cantidad = parseInt(d['cantidad']);

    // revertir stock en producto (buscar product by nombre)
    final prodSnap = await productosRef().where('nombre', isEqualTo: productoNombre).limit(1).get();
    if (prodSnap.docs.isNotEmpty) {
      final prodDoc = prodSnap.docs.first;
      final stockActual = parseInt(prodDoc['stock']);
      await prodDoc.reference.update({'stock': stockActual + cantidad});
    }

    await movDoc.reference.delete();
  }

  Future<void> _editarMovimiento(DocumentSnapshot movDoc) async {
    final data = movDoc.data() as Map<String, dynamic>;
    final TextEditingController cantidadCtrl = TextEditingController(text: parseInt(data['cantidad']).toString());
    final TextEditingController precioCtrl = TextEditingController(text: parseDouble(data['precio']).toString());
    String productoNombre = (data['producto'] ?? '').toString();
    String cliente = (data['cliente'] ?? '').toString();
    String metodo = (data['pago'] ?? '').toString();

    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('Editar movimiento'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: cantidadCtrl, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
                    TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
                    TextField(controller: TextEditingController(text: productoNombre), decoration: const InputDecoration(labelText: 'Producto (no editable)'), enabled: false),
                    TextField(controller: TextEditingController(text: cliente), decoration: const InputDecoration(labelText: 'Cliente'), enabled: false),
                    TextField(controller: TextEditingController(text: metodo), decoration: const InputDecoration(labelText: 'Método pago')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () async {
                      final nuevaCantidad = parseInt(int.tryParse(cantidadCtrl.text) ?? 0);
                      final nuevoPrecio = parseDouble(double.tryParse(precioCtrl.text) ?? 0);

                      // revertir stock antiguo y aplicar nuevo
                      final prodSnap = await productosRef().where('nombre', isEqualTo: productoNombre).limit(1).get();
                      if (prodSnap.docs.isNotEmpty) {
                        final prodDoc = prodSnap.docs.first;
                        int stockActual = parseInt(prodDoc['stock']);
                        final cantidadAnterior = parseInt(data['cantidad']);
                        // revertir
                        stockActual += cantidadAnterior;
                        // aplicar nueva
                        stockActual -= nuevaCantidad;
                        if (stockActual < 0) stockActual = 0;
                        await prodDoc.reference.update({'stock': stockActual});
                      }

                      await movDoc.reference.update({
                        'cantidad': nuevaCantidad,
                        'precio': nuevoPrecio,
                        'pago': metodo,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      Navigator.pop(context);
                    },
                    child: const Text('Guardar'))
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos - Repartidor'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(controller: buscarCtrl, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar cliente o producto...'), onChanged: (_) => setState(() {})),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: movimientosRef().where('repartidor', isEqualTo: true).orderBy('fecha', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  final cliente = (m['Clientes'] ?? '').toString().toLowerCase();
                  final producto = (m['productos'] ?? '').toString().toLowerCase();
                  final q = buscarCtrl.text.toLowerCase();
                  return cliente.contains(q) || producto.contains(q);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('No hay movimientos'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final m = d.data() as Map<String, dynamic>;
                    final fechaStr = (m['fecha'] as Timestamp?)?.toDate().toLocal().toString().substring(0, 16) ?? '';
                    return Card(
                      child: ListTile(
                        title: Text('${m['producto'] ?? ''} — ${m['cliente'] ?? ''}'),
                        subtitle: Text('Cant: ${m['cantidad'] ?? ''} | Precio: ${m['precio'] ?? ''} | Pago: ${m['pago'] ?? ''}\n$fechaStr'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'ver') {
                              showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Detalle'), content: Text(m.toString()), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
                            } else if (v == 'editar') {
                              await _editarMovimiento(d);
                              setState(() {});
                            } else if (v == 'eliminar') {
                              final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                        title: const Text('Confirmar'),
                                        content: const Text('¿Eliminar movimiento y restaurar stock?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
                                        ],
                                      ));
                              if (ok == true) {
                                await _eliminarMovimiento(d);
                                setState(() {});
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'ver', child: Text('Ver')),
                            const PopupMenuItem(value: 'editar', child: Text('Editar')),
                            const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
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
    );
  }
}
