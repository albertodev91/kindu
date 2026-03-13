import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';

// --- NUEVA CLASE PARA EL CHAT DE DISPUTAS ---
class MensajeDisputa {
  final String autor;
  final String texto;
  final DateTime fecha;
  MensajeDisputa({required this.autor, required this.texto, required this.fecha});
}

// --- ESTRUCTURA DEL GASTO NIVEL DIOS ---
class Gasto {
  final String id; // 🆔 NUEVO: Identificador único para enlaces fuertes
  final String titulo;
  final double total;
  final double miParte;
  final double porcentaje; 
  final bool soyDeudor;
  final String creador; 
  final String categoria;
  final List<String> rutasAdjuntos; 
  final bool esCobroIntegro; 
  final DateTime fecha; 
  final DateTime? fechaEdicion; 
  final bool esRecurrente; 
  final bool esExtraordinario; 
  final List<String> ninosAsignados; 
  
  final DateTime? fechaLimite; 
  final bool esDevolucion; 
  String? comprobantePago; 
  
  double cantidadPagada; 
  // BUG 1: Gato por Bizum - Campo para retener el dinero hasta que se valide
  double pagoPendienteValidacion;

  bool enDisputa; 
  
  String? motivoDisputa; 
  List<MensajeDisputa> hiloDisputa; 
  
  // ¡EL BLINDAJE DEFINITIVO! (Bug 4)
  String? creadorDisputa; 
  
  String metodoPago;

  // AUDITORÍA: Historial de cambios para trazabilidad legal
  final List<String> historialModificaciones;

  Gasto({
    String? id, // Opcional al crear, se genera auto si es null
    required this.titulo,
    required this.total,
    required this.miParte,
    required this.porcentaje,
    required this.soyDeudor,
    required this.creador,
    required this.categoria,
    required this.fecha,
    required this.esRecurrente,
    required this.esExtraordinario,
    required this.ninosAsignados,
    this.rutasAdjuntos = const [],
    this.fechaEdicion,
    this.esCobroIntegro = false,
    this.cantidadPagada = 0.0,
    this.pagoPendienteValidacion = 0.0,
    this.enDisputa = false,
    this.motivoDisputa, 
    List<MensajeDisputa>? hiloDisputa,
    this.metodoPago = '',
    this.fechaLimite,
    this.esDevolucion = false,
    this.comprobantePago,
    this.creadorDisputa, // Inicializado
    this.historialModificaciones = const [],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(), // 🆔 Generación automática
       hiloDisputa = hiloDisputa ?? []; 

  bool get estaPagado => cantidadPagada >= miParte;
}

// --- BASE DE DATOS EN MEMORIA (GLOBAL) ---
// Al sacarla fuera del Widget, persiste aunque cambies de pestaña
List<Gasto> baseDatosGastosGlobal = [
  Gasto(
    titulo: 'Dentista Ivy', total: 120.0, miParte: 60.0, porcentaje: 50.0, soyDeudor: false, creador: 'Alberto',
    categoria: 'Salud', fecha: DateTime.now().subtract(const Duration(days: 1)), esRecurrente: false, esExtraordinario: true, ninosAsignados: ['Ivy'], cantidadPagada: 20.0,
  ),
  Gasto(
    titulo: 'Zapatillas Marca', total: 80.0, miParte: 40.0, porcentaje: 50.0, soyDeudor: false, creador: 'Alberto',
    categoria: 'Ropa', fecha: DateTime.now().subtract(const Duration(days: 2)), esRecurrente: false, esExtraordinario: false, ninosAsignados: ['Viggo'], enDisputa: true,
    creadorDisputa: 'Yaiza',
    hiloDisputa: [MensajeDisputa(autor: 'Yaiza', texto: 'No acordamos comprar zapatillas tan caras. Te pago 20€ como si fueran del Decathlon.', fecha: DateTime.now())]
  ),
  Gasto(
    titulo: 'Academia Inglés', total: 50.0, miParte: 16.5, porcentaje: 33.0, soyDeudor: true, creador: 'Yaiza',
    categoria: 'Educación', fecha: DateTime.now().subtract(const Duration(days: 5)), esRecurrente: true, esExtraordinario: false, ninosAsignados: ['Viggo', 'Ivy'],
    fechaLimite: DateTime.now().add(const Duration(days: 3))
  ),
  // --- CASO DE PRUEBA PARA VALIDACIÓN ---
  Gasto(
    titulo: 'Prueba Validación', total: 100.0, miParte: 50.0, porcentaje: 50.0, soyDeudor: false, creador: 'Alberto',
    categoria: 'Ocio', fecha: DateTime.now(), esRecurrente: false, esExtraordinario: false, ninosAsignados: ['Viggo'],
    pagoPendienteValidacion: 50.0,
  ),
];

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _importeController = TextEditingController();

  String _filtroActual = 'Todos';
  String _categoriaFiltro = 'Todas';
  String _searchQuery = '';

  final String miNombreReal = 'Alberto'; 
  final String nombreOtroProgenitor = 'Yaiza'; 
  final List<String> misHijos = ['Viggo', 'Ivy']; 

  List<Gasto> listaGastos = [];

  // JUGADA 4: RBAC (Role-Based Access Control) - Igual que en Calendario
  String _rolUsuario = 'admin'; // Valores: 'admin' (Padre/Madre), 'observer' (Abuelo/Mediador)

  void _cambiarRol() {
    setState(() {
      _rolUsuario = _rolUsuario == 'admin' ? 'observer' : 'admin';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rol cambiado a: ${_rolUsuario.toUpperCase()}'), backgroundColor: Colors.indigo));
  }

  @override
  void initState() {
    super.initState();
    // CONECTAMOS CON LA "BASE DE DATOS GLOBAL"
    listaGastos = baseDatosGastosGlobal;
  }

  // BUG 3: Lapsus del Céntimo - Helper para sanear doubles
  double _redondear(double valor) {
    return double.parse(valor.toStringAsFixed(2));
  }

  double _calcularBalance() {
    double balance = 0.0;
    for (var gasto in listaGastos) {
      if (!gasto.enDisputa && !gasto.estaPagado) { 
        double deudaRestante = gasto.miParte - gasto.cantidadPagada;
        if (deudaRestante > 0) {
          bool deudorReal = gasto.esDevolucion ? !gasto.soyDeudor : gasto.soyDeudor;
          if (!deudorReal) { balance += deudaRestante; } else { balance -= deudaRestante; }
        }
      }
    }
    return _redondear(balance);
  }

  void _mostrarDialogoPago(int indexReal, bool cobrando) {
    final gasto = listaGastos[indexReal];
    // BUG 3: Usamos _redondear
    final double restante = _redondear(gasto.miParte - gasto.cantidadPagada);
    TextEditingController pagoCtrl = TextEditingController(text: restante.toStringAsFixed(2));
    String? justificanteTmp;
    
    String metodoSeleccionado = 'Bizum'; 

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(cobrando ? 'Registrar Cobro' : 'Registrar Pago'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Quedan pendientes: ${restante.toStringAsFixed(2)}€'),
                const SizedBox(height: 10),
                TextField(
                  controller: pagoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Importe a registrar (€)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.euro)),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: metodoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Método de pago', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_wallet)),
                  items: ['Bizum', 'Transferencia', 'Efectivo'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) { setModalState(() { metodoSeleccionado = val!; }); },
                ),
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  onPressed: () async { 
                    final XFile? foto = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (foto != null) {
                      if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300)); // Blindaje Web
                      setModalState(() { justificanteTmp = foto.path; });
                    }
                  },
                  icon: Icon(justificanteTmp != null ? Icons.check_circle : Icons.receipt_long, color: justificanteTmp != null ? Colors.green : Colors.blueGrey), 
                  label: Text(justificanteTmp != null ? 'Recibo subido' : 'Subir pantallazo Bizum/Banco', style: const TextStyle(fontSize: 12)),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  double abonado = _redondear(double.tryParse(pagoCtrl.text.replaceAll(',', '.')) ?? 0.0);
                  if (abonado > 0 && abonado <= restante) {
                    setState(() {
                      listaGastos[indexReal].metodoPago = metodoSeleccionado; 
                      if (justificanteTmp != null) listaGastos[indexReal].comprobantePago = justificanteTmp; 
                      
                      // BUG 1: Lógica de Verificación
                      // Si soy el deudor (el que paga), el dinero se queda en el limbo (pendiente)
                      if (listaGastos[indexReal].soyDeudor && !cobrando) {
                        listaGastos[indexReal].pagoPendienteValidacion = _redondear(listaGastos[indexReal].pagoPendienteValidacion + abonado);
                      } else {
                        // Si soy el acreedor (registro un cobro), el dinero entra directo
                        listaGastos[indexReal].cantidadPagada = _redondear(listaGastos[indexReal].cantidadPagada + abonado);
                        
                        // Si se paga entero, quitamos automáticamente la disputa
                        if (listaGastos[indexReal].estaPagado) {
                          listaGastos[indexReal].enDisputa = false;
                          listaGastos[indexReal].creadorDisputa = null; 
                        }
                      }
                    });
                    Navigator.pop(ctx);
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    
                    // Mensaje distinto según si requiere validación o no
                    String msg = (listaGastos[indexReal].soyDeudor && !cobrando) 
                        ? 'Pago enviado a revisión. Espera a que te lo validen.' 
                        : 'Cobro registrado correctamente.';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.teal));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importe inválido'), backgroundColor: Colors.red));
                  }
                }, 
                child: const Text('Guardar'),
              )
            ],
          );
        }
      )
    );
  }

  void _mostrarDialogoDisputa(int indexReal) {
    TextEditingController motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.gavel, color: Colors.red), SizedBox(width: 10), Text('Abrir Disputa')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Abre un hilo de disputa detallando tu reclamación o rechazo:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: motivoCtrl, maxLines: 3,
              decoration: const InputDecoration(hintText: 'Ej: Llevas 3 meses sin pagarme...', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (motivoCtrl.text.trim().isNotEmpty) {
                setState(() { 
                  listaGastos[indexReal].enDisputa = true; 
                  // GUARDAMOS A FUEGO QUIÉN ABRE LA DISPUTA
                  listaGastos[indexReal].creadorDisputa = miNombreReal;
                  listaGastos[indexReal].hiloDisputa.add(MensajeDisputa(autor: miNombreReal, texto: motivoCtrl.text.trim(), fecha: DateTime.now()));
                });
                Navigator.pop(ctx);
                if (Navigator.canPop(context)) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disputa iniciada. Gasto congelado.'), backgroundColor: Colors.red));
              }
            }, 
            child: const Text('Iniciar Disputa'),
          )
        ],
      )
    );
  }

  void _enviarMensajeDisputa(int indexReal, String texto) {
    if (texto.trim().isNotEmpty) {
      setState(() {
        listaGastos[indexReal].hiloDisputa.add(MensajeDisputa(autor: miNombreReal, texto: texto.trim(), fecha: DateTime.now()));
      });
    }
  }

  void _borrarGasto(int indexReal) {
    setState(() { listaGastos.removeAt(indexReal); });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto eliminado'), backgroundColor: Colors.redAccent));
  }

  // --- NUEVA LÓGICA: LIQUIDACIÓN AVANZADA (BATCH PAYMENT) ---
  void _abrirLiquidacionAvanzada() {
    // 1. Filtramos solo MIS deudas pendientes (donde yo soy el deudor)
    List<int> indicesDeudas = [];
    for (int i = 0; i < listaGastos.length; i++) {
      final g = listaGastos[i];
      // Si soy deudor, no está pagado y no está en disputa
      // CORRECCIÓN: Restamos también lo que está pendiente de validar para no pagar doble
      double deudaReal = g.miParte - g.cantidadPagada - g.pagoPendienteValidacion;
      if (g.soyDeudor && !g.estaPagado && !g.enDisputa && deudaReal > 0.01) {
        indicesDeudas.add(i);
      }
    }

    if (indicesDeudas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes pagos pendientes que realizar.'), backgroundColor: Colors.green));
      return;
    }

    // Estado temporal para el modal
    List<int> seleccionados = List.from(indicesDeudas); // Por defecto todos seleccionados
    String metodoPago = 'Bizum';
    String? rutaJustificante;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalSeleccionado = 0.0;
            for (var idx in seleccionados) {
              // CORRECCIÓN: El total a pagar descuenta lo que ya está en el limbo (pendiente de validar)
              totalSeleccionado += (listaGastos[idx].miParte - listaGastos[idx].cantidadPagada - listaGastos[idx].pagoPendienteValidacion);
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Liquidar Deuda Acumulada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 5),
                  const Text('Selecciona los gastos que vas a pagar ahora:', style: TextStyle(color: Colors.grey)),
                  const Divider(),
                  
                  // LISTA DE DEUDAS (Max height para que no ocupe toda la pantalla)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: indicesDeudas.length,
                      itemBuilder: (ctx, i) {
                        final indexReal = indicesDeudas[i];
                        final gasto = listaGastos[indexReal];
                        final pendiente = gasto.miParte - gasto.cantidadPagada - gasto.pagoPendienteValidacion;
                        final isSelected = seleccionados.contains(indexReal);

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: Colors.teal,
                          title: Text(gasto.titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text('${_formatearFecha(gasto.fecha)} | ${gasto.categoria}'),
                          secondary: Text('${pendiente.toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) { seleccionados.add(indexReal); } else { seleccionados.remove(indexReal); }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  
                  // RESUMEN Y FORMA DE PAGO
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total a Pagar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('${totalSeleccionado.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal))]),
                  const SizedBox(height: 15),
                  
                  DropdownButtonFormField<String>(
                    initialValue: metodoPago,
                    decoration: const InputDecoration(labelText: 'Método de pago realizado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payment), isDense: true),
                    items: ['Bizum', 'Transferencia', 'Efectivo'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) { setModalState(() { metodoPago = val!; }); },
                  ),
                  const SizedBox(height: 10),
                  
                  OutlinedButton.icon(
                    onPressed: () async { 
                      final XFile? foto = await ImagePicker().pickImage(source: ImageSource.gallery); 
                      if (foto != null) { 
                        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                        setModalState(() { rutaJustificante = foto.path; }); 
                      } 
                    },
                    icon: Icon(rutaJustificante != null ? Icons.check_circle : Icons.camera_alt, color: rutaJustificante != null ? Colors.green : Colors.blueGrey),
                    label: Text(rutaJustificante != null ? 'Justificante Adjuntado' : 'Subir Justificante del Pago Total'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  ),
                  
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: totalSeleccionado > 0 ? () {
                        // APLICAR PAGO A TODOS LOS SELECCIONADOS
                        setState(() {
                          for (var idx in seleccionados) {
                            final gasto = listaGastos[idx];
                            final deuda = _redondear(gasto.miParte - gasto.cantidadPagada - gasto.pagoPendienteValidacion);
                            
                            // Actualizamos el gasto como si fuera un pago individual
                            gasto.metodoPago = metodoPago;
                            if (rutaJustificante != null) gasto.comprobantePago = rutaJustificante;
                            
                            // Como soy deudor, va a validación
                            // CORRECCIÓN FINAL: Sumamos a lo que ya pudiera haber pendiente, no lo sobrescribimos
                            gasto.pagoPendienteValidacion = _redondear(gasto.pagoPendienteValidacion + deuda);
                          }
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se han registrado ${seleccionados.length} pagos pendientes de validar.'), backgroundColor: Colors.teal));
                      } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: Text('Pagar ${totalSeleccionado.toStringAsFixed(2)}€ y Liquidar'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _abrirMenuExportacion() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Exportar Datos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.picture_as_pdf, color: Colors.white)),
                title: const Text('Informe Legal (PDF)'),
                subtitle: const Text('Documento formal para abogados/jueces'),
                onTap: () { Navigator.pop(ctx); PdfService().exportarInformeLegal(context, listaGastos, _calcularBalance(), null); },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.table_view, color: Colors.white)),
                title: const Text('Excel / CSV'),
                subtitle: const Text('Hoja de cálculo para tus cuentas'),
                onTap: () { Navigator.pop(ctx); ExcelService().exportarExcel(context, listaGastos); },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.date_range, color: Colors.white)),
                title: const Text('Informe PDF por Fechas'),
                subtitle: const Text('Elige un trimestre o mes concreto'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final DateTimeRange? rango = await showDateRangePicker(
                    context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), helpText: 'SELECCIONA EL PERIODO', cancelText: 'CANCELAR', confirmText: 'EXPORTAR',
                    builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)), child: child!),
                  );
                  if (rango != null) {
                    List<Gasto> filtrados = listaGastos.where((g) { return g.fecha.isAfter(rango.start.subtract(const Duration(days: 1))) && g.fecha.isBefore(rango.end.add(const Duration(days: 1))); }).toList();
                    double balanceFiltrado = 0.0;
                    for (var gasto in filtrados) {
                      if (!gasto.enDisputa && !gasto.estaPagado) {
                        double deudaRestante = _redondear(gasto.miParte - gasto.cantidadPagada);
                        if (deudaRestante > 0) {
                          bool deudorReal = gasto.esDevolucion ? !gasto.soyDeudor : gasto.soyDeudor;
                          if (!deudorReal) { balanceFiltrado += deudaRestante; } else { balanceFiltrado -= deudaRestante; }
                        }
                      }
                    }
                    PdfService().exportarInformeLegal(context, filtrados, balanceFiltrado, rango);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      }
    );
  }

  IconData _getIconoPorCategoria(String categoria) {
    switch (categoria) {
      case 'Educación': return Icons.school;
      case 'Salud': return Icons.medical_services;
      case 'Ropa': return Icons.checkroom;
      case 'Alimentación': return Icons.restaurant;
      case 'Ocio': return Icons.sports_esports;
      case 'Pensión': return Icons.account_balance_wallet;
      default: return Icons.receipt; 
    }
  }

  Color _getColorPorCategoria(String categoria) {
    switch (categoria) {
      case 'Educación': return Colors.blue;
      case 'Salud': return Colors.red.shade400;
      case 'Ropa': return Colors.purple.shade400;
      case 'Alimentación': return Colors.orange;
      case 'Ocio': return Colors.teal.shade300;
      case 'Pensión': return Colors.green.shade600;
      default: return Colors.blueGrey;
    }
  }

  String _formatearFecha(DateTime fecha) { return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}'; }
  String _formatearHora(DateTime fecha) { return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'; }

  void _mostrarDetalleGasto(BuildContext context, Gasto gasto, int indexReal) {
    double restante = _redondear(gasto.miParte - gasto.cantidadPagada);
    bool esAcreedorReal = gasto.esDevolucion ? gasto.soyDeudor : !gasto.soyDeudor;
    TextEditingController chatCtrl = TextEditingController();

    bool esObserver = _rolUsuario == 'observer';

    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder( 
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(gasto.esDevolucion ? 'Detalle de Devolución' : 'Detalle del Gasto', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    
                    Row(
                      children: [
                        // EDITAR: Siempre visible (pero dentro se bloquea si es necesario)
                        if (gasto.creador == miNombreReal && !esObserver) IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () { Navigator.pop(context); _abrirFormulario(context, esGastoCompartido: !gasto.esCobroIntegro, gastoAEditar: gasto, indexAEditar: indexReal); }),
                        // BORRAR: Solo visible si es seguro (Tu lógica original estaba perfecta aquí)
                        if (!gasto.estaPagado && !gasto.enDisputa && gasto.creador == miNombreReal && gasto.cantidadPagada == 0 && gasto.pagoPendienteValidacion == 0 && !esObserver) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _borrarGasto(indexReal)),
                      ],
                    )
                  ],
                ),
                const Divider(),

                Wrap(
                  spacing: 8,
                  children: [
                    if (gasto.esDevolucion) Chip(label: const Text('ABONO / DEVOLUCIÓN', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.teal.shade800, visualDensity: VisualDensity.compact),
                    if (!gasto.esDevolucion) Chip(
                      label: Text(gasto.esExtraordinario ? 'Extraordinario' : 'Ordinario', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)), 
                      backgroundColor: gasto.esExtraordinario ? Colors.purple.shade400 : Colors.blueGrey.shade400,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (gasto.ninosAsignados.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.face, size: 14, color: Colors.teal),
                        label: Text(gasto.ninosAsignados.join(', '), style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)), 
                        backgroundColor: Colors.teal.shade50,
                        visualDensity: VisualDensity.compact,
                      )
                  ],
                ),
                const SizedBox(height: 10),

                if (gasto.enDisputa)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), width: double.infinity, 
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Row(children: [Icon(Icons.gavel, color: Colors.red), SizedBox(width: 10), Text('HILO DE RESOLUCIÓN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]), 
                        const SizedBox(height: 10),
                        ...gasto.hiloDisputa.map((msg) => Container(
                          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: msg.autor == miNombreReal ? Colors.white : Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(msg.autor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: msg.autor == miNombreReal ? Colors.teal : Colors.red.shade800)), Text('${_formatearFecha(msg.fecha)} ${_formatearHora(msg.fecha)}', style: const TextStyle(fontSize: 9, color: Colors.grey))]),
                            const SizedBox(height: 4), Text(msg.texto, style: const TextStyle(fontSize: 13)),
                          ]),
                        )),
                        const Divider(color: Colors.red),
                        if (!esObserver)
                          Row(children: [
                            Expanded(child: TextField(controller: chatCtrl, decoration: InputDecoration(hintText: 'Escribir respuesta...', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
                            IconButton(icon: const Icon(Icons.send, color: Colors.red), onPressed: () {
                              if (chatCtrl.text.isNotEmpty) {
                                _enviarMensajeDisputa(indexReal, chatCtrl.text);
                                chatCtrl.clear();
                                setModalState((){}); 
                              }
                            })
                          ])
                      ]
                    )
                  ),
                
                // BUG 1: UI de Verificación de Pago
                if (gasto.pagoPendienteValidacion > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange), 
                          const SizedBox(width: 10), 
                          Expanded(child: Text('Pago de ${gasto.pagoPendienteValidacion.toStringAsFixed(2)}€ pendiente de validar', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)))
                        ]),
                        const SizedBox(height: 10),
                        if (esAcreedorReal && !esObserver) // Si soy el que cobra, me salen los botones
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () { setState(() { listaGastos[indexReal].pagoPendienteValidacion = 0.0; }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago rechazado'), backgroundColor: Colors.red)); }, 
                                child: const Text('Rechazar', style: TextStyle(color: Colors.red))
                              ),
                              ElevatedButton(
                                onPressed: () { setState(() { listaGastos[indexReal].cantidadPagada = _redondear(listaGastos[indexReal].cantidadPagada + listaGastos[indexReal].pagoPendienteValidacion); listaGastos[indexReal].pagoPendienteValidacion = 0.0; if(listaGastos[indexReal].estaPagado) { listaGastos[indexReal].enDisputa = false; listaGastos[indexReal].creadorDisputa = null; } }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago validado y sumado.'), backgroundColor: Colors.green)); }, 
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                child: const Text('Validar y Aceptar')
                              ),
                            ],
                          )
                        else // Si soy el que pagó, solo veo el aviso
                          const Text('Esperando a que el otro progenitor confirme la recepción.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),

                // SECCIÓN DE AUDITORÍA (Solo visible si hay cambios)
                if (gasto.historialModificaciones.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Historial de Modificaciones', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    leading: const Icon(Icons.history_edu, size: 16, color: Colors.grey),
                    children: gasto.historialModificaciones.map((mod) => ListTile(
                      dense: true, title: Text(mod, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)), leading: const Icon(Icons.circle, size: 6, color: Colors.grey),
                    )).toList(),
                  ),

                ListTile(
                  leading: Icon(gasto.estaPagado ? Icons.history : _getIconoPorCategoria(gasto.categoria), color: gasto.estaPagado ? Colors.grey : _getColorPorCategoria(gasto.categoria)),
                  title: Text(gasto.titulo),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Creado por: ${gasto.creador}\n${gasto.categoria} | ${_formatearFecha(gasto.fecha)}\nTotal Ticket: ${gasto.total.toStringAsFixed(2)}€\nProporción: ${gasto.esCobroIntegro ? '100%' : '${gasto.porcentaje.toInt()}% / ${(100 - gasto.porcentaje).toInt()}%'}'),
                      if (gasto.fechaLimite != null) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('⚠️ Vence el: ${_formatearFecha(gasto.fechaLimite!)}', style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12))),
                      if (gasto.fechaEdicion != null) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('(Editado el ${_formatearFecha(gasto.fechaEdicion!)})', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey, fontSize: 11))),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(gasto.esDevolucion ? 'Me deben:' : 'Total a pagar:', style: const TextStyle(fontSize: 10)),
                      Text('${gasto.miParte.toStringAsFixed(2)}€', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),

                if (gasto.cantidadPagada > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Abonado: ${gasto.cantidadPagada.toStringAsFixed(2)}€', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          if (!gasto.estaPagado) Text('Resta: ${restante.toStringAsFixed(2)}€', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: gasto.cantidadPagada / gasto.miParte, backgroundColor: Colors.grey.shade200, color: Colors.green),
                      const SizedBox(height: 10),
                    ],
                  ),
                  
                if (gasto.comprobantePago != null) 
                  Container(margin: const EdgeInsets.symmetric(vertical: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.receipt, color: Colors.blue), const SizedBox(width: 10), const Expanded(child: Text('Justificante de pago adjuntado', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))), OutlinedButton(onPressed: (){}, style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('Ver'))])),

                if (gasto.esRecurrente) const Align(alignment: Alignment.centerLeft, child: Chip(avatar: Icon(Icons.autorenew, size: 16), label: Text('Se repite cada mes'), backgroundColor: Colors.amberAccent)),

                const SizedBox(height: 10),
                if (gasto.rutasAdjuntos.isNotEmpty) SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: gasto.rutasAdjuntos.length, itemBuilder: (ctx, i) { 
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                backgroundColor: Colors.black,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InteractiveViewer(child: kIsWeb ? Image.network(gasto.rutasAdjuntos[i]) : Image.file(File(gasto.rutasAdjuntos[i]))),
                                    Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx))),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(width: 120, height: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300), image: DecorationImage(image: kIsWeb ? NetworkImage(gasto.rutasAdjuntos[i]) as ImageProvider : FileImage(File(gasto.rutasAdjuntos[i])), fit: BoxFit.cover)))
                        ),
                        if (gasto.creador == miNombreReal && !gasto.estaPagado && !gasto.enDisputa)
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () => setModalState(() => gasto.rutasAdjuntos.removeAt(i)),
                              child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14)),
                            ),
                          )
                      ],
                    ),
                  );
                })),
                const SizedBox(height: 20),

                if (gasto.estaPagado) ...[
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.verified, color: Colors.green), const SizedBox(width: 10), Text('LIQUIDADO AL 100% POR ${gasto.metodoPago.toUpperCase()}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))]))
                ] else if (esObserver) ...[
                  Container(padding: const EdgeInsets.all(12), width: double.infinity, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Text('Modo Observador: Acciones restringidas', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                ] else ...[
                  if (!esAcreedorReal) ...[
                    SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(onPressed: () => _mostrarDialogoPago(indexReal, false), icon: const Icon(Icons.payment), label: const Text('Registrar Pago'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white))),
                  ] else ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recordatorio enviado a $nombreOtroProgenitor'), backgroundColor: Colors.orange)); }, icon: const Icon(Icons.notifications_active), label: const Text('Recordar'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white)), ElevatedButton.icon(onPressed: () => _mostrarDialogoPago(indexReal, true), icon: const Icon(Icons.check_circle), label: const Text('Cobrar'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))]),
                  ],
                  const SizedBox(height: 10),
                  
                  if (!gasto.enDisputa)
                    SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () => _mostrarDialogoDisputa(indexReal), icon: const Icon(Icons.gavel), label: Text(!esAcreedorReal ? 'Rechazar Gasto / Disputar' : 'Reclamar Impago / Abrir Disputa'), style: TextButton.styleFrom(foregroundColor: Colors.red)))
                  else if (gasto.creadorDisputa == miNombreReal) // SOLO EL CREADOR DE LA DISPUTA PUEDE RESOLVERLA
                    SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () { setState(() { listaGastos[indexReal].enDisputa = false; listaGastos[indexReal].creadorDisputa = null; listaGastos[indexReal].hiloDisputa.add(MensajeDisputa(autor: miNombreReal, texto: 'Disputa marcada como resuelta.', fecha: DateTime.now())); }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disputa resuelta. Gasto descongelado.'), backgroundColor: Colors.green)); }, icon: const Icon(Icons.handshake), label: const Text('Marcar Disputa como Resuelta'), style: TextButton.styleFrom(foregroundColor: Colors.green)))
                  else // AVISO PARA EL QUE NO ABRIÓ LA DISPUTA
                    Container(width: double.infinity, alignment: Alignment.center, padding: const EdgeInsets.all(10), child: Text('Disputa abierta por ${gasto.creadorDisputa}. Solo esa persona puede cerrarla.', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 12))),
                ],
                const SizedBox(height: 10),
              ],
            ),
          );
        }
      ),
    );
  }

  // --- NUEVA FUNCIÓN: ESTADÍSTICAS DE GASTOS ---
  void _mostrarEstadisticas() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool verSoloLoMio = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Map<String, double> porCategoria = {};
            double totalCalculado = 0.0;

            // Calculamos totales según el filtro
            for (var g in listaGastos) {
              // Si verSoloLoMio es true, usamos g.miParte. Si es false, usamos g.total
              double valor = verSoloLoMio ? g.miParte : g.total;
              
              porCategoria.update(g.categoria, (val) => val + valor, ifAbsent: () => valor);
              totalCalculado += valor;
            }

            // Ordenamos de mayor a menor gasto
            var categoriasOrdenadas = porCategoria.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Desglose de Gastos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 10),
                  
                  // INTERRUPTOR MÁGICO
                  Container(
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                    child: SwitchListTile(
                      title: Text(verSoloLoMio ? 'Mi Coste Real' : 'Coste Total (Niños)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(verSoloLoMio ? 'Lo que te corresponde pagar a ti' : 'Suma total de los tickets subidos'),
                      value: verSoloLoMio,
                      activeThumbColor: Colors.teal,
                      secondary: Icon(verSoloLoMio ? Icons.person : Icons.people, color: Colors.teal),
                      onChanged: (val) { setModalState(() { verSoloLoMio = val; }); }
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  Text('Total: ${totalCalculado.toStringAsFixed(2)} €', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(height: 20),
                  
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categoriasOrdenadas.length,
                      itemBuilder: (ctx, i) {
                        final cat = categoriasOrdenadas[i];
                        final porcentaje = totalCalculado > 0 ? (cat.value / totalCalculado) : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(_getIconoPorCategoria(cat.key), color: _getColorPorCategoria(cat.key), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(cat.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Text('${cat.value.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                value: porcentaje,
                                backgroundColor: Colors.grey.shade200,
                                color: _getColorPorCategoria(cat.key),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              Align(alignment: Alignment.centerRight, child: Text('${(porcentaje * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: Colors.grey))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _abrirFormulario(BuildContext context, {required bool esGastoCompartido, Gasto? gastoAEditar, int? indexAEditar, bool esDevolucion = false, bool esPagoPropio = false}) {
    if (gastoAEditar != null) {
      _conceptoController.text = gastoAEditar.titulo;
      _importeController.text = gastoAEditar.total.toStringAsFixed(2).replaceAll('.', ','); 
    } else {
      _conceptoController.clear();
      _importeController.clear();
    }

    List<String> rutasFotosTemporales = gastoAEditar?.rutasAdjuntos.toList() ?? [];
    String categoriaSeleccionada = gastoAEditar?.categoria ?? (esGastoCompartido ? 'Otro' : (esPagoPropio ? 'Pensión' : 'Otro')); 
    DateTime fechaSeleccionada = gastoAEditar?.fecha ?? DateTime.now();
    DateTime? fechaLimite = gastoAEditar?.fechaLimite;
    double porcentajeSeleccionado = gastoAEditar?.porcentaje ?? 50.0;
    bool esRecurrente = gastoAEditar?.esRecurrente ?? false;
    bool esExtraordinario = gastoAEditar?.esExtraordinario ?? false;
    List<String> ninosSeleccionados = gastoAEditar?.ninosAsignados.toList() ?? [];

    // BLINDAJE INTELIGENTE: Si hay dinero de por medio, bloqueamos campos críticos
    bool edicionBloqueada = false;
    if (gastoAEditar != null && (gastoAEditar.cantidadPagada > 0 || gastoAEditar.pagoPendienteValidacion > 0 || gastoAEditar.enDisputa)) { edicionBloqueada = true; }

    final categorias = esGastoCompartido ? ['Educación', 'Salud', 'Ropa', 'Alimentación', 'Ocio', 'Otro'] : ['Pensión', 'Educación', 'Salud', 'Otro'];

    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gastoAEditar != null ? 'Editar Registro' : 
                      (esDevolucion ? 'Registrar Devolución' : 
                      (esGastoCompartido ? 'Añadir Gasto Compartido' : 
                      (esPagoPropio ? 'Registrar Pago Íntegro (Ej: Pensión)' : 'Solicitar Cobro Íntegro'))), 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal), textAlign: TextAlign.center
                    ),
                    
                    if (edicionBloqueada)
                      Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange)), child: const Row(children: [Icon(Icons.lock, size: 16, color: Colors.orange), SizedBox(width: 5), Expanded(child: Text('Edición limitada: Gasto con actividad financiera.', style: TextStyle(fontSize: 12, color: Colors.deepOrange)))]))
                    ,
                    const SizedBox(height: 15),
                    
                    if (esGastoCompartido && !esDevolucion) ...[
                      SwitchListTile(
                        title: const Text('Es un Gasto Extraordinario', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Gafas, dentista, extraescolares...'),
                        value: esExtraordinario,
                        activeThumbColor: Colors.purple,
                        onChanged: (val) { setModalState(() { esExtraordinario = val; if (val) esRecurrente = false; }); }
                      ),
                      const Divider(),
                      const Align(alignment: Alignment.centerLeft, child: Text('¿A quién corresponde este gasto?', style: TextStyle(fontWeight: FontWeight.bold))),
                      Wrap(
                        spacing: 10,
                        children: misHijos.map((nino) {
                          return FilterChip(
                            label: Text(nino),
                            selected: ninosSeleccionados.contains(nino),
                            selectedColor: Colors.teal.shade100,
                            checkmarkColor: Colors.teal,
                            onSelected: (bool selected) {
                              setModalState(() {
                                if (selected) {
                                  ninosSeleccionados.add(nino);
                                } else {
                                  ninosSeleccionados.remove(nino);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 15),
                    ],

                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(initialValue: categoriaSeleccionada, decoration: InputDecoration(labelText: 'Categoría', prefixIcon: Icon(_getIconoPorCategoria(categoriaSeleccionada), color: _getColorPorCategoria(categoriaSeleccionada)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), items: categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(), onChanged: (val) { setModalState(() { categoriaSeleccionada = val!; }); })),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton.icon(onPressed: () async { DateTime? elegida = await showDatePicker(context: context, initialDate: fechaSeleccionada, firstDate: DateTime(2020), lastDate: DateTime.now()); if (elegida != null) setModalState(() { fechaSeleccionada = elegida; }); }, icon: const Icon(Icons.calendar_today), label: Text(_formatearFecha(fechaSeleccionada)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    if (!esDevolucion)
                      OutlinedButton.icon(onPressed: () async { DateTime? elegida = await showDatePicker(context: context, initialDate: fechaLimite ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2030)); if (elegida != null) setModalState(() { fechaLimite = elegida; }); }, icon: Icon(Icons.timer, color: fechaLimite != null ? Colors.red : Colors.grey), label: Text(fechaLimite != null ? 'Vence: ${_formatearFecha(fechaLimite!)}' : 'Añadir Fecha Límite de Pago', style: TextStyle(color: fechaLimite != null ? Colors.red : Colors.black87)), style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), alignment: Alignment.centerLeft)),
                    const SizedBox(height: 15),

                    TextField(controller: _conceptoController, readOnly: edicionBloqueada, decoration: InputDecoration(labelText: esDevolucion ? 'Concepto de la Devolución' : 'Concepto / Tienda', prefixIcon: const Icon(Icons.edit_note), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: edicionBloqueada, fillColor: edicionBloqueada ? Colors.grey.shade200 : null)),
                    const SizedBox(height: 15),
                    
                    TextField(controller: _importeController, readOnly: edicionBloqueada, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: esDevolucion ? 'Importe Devuelto (€)' : 'Importe Total del Ticket (€)', prefixIcon: const Icon(Icons.euro), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: edicionBloqueada, fillColor: edicionBloqueada ? Colors.grey.shade200 : null)),
                    const SizedBox(height: 15),

                    if (esGastoCompartido) ...[
                      const Align(alignment: Alignment.centerLeft, child: Text('Distribución legal (%):', style: TextStyle(fontWeight: FontWeight.bold))),
                      Row(
                        children: [
                          Text('Tú: ${porcentajeSeleccionado.toInt()}%', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          Expanded(child: Slider(value: porcentajeSeleccionado, min: 0, max: 100, divisions: 100, label: '${porcentajeSeleccionado.toInt()}%', onChanged: edicionBloqueada ? null : (val) { setModalState(() { porcentajeSeleccionado = val; }); })),
                          Text('El otro: ${(100 - porcentajeSeleccionado).toInt()}%', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    OutlinedButton.icon(
                      onPressed: () async { 
                        final List<XFile> fotos = await ImagePicker().pickMultiImage(); 
                        if (fotos.isNotEmpty) {
                          if (kIsWeb) await Future.delayed(const Duration(milliseconds: 300));
                          setModalState(() { rutasFotosTemporales.addAll(fotos.map((f) => f.path)); }); 
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📸 ${fotos.length} adjuntos añadidos'), backgroundColor: Colors.teal)); 
                        } 
                      },
                      icon: Icon(rutasFotosTemporales.isNotEmpty ? Icons.library_add_check : Icons.add_photo_alternate, color: rutasFotosTemporales.isNotEmpty ? Colors.green : Colors.teal), 
                      label: Text(rutasFotosTemporales.isNotEmpty ? '${rutasFotosTemporales.length} Tickets adjuntados (Añadir más)' : 'Subir tickets o facturas'), 
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), side: BorderSide(color: rutasFotosTemporales.isNotEmpty ? Colors.green : Colors.teal)),
                    ),
                    
                    SwitchListTile(title: const Text('Gasto recurrente (Mensual)'), secondary: const Icon(Icons.autorenew), value: esRecurrente, activeThumbColor: Colors.teal, onChanged: (bool val) { setModalState(() { esRecurrente = val; if (val) esExtraordinario = false; }); }),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          String concepto = _conceptoController.text.trim();
                          double importe = double.tryParse(_importeController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;
                
                          if (concepto.isNotEmpty && importe > 0) {
                            setState(() {
                              // LÓGICA CORREGIDA:
                              double miPorcentajeCalculado;
                              double miParteCalculada; // Lo que debo pagar O lo que me deben pagar
                              bool soyElDeudor;

                              if (esGastoCompartido) {
                                miPorcentajeCalculado = porcentajeSeleccionado;
                                soyElDeudor = false; // Yo he pagado el ticket, reclamo la diferencia
                                miParteCalculada = importe * ((100 - miPorcentajeCalculado) / 100);
                              } else if (esPagoPropio) {
                                // CASO: PAGO PENSIÓN (Yo pago todo)
                                miPorcentajeCalculado = 100.0; // Mi coste es el 100%
                                soyElDeudor = true; // Yo debo este dinero (o lo estoy pagando)
                                miParteCalculada = importe; 
                              } else {
                                // CASO: SOLICITAR COBRO (Me deben todo)
                                miPorcentajeCalculado = 0.0; // Mi coste es 0%
                                soyElDeudor = false; // Yo soy el acreedor
                                miParteCalculada = importe;
                              }

                              // AUDITORÍA: Si editamos, registramos qué ha pasado
                              List<String> historial = gastoAEditar?.historialModificaciones.toList() ?? [];
                              if (gastoAEditar != null) {
                                String fechaCambio = _formatearFecha(DateTime.now());
                                // Si cambiamos categoría o fecha, lo anotamos. Usamos ! porque ya sabemos que no es null
                                if (gastoAEditar.categoria != categoriaSeleccionada) {
                                  historial.add('$fechaCambio: Categoría cambiada de ${gastoAEditar.categoria} a $categoriaSeleccionada');
                                }
                                // Aquí se pueden añadir más campos si se desbloquean
                              }
                
                              Gasto gastoModificado = Gasto(
                                titulo: concepto, total: importe, miParte: miParteCalculada, porcentaje: miPorcentajeCalculado, soyDeudor: soyElDeudor, creador: miNombreReal, 
                                rutasAdjuntos: rutasFotosTemporales, categoria: categoriaSeleccionada, esCobroIntegro: !esGastoCompartido, fecha: fechaSeleccionada, 
                                esRecurrente: esRecurrente, esExtraordinario: esExtraordinario, ninosAsignados: ninosSeleccionados,
                                fechaEdicion: (gastoAEditar != null) ? DateTime.now() : null, 
                                cantidadPagada: gastoAEditar?.cantidadPagada ?? 0.0, 
                                enDisputa: gastoAEditar?.enDisputa ?? false, 
                                creadorDisputa: gastoAEditar?.creadorDisputa, // ARRASTRA QUIÉN ABRIÓ LA DISPUTA
                                motivoDisputa: gastoAEditar?.motivoDisputa, 
                                hiloDisputa: gastoAEditar?.hiloDisputa, 
                                metodoPago: gastoAEditar?.metodoPago ?? '',
                                esDevolucion: esDevolucion, fechaLimite: fechaLimite, 
                                comprobantePago: gastoAEditar?.comprobantePago,
                                historialModificaciones: historial
                              );
                
                              if (gastoAEditar != null && indexAEditar != null) { listaGastos[indexAEditar] = gastoModificado; } else { listaGastos.insert(0, gastoModificado); }
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gastoAEditar != null ? 'Registro actualizado' : 'Guardado correctamente'), backgroundColor: Colors.teal));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el concepto o el importe.'), backgroundColor: Colors.red));
                          }
                        },
                        icon: const Icon(Icons.save), label: Text(gastoAEditar != null ? 'Actualizar' : 'Guardar'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _mostrarMenuOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Qué quieres hacer?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.receipt, color: Colors.white)), title: const Text('Añadir Gasto Compartido'), onTap: () { Navigator.pop(context); _abrirFormulario(context, esGastoCompartido: true); }),
            const Divider(),
            ListTile(leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.request_quote, color: Colors.white)), title: const Text('Solicitar Cobro Íntegro'), onTap: () { Navigator.pop(context); _abrirFormulario(context, esGastoCompartido: false); }),
            const Divider(),
            ListTile(leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.payments, color: Colors.white)), title: const Text('Registrar Pago Propio'), subtitle: const Text('Ej: Pagar Pensión, Extraescolar completa...'), onTap: () { Navigator.pop(context); _abrirFormulario(context, esGastoCompartido: false, esPagoPropio: true); }),
            const Divider(),
            ListTile(leading: CircleAvatar(backgroundColor: Colors.teal.shade800, child: const Icon(Icons.currency_exchange, color: Colors.white)), title: const Text('Registrar Abono / Devolución'), subtitle: const Text('Si te han devuelto dinero de una compra'), onTap: () { Navigator.pop(context); _abrirFormulario(context, esGastoCompartido: true, esDevolucion: true); }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double balanceFinal = _calcularBalance();
    bool saldoAFavor = balanceFinal >= 0;

    List<Gasto> gastosMostrados = listaGastos.where((gasto) {
      bool pasaFiltroPersona = true;
      if (_filtroActual == miNombreReal) { pasaFiltroPersona = gasto.esDevolucion ? gasto.soyDeudor : !gasto.soyDeudor; } 
      if (_filtroActual == nombreOtroProgenitor) { pasaFiltroPersona = gasto.esDevolucion ? !gasto.soyDeudor : gasto.soyDeudor; }
      
      bool pasaFiltroCat = _categoriaFiltro == 'Todas' || gasto.categoria == _categoriaFiltro;
      bool pasaBuscador = gasto.titulo.toLowerCase().contains(_searchQuery.toLowerCase());
      
      return pasaFiltroPersona && pasaFiltroCat && pasaBuscador;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas', style: TextStyle(fontSize: 18, color: Colors.teal)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. BUSCADOR, ESTADÍSTICAS Y FILTRO CATEGORÍA (AHORA ARRIBA)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(hintText: 'Buscar gasto...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true, contentPadding: const EdgeInsets.all(8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onChanged: (val) { setState(() { _searchQuery = val; }); },
                  ),
                ),
                // BOTÓN DE ESTADÍSTICAS AÑADIDO AQUÍ
                IconButton(
                  icon: const Icon(Icons.pie_chart, color: Colors.teal),
                  onPressed: _mostrarEstadisticas,
                  tooltip: 'Ver estadísticas',
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _categoriaFiltro,
                  items: ['Todas', 'Educación', 'Salud', 'Ropa', 'Alimentación', 'Ocio', 'Pensión', 'Otro'].map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) { setState(() { _categoriaFiltro = val!; }); },
                )
              ],
            ),
          ),

          // 2. FILTROS DE PERSONA Y BOTÓN DE EXPORTAR (JUNTOS)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Todos', miNombreReal, nombreOtroProgenitor].map((filtro) {
                      bool seleccionado = _filtroActual == filtro;
                      return ChoiceChip(label: Text(filtro, style: TextStyle(color: seleccionado ? Colors.teal.shade900 : Colors.grey.shade700)), selected: seleccionado, selectedColor: Colors.teal.shade100, backgroundColor: Colors.grey.shade200, onSelected: (val) { setState(() { _filtroActual = filtro; }); });
                    }).toList(),
                  ),
                ),
                // BOTÓN CAMBIAR ROL (ADMIN/OBSERVER) AÑADIDO AQUÍ
                IconButton(
                  icon: Icon(_rolUsuario == 'admin' ? Icons.security : Icons.remove_red_eye, size: 20, color: _rolUsuario == 'admin' ? Colors.blue : Colors.grey),
                  onPressed: _cambiarRol,
                  tooltip: 'Cambiar Rol (Admin/Observer)',
                  padding: EdgeInsets.zero,
                ),
                // BOTÓN EXPORTAR INTEGRADO AQUÍ
                TextButton.icon(
                  onPressed: _abrirMenuExportacion, 
                  icon: const Icon(Icons.download, size: 18, color: Colors.teal), 
                  label: const Text('Exportar', style: TextStyle(color: Colors.teal, fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
                ),
              ],
            ),
          ),
          
          // 3. TARJETA DE BALANCE (AHORA DEBAJO DE LOS CONTROLES)
          Container(
            width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: saldoAFavor ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: saldoAFavor ? Colors.green.shade200 : Colors.red.shade200)),
            child: Column(
              children: [
                Text(saldoAFavor ? 'Balance Total a tu favor' : 'Balance Total en contra', style: TextStyle(color: saldoAFavor ? Colors.green : Colors.red)),
                const SizedBox(height: 8),
                Text('${saldoAFavor ? '+' : ''} ${balanceFinal.toStringAsFixed(2)} €', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: saldoAFavor ? Colors.green : Colors.red)),
              ],
            ),
          ),
          
          // 4. BOTÓN LIQUIDAR DEUDA (SI APLICA)
          if (balanceFinal != 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OutlinedButton.icon(
                onPressed: _abrirLiquidacionAvanzada, icon: const Icon(Icons.checklist_rtl, size: 18), label: const Text('Liquidar Deuda Acumulada (Seleccionar)'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.teal.shade800, side: BorderSide(color: Colors.teal.shade200)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Historial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gastosMostrados.length,
              itemBuilder: (context, index) {
                final gasto = gastosMostrados[index];
                final int indexReal = listaGastos.indexOf(gasto);
                bool esAcreedorReal = gasto.esDevolucion ? gasto.soyDeudor : !gasto.soyDeudor;
                bool esperandoValidacion = gasto.pagoPendienteValidacion > 0;

                Color colorDeFondo;
                if (gasto.enDisputa) { colorDeFondo = Colors.red.shade50; } else if (gasto.estaPagado) { colorDeFondo = Colors.grey.shade100; } else if (esAcreedorReal) { colorDeFondo = Colors.teal.shade50; } else { colorDeFondo = Colors.orange.shade50; }

                return Card(
                  elevation: gasto.estaPagado ? 0 : 2, color: colorDeFondo, margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: gasto.enDisputa ? Colors.red : (gasto.estaPagado ? Colors.transparent : (!esAcreedorReal ? Colors.orange.shade200 : Colors.teal.shade200)))),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: gasto.estaPagado ? Colors.grey.shade400 : (gasto.enDisputa ? Colors.red : _getColorPorCategoria(gasto.categoria)), child: Icon(gasto.estaPagado ? Icons.history : (gasto.enDisputa ? Icons.gavel : _getIconoPorCategoria(gasto.categoria)), color: Colors.white)),
                    title: Row(
                      children: [
                        Expanded(child: Text(gasto.titulo, style: TextStyle(decoration: gasto.estaPagado ? TextDecoration.lineThrough : null, color: gasto.enDisputa ? Colors.red : (gasto.estaPagado ? Colors.grey : Colors.black), fontWeight: gasto.enDisputa ? FontWeight.bold : FontWeight.normal))),
                        if (gasto.esExtraordinario && !gasto.esDevolucion) const Icon(Icons.star, size: 14, color: Colors.purple), 
                        if (gasto.esDevolucion) const Icon(Icons.currency_exchange, size: 14, color: Colors.teal), 
                        if (esperandoValidacion) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.pending_actions, size: 14, color: Colors.orange)),
                      ],
                    ),
                    
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gasto.enDisputa ? '⚠️ EN DISPUTA' : (gasto.estaPagado ? 'Liquidado el ${_formatearFecha(gasto.fecha)}' : (esperandoValidacion ? '🕒 Esperando validación del pago...' : (!esAcreedorReal ? 'Debes pagar tu parte' : 'Te deben este dinero')))),
                        if (gasto.fechaLimite != null && !gasto.estaPagado && !gasto.enDisputa) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text('⏳ Vence: ${_formatearFecha(gasto.fechaLimite!)}', style: TextStyle(fontSize: 11, color: Colors.red.shade800, fontWeight: FontWeight.bold))),
                        if (gasto.cantidadPagada > 0 && !gasto.estaPagado) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text('💰 Abonado: ${gasto.cantidadPagada.toStringAsFixed(2)}€', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${!esAcreedorReal ? '-' : '+'}${_redondear(gasto.miParte - gasto.cantidadPagada).toStringAsFixed(2)} €', style: TextStyle(color: gasto.enDisputa ? Colors.red : (gasto.estaPagado ? Colors.grey : (esperandoValidacion ? Colors.orange : (!esAcreedorReal ? Colors.red : Colors.green))), fontWeight: FontWeight.bold, decoration: (gasto.estaPagado || gasto.enDisputa) ? TextDecoration.lineThrough : null)),
                        if (gasto.estaPagado) const Text('PAGADO', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    onTap: () => _mostrarDetalleGasto(context, gasto, indexReal),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _rolUsuario == 'observer' ? null : FloatingActionButton(onPressed: () => _mostrarMenuOpciones(context), backgroundColor: Colors.teal, child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}