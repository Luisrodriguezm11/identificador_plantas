// frontend/lib/screens/dose_calculation_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'dart:ui';

class DoseCalculationScreen extends StatefulWidget {
  final bool isNavExpanded;
  const DoseCalculationScreen({super.key, this.isNavExpanded = true});

  @override
  State<DoseCalculationScreen> createState() => _DoseCalculationScreenState();
}

class _DoseCalculationScreenState extends State<DoseCalculationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  late bool _isNavExpanded;

  // Controladores para los nuevos campos de texto
  final _productDoseController = TextEditingController();
  final _waterAmountController = TextEditingController();
  final _plantCountController = TextEditingController();

  // Variables de estado para los menús desplegables
  String _productDoseUnit = 'ml'; // Valor inicial
  String _waterUnit = 'litros'; // Valor inicial

  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _isNavExpanded = widget.isNavExpanded;
  }

  void _performLocalCalculation() {
    if (_formKey.currentState!.validate()) {
      // 1. Obtener los valores de los campos
      final double productDose = double.parse(_productDoseController.text);
      final double waterAmount = double.parse(_waterAmountController.text);
      final int plantCount = int.parse(_plantCountController.text);

      // 2. Convertir todo a una unidad base (mililitros)
      double productDoseInMl = productDose;
      if (_productDoseUnit == 'onzas') {
        productDoseInMl = productDose * 29.5735; // 1 onza fluida = 29.5735 ml
      }

      double waterAmountInMl = waterAmount;
      if (_waterUnit == 'litros') {
        waterAmountInMl = waterAmount * 1000; // 1 litro = 1000 ml
      }

      // 3. Realizar el cálculo final
      final double totalProductMl = productDoseInMl * plantCount;
      final double totalWaterLiters = (waterAmountInMl * plantCount) / 1000;

      // 4. Mostrar el resultado
      setState(() {
        _resultMessage =
            "Necesitarás:\n"
            "${totalProductMl.toStringAsFixed(2)} ml de producto.\n"
            "${totalWaterLiters.toStringAsFixed(2)} litros de agua.";
      });
    }
  }

  // --- La navegación no cambia, solo los índices ---
  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: HistoryScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: TrashScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 3:
        break; // Ya estamos aquí
      case 4:
        _logout(context);
        break;
    }
  }

  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await _authService.deleteToken();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Row(
            children: [
              SideNavigationRail(
                isExpanded: _isNavExpanded,
                selectedIndex: 3,
                isAdmin: false, // <-- Añade el argumento requerido aquí (ajusta según tu lógica)
                onToggle: () => setState(() => _isNavExpanded = !_isNavExpanded),
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("Cálculo de Dosis Dinámico", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 32),
                                  
                                  // --- Campos dinámicos ---
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _productDoseController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(labelText: "Dosis por planta"),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      DropdownButton<String>(
                                        value: _productDoseUnit,
                                        dropdownColor: Colors.grey[800],
                                        style: const TextStyle(color: Colors.white),
                                        onChanged: (String? newValue) => setState(() => _productDoseUnit = newValue!),
                                        items: <String>['ml', 'onzas'].map<DropdownMenuItem<String>>((String value) {
                                          return DropdownMenuItem<String>(value: value, child: Text(value));
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _waterAmountController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(labelText: "Agua por planta"),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      DropdownButton<String>(
                                        value: _waterUnit,
                                        dropdownColor: Colors.grey[800],
                                        style: const TextStyle(color: Colors.white),
                                        onChanged: (String? newValue) => setState(() => _waterUnit = newValue!),
                                        items: <String>['ml', 'litros'].map<DropdownMenuItem<String>>((String value) {
                                          return DropdownMenuItem<String>(value: value, child: Text(value));
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: _plantCountController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(labelText: "Número total de plantas"),
                                    keyboardType: TextInputType.number,
                                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                                  ),
                                  const SizedBox(height: 40),
                                  ElevatedButton(
                                    onPressed: _performLocalCalculation,
                                    child: const Text("Calcular"),
                                  ),
                                  const SizedBox(height: 32),
                                  if (_resultMessage != null)
                                    Text(
                                      _resultMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}