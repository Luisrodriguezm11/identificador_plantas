// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:frontend/config/theme_provider.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/admin_user_list_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/detection_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/manage_recommendations_screen.dart';
import 'package:frontend/screens/register_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:provider/provider.dart';
//import 'screens/auth_check_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'package:frontend/widgets/main_layout.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Envolvemos la app con el ChangeNotifierProvider para que el tema esté disponible en todos los widgets.
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos un Consumer para que MaterialApp se redibuje cuando cambie el tema.
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
       return MaterialApp(
    title: 'Identificador de Plantas',

          debugShowCheckedModeBanner: false,

          // --- 1. AÑADIMOS DE NUEVO ESTAS LÍNEAS ---
          theme: AppTheme.lightTheme,       // Asignamos el tema claro
          darkTheme: AppTheme.darkTheme,    // Asignamos el tema oscuro
          themeMode: themeProvider.themeMode, // El provider vuelve a decidir cuál mostrar


    home: const MainLayout(), // <-- AQUÍ ESTÁ EL CAMBIO
    // Tus rutas se quedan como están, MaterialApp es suficientemente
    // inteligente para usarlas con el nuevo Navigator.
    routes: {
      '/login': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/dashboard': (context) => const DashboardScreen(),
      '/history': (context) => const HistoryScreen(),
      '/trash': (context) => const TrashScreen(),
      '/detection': (context) => const DetectionScreen(),
      '/dose-calculation': (context) => const DoseCalculationScreen(),
      '/admin-dashboard': (context) => const AdminDashboardScreen(),
      '/admin-users': (context) => const AdminUserListScreen(),
      '/manage-recommendations': (context) => const ManageRecommendationsScreen(),
    },
       );
      },
    );
  }
}