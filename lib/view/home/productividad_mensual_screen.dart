import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../viewmodel/cartera_viewmodel.dart';

class ProductividadMensualScreen extends StatefulWidget {
  const ProductividadMensualScreen({super.key});

  @override
  State<ProductividadMensualScreen> createState() => _ProductividadMensualScreenState();
}

class _ProductividadMensualScreenState extends State<ProductividadMensualScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarteraViewModel>().fetchProductividadMensual();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CarteraViewModel>();
    const scotiaRed = Color(0xFFED1C24);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Productividad del Equipo", style: TextStyle(color: Colors.white)),
        backgroundColor: scotiaRed,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _generatePDF(viewModel.productividadAsesores)),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator(color: scotiaRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Comparativo de Solicitudes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 24),
                  SizedBox(height: 250, child: _buildBarChart(viewModel.productividadAsesores)),
                  const SizedBox(height: 32),
                  const Text("Resumen Detallado", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  _buildTable(viewModel.productividadAsesores),
                ],
              ),
            ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: e.value['enviadas'].toDouble(), color: Colors.grey[400], width: 10),
            BarChartRodData(toY: e.value['aprobadas'].toDouble(), color: Colors.green, width: 10),
            BarChartRodData(toY: e.value['desembolsadas'].toDouble(), color: Colors.blue, width: 10),
          ]);
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            if (v < 0 || v >= data.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 8), child: Text(data[v.toInt()]['nombre'].split(' ')[0], style: const TextStyle(fontSize: 10)));
          })),
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> data) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Asesor")),
            DataColumn(label: Text("Env.")),
            DataColumn(label: Text("Aprob.")),
            DataColumn(label: Text("Desem.")),
            DataColumn(label: Text("Monto")),
          ],
          rows: data.map((a) => DataRow(cells: [
            DataCell(Text(a['nombre'])),
            DataCell(Text(a['enviadas'].toString())),
            DataCell(Text(a['aprobadas'].toString())),
            DataCell(Text(a['desembolsadas'].toString())),
            DataCell(Text("S/ ${a['monto']}")),
          ])).toList(),
        ),
      ),
    );
  }

  Future<void> _generatePDF(List<Map<String, dynamic>> data) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Column(children: [
      pw.Header(level: 0, child: pw.Text("Productividad Mensual de Fuerza de Ventas")),
      pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(
        headers: ['Asesor', 'Enviadas', 'Aprobadas', 'Desembolsadas', 'Monto Total'],
        data: data.map((a) => [a['nombre'], a['enviadas'], a['aprobadas'], a['desembolsadas'], 'S/ ${a['monto']}']).toList(),
      ),
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}