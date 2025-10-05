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
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'package:frontend/widgets/main_layout.dart';
// --> 1. AÑADE LA IMPORTACIÓN DE TU SERVICIO
import 'package:frontend/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // --> 2. ENVUELVE LA APP CON MULTIPROVIDER
  runApp(
    MultiProvider(
      providers: [
        // Tu provider de tema que ya tenías
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        
        // El provider que faltaba para AuthService
        Provider<AuthService>(create: (context) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
       return MaterialApp(
          title: 'Identificador de Plantas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MainLayout(),
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