import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reward_token_app/admin_registration/admin_registration_page.dart';
import 'package:reward_token_app/customer_registration/customer_registration_page.dart';
import 'package:reward_token_app/employee_registration/employee_registration_page.dart';
import 'package:reward_token_app/home/home_page.dart';
import 'package:reward_token_app/qr_scan/points_qr_scan_page.dart';
import 'package:reward_token_app/records/activity_records_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _scanFabExpanded = false;

  bool _isAdmin = false;
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _openQrScan(PointsOperation operation) async {
    setState(() {
      _scanFabExpanded = false;
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PointsQrScanPage(operation: operation),
      ),
    );
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
      'Customer Registration',
      'Records',
      if (_isAdmin) 'Employee Registration',
      if (_isAdmin) 'Admin Registration',
    ];

    final pages = <Widget>[
      const HomePage(),
      const CustomerRegistrationForm(),
      const ActivityRecordsPage(),
      if (_isAdmin) const EmployeeRegistrationForm(),
      if (_isAdmin) const AdminRegistrationForm(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _loadingRole
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_scanFabExpanded) ...[
                  FloatingActionButton.extended(
                    heroTag: 'addPointsFab',
                    onPressed: () => _openQrScan(PointsOperation.add),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Points'),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'usePointsFab',
                    onPressed: () => _openQrScan(PointsOperation.use),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Use Points'),
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton(
                  heroTag: 'qrMainFab',
                  onPressed: () {
                    setState(() {
                      _scanFabExpanded = !_scanFabExpanded;
                    });
                  },
                  child: Icon(
                    _scanFabExpanded ? Icons.close : Icons.qr_code_scanner,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) {
          setState(() {
            _scanFabExpanded = false;
            _index = value;
          });
        },
        items: items,
      ),
    );
  }
}
