import 'package:flutter/material.dart';
import 'package:reward_token_app/customer_registration/customer_registration_page.dart';
import 'package:reward_token_app/home/home_page.dart';
import 'package:reward_token_app/qr_scan/qr_scan_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = <String>[
    'Home',
    'QR Scan',
    'Customer Registration',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          QrScanBody(active: _index == 1),
          const CustomerRegistrationForm(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'QR Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.app_registration),
            label: 'Customer Registration',
          ),
        ],
      ),
    );
  }
}
