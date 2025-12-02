import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_background.dart';

class RepartidorHome extends StatefulWidget {
  final String empresaCodigo;
  const RepartidorHome({super.key, required this.empresaCodigo});

  @override
  _RepartidorHomeState createState() => _RepartidorHomeState();
}

class _RepartidorHomeState extends State<RepartidorHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Variable para el buscador
  String _searchQuery = "";

  // Campos del modal de pedidos
  String? selectedClienteNombre;
  String? selectedClienteId;
  String? selectedProductoNombre;
  String? selectedProductoId;
  double precio = 0;
  double total = 0;
  double stockActual = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0, // Quitamos elevación para que se vea más limpio como en la imagen 1
          title: Text(
            "Panel de Repartidor",
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.blueAccent,
            tabs: const [
              Tab(icon: Icon(Icons.swap_horiz), text: "Movimientos"),
              Tab(icon: Icon(Icons.people), text: "Clientes"),
              Tab(icon: Icon(Icons.shopping_cart), text: "Pedidos"),
            ],
          ),
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blueAccent,
          child: const Icon(Icons.add),
          onPressed: () {
            if (_tabController.index == 0) {
              _showAddMovimientoModal(context);
            } else if (_tabController.index == 2) {
              _showAddPedidoModal(context);
            }
            // Nota: Si quieres agregar clientes, añade la condición para index == 1
          },
        ),

        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMovimientosTab(),
            _buildClientesTab(), // ESTA ES LA QUE MODIFICAMOS
            _buildPedidosTab(),
          ],
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  ///
  ///                           🔵 1. MOVIMIENTOS
  ///
  //////////////////////////////////////////////////////////////////////////////

 Widget _buildMovimientosTab() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos')
      .orderBy('fecha', descending: true)
      .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      var docs = snapshot.data!.docs;

      if (docs.isEmpty) {
        return const Center(child: Text("No hay movimientos aún"));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          var data = docs[index].data() as Map<String, dynamic>;

          bool esSalida = data['salida'] == true;
          bool esEntrada = data['entrada'] == true;

          String tipo = esSalida ? "Salida" : "Entrada";

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                "$tipo – ${data['producto']}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: esSalida ? Colors.redAccent : Colors.green,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cantidad: ${data['cantidad']}"),
                  Text("Fecha: ${data['fecha'].toDate()}"),
                  if (esEntrada && data['salidaRef'] != null)
                    Text("Relacionado con salida: ${data['salidaRef']}"),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


  //////////////////////////////////////////////////////////////////////////////
  ///
  ///                           🔵 2. CLIENTES (DISEÑO TIPO IMAGEN 1)
  ///
  //////////////////////////////////////////////////////////////////////////////

  Widget _buildClientesTab() {
    return Column(
      children: [
        // --- BARRA DE BÚSQUEDA (Como en la Imagen 1) ---
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), // Fondo semitransparente
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.3))
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: GoogleFonts.poppins(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Buscar cliente...",
                hintStyle: GoogleFonts.poppins(color: Colors.black54),
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // --- LISTA DE CLIENTES ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas')
                .doc(widget.empresaCodigo)
                .collection('Clientes') // Verifica si es 'Clientes' o 'clientes' en tu DB
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var docs = snapshot.data!.docs;
              
              // Filtrado local por buscador
              var filteredDocs = docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String nombre = data['nombre'].toString().toLowerCase();
                return nombre.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Text("No se encontraron clientes", 
                    style: GoogleFonts.poppins(color: Colors.black54))
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredDocs.length,
                itemBuilder: (context, i) {
                  var data = filteredDocs[i].data() as Map<String, dynamic>;
                  // Datos simulados para igualar la imagen 1 si no existen en tu DB
                  int garrafonesRN = data['garrafonesRN'] ?? 0; 

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15), // Bordes redondeados como la imagen 1
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          // 1. EL ÍCONO CUADRADO AZUL (Avatar)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FE), // Azul muy clarito (fondo del icono)
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),

                          // 2. TEXTOS (Nombre, Dirección, Garrafones)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['nombre'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data['direccion'] ?? "Sin dirección",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Garrafones RN: $garrafonesRN", // Texto azul extra
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
//////////////////////////////////////////////////////////////////////////////
  ///
  ///                          🔵 3. PEDIDOS (AGREGAR/EDITAR)
  ///
  //////////////////////////////////////////////////////////////////////////////

  Widget _buildPedidosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaCodigo)
          .collection('pedidos')
          .orderBy("fecha", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No hay pedidos registrados"));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            var data = docs[i].data() as Map<String, dynamic>;
            var id = docs[i].id;

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text("${data['producto']} - \$${data['total']}",
                    style: GoogleFonts.poppins(fontSize: 16)),
                subtitle: Text("Cliente: ${data['cliente']}",
                    style: GoogleFonts.poppins()),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () => _showEditPedidoModal(id, data),
                ),
              ),
            );
          },
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  ///
  ///                     ⭐ MODAL: AGREGAR MOVIMIENTO
  ///
  //////////////////////////////////////////////////////////////////////////////

  void _showAddMovimientoModal(BuildContext context) {
    String tipo = "Entrada";
    String? productoId;
    String productoNombre = "";
    int cantidad = 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("Registrar Movimiento"),
          content: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField(
                    value: tipo,
                    decoration: _inputStyle(),
                    items: const [
                      DropdownMenuItem(value: "Entrada", child: Text("Entrada")),
                      DropdownMenuItem(value: "Salida", child: Text("Salida")),
                    ],
                    onChanged: (v) => setStateModal(() => tipo = v!),
                  ),
                  const SizedBox(height: 10),

                  /// PRODUCTOS
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("empresas")
                        .doc(widget.empresaCodigo)
                        .collection("productos")
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      var docs = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: productoId,
                        decoration: _inputStyle(),
                        items: docs.map((d) {
                          var info = d.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text(info['nombre']),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setStateModal(() {
                            productoId = v;
                            productoNombre = docs
                                .firstWhere((e) => e.id == v)
                                .get("nombre");
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    decoration: _inputStyle().copyWith(labelText: "Cantidad"),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => cantidad = int.tryParse(v) ?? 1,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("empresas")
                    .doc(widget.empresaCodigo)
                    .collection("movimientos")
                    .add({
                  "tipo": tipo,
                  "producto": productoNombre,
                  "productoId": productoId,
                  "cantidad": cantidad,
                  "fecha": Timestamp.now(),
                });

                Navigator.pop(context);
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  ///
  ///                     ⭐ MODAL: AGREGAR PEDIDO (ANTES VENTA)
  ///
  //////////////////////////////////////////////////////////////////////////////

  void _showAddPedidoModal(BuildContext context) {
    selectedClienteId = null;
    selectedProductoId = null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Agregar Pedido"),
          content: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// CLIENTES
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(widget.empresaCodigo)
                        .collection('clientes')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      var docs = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedClienteId,
                        decoration: _inputStyle(),
                        hint: const Text("Seleccionar cliente"),
                        items: docs.map((d) {
                          var info = d.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text(info['nombre']),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setStateModal(() {
                            selectedClienteId = v;
                            selectedClienteNombre =
                                docs.firstWhere((e) => e.id == v).get("nombre");
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  /// PRODUCTOS
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(widget.empresaCodigo)
                        .collection('productos')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      var docs = snapshot.data!.docs;

                      return DropdownButtonFormField<String>(
                        value: selectedProductoId,
                        decoration: _inputStyle(),
                        hint: const Text("Seleccionar producto"),
                        items: docs.map((d) {
                          var info = d.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text(info['nombre']),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setStateModal(() {
                            selectedProductoId = v;
                            var data = docs.firstWhere((e) => e.id == v).data()
                                as Map<String, dynamic>;

                            selectedProductoNombre = data['nombre'];
                            precio = (data['precio'] ?? 0).toDouble();
                            total = precio;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  TextFormField(
                    readOnly: true,
                    decoration: _inputStyle().copyWith(labelText: "Total"),
                    initialValue: total.toString(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text("Guardar"),
              onPressed: _savePedido,
            ),
          ],
        );
      },
    );
  }

  /// GUARDAR PEDIDO
  Future<void> _savePedido() async {
    if (selectedClienteId == null || selectedProductoId == null) return;

    await FirebaseFirestore.instance
        .collection("empresas")
        .doc(widget.empresaCodigo)
        .collection("pedidos")
        .add({
      "cliente": selectedClienteNombre,
      "clienteId": selectedClienteId,
      "producto": selectedProductoNombre,
      "productoId": selectedProductoId,
      "total": total,
      "fecha": Timestamp.now(),
    });

    Navigator.pop(context);
  }

  //Al guardar un movimiento (SALIDA)
  Future<void> registrarSalida(String producto, String productoId, int cantidad) async {
  await FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos')
      .add({
    "producto": producto,
    "productoId": productoId,
    "cantidad": cantidad,
    "salida": true,
    "entrada": false,
    "salidaRef": null,
    "fecha": Timestamp.now(),
  });
}
//Al guardar una ENTRADA vinculada a una salida
Future<void> registrarEntrada(String producto, String productoId, int cantidad, String salidaId) async {
  await FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos')
      .add({
    "producto": producto,
    "productoId": productoId,
    "cantidad": cantidad,
    "salida": false,
    "entrada": true,
    "salidaRef": salidaId,   // 🔗 Relación directa
    "fecha": Timestamp.now(),
  });
}

  //////////////////////////////////////////////////////////////////////////////
  ///
  ///                  ⭐ EDITAR PEDIDO (MODAL)
  ///
  //////////////////////////////////////////////////////////////////////////////

  void _showEditPedidoModal(String pedidoId, Map<String, dynamic> pedido) {
    double newTotal = pedido["total"].toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text("Editar Pedido"),
          content: TextFormField(
            initialValue: newTotal.toString(),
            decoration: _inputStyle(),
            keyboardType: TextInputType.number,
            onChanged: (v) => newTotal = double.tryParse(v) ?? newTotal,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection("empresas")
                    .doc(widget.empresaCodigo)
                    .collection("pedidos")
                    .doc(pedidoId)
                    .update({"total": newTotal});

                Navigator.pop(context);
              },
              child: const Text("Guardar"),
            )
          ],
        );
      },
    );
  }

  /// ESTILO INPUT
  InputDecoration _inputStyle() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class MovimientosWidget extends StatelessWidget {
  final String empresaCodigo;

  const MovimientosWidget({super.key, required this.empresaCodigo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection("empresas")
          .doc(empresaCodigo)
          .collection("movimientos")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar movimientos"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No hay movimientos aún"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            String producto = data["producto"] ?? "Sin nombre";
            bool salida = data["salida"] ?? false;
            bool entrada = data["entrada"] ?? false;
            int cantidad = data["cantidad"] ?? 0;
            String? ref = data["refSalida"];
            DateTime fecha = (data["createdAt"] as Timestamp).toDate();

            // lógica salida or entrada
            String tipo = salida ? "Salida" : "Entrada";

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              child: ListTile(
                title: Text(
                  "$tipo: $producto",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cantidad: $cantidad"),
                    Text("Fecha: $fecha"),
                    if (entrada && ref != null)
                      Text(
                        "Entrada ligada a salida: $ref",
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

