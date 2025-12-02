// admin_home.dart (DISEÑO MODERNO CON HISTORIAL DE CORTES INTEGRADO)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asegúrate de tener estas importaciones o comenta si no las usas por ahora
import 'movimientos_repartidor.dart';
import 'movimientos_ventanilla.dart';
import '../../widgets/animated_background.dart';

/// ------------------- COLORES / ESTILOS -------------------
const Color primaryColor = Color(0xFF3B82F6); // Azul principal
const Color secondaryColor = Color(0xFF60A5FA); // Azul claro secundario
const Color backgroundColor = Color(0xFFF5F7FA); // Fondo claro suave
const Color stockLowColor = Colors.redAccent;
const Color stockOkColor = Color(0xFF2ECC71);
const Color reportColor = Color(0xFF2E7D32); // Verde para reportes/excel

// ------------------- WIDGETS AUXILIARES DE DISEÑO -------------------

Widget _buildSummaryWidget({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Expanded(
    child: Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildProductCard(
  DocumentSnapshot d,
  Map<String, dynamic> data,
  Function(String id, Map<String, dynamic> data) onEdit,
  Function(String id) onDelete,
  int Function(dynamic v) parseInt,
  double Function(dynamic v) parseDouble,
) {
  final stock = parseInt(data['stock']);
  final price = parseDouble(data['precio']);
  final stockColor = stock == 0 ? stockLowColor : stockOkColor;
  final stockText = stock == 0 ? 'Agotado' : '$stock unidades';

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined, color: primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['nombre'] ?? 'Sin nombre',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  (data['descripcion'] ?? 'Sin descripción').toString(),
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: secondaryColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Chip(
                label: Text(stockText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                backgroundColor: stockColor,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: primaryColor,
                    onPressed: () => onEdit(d.id, data),
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: stockLowColor,
                    onPressed: () => onDelete(d.id),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ------------------- CLASE PRINCIPAL (LÓGICA ORIGINAL MANTENIDA) -------------------

class AdminHome extends StatefulWidget {
  final String empresaCodigo;
  const AdminHome({Key? key, required this.empresaCodigo}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Productos
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController precioCtrl = TextEditingController();
  final TextEditingController stockCtrl = TextEditingController();
  final TextEditingController buscarProductoCtrl = TextEditingController();

  // Clientes
  final TextEditingController clienteNombreCtrl = TextEditingController();
  final TextEditingController clienteTelCtrl = TextEditingController();
  final TextEditingController clienteCorreoCtrl = TextEditingController();
  final TextEditingController clienteDireccionCtrl = TextEditingController();
  final TextEditingController clienteNotasCtrl = TextEditingController();
  final TextEditingController clienteGarrafonesCtrl = TextEditingController();
  final TextEditingController buscarClienteCtrl = TextEditingController();

  // Ventas / Movimientos (registro desde admin)
  String? clienteSeleccionado;
  String? productoSeleccionado;
  final TextEditingController movCantidadCtrl = TextEditingController();
  final TextEditingController movPrecioCtrl = TextEditingController();
  String movMetodoPago = 'Efectivo';
  String movOrigen = 'ventanilla'; // 'ventanilla' o 'repartidor'

  // Para mostrar FAB dinámico cuando cambia la pestaña
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  // util
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



  // ---------------- Productos (Colección y funciones) ----------------
  CollectionReference productosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('productos');

  Future<void> _agregarProducto() async {
    if (nombreCtrl.text.isEmpty) return;
    await productosRef().add({
      'nombre': nombreCtrl.text.trim(),
      'descripcion': descCtrl.text.trim(),
      'precio': parseDouble(precioCtrl.text),
      'stock': parseInt(stockCtrl.text),
      'createdAt': FieldValue.serverTimestamp(),
    });
    nombreCtrl.clear();
    descCtrl.clear();
    precioCtrl.clear();
    stockCtrl.clear();
  }

  Future<void> _editarProducto(String id, Map<String, dynamic> data) async {
    nombreCtrl.text = (data['nombre'] ?? '').toString();
    descCtrl.text = (data['descripcion'] ?? '').toString();
    precioCtrl.text = parseDouble(data['precio']).toString();
    stockCtrl.text = parseInt(data['stock']).toString();

    await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('✏️ Editar producto', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
                  TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
                  TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () async {
                    await productosRef().doc(id).update({
                      'nombre': nombreCtrl.text.trim(),
                      'descripcion': descCtrl.text.trim(),
                      'precio': parseDouble(precioCtrl.text),
                      'stock': parseInt(stockCtrl.text),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                  },
                  child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white))),
            ],
          );
        });
  }

  Future<void> _eliminarProducto(String id) async {
    await productosRef().doc(id).delete();
  }

  // ---------------- Clientes ----------------
  CollectionReference clientesRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('Clientes');

  Future<void> _agregarCliente() async {
    if (clienteNombreCtrl.text.isEmpty) return;

    await clientesRef().add({
      'nombre': clienteNombreCtrl.text.trim(),
      'telefono': clienteTelCtrl.text.trim(),
      'correo': clienteCorreoCtrl.text.trim(),
      'direccion': clienteDireccionCtrl.text.trim(),
      'notas': clienteNotasCtrl.text.trim(),
      'garrafonesRN': int.tryParse(clienteGarrafonesCtrl.text.trim()) ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Limpiar controles
    clienteNombreCtrl.clear();
    clienteTelCtrl.clear();
    clienteCorreoCtrl.clear();
    clienteDireccionCtrl.clear();
    clienteNotasCtrl.clear();
    clienteGarrafonesCtrl.clear();
  }

  Future<void> _editarCliente(String id, Map<String, dynamic> data) async {
      clienteNombreCtrl.text = data['nombre'] ?? '';
      clienteTelCtrl.text = data['telefono'] ?? '';
      clienteCorreoCtrl.text = data['correo'] ?? '';
      clienteDireccionCtrl.text = data['direccion'] ?? '';
      clienteNotasCtrl.text = data['notas'] ?? '';
      clienteGarrafonesCtrl.text = (data['garrafonesRN'] ?? 0).toString();

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("✏️ Editar Cliente", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: clienteNombreCtrl, decoration: const InputDecoration(labelText: "Nombre")),
                  TextField(controller: clienteTelCtrl, decoration: const InputDecoration(labelText: "Teléfono")),
                  TextField(controller: clienteCorreoCtrl, decoration: const InputDecoration(labelText: "Correo")),
                  TextField(controller: clienteDireccionCtrl, decoration: const InputDecoration(labelText: "Dirección")),
                  TextField(controller: clienteNotasCtrl, decoration: const InputDecoration(labelText: "Notas")),
                  TextField(controller: clienteGarrafonesCtrl, decoration: const InputDecoration(labelText: "Garrafones RN"), keyboardType: TextInputType.number),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  await clientesRef().doc(id).update({
                    'nombre': clienteNombreCtrl.text.trim(),
                    'telefono': clienteTelCtrl.text.trim(),
                    'correo': clienteCorreoCtrl.text.trim(),
                    'direccion': clienteDireccionCtrl.text.trim(),
                    'notas': clienteNotasCtrl.text.trim(),
                    'garrafonesRN': int.tryParse(clienteGarrafonesCtrl.text) ?? 0,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                },
                child: Text("Guardar", style: GoogleFonts.poppins(color:Colors.white)),
              ),
            ],
          );
        },
      );
    }

  // ---------------- Movimientos / Ventas (registrar desde admin) ----------------
  CollectionReference movimientosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos');

  Future<void> _registrarMovimientoDesdeAdmin() async {
    if (clienteSeleccionado == null || productoSeleccionado == null || movCantidadCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona cliente/producto y cantidad')));
      return;
    }

    // buscar product doc by nombre (productoSeleccionado guarda nombre)
    final prodSnap = await productosRef().where('nombre', isEqualTo: productoSeleccionado).limit(1).get();
    if (prodSnap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto no encontrado')));
      return;
    }
    final prodDoc = prodSnap.docs.first;
    final stockActual = parseInt(prodDoc['stock']);
    final cantidad = parseInt(movCantidadCtrl.text);
    if (cantidad > stockActual) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock insuficiente')));
      return;
    }

    final precioUnitario = movPrecioCtrl.text.isEmpty ? parseDouble(prodDoc['precio']) : parseDouble(movPrecioCtrl.text);

    // crear movimiento (repartidor true/ventanilla true según movOrigen)
    final isRepartidor = movOrigen == 'repartidor';
    final isVentanilla = movOrigen == 'ventanilla';

    await movimientosRef().add({
      'cliente': clienteSeleccionado,
      'producto': productoSeleccionado,
      'cantidad': cantidad,
      'precio': precioUnitario,
      'pago': movMetodoPago,
      'repartidor': isRepartidor,
      'ventanilla': isVentanilla,
      'fecha': FieldValue.serverTimestamp(),
      'origen': 'admin', // para referencia
    });

    // restar stock
    await prodDoc.reference.update({'stock': stockActual - cantidad});

    movCantidadCtrl.clear();
    movPrecioCtrl.clear();
    setState(() {
      clienteSeleccionado = null;
      productoSeleccionado = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento guardado')));
  }

  // ------------------ MODALES (DISEÑO) ------------------

  // Modal para agregar producto (está estilo tarjeta)
  Future<void> _showAddProductModal() async {
    nombreCtrl.clear();
    descCtrl.clear();
    precioCtrl.clear();
    stockCtrl.clear();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('➕ Agregar Producto', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                          const SizedBox(height: 8),
                          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
                          const SizedBox(height: 8),
                          TextField(controller: precioCtrl, decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$'), keyboardType: TextInputType.number),
                          const SizedBox(height: 8),
                          TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        onPressed: () async {
                          await _agregarProducto();
                          if (mounted) Navigator.pop(context);
                        },
                        child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white)),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Modal para agregar cliente
  Future<void> _showAddClientModal() async {
  clienteNombreCtrl.clear();
  clienteTelCtrl.clear();
  clienteCorreoCtrl.clear();
  clienteDireccionCtrl.clear();
  clienteNotasCtrl.clear();
  clienteGarrafonesCtrl.clear();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('➕ Agregar Cliente', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        TextField(controller: clienteNombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                        const SizedBox(height: 8),
                        TextField(controller: clienteTelCtrl, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
                        const SizedBox(height: 8),
                        TextField(controller: clienteCorreoCtrl, decoration: const InputDecoration(labelText: 'Correo')),
                        const SizedBox(height: 8),
                        TextField(controller: clienteDireccionCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
                        const SizedBox(height: 8),
                        TextField(controller: clienteNotasCtrl, decoration: const InputDecoration(labelText: 'Notas')),
                        const SizedBox(height: 8),
                        TextField(controller: clienteGarrafonesCtrl, decoration: const InputDecoration(labelText: 'Garrafones RN'), keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: () async {
                        await _agregarCliente();
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      );
    },
  );
}


  // Modal para registrar movimiento (CORREGIDO)
  Future<void> _showRegisterMovementModal() async {
    movCantidadCtrl.clear();
    movPrecioCtrl.clear();
    clienteSeleccionado = null;
    productoSeleccionado = null;
    movMetodoPago = 'Efectivo';
    movOrigen = 'ventanilla';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 12),
                  Text('🧾 Registrar Movimiento', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          // ---------------- CORRECCIÓN AQUÍ (CLIENTE) ----------------
                          StreamBuilder<QuerySnapshot>(
                            stream: clientesRef().snapshots(),
                            builder: (context, snapC) {
                              if (!snapC.hasData) return const SizedBox();
                              final clientes = snapC.data!.docs;
                              final items = clientes.map((c) => (c['nombre'] ?? '').toString()).toList();

                              return DropdownButtonFormField<String>(
                                isExpanded: true, // <--- SE MOVIÓ AQUÍ (FUERA DE DECORATION)
                                decoration: const InputDecoration(
                                  labelText: 'Cliente', 
                                  border: OutlineInputBorder()
                                ),
                                hint: const Text('Seleccionar cliente'),
                                value: clienteSeleccionado,
                                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => clienteSeleccionado = v),
                              );
                            },
                          ),
                          const SizedBox(height: 8),

                          // ---------------- CORRECCIÓN AQUÍ (PRODUCTO) ----------------
                          StreamBuilder<QuerySnapshot>(
                            stream: productosRef().snapshots(),
                            builder: (context, snapP) {
                              if (!snapP.hasData) return const SizedBox();
                              final productos = snapP.data!.docs;
                              final items = productos.map((p) => (p['nombre'] ?? '').toString()).toList();

                              return DropdownButtonFormField<String>(
                                isExpanded: true, // <--- SE MOVIÓ AQUÍ (FUERA DE DECORATION)
                                decoration: const InputDecoration(
                                  labelText: 'Producto', 
                                  border: OutlineInputBorder()
                                ),
                                hint: const Text('Seleccionar producto'),
                                value: productoSeleccionado,
                                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => productoSeleccionado = v),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // El resto sigue igual...
                          TextField(controller: movCantidadCtrl, decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                          const SizedBox(height: 8),
                          TextField(controller: movPrecioCtrl, decoration: const InputDecoration(labelText: 'Precio unitario (opcional)', prefixText: '\$', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                            value: movMetodoPago,
                            items: const [
                              DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                              DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                            ],
                            onChanged: (v) => setState(() => movMetodoPago = v ?? 'Efectivo'),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Text('Origen:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Ventanilla'),
                              selected: movOrigen == 'ventanilla',
                              selectedColor: primaryColor.withOpacity(0.12),
                              onSelected: (_) => setState(() => movOrigen = 'ventanilla'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Repartidor'),
                              selected: movOrigen == 'repartidor',
                              selectedColor: primaryColor.withOpacity(0.12),
                              onSelected: (_) => setState(() => movOrigen = 'repartidor'),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: () async {
                        await _registrarMovimientoDesdeAdmin();
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text('Registrar', style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------ BUILD ------------------

@override
Widget build(BuildContext context) {
  return AnimatedBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,

      // AppBar limpio
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          'Panel de Administración',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.black,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Productos'),
            Tab(text: 'Clientes'),
            Tab(text: 'Movimientos'),
          ],
        ),
      ),
      
      body: Column(
        children: [
          // Banner con código de empresa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.label, color: primaryColor),
                ),
                title: Text(
                  'Empresa: ${widget.empresaCodigo}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Panel de administración',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ),
          ),

          // Contenido principal (Tabs)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(),
                _buildClientesTab(),
                _buildMovimientosTab(),
              ],
            ),
          ),
        ],
      ),

      // FAB dinámico según pestaña
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddProductModal,
              label: Text('Agregar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
              icon: const Icon(Icons.add, color: Colors.white),
              backgroundColor: primaryColor,
            )
          : _tabController.index == 1
              ? FloatingActionButton.extended(
                  onPressed: _showAddClientModal,
                  label: Text('Agregar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  backgroundColor: primaryColor,
                )
              : FloatingActionButton.extended(
                  onPressed: _showRegisterMovementModal,
                  label: Text('Registrar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  backgroundColor: primaryColor,
                ),
    ),
  );
}


  // ------------------ PESTAÑAS (SEPARADAS PARA CLARIDAD) ------------------

  Widget _buildProductsTab() {
    return AnimatedBackground(
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Resumen ejecutivo
          StreamBuilder<QuerySnapshot>(
            stream: productosRef().snapshots(),
            builder: (context, snapshot) {
              int totalStock = 0;
              double totalStockValue = 0.0;
              int criticalStock = 0;
              if (snapshot.hasData) {
                final docs = snapshot.data!.docs;
                criticalStock = docs.where((d) => parseInt(d['stock']) < 10).length;
                for (var d in docs) {
                  final stock = parseInt(d['stock']);
                  final price = parseDouble(d['precio']);
                  totalStock += stock;
                  totalStockValue += stock * price;
                }
              }
              return Row(
                children: [
                  _buildSummaryWidget(title: 'Unidades', value: totalStock.toString(), icon: Icons.inventory_2, color: secondaryColor),
                  const SizedBox(width: 8),
                  _buildSummaryWidget(title: 'Crítico', value: criticalStock.toString(), icon: Icons.warning_amber_rounded, color: stockLowColor),
                  const SizedBox(width: 8),
                  _buildSummaryWidget(title: 'Valor', value: '\$${totalStockValue.toStringAsFixed(0)}', icon: Icons.attach_money, color: stockOkColor),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Buscador
          TextField(
            controller: buscarProductoCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Lista de productos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productosRef().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((d) {
                  final nombre = (d['nombre'] ?? '').toString().toLowerCase();
                  return nombre.contains(buscarProductoCtrl.text.toLowerCase());
                }).toList();
                if (docs.isEmpty) {
                  return Center(child: Text('No hay productos', style: GoogleFonts.poppins(color: Colors.grey[600])));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;
                    return _buildProductCard(d, data, _editarProducto, _eliminarProducto, parseInt, parseDouble);
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
  
  Widget _buildClientesTab() {
  return AnimatedBackground(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          TextField(
            controller: buscarClienteCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              prefixIcon: const Icon(Icons.search, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.20),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: clientesRef().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((d) {
                  final nombre = (d['nombre'] ?? '').toString().toLowerCase();
                  return nombre.contains(buscarClienteCtrl.text.toLowerCase());
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No hay clientes', style: GoogleFonts.poppins(color: Colors.grey[600])),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;

                    // Función envoltorio para editar
                    void onEdit(String id, Map<String, dynamic> data) {
                        _editarCliente(id, data);
                    }

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.person_outline, color: primaryColor, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['nombre'] ?? 'Sin nombre',
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['direccion'] ?? 'Sin dirección',
                                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Garrafones RN: ${data['garrafonesRN'] ?? 0}",
                                    style: GoogleFonts.poppins(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              color: primaryColor,
                              onPressed: () => onEdit(d.id, data),
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
    ),
  );
}



Widget _buildMovimientosTab() {
  return Stack(
    children: [
      Positioned.fill(
        child: AnimatedBackground(child: const SizedBox()),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Text(
              '📝 Registrar Venta/Movimiento (Admin)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),

            Card(
              elevation: 2,
              color: Colors.white.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: clientesRef().snapshots(),
                      builder: (context, snapC) {
                        if (!snapC.hasData) return const SizedBox();
                        final clientes = snapC.data!.docs;
                        final items = clientes.map((c) => (c['nombre'] ?? '').toString()).toList();

                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                          isExpanded: true,
                          hint: const Text('Seleccionar cliente'),
                          value: clienteSeleccionado,
                          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => clienteSeleccionado = v),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    StreamBuilder<QuerySnapshot>(
                      stream: productosRef().snapshots(),
                      builder: (context, snapP) {
                        if (!snapP.hasData) return const SizedBox();
                        final productos = snapP.data!.docs;
                        final items = productos.map((p) => (p['nombre'] ?? '').toString()).toList();

                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Producto', border: OutlineInputBorder()),
                          isExpanded: true,
                          hint: const Text('Seleccionar producto'),
                          value: productoSeleccionado,
                          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => productoSeleccionado = v),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: movCantidadCtrl, decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: movPrecioCtrl, decoration: const InputDecoration(labelText: 'Precio (opc)', prefixText: '\$', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                      ],
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Método de Pago', border: OutlineInputBorder()),
                      value: movMetodoPago,
                      items: const [
                        DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                        DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                      ],
                      onChanged: (v) => setState(() => movMetodoPago = v ?? 'Efectivo'),
                    ),

                    const SizedBox(height: 10),

                    Row(children: [
                      Text('Origen:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Ventanilla'),
                        selected: movOrigen == 'ventanilla',
                        selectedColor: primaryColor.withOpacity(0.12),
                        onSelected: (_) => setState(() => movOrigen = 'ventanilla'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Repartidor'),
                        selected: movOrigen == 'repartidor',
                        selectedColor: primaryColor.withOpacity(0.12),
                        onSelected: (_) => setState(() => movOrigen = 'repartidor'),
                      ),
                    ]),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined, color: Colors.transparent),
                        label: Text('Registrar Movimiento', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _registrarMovimientoDesdeAdmin,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            
            // --- BOTÓN NUEVO: VER HISTORIAL DE CORTES ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.assessment_outlined, color: Colors.white),
                label: Text('Ver Historial de Cortes (Reportes)', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: reportColor, // Color Verde
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminCortesScreen(empresaCodigo: widget.empresaCodigo),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delivery_dining),
                    label: Text('Ver Repartidor', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: primaryColor,
                      backgroundColor: primaryColor.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MovimientosRepartidorPage(empresaCodigo: widget.empresaCodigo)));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.store),
                    label: Text('Ver Ventanilla', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: secondaryColor,
                      backgroundColor: secondaryColor.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MovimientosVentanillaPage(empresaCodigo: widget.empresaCodigo)));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
}


// ============================================================================
// CLASE PARA VER EL HISTORIAL DE CORTES (PANTALLA NUEVA)
// ============================================================================

class AdminCortesScreen extends StatelessWidget {
  final String empresaCodigo;

  const AdminCortesScreen({super.key, required this.empresaCodigo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Mismo fondo claro
      appBar: AppBar(
        title: Text("Historial de Cortes", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaCodigo)
            .collection('cortes_diarios')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text("No hay cortes registrados", style: GoogleFonts.poppins(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String fecha = data['fecha_string'] ?? "Fecha desconocida";
              double total = (data['total_dinero'] ?? 0).toDouble();
              int garrafones = (data['total_garrafones'] ?? 0).toInt();
              List<dynamic> detalles = data['detalles'] ?? [];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
                  ),
                  title: Text(
                    "Corte: $fecha",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Total: \$$total | Garrafones: $garrafones",
                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                      ),
                      child: Column(
                        children: [
                          // Encabezados tabla
                          Row(
                            children: [
                              Expanded(flex: 2, child: _headerText("Cliente")),
                              Expanded(flex: 2, child: _headerText("Prod.")),
                              Expanded(child: _headerText("Cant.")),
                              Expanded(child: _headerText("Total")),
                            ],
                          ),
                          const Divider(),
                          // Detalles
                          if (detalles.isEmpty) 
                            Padding(padding: const EdgeInsets.all(8), child: Text("Sin detalles", style: GoogleFonts.poppins(fontSize: 12))),
                            
                          ...detalles.map((d) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: _bodyText(d['cliente'] ?? '-')),
                                  Expanded(flex: 2, child: _bodyText(d['producto'] ?? '-')),
                                  Expanded(child: _bodyText("${d['cantidad'] ?? 0}")),
                                  Expanded(child: _bodyText("\$${d['precio'] ?? 0}")),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "TOTAL CIERRE: \$$total",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold, 
                                      color: const Color(0xFF2E7D32),
                                      fontSize: 16
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600]));
  }

  Widget _bodyText(String text) {
    return Text(text, style: GoogleFonts.poppins(fontSize: 12));
  }
}