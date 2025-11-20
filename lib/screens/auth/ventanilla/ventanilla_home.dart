import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VentanillaHome extends StatefulWidget {
  final String empresaCodigo;

  const VentanillaHome({Key? key, required this.empresaCodigo}) : super(key: key);

  @override
  State<VentanillaHome> createState() => _VentanillaHomeState();
}

class _VentanillaHomeState extends State<VentanillaHome> {
  int _selectedIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    final String nombreUsuario = user?.displayName ?? "Usuario sin nombre";

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FF), // azul muy claro
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0), // azul principal
        elevation: 4,
        centerTitle: true,
        title: const Text(
          "Panel de Ventanilla",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),

      // Contenido principal con banner superior
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  "Repartidor: $nombreUsuario",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Empresa: ${widget.empresaCodigo}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Expanded(child: _buildSelectedTab()),
        ],
      ),

      // FAB dinámico
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1976D2),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          if (_selectedIndex == 0) {
            _agregarMovimiento();
          } else if (_selectedIndex == 1) {
            _agregarPedido();
          } else if (_selectedIndex == 2) {
            _agregarVenta();
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Movimientos'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Ventas'),
        ],
      ),
    );
  }

  // ---------- Pestañas ----------
  Widget _buildSelectedTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildMovimientosTab();
      case 1:
        return _buildPedidosTab();
      case 2:
        return _buildVentasTab();
      default:
        return const Center(child: Text("Pestaña desconocida"));
    }
  }

  // ---------- Ejemplo de pestañas ----------
  Widget _buildMovimientosTab() {
    return _buildFirestoreList(
      collection: 'movimientos',
      icon: Icons.swap_horiz,
      title: 'Movimiento',
    );
  }

  Widget _buildPedidosTab() {
    return _buildFirestoreList(
      collection: 'pedidos',
      icon: Icons.local_shipping,
      title: 'Pedido',
    );
  }

  Widget _buildVentasTab() {
    return _buildFirestoreList(
      collection: 'ventas',
      icon: Icons.point_of_sale,
      title: 'Venta',
    );
  }

  Widget _buildFirestoreList({
    required String collection,
    required IconData icon,
    required String title,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('empresa', isEqualTo: widget.empresaCodigo)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar datos'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Sin registros disponibles"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFBBDEFB),
                  child: Icon(icon, color: const Color(0xFF1565C0)),
                ),
                title: Text(
                  "$title: ${data['nombre'] ?? 'Sin nombre'}",
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Fecha: ${data['fecha'] ?? 'Desconocida'}",
                  style: const TextStyle(fontFamily: 'Poppins'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  // ---------- Métodos de acciones ----------
  void _agregarMovimiento() {
    _mostrarDialogo("Agregar Movimiento");
  }

  void _agregarPedido() {
    _mostrarDialogo("Agregar Pedido");
  }

  void _agregarVenta() {
    _mostrarDialogo("Agregar Venta");
  }

  void _mostrarDialogo(String titulo) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          content: const Text(
            "Aquí puedes implementar el formulario correspondiente.",
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              child: const Text("Cerrar", style: TextStyle(color: Colors.redAccent)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}
