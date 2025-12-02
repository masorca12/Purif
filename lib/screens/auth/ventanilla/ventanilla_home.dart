import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VentanillaHome extends StatefulWidget {
  final String empresaCodigo;
  
  const VentanillaHome({Key? key, required this.empresaCodigo}) : super(key: key);

  @override
  _VentanillaHomeState createState() => _VentanillaHomeState();
}

class _VentanillaHomeState extends State<VentanillaHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Variables de lógica
  String _searchQuery = "";
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Variables para Modales
  String? selectedClienteNombre;
  String? selectedClienteId;
  String? selectedProductoNombre;
  String? selectedProductoId;
  double precio = 0;
  double total = 0;

  // Colores del diseño (Verde a Azul)
  final Color _greenPrimary = const Color(0xFF66BB6A); 
  final Color _blueGradientEnd = const Color(0xFF42A5F5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

// ------------------------------------------------------------------------
  //FUNCIÓN: REALIZAR CORTE DEL DÍA (Guardar como Histórico)
  // ------------------------------------------------------------------------
  Future<void> _realizarCorteDeCaja() async {
  try {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // 1. Definir rango de fechas
    DateTime now = DateTime.now();
    // Inicio del día (00:00:00)
    DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    // Fin del día (23:59:59)
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    print("--- INICIANDO CORTE ---");
    print("Buscando entre: $startOfDay y $endOfDay");
    print("Empresa: ${widget.empresaCodigo}");

    // 2. Consulta a Firebase
    var query = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaCodigo)
        .collection('movimientos')
        .where('ventanilla', isEqualTo: true) // Solo ventanilla
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));

    var snapshot = await query.get();

    // Cerrar el indicador de carga
    Navigator.pop(context); 

    print("Documentos encontrados: ${snapshot.docs.length}");

    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ No hay ventas registradas HOY en ventanilla."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Calcular Totales
    double totalDinero = 0.0;
    int totalGarrafones = 0;
    List<Map<String, dynamic>> detallesVenta = [];

    for (var doc in snapshot.docs) {
      var data = doc.data();
      print("Procesando doc: ${doc.id} - Salida: ${data['salida']}");

      // Solo sumamos si es Salida (Venta)
      if (data['salida'] == true) {
        // Convertir a numero seguro (a veces viene como String o int)
        double precioVenta = double.tryParse(data['precio'].toString()) ?? 0.0;
        int cantidad = int.tryParse(data['cantidad'].toString()) ?? 0;
        

        totalDinero += precioVenta; 
        totalGarrafones += cantidad;

        detallesVenta.add({
          "cliente": data['cliente'] ?? "Público",
          "producto": data['producto'] ?? "Producto",
          "cantidad": cantidad,
          "precio": precioVenta,
          "pago": data['pago'] ?? "Efectivo",
          // Formatear hora
          "hora": (data['fecha'] as Timestamp).toDate().toString().substring(11, 16),
        });
      }
    }

    // 4. Confirmación
    bool confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Corte"),
        content: Text(
          "Fecha: ${now.day}/${now.month}/${now.year}\n"
          "---------------------------\n"
          "Ventas: $totalGarrafones productos\n"
          "Total Caja: \$${totalDinero.toStringAsFixed(2)}\n"
          "---------------------------\n"
          "¿Cerrar el día?"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirmar")),
        ],
      ),
    ) ?? false;

    if (!confirmar) return;

    // 5. Guardar
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaCodigo)
        .collection('cortes_diarios')
        .add({
      "fecha": Timestamp.now(),
      "fecha_string": "${now.day}/${now.month}/${now.year}",
      "responsable": FirebaseAuth.instance.currentUser?.displayName ?? "Ventanilla",
      "total_dinero": totalDinero,
      "total_garrafones": totalGarrafones,
      "detalles": detallesVenta,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Corte guardado exitosamente"), backgroundColor: Colors.green),
    );

  } catch (e) {
 
    print("ERROR EN CORTE: $e");
    
    // MOSTRAR ERROR EN PANTALLA
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Error"),
        content: Text(e.toString()), 
        actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("OK"))],
      )
    );
  }
}
  
  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      // Extendemos el body para que el degradado cubra todo el fondo
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Quitamos la flecha de atrás por defecto
        backgroundColor: Colors.transparent, // Transparente para ver el verde
        elevation: 0,
        title: Text(
          "Panel de Ventanilla",
          style: GoogleFonts.poppins(
            fontSize: 22, 
            fontWeight: FontWeight.bold, 
            color: Colors.black87
          ),
        ),
        // --- BOTÓN CERRAR SESIÓN ---
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            tooltip: "Cerrar Sesión",
            onPressed: () async {
              await _auth.signOut();
    
              Navigator.of(context).pushReplacementNamed('/login'); 
            },
          ),

          IconButton(
            icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
            tooltip: "Corte del día",
            onPressed: _realizarCorteDeCaja,
          ),
        ],
        // --- TABS SUPERIORES ---
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.swap_horiz), text: "Movimientos"),
            Tab(icon: Icon(Icons.people), text: "Clientes"),
            Tab(icon: Icon(Icons.shopping_cart), text: "Pedidos"),
          ],
        ),
      ),

      // --- FONDO DEGRADADO Y CONTENIDO ---
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_greenPrimary, _blueGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. OBTENER NOMBRE AUTOMÁTICAMENTE (Firestore o Auth)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users') 
                    .doc(user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String nombreMostrar = "Cargando...";
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    nombreMostrar = data['nombre'] ?? user?.displayName ?? "Usuario";
                  } else {
                    nombreMostrar = user?.displayName ?? "Usuario sin nombre";
                  }

                  return _buildInfoCard(nombreMostrar);
                },
              ),

              // 2. BARRA DE BÚSQUEDA GLOBAL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Buscar...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // 3. CONTENIDO DE LAS PESTAÑAS
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMovimientosTab(),
                    _buildClientesTab(),
                    _buildPedidosTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      
      // BOTÓN FLOTANTE
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddMovimientoModal(context);
          } else if (_tabController.index == 2) {
            _showAddPedidoModal(context);
          }
        },
      ),
    );
  }

  // ------------------------------------------------------------------------
  // TARJETA DE INFORMACIÓN (Header estilo imagen)
  // ------------------------------------------------------------------------
  Widget _buildInfoCard(String nombreUsuario) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Azul muy claro
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.empresaCodigo, // Nombre empresa (variable original)
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Ventanilla: $nombreUsuario",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // 1. TAB MOVIMIENTOS
  // ------------------------------------------------------------------------
  Widget _buildMovimientosTab() {
    return StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaCodigo)
      .collection('movimientos')
      .where('ventanilla', isEqualTo: true)
      .orderBy('fecha', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    
    // 1. SI HAY ERROR, MOSTRARLO EN PANTALLA
    if (snapshot.hasError) {
      print("ERROR FIRESTORE: ${snapshot.error}"); // Míralo en la consola
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            "Error: ${snapshot.error}", 
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    var docs = snapshot.data!.docs;
    
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          "No hay movimientos de ventanilla registrados.",
          style: TextStyle(color: Colors.white, fontSize: 16),
        )
      );
    }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            // ... (resto de tu código de tarjetas igual)
            bool esSalida = data['salida'] == true;
            String tipo = esSalida ? "Salida" : "Entrada";

            return Card(
              // ... tu diseño de tarjeta ...
              child: ListTile(
                // ...
                title: Text("$tipo – ${data['producto']}"),
                subtitle: Text("Registrado en Ventanilla"), // Feedback visual
              ),
            );
          },
        );
      },
    );
  }
  // ------------------------------------------------------------------------
  // 2. TAB CLIENTES (Con filtro del Buscador Global)
  // ------------------------------------------------------------------------
  Widget _buildClientesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaCodigo)
          .collection('Clientes') // Ojo mayúsculas/minúsculas en tu DB
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

        var docs = snapshot.data!.docs;
        
        // Filtramos usando la variable global _searchQuery
        var filteredDocs = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String nombre = data['nombre'].toString().toLowerCase();
          return nombre.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(child: Text("No se encontraron clientes", style: GoogleFonts.poppins(color: Colors.white)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, i) {
            var data = filteredDocs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.blueAccent),
                ),
                title: Text(data['nombre'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                subtitle: Text(data['direccion'] ?? "Sin dirección", style: GoogleFonts.poppins(fontSize: 12)),
                trailing: Text("${data['garrafonesRN'] ?? 0} Garrafones", 
                  style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // 3. TAB PEDIDOS
  // ------------------------------------------------------------------------
  Widget _buildPedidosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaCodigo)
          .collection('pedidos')
          .orderBy("fecha", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No hay pedidos", style: TextStyle(color: Colors.white)));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            var data = docs[i].data() as Map<String, dynamic>;
            var id = docs[i].id;

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text("${data['producto']} - \$${data['total']}", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text("Cliente: ${data['cliente']}", style: GoogleFonts.poppins(fontSize: 12)),
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

  // ------------------------------------------------------------------------
  // MODAL AGREGAR MOVIMIENTO
  // ------------------------------------------------------------------------
void _showAddMovimientoModal(BuildContext context) {
    // Variables iniciales
    String tipo = "Salida"; 
    String? productoId;
    String productoNombre = "";
    int cantidad = 1;
    
    // Variables para la venta
    String clienteNombre = ""; // Aquí guardaremos el nombre final
    String pago = "Efectivo"; 
    double precio = 0.0;

    

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            "Registrar Movimiento", 
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setStateModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. TIPO DE MOVIMIENTO
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: _inputStyle().copyWith(labelText: "Tipo"),
                      items: const [
                        DropdownMenuItem(value: "Salida", child: Text("Salida (Venta)")),
                        DropdownMenuItem(value: "Entrada", child: Text("Entrada (Surtido)")),
                      ],
                      onChanged: (v) => setStateModal(() => tipo = v.toString()),
                    ),
                    const SizedBox(height: 10),

                    // 2. PRODUCTO
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("empresas")
                          .doc(widget.empresaCodigo)
                          .collection("productos")
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        var docs = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: productoId,
                          decoration: _inputStyle().copyWith(labelText: "Producto"),
                          hint: const Text("Selecciona Producto"),
                          items: docs.map((d) {
                            var info = d.data() as Map<String, dynamic>;
                            return DropdownMenuItem(value: d.id, child: Text(info['nombre']));
                          }).toList(),
                          onChanged: (v) {
                            setStateModal(() {
                              productoId = v;
                              var data = docs.firstWhere((e) => e.id == v).data() as Map<String, dynamic>;
                              productoNombre = data['nombre'];
                              // precio = (data['precio'] ?? 0).toDouble(); // Descomentar si quieres precio automático
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 3. CANTIDAD
                    TextFormField(
                      decoration: _inputStyle().copyWith(labelText: "Cantidad"),
                      keyboardType: TextInputType.number,
                      initialValue: "1",
                      onChanged: (v) => cantidad = int.tryParse(v) ?? 1,
                    ),
                    const SizedBox(height: 10),

                    // --- CAMPOS ESPECÍFICOS DE SALIDA ---
                    if (tipo == "Salida") ...[
                      
                      // 4. PRECIO
                      TextFormField(
                        decoration: _inputStyle().copyWith(labelText: "Precio Total (\$)"),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => precio = double.tryParse(v) ?? 0.0,
                      ),
                      const SizedBox(height: 10),

                      // 5. BUSCADOR DE CLIENTES (AUTOCOMPLETE) ⭐ NUEVO
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("empresas")
                            .doc(widget.empresaCodigo)
                            .collection("Clientes") // Asegúrate que la colección se llame así en tu BD
                            .orderBy('nombre')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          
                          // Lista de documentos de clientes
                          final List<QueryDocumentSnapshot> clientesDocs = snapshot.data!.docs;

                          return Autocomplete<QueryDocumentSnapshot>(
                            // Lógica de filtrado
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') {
                                return const Iterable<QueryDocumentSnapshot>.empty();
                              }
                              return clientesDocs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final String nombre = data['nombre'].toString().toLowerCase();
                                return nombre.contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            // Cómo se ve cada opción en la lista desplegable
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 250, // Ancho de la lista desplegable
                                    color: Colors.white,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final doc = options.elementAt(index);
                                        final data = doc.data() as Map<String, dynamic>;
                                        return ListTile(
                                          title: Text(data['nombre']),
                                          onTap: () => onSelected(doc),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            // Qué pasa cuando seleccionas uno
                            onSelected: (QueryDocumentSnapshot selection) {
                              final data = selection.data() as Map<String, dynamic>;
                              clienteNombre = data['nombre'];
                              // Si quisieras guardar el ID del cliente también:
                              // clienteId = selection.id; 
                            },
                            // El campo de texto visual
                            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                onEditingComplete: onEditingComplete,
                                decoration: _inputStyle().copyWith(
                                  labelText: "Buscar Cliente",
                                  suffixIcon: const Icon(Icons.search, color: Colors.grey),
                                ),
                                onChanged: (value) {
                                  // Esto permite guardar nombres nuevos que NO estén en la lista
                                  clienteNombre = value;
                                },
                              );
                            },
                            // Qué texto se pone en el input al seleccionar
                            displayStringForOption: (QueryDocumentSnapshot option) {
                              final data = option.data() as Map<String, dynamic>;
                              return data['nombre'];
                            },
                          );
                        },
                      ),
                      
                      const SizedBox(height: 10),

                      // 6. MÉTODO DE PAGO
                      DropdownButtonFormField<String>(
                        value: pago,
                        decoration: _inputStyle().copyWith(labelText: "Método de Pago"),
                        items: const [
                          DropdownMenuItem(value: "Efectivo", child: Text("Efectivo")),
                          DropdownMenuItem(value: "Tarjeta", child: Text("Tarjeta")),
                          DropdownMenuItem(value: "Transferencia", child: Text("Transferencia")),
                          DropdownMenuItem(value: "Credito", child: Text("Crédito")),
                        ],
                        onChanged: (v) => setStateModal(() => pago = v.toString()),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancelar")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
              onPressed: () async {
                 if (productoId == null) return;
                 final User? user = _auth.currentUser;

                 await FirebaseFirestore.instance
                    .collection("empresas")
                    .doc(widget.empresaCodigo)
                    .collection("movimientos")
                    .add({
                  // CAMPOS BÁSICOS
                  "cantidad": cantidad,
                  "fecha": Timestamp.now(),
                  "producto": productoNombre,
                  "productoId": productoId,
                  
                  // LOGICA DE NEGOCIO
                  "entrada": tipo == "Entrada",
                  "salida": tipo == "Salida",
                  "usuarioId": user?.uid,
                  
                  // ESTRUCTURA SOLICITADA
                  "cliente": clienteNombre.isEmpty ? "Publico General" : clienteNombre, // Usamos la variable del buscador
                  "origen": "ventanilla",
                  "pago": pago,
                  "precio": precio,
                  "repartidor": false,
                  "ventanilla": true,
                });
                Navigator.pop(context);
              },
              child: const Text("Guardar", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
  // ------------------------------------------------------------------------
  // MODAL AGREGAR PEDIDO
  // ------------------------------------------------------------------------
  void _showAddPedidoModal(BuildContext context) {
    selectedClienteId = null;
    selectedProductoId = null;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Agregar Pedido", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CLIENTES
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(widget.empresaCodigo)
                        .collection('Clientes') // Verifica si es 'Clientes' o 'clientes'
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      var docs = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: selectedClienteId,
                        decoration: _inputStyle(),
                        hint: const Text("Seleccionar cliente"),
                        items: docs.map((d) {
                          var info = d.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: d.id, child: Text(info['nombre']));
                        }).toList(),
                        onChanged: (v) {
                          setStateModal(() {
                            selectedClienteId = v;
                            selectedClienteNombre = docs.firstWhere((e) => e.id == v).get("nombre");
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // PRODUCTOS
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(widget.empresaCodigo)
                        .collection('productos')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      var docs = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: selectedProductoId,
                        decoration: _inputStyle(),
                        hint: const Text("Seleccionar producto"),
                        items: docs.map((d) {
                          var info = d.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: d.id, child: Text(info['nombre']));
                        }).toList(),
                        onChanged: (v) {
                          setStateModal(() {
                            selectedProductoId = v;
                            var data = docs.firstWhere((e) => e.id == v).data() as Map<String, dynamic>;
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
                    key: Key(total.toString()), // Hack para refrescar
                    initialValue: total.toString(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: _savePedido,
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

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

  void _showEditPedidoModal(String pedidoId, Map<String, dynamic> pedido) {
    double newTotal = pedido["total"]?.toDouble() ?? 0.0;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Editar Pedido"),
          content: TextFormField(
            initialValue: newTotal.toString(),
            keyboardType: TextInputType.number,
            decoration: _inputStyle(),
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



  // Estilo Inputs Modal
  InputDecoration _inputStyle() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}