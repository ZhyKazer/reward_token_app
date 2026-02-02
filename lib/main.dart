import 'package:flutter/material.dart';
import 'package:reward_token_app/app_shell.dart';
import 'package:reward_token_app/customer_registration/customer_registration_page.dart';
import 'package:reward_token_app/qr_scan/qr_scan_page.dart';
import 'package:reward_token_app/state/customer_store.dart';
import 'package:reward_token_app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final CustomerStore _store = CustomerStore();

  @override
  Widget build(BuildContext context) {
    return CustomerStoreScope(
      notifier: _store,
      child: MaterialApp(
        title: 'Reward Token App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routes: {
          CustomerRegistrationPage.routeName: (_) => const CustomerRegistrationPage(),
          QrScanPage.routeName: (_) => const QrScanPage(),
        },
        home: const AppShell(),
      ),
    );
  }
}
