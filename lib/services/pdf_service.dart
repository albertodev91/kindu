import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Importamos la clase Gasto desde tu pestaña de finanzas
import '../screens/finance_tab.dart'; 

class PdfService {
  static final PdfService _instancia = PdfService._internal();
  factory PdfService() => _instancia;
  PdfService._internal();

  /// Exporta el PDF real usando los datos avanzados de la app
  Future<void> exportarInformeLegal(BuildContext context, List<Gasto> gastos, double balanceFinal, DateTimeRange? periodo) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Generando informe paginado...")]),
      ),
    );

    try {
      final pdf = pw.Document();
      
      // INYECTAMOS UNA FUENTE MODERNA (Para que pinte bien el símbolo €)
      final fuenteNormal = await PdfGoogleFonts.robotoRegular();
      final fuenteNegrita = await PdfGoogleFonts.robotoBold();

      final ahora = DateTime.now();
      final fechaFirma = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
      final horaFirma = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

      // TEXTO DEL RANGO DE FECHAS
      String textoPeriodo = 'PERIODO: Histórico completo de movimientos';
      if (periodo != null) {
        String inicio = '${periodo.start.day.toString().padLeft(2, '0')}/${periodo.start.month.toString().padLeft(2, '0')}/${periodo.start.year}';
        String fin = '${periodo.end.day.toString().padLeft(2, '0')}/${periodo.end.month.toString().padLeft(2, '0')}/${periodo.end.year}';
        textoPeriodo = 'PERIODO DEL INFORME: $inicio al $fin';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fuenteNormal, bold: fuenteNegrita),
          
          // --- MAGIA DE PAGINACIÓN: Este pie de página se repite en cada folio nuevo ---
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Column(
                children: [
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Generado automáticamente por la plataforma Kindu.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                          pw.Text('ID de Exportación Segura: KND-${ahora.millisecondsSinceEpoch}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        ]
                      ),
                      // ¡AQUÍ ESTÁ EL CONTADOR DE PÁGINAS!
                      pw.Text(
                        'Página ${context.pageNumber} de ${context.pagesCount}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey, fontWeight: pw.FontWeight.bold),
                      ),
                    ]
                  )
                ]
              )
            );
          },

          build: (pw.Context context) {
            return [
              // CABECERA
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('INFORME LEGAL DE GASTOS', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Text('Kindu App', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                  ]
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(textoPeriodo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey)),
              pw.SizedBox(height: 5),
              pw.Text('Fecha de emisión: $fechaFirma a las $horaFirma', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 20),

              // RESUMEN DEL BALANCE
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: balanceFinal >= 0 ? PdfColors.green50 : PdfColors.red50,
                  border: pw.Border.all(color: balanceFinal >= 0 ? PdfColors.green : PdfColors.red),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('BALANCE DEL PERIODO A FAVOR:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${balanceFinal >= 0 ? '+' : ''}${balanceFinal.toStringAsFixed(2)} €', 
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: balanceFinal >= 0 ? PdfColors.green800 : PdfColors.red800)
                    ),
                  ]
                )
              ),
              pw.SizedBox(height: 25),

              // TABLA DE GASTOS
              pw.Text('Desglose de movimientos registrados:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              
              if (gastos.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  alignment: pw.Alignment.center,
                  child: pw.Text('No hay movimientos registrados en el periodo seleccionado.', style: const pw.TextStyle(color: PdfColors.grey))
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Fecha', 'Concepto / Asignación', 'Tipo / Categoría', 'Importes (%)', 'Estado de Pago'],
                  data: gastos.map((g) {
                    
                    // LÓGICA DE ESTADO (Vencimiento, Disputas - CHAT - y Justificantes)
                    String textoEstado = '';
                    if (g.enDisputa) {
                      // Ahora captura el último mensaje del hilo (o el motivo antiguo si no hay)
                      String ultimoMensaje = g.hiloDisputa.isNotEmpty ? g.hiloDisputa.last.texto : (g.motivoDisputa ?? "No especificado");
                      textoEstado = 'EN DISPUTA\nÚlt. msj: $ultimoMensaje';
                    } else if (g.estaPagado) {
                      textoEstado = 'LIQUIDADO';
                      if (g.comprobantePago != null) textoEstado += '\n(Justificante adjunto)';
                    } else {
                      textoEstado = 'PENDIENTE\nAbonado: ${g.cantidadPagada.toStringAsFixed(2)} €\nResta: ${(g.miParte - g.cantidadPagada).toStringAsFixed(2)} €';
                      if (g.fechaLimite != null) {
                        textoEstado += '\nVence: ${g.fechaLimite!.day.toString().padLeft(2,'0')}/${g.fechaLimite!.month.toString().padLeft(2,'0')}/${g.fechaLimite!.year}';
                      }
                    }

                    // TIPO DE GASTO
                    String tipoGasto = g.categoria;
                    if (g.esDevolucion) {
                      tipoGasto += '\n(DEVOLUCIÓN / ABONO)';
                    } else {
                      tipoGasto += '\n${g.esExtraordinario ? "(Extraordinario)" : "(Ordinario)"}';
                    }

                    String ninos = g.ninosAsignados.isEmpty ? 'Sin asignar' : g.ninosAsignados.join(', ');

                    return [
                      '${g.fecha.day.toString().padLeft(2,'0')}/${g.fecha.month.toString().padLeft(2,'0')}/${g.fecha.year}',
                      '${g.titulo}\nPara: $ninos',
                      tipoGasto,
                      'Total: ${g.total.toStringAsFixed(2)} €\nCuota: ${g.esCobroIntegro ? "100%" : "${g.porcentaje.toInt()}% / ${(100 - g.porcentaje).toInt()}%"}',
                      textoEstado
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  cellStyle: const pw.TextStyle(fontSize: 8), 
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
            ];
          },
        ),
      );

      if (Navigator.canPop(context)) Navigator.pop(context);

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Kindu_Informe_${ahora.millisecondsSinceEpoch}.pdf');

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
    }
  }
}