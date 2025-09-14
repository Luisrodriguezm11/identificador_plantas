// frontend/lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import '../services/detection_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DetectionService _detectionService = DetectionService();
  // Ahora la lista del historial es una variable de estado, no un Future
  List<dynamic>? _historyList;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // Función para cargar o recargar el historial
  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await _detectionService.getHistory();
      setState(() {
        _historyList = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // --- NUEVA FUNCIÓN PARA MANEJAR EL BORRADO ---
  Future<void> _deleteItem(int analysisId, int index) async {
    // Mostrar diálogo de confirmación
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: const Text('¿Estás seguro de que quieres borrar este análisis? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // No confirmar
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Sí confirmar
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Si el usuario no confirma, no hacer nada
    if (confirmed != true) return;

    try {
      final success = await _detectionService.deleteHistoryItem(analysisId);
      if (success) {
        // Si el borrado fue exitoso, actualiza la UI al instante
        setState(() {
          _historyList!.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Análisis borrado con éxito'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historial de Análisis"),
        backgroundColor: Colors.green[700],
      ),
      // Usamos un RefreshIndicator para poder recargar el historial deslizando hacia abajo
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _historyList!.isEmpty
                  ? const Center(child: Text('No hay análisis en tu historial.'))
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      child: ListView.builder(
                        itemCount: _historyList!.length,
                        itemBuilder: (context, index) {
                          final analysis = _historyList![index];
                          final confidence = (analysis['confianza'] * 100).toStringAsFixed(1);
                          final fecha = DateTime.parse(analysis['fecha_analisis']);
                          final fechaFormateada = "${fecha.day}/${fecha.month}/${fecha.year}";

                          return Card(
                            margin: const EdgeInsets.all(10.0),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Imagen en miniatura
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      analysis['url_imagen'],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      // Muestra un loader mientras carga la imagen
                                      loadingBuilder: (context, child, progress) {
                                        return progress == null ? child : const Center(child: CircularProgressIndicator());
                                      },
                                      // Muestra un ícono de error si la imagen no carga
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.error, size: 40);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // --- CAMBIO AQUÍ ---
                                  // Envolvemos la columna en un Expanded
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          analysis['resultado_prediccion'],
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 5),
                                        Text("Confianza: $confidence%"),
                                        Text("Fecha: $fechaFormateada"),
                                      ],
                                    ),
                                  ),
                                  // --- FIN DEL CAMBIO ---
                                  // Botón de borrado
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deleteItem(analysis['id_analisis'], index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}