import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:reward_token_app/admin_registration/admin_registration_page.dart';
import 'package:reward_token_app/auth/login_page.dart';
import 'package:reward_token_app/app_shell.dart';
import 'package:reward_token_app/customer_registration/customer_registration_page.dart';
import 'package:reward_token_app/employee_registration/employee_registration_page.dart';
import 'package:reward_token_app/qr_scan/qr_scan_page.dart';
import 'package:reward_token_app/state/customer_store.dart';
import 'package:reward_token_app/theme/app_theme.dart';
import 'package:reward_token_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.requireLogin = true});

  final bool requireLogin;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final CustomerStore _store = CustomerStore();

  String? _employeeId;

  @override
  void initState() {
    super.initState();
    // In widget tests, Firebase is usually not initialized.
    if (Firebase.apps.isNotEmpty) {
      _store.startSync();
    }
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = !widget.requireLogin || _employeeId != null;
    return CustomerStoreScope(
      notifier: _store,
      child: MaterialApp(
        title: 'Reward Token App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routes: {
          CustomerRegistrationPage.routeName: (_) => const CustomerRegistrationPage(),
          EmployeeRegistrationPage.routeName: (_) => const EmployeeRegistrationPage(),
          AdminRegistrationPage.routeName: (_) => const AdminRegistrationPage(),
          QrScanPage.routeName: (_) => const QrScanPage(),
        },
        home: loggedIn
            ? const AppShell()
            : LoginPage(
                onLoggedIn: ({required employeeId, required username}) {
                  setState(() {
                    _employeeId = employeeId;
                  });
                },
              ),
      ),
    );
  }
}
