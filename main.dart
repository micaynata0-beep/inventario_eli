import 'dart:convert';
import 'dart:io'; // Librería local
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart'; // Para rutas locales
import 'package:share_plus/share_plus.dart'; // Para menú compartir de iOS

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIAJE DE MI AMIGO ELI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const InventoryPage(),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final Map<String, TextEditingController> _controllers = {
    'Proveedor': TextEditingController(),
    'Codigo de proovedor': TextEditingController(),
    'Articulo': TextEditingController(),
    'Precio en Yuan': TextEditingController(),
    'Precio en Dolar': TextEditingController(),
    'Unidades por caja': TextEditingController(),
    'M3 (mts cubicos)': TextEditingController(),
    'Peso KG': TextEditingController(),
    'Cantidad minima de compra': TextEditingController(),
    'Contacto agendado': TextEditingController(),
    'Observaciones': TextEditingController(),
  };

  List<Map<String, String>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('inventory_data');
    if (storedData != null) {
      setState(() {
        _records = List<Map<String, String>>.from(
            json.decode(storedData).map((x) => Map<String, String>.from(x))
        );
      });
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inventory_data', json.encode(_records));
  }

  void _addRecord() {
    Map<String, String> newEntry = {};
    _controllers.forEach((key, controller) => newEntry[key] = controller.text);

    setState(() {
      _records.add(newEntry);
    });
    _saveToStorage();
    _clearInputs();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registro añadido a la lista")));
  }

  void _clearInputs() {
    for (var controller in _controllers.values) {
      controller.clear();
    }
  }

  void _deleteAllRecords() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Borrar Listado"),
        content: const Text("¿Estás seguro de que quieres borrar todos los registros?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(onPressed: () {
            setState(() => _records.clear());
            _saveToStorage();
            Navigator.pop(context);
          }, child: const Text("Borrar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // EXPORTACIÓN LOCAL PARA IPHONE
  Future<void> _exportToExcel() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar")));
      return;
    }

    var excel = Excel.createExcel();
    excel.delete('Sheet1');
    Sheet sheetObject = excel['Registros'];

    List<CellValue> headers = _controllers.keys.map((h) => TextCellValue(h)).toList();
    sheetObject.appendRow(headers);

    for (var row in _records) {
      List<CellValue> dataRow = _controllers.keys.map((k) => TextCellValue(row[k] ?? "")).toList();
      sheetObject.appendRow(dataRow);
    }

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      // 1. Obtener carpeta temporal del iPhone
      final directory = await getTemporaryDirectory();
      final fileName = "Inventario_${DateTime.now().day}_${DateTime.now().hour}_${DateTime.now().minute}.xlsx";
      final filePath = "${directory.path}/$fileName";

      // 2. Guardar el archivo físicamente
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // 3. Abrir menú de compartir de iOS (Aquí puedes elegir Guardar en Archivos o WeChat)
      await Share.shareXFiles([XFile(filePath)], text: 'Mi Inventario Eli');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VIAJE DE MI AMIGO ELI"),
        centerTitle: true,
        backgroundColor: Colors.blue[100],
      ),
      body: SingleChildScrollView( // Todo en una sola columna hacia abajo
        child: Column(
          children: [
            // SECCIÓN 1: FORMULARIO
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ..._controllers.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: TextField(
                          controller: e.value,
                          decoration: InputDecoration(
                              labelText: e.key,
                              border: const OutlineInputBorder(),
                              isDense: true
                          ),
                        ),
                      )).toList(),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(onPressed: _addRecord, icon: const Icon(Icons.add_circle), label: const Text("Agregar")),
                          ElevatedButton.icon(onPressed: _clearInputs, icon: const Icon(Icons.cleaning_services), label: const Text("Borrar Líneas")),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // SECCIÓN 2: BOTONES DE ACCIÓN GLOBAL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.file_download),
                    label: const Text("EXPORTAR EXCEL"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[100]),
                  ),
                  ElevatedButton.icon(
                    onPressed: _deleteAllRecords,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("BORRAR LISTA"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100]),
                  ),
                ],
              ),
            ),

            const Divider(height: 40, thickness: 2),

            // SECCIÓN 3: TABLA DE REGISTROS (ABAJO)
            const Text("Registros Guardados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("No hay registros todavía."),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _controllers.keys.map((k) => DataColumn(label: Text(k))).toList(),
                  rows: _records.map((r) => DataRow(
                    cells: _controllers.keys.map((k) => DataCell(Text(r[k] ?? ""))).toList(),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 50), // Espacio al final
          ],
        ),
      ),
    );
  }
}