import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reward_token_app/admin_registration/admin_registration_page.dart';
import 'package:reward_token_app/customer_registration/customer_registration_page.dart';
import 'package:reward_token_app/employee_registration/employee_registration_page.dart';
import 'package:reward_token_app/home/home_page.dart';
import 'package:reward_token_app/qr_scan/qr_scan_page.dart';
import 'package:reward_token_app/records/activity_records_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  bool _isAdmin = false;
  bool _loadingRole = true;

  void _handleQrOperationSuccess(String message) {
    if (!mounted) return;
    setState(() => _index = 0);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _loadingRole = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(uid)
          .get();
      final role = doc.data()?['role'] as String?;

      if (!mounted) return;
      setState(() {
        _isAdmin = role == 'admin';
        _loadingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _loadingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = <String>[
      'Home',
      'QR Scan',
      'Customer Registration',
      'Records',
      if (_isAdmin) 'Employee Registration',
      if (_isAdmin) 'Admin Registration',
    ];

    final pages = <Widget>[
      const HomePage(),
      QrScanBody(
        active: _index == 1,
        onOperationSuccess: _handleQrOperationSuccess,
      ),
      const CustomerRegistrationForm(),
      const ActivityRecordsPage(),
      if (_isAdmin) const EmployeeRegistrationForm(),
      if (_isAdmin) const AdminRegistrationForm(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(
        icon: Icon(Icons.qr_code_scanner),
        label: 'QR Scan',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.app_registration),
        label: 'Customer Registration',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'Records',
      ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.badge_outlined),
          label: 'Employee Registration',
        ),
      if (_isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: 'Admin Registration',
        ),
    ];

    if (_index >= pages.length) {
      _index = 0;
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: _loadingRole
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: items,
      ),
    );
  }
}
