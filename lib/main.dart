import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/theme/app_theme.dart';
import 'package:oksigen24medis_mobile2/core/state/auth_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/dashboard_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/warehouse_provider.dart';
import 'package:oksigen24medis_mobile2/core/state/transaction_provider.dart';
import 'package:oksigen24medis_mobile2/features/auth/login_screen.dart';
import 'package:oksigen24medis_mobile2/features/dashboard/dashboard_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Oksigen24App());
}

class Oksigen24App extends StatelessWidget {
  const Oksigen24App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => WarehouseProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        title: 'Oksigen24 Medis',
        debugShowCheckedModeBanner: false,
        theme: AppThemeData.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show splash/spinner screen during initialization
    if (!authProvider.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF0055FF),
              ),
              SizedBox(height: 16),
              Text(
                'Menginisialisasi aplikasi...',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      return const DashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}
