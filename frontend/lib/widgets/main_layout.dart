// frontend/lib/widgets/main_layout.dart

import 'package:flutter/material.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/auth_check_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/detection_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/widgets/animated_bubble_background.dart';

final GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();

class MainLayout extends StatelessWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // El fondo animado SIEMPRE estará en la base del Stack.
          const AnimatedBubbleBackground(),
          Navigator(
            key: mainNavigatorKey,
            initialRoute: '/auth_check', 
            onGenerateRoute: (settings) {
              Widget page;
              switch (settings.name) {
                case '/auth_check':
                  page = const AuthCheckScreen();
                  break;
                case '/dashboard':
                  page = const DashboardScreen();
                  break;
                case '/history':
                  final args = settings.arguments as Map<String, dynamic>?;
                  page = HistoryScreen(highlightedAnalysisId: args?['highlightedAnalysisId']);
                  break;
                case '/trash':
                  page = const TrashScreen();
                  break;
                case '/dose-calculation':
                  page = const DoseCalculationScreen();
                  break;
                case '/detection':
                  page = const DetectionScreen();
                   break;
                case '/admin-dashboard':
                   page = const AdminDashboardScreen();
                   break;
                default:
                  page = const AuthCheckScreen();
              }
              return PageRouteBuilder(
                pageBuilder: (_, __, ___) => page,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
            },
          ),
        ],
      ),
    );
  }
}