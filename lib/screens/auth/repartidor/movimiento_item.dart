import 'package:flutter/material.dart';

class MovimientoItem extends StatelessWidget {
  final String producto;
  final bool salida;
  final bool entrada;
  final int cantidad;
  final String? refSalida;
  final DateTime fecha;

  const MovimientoItem({
    super.key,
    required this.producto,
    required this.salida,
    required this.entrada,
    required this.cantidad,
    required this.fecha,
    this.refSalida,
  });

  @override
  Widget build(BuildContext context) {
    String tipo = salida ? "Salida" : entrada ? "Entrada" : "Desconocido";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          "$tipo: $producto",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Cantidad: $cantidad"),
            const SizedBox(height: 4),
            Text("Fecha: ${fecha.toLocal()}"),
            
            if (entrada && refSalida != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Entrada vinculada a salida: $refSalida",
                  style: const TextStyle(
                      fontSize: 13, fontStyle: FontStyle.italic),
                ),
              )
          ],
        ),
      ),
    );
  }
}
