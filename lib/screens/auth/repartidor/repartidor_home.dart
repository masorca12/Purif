// repartidor_home.dart (DISEÑO MODERNO APLICADO, LÓGICA ORIGINAL MANTENIDA)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class RepartidorHome extends StatefulWidget {
  final String empresaCodigo;
  const RepartidorHome({super.key, required this.empresaCodigo});

  @override
  State<RepartidorHome> createState() => _RepartidorHomeState();
}

class _RepartidorHomeState extends State<RepartidorHome> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _buscadorController = TextEditingController();
  final TextEditingController _buscadorClienteController = TextEditingController();
  final TextEditingController _cantidadPedidoController = TextEditingController();

  String? _productoSeleccionado;
  String? _clienteSeleccionado;
  bool _isSalida = true;
  bool _pedidoPagado = false;
  String _estadoPedido = "pendiente";

  // ------------------ DISEÑO / COLORES ------------------
  static const Color primaryColor = Color(0xFF3B82F6); // azul principal
  static const Color secondaryColor = Color(0xFF60A5FA); // azul claro
  static const Color backgroundColor = Color(0xFFF5F7FA); // fondo claro
  static const Color accentStockOk = Color(0xFF2ECC71);
  static const Color accentStockLow = Colors.redAccent;

  // ------------------ UTIL / REFERENCIAS ------------------
  CollectionReference productosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('productos');

  CollectionReference clientesRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('Clientes');

  CollectionReference pedidosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('pedidos');

  CollectionReference movimientosRef() => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos');

  // ================== REGISTRAR MOVIMIENTO (ORIGINAL) ==================
  Future<void> _registrarMovimiento() async {
    if (_productoSeleccionado == null || _cantidadController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona producto y cantidad")),
      );
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text) ?? 0;

    final productoDoc = FirebaseFirestore.instance
        .collection("empresas")
        .doc(widget.empresaCodigo)
        .collection("productos")
        .doc(_productoSeleccionado);

    final productoData = await productoDoc.get();
    if (!productoData.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto no encontrado")),
      );
      return;
    }

    final currentStock = int.tryParse(productoData["stock"]?.toString() ?? "0") ?? 0;
    int nuevoStock = _isSalida ? max(0, currentStock - cantidad) : currentStock + cantidad;

    await productoDoc.update({"stock": nuevoStock});

    await FirebaseFirestore.instance
        .collection("empresas")
        .doc(widget.empresaCodigo)
        .collection("movimientos")
        .add({
      "productoId": _productoSeleccionado,
      "cantidad": cantidad,
      "fecha": FieldValue.serverTimestamp(),
      "repartidorId": user?.uid,
      "tipo": _isSalida ? "salida" : "entrada",
    });

    _cantidadController.clear();
    setState(() => _productoSeleccionado = null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Movimiento registrado")),
    );
  }

  // ================== AGREGAR PEDIDO (ORIGINAL) ==================
  Future<void> _agregarPedido() async {
    if (_clienteSeleccionado == null || _productoSeleccionado == null || _cantidadPedidoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    final cantidad = int.tryParse(_cantidadPedidoController.text) ?? 0;

    await FirebaseFirestore.instance
        .collection("empresas")
        .doc(widget.empresaCodigo)
        .collection("pedidos")
        .add({
      "cliente": _clienteSeleccionado,
      "producto": _productoSeleccionado,
      "cantidad": cantidad,
      "pagado": _pedidoPagado,
      "estado": _estadoPedido,
      "fecha": FieldValue.serverTimestamp(),
      "repartidorId": user?.uid,
    });

    _cantidadPedidoController.clear();
    setState(() {
      _clienteSeleccionado = null;
      _productoSeleccionado = null;
      _pedidoPagado = false;
      _estadoPedido = "pendiente";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pedido agregado correctamente")),
    );
  }

  // ================== EDITAR PEDIDO (ORIGINAL) ==================
  Future<void> _editarPedido(DocumentSnapshot pedido) async {
    if (pedido["repartidorId"] != user?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Solo puedes editar tus propios pedidos")),
      );
      return;
    }

    final TextEditingController cantidadCtrl = TextEditingController(text: pedido["cantidad"].toString());
    String estado = pedido["estado"] ?? "pendiente";
    bool pagado = pedido["pagado"] ?? false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("Editar pedido", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text("Cliente: ${pedido["cliente"]}", style: GoogleFonts.poppins()),
                const SizedBox(height: 8),
                Text("Producto: ${pedido["producto"]}", style: GoogleFonts.poppins()),
                const SizedBox(height: 16),
                TextField(
                  controller: cantidadCtrl,
                  decoration: InputDecoration(
                    labelText: "Cantidad",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: estado,
                  items: const [
                    DropdownMenuItem(value: "pendiente", child: Text("Pendiente")),
                    DropdownMenuItem(value: "entregado_pagado", child: Text("Entregado y pagado")),
                    DropdownMenuItem(value: "entregado_falta_pagar", child: Text("Entregado - falta pagar")),
                    DropdownMenuItem(value: "no_entregado", child: Text("No entregado / Cancelado")),
                  ],
                  onChanged: (v) => setState(() => estado = v ?? "pendiente"),
                  decoration: InputDecoration(
                    labelText: "Estado",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: pagado,
                      onChanged: (v) => setState(() => pagado = v ?? false),
                    ),
                    const SizedBox(width: 8),
                    Text("Pagado", style: GoogleFonts.poppins()),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar", style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("empresas")
                    .doc(widget.empresaCodigo)
                    .collection("pedidos")
                    .doc(pedido.id)
                    .update({
                  "cantidad": int.tryParse(cantidadCtrl.text) ?? 0,
                  "estado": estado,
                  "pagado": pagado,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text("Guardar", style: GoogleFonts.poppins(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  // ================== MODALES DE DISEÑO (PARA FABs) ==================

  // Modal para registrar movimiento (usa _registrarMovimiento)
  Future<void> _showRegisterMovementModal() async {
    _cantidadController.clear();
    _productoSeleccionado = null;
    _isSalida = true;

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
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
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
                                value: _productoSeleccionado,
                                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => _productoSeleccionado = v),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cantidadController,
                            decoration: InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[200]),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ChoiceChip(label: const Text('Salida'), selected: _isSalida, selectedColor: primaryColor.withOpacity(0.12), onSelected: (_) => setState(() => _isSalida = true)),
                              const SizedBox(width: 8),
                              ChoiceChip(label: const Text('Entrada'), selected: !_isSalida, selectedColor: primaryColor.withOpacity(0.12), onSelected: (_) => setState(() => _isSalida = false)),
                            ],
                          ),
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
                        await _registrarMovimiento();
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

  // Modal para agregar cliente (añade función simple para mantener coherencia con diseño)
  Future<void> _showAddClientModal() async {
    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController direccionCtrl = TextEditingController();
    final TextEditingController telCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 12),
                Text('➕ Agregar Cliente', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(children: [
                      TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                      const SizedBox(height: 8),
                      TextField(controller: direccionCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
                      const SizedBox(height: 8),
                      TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    onPressed: () async {
                      if (nombreCtrl.text.trim().isEmpty) return;
                      await clientesRef().add({
                        'nombre': nombreCtrl.text.trim(),
                        'direccion': direccionCtrl.text.trim(),
                        'telefono': telCtrl.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text('Guardar', style: GoogleFonts.poppins(color: Colors.white)),
                  )
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  // Modal para agregar pedido (usa _agregarPedido)
  Future<void> _showAddPedidoModal() async {
    _cantidadPedidoController.clear();
    _clienteSeleccionado = null;
    _productoSeleccionado = null;
    _pedidoPagado = false;
    _estadoPedido = "pendiente";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 12),
                Text('➕ Agregar Pedido', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: clientesRef().snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final items = snapshot.data!.docs.map((d) => (d['nombre'] ?? '').toString()).toList();
                          return DropdownButtonFormField<String>(
                            value: _clienteSeleccionado,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Cliente', border: OutlineInputBorder()),
                            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _clienteSeleccionado = v),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: productosRef().snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final items = snapshot.data!.docs.map((d) => (d['nombre'] ?? '').toString()).toList();
                          return DropdownButtonFormField<String>(
                            value: _productoSeleccionado,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Producto', border: OutlineInputBorder()),
                            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _productoSeleccionado = v),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cantidadPedidoController,
                        decoration: InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[200]),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _estadoPedido,
                        items: const [
                          DropdownMenuItem(value: "pendiente", child: Text("Pendiente")),
                          DropdownMenuItem(value: "entregado_pagado", child: Text("Entregado y pagado")),
                          DropdownMenuItem(value: "entregado_falta_pagar", child: Text("Entregado - falta pagar")),
                          DropdownMenuItem(value: "no_entregado", child: Text("No entregado / Cancelado")),
                        ],
                        onChanged: (v) => setState(() => _estadoPedido = v ?? "pendiente"),
                        decoration: InputDecoration(labelText: 'Estado', border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[200]),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Checkbox(value: _pedidoPagado, onChanged: (v) => setState(() => _pedidoPagado = v ?? false)),
                        const SizedBox(width: 8),
                        Text('Pagado', style: GoogleFonts.poppins()),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.poppins())),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    onPressed: () async {
                      await _agregarPedido();
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text('Agregar', style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ================== TABS (VISTAS ADAPTADAS CON DISEÑO) ==================

  Widget _buildMovimientosTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Text("Registrar movimiento", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                StreamBuilder<QuerySnapshot>(
                  stream: productosRef().snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final items = snapshot.data!.docs.map((d) => (d['nombre'] ?? '').toString()).toList();
                    return DropdownButtonFormField<String>(
                      value: _productoSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Selecciona producto", border: OutlineInputBorder()),
                      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _productoSeleccionado = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cantidadController,
                  decoration: InputDecoration(labelText: "Cantidad", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[200]),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ChoiceChip(label: const Text('Salida'), selected: _isSalida, selectedColor: primaryColor.withOpacity(0.12), onSelected: (_) => setState(() => _isSalida = true)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Entrada'), selected: !_isSalida, selectedColor: primaryColor.withOpacity(0.12), onSelected: (_) => setState(() => _isSalida = false)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _registrarMovimiento,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text("Registrar", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _buscadorClienteController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: primaryColor),
              hintText: "Buscar cliente...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: clientesRef().snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final clientes = snapshot.data!.docs.where((doc) {
                final nombre = (doc["nombre"] ?? "").toString().toLowerCase();
                return nombre.contains(_buscadorClienteController.text.toLowerCase());
              }).toList();

              if (clientes.isEmpty) return Center(child: Text('No hay clientes', style: GoogleFonts.poppins(color: Colors.grey[600])));

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: clientes.length,
                itemBuilder: (context, index) {
                  final cliente = clientes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: ListTile(
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, color: primaryColor)),
                      title: Text(cliente["nombre"], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text("Dirección: ${cliente["direccion"] ?? ''}", style: GoogleFonts.poppins(color: Colors.grey[600])),
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

  Widget _buildPedidosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Registrar nuevo pedido", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: clientesRef().snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final items = snapshot.data!.docs.map((d) => (d['nombre'] ?? '').toString()).toList();
                    return DropdownButtonFormField<String>(
                      value: _clienteSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Cliente", border: OutlineInputBorder()),
                      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _clienteSeleccionado = v),
                    );
                  },
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: productosRef().snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final items = snapshot.data!.docs.map((d) => (d['nombre'] ?? '').toString()).toList();
                    return DropdownButtonFormField<String>(
                      value: _productoSeleccionado,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Producto", border: OutlineInputBorder()),
                      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _productoSeleccionado = v),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cantidadPedidoController,
                  decoration: InputDecoration(labelText: "Cantidad", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[200]),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _estadoPedido,
                  items: const [
                    DropdownMenuItem(value: "pendiente", child: Text("Pendiente")),
                    DropdownMenuItem(value: "entregado_pagado", child: Text("Entregado y pagado")),
                    DropdownMenuItem(value: "entregado_falta_pagar", child: Text("Entregado - falta pagar")),
                    DropdownMenuItem(value: "no_entregado", child: Text("No entregado / Cancelado")),
                  ],
                  onChanged: (v) => setState(() => _estadoPedido = v ?? "pendiente"),
                  decoration: InputDecoration(labelText: "Estado", border: OutlineInputBorder(), filled: true, fillColor: Colors.grey[200]),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Checkbox(value: _pedidoPagado, onChanged: (v) => setState(() => _pedidoPagado = v ?? false)),
                  const SizedBox(width: 8),
                  Text("Pagado", style: GoogleFonts.poppins()),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _agregarPedido,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text("Agregar Pedido", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text("Lista de pedidos", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: pedidosRef().orderBy("fecha", descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final pedidos = snapshot.data!.docs;
              if (pedidos.isEmpty) return Center(child: Text('No hay pedidos', style: GoogleFonts.poppins(color: Colors.grey[600])));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pedidos.length,
                itemBuilder: (context, index) {
                  final pedido = pedidos[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: ListTile(
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.receipt_long, color: primaryColor)),
                      title: Text("${pedido["cliente"]} - ${pedido["producto"]}", style: GoogleFonts.poppins()),
                      subtitle: Text("Cantidad: ${pedido["cantidad"]} • Estado: ${pedido["estado"]}", style: GoogleFonts.poppins(color: Colors.grey[600])),
                      trailing: IconButton(icon: const Icon(Icons.edit, color: primaryColor), onPressed: () => _editarPedido(pedido)),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ================== CERRAR SESIÓN ==================
  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  final List<String> _tabs = ["Movimientos", "Clientes", "Pedidos"];

  // Obtener nombre del repartidor (displayName) con fallback
  String get repartidorNombre {
    final n = user?.displayName;
    if (n != null && n.trim().isNotEmpty) return n;
    // si no hay displayName, intentar con email antes de fallback
    final e = user?.email;
    if (e != null && e.contains('@')) return e.split('@')[0];
    return 'Repartidor sin nombre';
  }

  @override
  Widget build(BuildContext context) {
    final tabWidgets = [
      _buildMovimientosTab(),
      _buildClientesTab(),
      _buildPedidosTab(),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text('Panel del Repartidor', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: accentStockLow,
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Banner con nombre del repartidor
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.person_pin, color: primaryColor),
                ),
                title: Text(repartidorNombre, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                subtitle: Text('Repartidor', style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
              ),
            ),
          ),
          // tabs content
          Expanded(child: tabWidgets[_currentIndex]),
        ],
      ),
      // FAB dinámico por pestaña
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showRegisterMovementModal,
              label: Text('Registrar movimiento', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              icon: const Icon(Icons.add, color: Colors.white),
              backgroundColor: primaryColor,
            )
          : _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: _showAddClientModal,
                  label: Text('Agregar cliente', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  backgroundColor: primaryColor,
                )
              : FloatingActionButton.extended(
                  onPressed: _showAddPedidoModal,
                  label: Text('Agregar pedido', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                  backgroundColor: primaryColor,
                ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: primaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: const Icon(Icons.list),
                  label: t,
                ))
            .toList(),
        onTap: (i) {
          _buscadorController.clear();
          _buscadorClienteController.clear();
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}
