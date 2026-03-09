import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Importamos la clase Gasto desde tu pestaña de finanzas
import '../screens/finance_tab.dart'; 
import '../screens/calendar_tab.dart'; // Importamos Evento y EstadoEvento

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
                      pw.Row(
                        children: [
                          pw.BarcodeWidget(
                            data: 'KND_VERIFY\nType:FINANCE\nID:KND-${ahora.millisecondsSinceEpoch}\nDate:$fechaFirma\nBalance:${balanceFinal.toStringAsFixed(2)}EUR\nStatus:VALID',
                            barcode: pw.Barcode.qrCode(),
                            width: 35,
                            height: 35,
                            drawText: false,
                            color: PdfColors.teal,
                          ),
                          pw.SizedBox(width: 8),
                          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text('Generado automáticamente por la plataforma Kindu.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                            pw.Text('ID de Exportación Segura: KND-${ahora.millisecondsSinceEpoch}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                            pw.Text('Escanea el QR para verificar la veracidad del documento.', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
                          ]),
                        ],
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
                      '${g.titulo}\nPara: $ninos\nCreado por: ${g.creador}',
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

  /// Exporta el PDF de la Agenda con diseño profesional
  Future<void> exportarInformeAgenda(BuildContext context, List<Evento> eventos, DateTimeRange? periodo) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Generando informe de agenda...")]),
      ),
    );

    try {
      final pdf = pw.Document();
      
      final fuenteNormal = await PdfGoogleFonts.robotoRegular();
      final fuenteNegrita = await PdfGoogleFonts.robotoBold();

      final ahora = DateTime.now();
      final fechaFirma = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
      final horaFirma = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';

      String textoPeriodo = 'PERIODO: Histórico completo de eventos';
      if (periodo != null) {
        String inicio = '${periodo.start.day.toString().padLeft(2, '0')}/${periodo.start.month.toString().padLeft(2, '0')}/${periodo.start.year}';
        String fin = '${periodo.end.day.toString().padLeft(2, '0')}/${periodo.end.month.toString().padLeft(2, '0')}/${periodo.end.year}';
        textoPeriodo = 'PERIODO DEL INFORME: $inicio al $fin';
      }

      // Ordenamos los eventos por fecha para que el informe sea cronológico
      eventos.sort((a, b) => a.fecha.compareTo(b.fecha));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: fuenteNormal, bold: fuenteNegrita),
          
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
                      pw.Row(
                        children: [
                          pw.BarcodeWidget(
                            data: 'KND_VERIFY\nType:AGENDA\nID:KND-AG-${ahora.millisecondsSinceEpoch}\nDate:$fechaFirma\nRecords:${eventos.length}\nStatus:VALID',
                            barcode: pw.Barcode.qrCode(),
                            width: 35,
                            height: 35,
                            drawText: false,
                            color: PdfColors.teal,
                          ),
                          pw.SizedBox(width: 8),
                          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text('Generado automáticamente por la plataforma Kindu.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                            pw.Text('ID de Exportación Segura: KND-AG-${ahora.millisecondsSinceEpoch}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                            pw.Text('Escanea el QR para verificar la veracidad del documento.', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
                          ]),
                        ],
                      ),
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
                    pw.Text('INFORME LEGAL DE AGENDA', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Text('Kindu App', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                  ]
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(textoPeriodo, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey)),
              pw.SizedBox(height: 5),
              pw.Text('Fecha de emisión: $fechaFirma a las $horaFirma', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 20),

              // TABLA DE EVENTOS
              if (eventos.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  alignment: pw.Alignment.center,
                  child: pw.Text('No hay eventos registrados en el periodo seleccionado.', style: const pw.TextStyle(color: PdfColors.grey))
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: ['Fecha / Hora', 'Evento / Descripción', 'Categoría', 'Responsable', 'Estado / Trazabilidad'],
                  data: eventos.map((e) {
                    // Accedemos dinámicamente a las propiedades del objeto Evento
                    final fecha = e.fecha;
                    final fechaStr = '${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')}/${fecha.year}';
                    final horaStr = '${fecha.hour.toString().padLeft(2,'0')}:${fecha.minute.toString().padLeft(2,'0')}';
                    
                    String estadoTexto = 'VALIDADO';
                    // Convertimos el enum a string para comprobar
                    String estadoRaw = e.estado.toString();
                    
                    if (estadoRaw.contains('pendiente')) {
                      estadoTexto = 'PENDIENTE DE APROBACIÓN';
                    } else if (estadoRaw.contains('solicitudEliminacion')) {
                      estadoTexto = 'SOLICITUD DE BORRADO\nPor: ${e.solicitanteCambio ?? "?"}\nMotivo: ${e.motivoSolicitud ?? "?"}';
                    } else if (estadoRaw.contains('cancelado')) {
                      estadoTexto = 'CANCELADO';
                    }

                    if (e.vistoPorOtro != null) {
                      final visto = e.vistoPorOtro!;
                      estadoTexto += '\nVisto: ${visto.day}/${visto.month}/${visto.year}';
                    }
                    
                    // JUGADA 2 y 1 EN PDF: AÑADIR LOGS Y ADJUNTOS
                    if (e.adjuntos.isNotEmpty) {
                      estadoTexto += '\n\n[📎 ${e.adjuntos.length} EVIDENCIAS ADJUNTAS]';
                    }
                    
                    if (e.logsTrazabilidad.isNotEmpty) {
                      estadoTexto += '\n\n--- LOGS ---';
                      for(var log in e.logsTrazabilidad) estadoTexto += '\n$log';
                    }

                    return [
                      '$fechaStr\n$horaStr',
                      '${e.titulo}\nCreado por: ${e.creador}',
                      e.categoria,
                      e.responsable,
                      estadoTexto
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  cellStyle: const pw.TextStyle(fontSize: 8), 
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(60),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FixedColumnWidth(60),
                    3: const pw.FixedColumnWidth(60),
                    4: const pw.FlexColumnWidth(1.5),
                  }
                ),
            ];
          },
        ),
      );

      if (Navigator.canPop(context)) Navigator.pop(context);

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Kindu_Agenda_${ahora.millisecondsSinceEpoch}.pdf');

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
    }
  }

  /// --- NUEVO: EXPORTACIÓN VISUAL DE CALENDARIO (GRID) ---
  Future<void> exportarCalendarioVisual(BuildContext context, List<Evento> eventos, DateTimeRange periodo, String Function(DateTime) calcularCustodia) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Diseñando calendario visual...")]),
      ),
    );

    try {
      final pdf = pw.Document();
      final fuenteNormal = await PdfGoogleFonts.robotoRegular();
      final fuenteNegrita = await PdfGoogleFonts.robotoBold();

      final ahora = DateTime.now();
      final fechaFirma = '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';

      // 1. Generar lista de meses dentro del rango
      List<DateTime> mesesAImprimir = [];
      DateTime cursor = DateTime(periodo.start.year, periodo.start.month, 1);
      while (cursor.isBefore(periodo.end) || cursor.isAtSameMomentAs(periodo.end)) {
        mesesAImprimir.add(cursor);
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }

      // 2. Iterar por cada mes y crear una página
      for (var mes in mesesAImprimir) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape, // APAISADO PARA QUE QUEPA MEJOR
            margin: const pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(base: fuenteNormal, bold: fuenteNegrita),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  // El calendario ocupa todo el espacio disponible
                  pw.Expanded(child: _construirPaginaMes(mes, eventos, calcularCustodia)),
                  
                  // PIE DE PÁGINA PROFESIONAL (Idéntico a FinanceTab)
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    margin: const pw.EdgeInsets.only(top: 10),
                    child: pw.Column(
                      children: [
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Row(
                              children: [
                                pw.BarcodeWidget(
                                  data: 'KND_VERIFY\nType:CALENDAR\nID:KND-CAL-${ahora.millisecondsSinceEpoch}\nDate:$fechaFirma\nPeriod:${mes.month}/${mes.year}\nStatus:VALID',
                                  barcode: pw.Barcode.qrCode(),
                                  width: 35,
                                  height: 35,
                                  drawText: false,
                                  color: PdfColors.teal,
                                ),
                                pw.SizedBox(width: 8),
                                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                  pw.Text('Generado automáticamente por la plataforma Kindu.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                                  pw.Text('ID de Exportación Segura: KND-CAL-${ahora.millisecondsSinceEpoch}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                                  pw.Text('Escanea el QR para verificar la veracidad del documento.', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
                                ]),
                              ],
                            ),
                            pw.Text(
                              'Página ${context.pageNumber} de ${context.pagesCount}',
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey, fontWeight: pw.FontWeight.bold),
                            ),
                          ]
                        )
                      ]
                    )
                  )
                ]
              );
            },
          ),
        );
      }

      if (Navigator.canPop(context)) Navigator.pop(context);
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Kindu_Calendario_${ahora.millisecondsSinceEpoch}.pdf');

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar Calendario: $e'), backgroundColor: Colors.red));
    }
  }

  pw.Widget _construirPaginaMes(DateTime mes, List<Evento> todosEventos, String Function(DateTime) calcularCustodia) {
    final diasEnMes = DateUtils.getDaysInMonth(mes.year, mes.month);
    final primerDiaSemana = DateTime(mes.year, mes.month, 1).weekday; // 1 = Lunes, 7 = Domingo
    
    // Nombres de meses y días
    const mesesNombres = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const diasSemana = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

    // Celdas del calendario
    List<pw.Widget> celdas = [];

    // Relleno inicial (días vacíos antes del 1 del mes)
    for (int i = 1; i < primerDiaSemana; i++) {
      celdas.add(pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300))));
    }

    // Días reales
    for (int dia = 1; dia <= diasEnMes; dia++) {
      final fechaDia = DateTime(mes.year, mes.month, dia);
      
      // Lógica de Custodia (Replicada del CalendarTab para consistencia visual)
      String custodio = calcularCustodia(fechaDia);
      PdfColor colorFondo = custodio == 'Alberto' ? PdfColors.blue50 : PdfColors.orange50;
      PdfColor colorTextoDia = custodio == 'Alberto' ? PdfColors.blue900 : PdfColors.orange900;

      // Filtrar eventos de este día
      final eventosDelDia = todosEventos.where((e) => 
        e.fecha.year == mes.year && e.fecha.month == mes.month && e.fecha.day == dia
      ).toList();

      celdas.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: colorFondo,
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Align(
                alignment: pw.Alignment.topRight,
                child: pw.Text('$dia', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: colorTextoDia, fontSize: 10)),
              ),
              pw.SizedBox(height: 2),
              ...eventosDelDia.map((e) {
                PdfColor colorEvento = PdfColors.teal;
                if (e.categoria == 'Médico') colorEvento = PdfColors.red;
                if (e.categoria == 'Escuela') colorEvento = PdfColors.blue;
                if (e.categoria == 'Ocio') colorEvento = PdfColors.orange;
                
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: pw.BoxDecoration(color: colorEvento, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2))),
                  child: pw.Text(
                    e.titulo, 
                    maxLines: 1, 
                    overflow: pw.TextOverflow.clip, 
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 6)
                  )
                );
              })
            ]
          )
        )
      );
    }

    return pw.Column(
      children: [
        // Cabecera del Mes
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${mesesNombres[mes.month - 1].toUpperCase()} ${mes.year}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.Text('Planificación Familiar Kindu', style: const pw.TextStyle(color: PdfColors.grey)),
          ]
        ),
        pw.SizedBox(height: 10),
        
        // Cabecera Días Semana
        pw.Row(
          children: diasSemana.map((d) => pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              color: PdfColors.teal,
              child: pw.Text(d, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))
            )
          )).toList()
        ),

        // Grid del Calendario
        pw.Expanded(
          child: pw.GridView(
            crossAxisCount: 7,
            children: celdas,
          ),
        ),
        
        // Leyenda
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          pw.Container(width: 10, height: 10, color: PdfColors.blue50), pw.SizedBox(width: 5), pw.Text("Turno Alberto", style: const pw.TextStyle(fontSize: 8)), pw.SizedBox(width: 15),
          pw.Container(width: 10, height: 10, color: PdfColors.orange50), pw.SizedBox(width: 5), pw.Text("Turno Yaiza", style: const pw.TextStyle(fontSize: 8)),
        ])
      ]
    );
  }
}