// frontend/lib/screens/trash_screen.dart

import 'package:flutter/material.dart';
import '../services/detection_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final DetectionService _detectionService = DetectionService();
  List<dynamic>? _trashedList;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrashedItems();
  }

  Future<void> _fetchTrashedItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _detectionService.getTrashedItems();
      setState(() {
        _trashedList = items;
        _isLoading = false;
      });
    } catch (e) {
      // Manejo de errores
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _restoreItem(int analysisId, int index) async {
      final success = await _detectionService.restoreHistoryItem(analysisId);
      if (success) {
        setState(() => _trashedList!.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Análisis restaurado'), backgroundColor: Colors.green));
        }
      }
  }

  Future<void> _permanentlyDeleteItem(int analysisId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrado Permanente'),
        content: const Text('Esta acción no se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Borrar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _detectionService.permanentlyDeleteItem(analysisId);
      if (success) {
        setState(() => _trashedList!.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrado permanentemente'), backgroundColor: Colors.orange));
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Papelera")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashedList == null || _trashedList!.isEmpty
              ? const Center(child: Text('La papelera está vacía.'))
              : ListView.builder(
                  itemCount: _trashedList!.length,
                  itemBuilder: (context, index) {
                    final item = _trashedList![index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.network(item['url_imagen'], width: 50, height: 50, fit: BoxFit.cover),
                        ),
                        title: Text(item['resultado_prediccion']),
                        subtitle: const Text('En la papelera'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_from_trash, color: Colors.blue),
                              tooltip: 'Restaurar',
                              onPressed: () => _restoreItem(item['id_analisis'], index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              tooltip: 'Borrar permanentemente',
                              onPressed: () => _permanentlyDeleteItem(item['id_analisis'], index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}