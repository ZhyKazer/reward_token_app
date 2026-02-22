import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:reward_token_app/qr_scan/add_points_page.dart';
import 'package:reward_token_app/qr_scan/use_points_page.dart';
import 'package:reward_token_app/state/customer_store.dart';

enum PointsOperation { add, use }

extension _PointsOperationText on PointsOperation {
  String get title {
    switch (this) {
      case PointsOperation.add:
        return 'Scan QR to Add Points';
      case PointsOperation.use:
        return 'Scan QR to Use Points';
    }
  }
}

class PointsQrScanPage extends StatefulWidget {
  const PointsQrScanPage({super.key, required this.operation});

  final PointsOperation operation;

  @override
  State<PointsQrScanPage> createState() => _PointsQrScanPageState();
}

class _PointsQrScanPageState extends State<PointsQrScanPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handlingScan = false;
  String? _lastValue;

  bool _looksLikeUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value.trim());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restartScan() async {
    _handlingScan = false;
    _lastValue = null;
    if (mounted) {
      await _controller.start();
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (!mounted || _handlingScan) return;

    String? value;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        value = raw.trim();
        break;
      }
    }
    if (value == null) return;
    if (value == _lastValue) return;

    _handlingScan = true;
    _lastValue = value;
    await _controller.stop();

    if (!_looksLikeUuid(value)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid QR code.')));
      await _restartScan();
      return;
    }

    if (!mounted) return;
    final store = CustomerStoreScope.of(context);
    final customer = store.findByUuid(value);
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer not found for this QR code.')),
      );
      await _restartScan();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm User'),
          content: Text(
            'Scanned user:\n${customer.fullName}\n\nIs this correct?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmed == true) {
      if (widget.operation == PointsOperation.add) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => AddPointsPage(customerUuid: customer.uuid),
          ),
        );
      } else {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => UsePointsPage(customerUuid: customer.uuid),
          ),
        );
      }
      return;
    }

    await _restartScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.operation.title)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Align the QR code inside the frame',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}