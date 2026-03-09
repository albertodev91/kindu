import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../screens/finance_tab.dart';

class ExcelService {
  static final ExcelService _instancia = ExcelService._internal();
  factory ExcelService() => _instancia;
  ExcelService._internal();

  /// Genera un archivo CSV compatible con Excel y abre el menú de compartir
  Future<void> exportarExcel(BuildContext context, List<Gasto> gastos) async {
    // Mostramos diálogo de carga para dar feedback visual
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Generando Excel...")])),
    );

    try {
      // 1. Definir las columnas del Excel
      List<String> cabeceras = [
        'Fecha',
        'Concepto',
        'Categoría',
        'Total Ticket (€)',
        'Mi Parte (€)',
        'Pagado / Abonado (€)',
        'Estado',
        'Creador',
        'Niños Asignados'
      ];

      // 2. Construir las filas de datos
      List<List<String>> filas = [];
      filas.add(cabeceras);

      // Variables para calcular los totales finales
      double sumaTotal = 0.0;
      double sumaMiParte = 0.0;
      double sumaPagado = 0.0;

      for (var g in gastos) {
        sumaTotal += g.total;
        sumaMiParte += g.miParte;
        sumaPagado += g.cantidadPagada;

        String estado = 'Pendiente';
        if (g.enDisputa) {
          estado = 'En Disputa';
        } else if (g.estaPagado) {
          estado = 'Liquidado';
        } else if (g.pagoPendienteValidacion > 0) {
          estado = 'Esperando Validación';
        }

        filas.add([
          '${g.fecha.day.toString().padLeft(2,'0')}/${g.fecha.month.toString().padLeft(2,'0')}/${g.fecha.year}',
          g.titulo,
          g.categoria,
          g.total.toStringAsFixed(2).replaceAll('.', ','), // Formato ES (coma decimal)
          g.miParte.toStringAsFixed(2).replaceAll('.', ','),
          g.cantidadPagada.toStringAsFixed(2).replaceAll('.', ','),
          estado,
          g.creador,
          g.ninosAsignados.join(', ')
        ]);
      }

      // Añadimos una fila vacía de separación
      filas.add(['', '', '', '', '', '', '', '', '']);

      // Añadimos la FILA DE TOTALES al final
      filas.add([
        'TOTALES', // En la columna Fecha
        '',
        '',
        sumaTotal.toStringAsFixed(2).replaceAll('.', ','),      // Suma Total Ticket
        sumaMiParte.toStringAsFixed(2).replaceAll('.', ','),    // Suma Mi Parte
        sumaPagado.toStringAsFixed(2).replaceAll('.', ','),     // Suma Pagado
        '',
        '',
        ''
      ]);

      // 3. Generar el contenido CSV (usando ; como separador para Excel español)
      String csvData = _generarCsvString(filas);

      // 4. Codificar a Bytes con BOM (Byte Order Mark) para UTF-8
      // Esto es CRUCIAL para que Excel muestre bien las tildes, ñ y el símbolo €
      List<int> bom = [0xEF, 0xBB, 0xBF];
      List<int> bytes = bom + utf8.encode(csvData);

      final ahora = DateTime.now();
      final filename = 'Kindu_Excel_${ahora.millisecondsSinceEpoch}.csv';

      // Cerramos el diálogo de carga antes de abrir el menú de compartir
      if (Navigator.canPop(context)) Navigator.pop(context);

      // 5. Compartir archivo (Reutilizamos Printing.sharePdf que permite compartir binarios)
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);

    } catch (e) {
      // Si falla, cerramos el diálogo y mostramos error
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar Excel: $e'), backgroundColor: Colors.red));
    }
  }

  String _generarCsvString(List<List<String>> filas) {
    StringBuffer buffer = StringBuffer();
    for (var fila in filas) {
      // Unimos las celdas con punto y coma (;) y escapamos comillas si es necesario
      buffer.writeln(fila.map((celda) => celda.contains(';') || celda.contains('\n') ? '"${celda.replaceAll('"', '""')}"' : celda).join(';'));
    }
    return buffer.toString();
  }
}