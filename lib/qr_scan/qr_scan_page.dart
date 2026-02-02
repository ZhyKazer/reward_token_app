import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:reward_token_app/qr/customer_qr_card_page.dart';
import 'package:reward_token_app/state/customer_store.dart';

class QrScanPage extends StatelessWidget {
  const QrScanPage({super.key});

  static const routeName = '/qr-scan';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scan'),
      ),
      body: const QrScanBody(active: true),
    );
  }
}

class QrScanBody extends StatefulWidget {
  const QrScanBody({super.key, required this.active});

  final bool active;

  @override
  State<QrScanBody> createState() => _QrScanBodyState();
}

class _QrScanBodyState extends State<QrScanBody> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handlingScan = false;
  String? _lastValue;
  bool _torchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant QrScanBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _controller.start();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.active) return;

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

  Future<bool> _showScanResultSheet(
    BuildContext context, {
    required String scannedValue,
    required Customer? customer,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scanned QR',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(scannedValue),
                const SizedBox(height: 12),
                if (customer != null) ...[
                  Text(
                    customer.fullName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('Points: ${customer.points}'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Open customer card'),
                  ),
                ] else ...[
                  Text(
                    'Customer not found in this device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan again'),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (!mounted) return;
    if (!widget.active) return;
    if (_handlingScan) return;

    String? value;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        value = v.trim();
        break;
      }
    }
    if (value == null) return;
    if (value == _lastValue) return;

    _handlingScan = true;
    _lastValue = value;

    await _controller.stop();
    if (!mounted) return;

    final store = CustomerStoreScope.of(context);
    final customer = store.findByUuid(value);

    final openCustomer = await _showScanResultSheet(
      context,
      scannedValue: value,
      customer: customer,
    );
    if (!mounted) return;

    if (openCustomer && customer != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CustomerQrCardPage(customer: customer),
        ),
      );
      if (!mounted) return;
    }

    _handlingScan = false;
    _lastValue = null;
    if (widget.active) {
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) async => _handleDetect(capture),
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'Camera unavailable',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (!mounted) return;
                      setState(() => _torchOn = !_torchOn);
                    },
                    icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                    tooltip: _torchOn ? 'Flash on' : 'Flash off',
                  ),
                  IconButton.filledTonal(
                    onPressed: () async {
                      await _controller.switchCamera();
                      if (!mounted) return;
                      setState(() {
                        _cameraFacing = _cameraFacing == CameraFacing.back
                            ? CameraFacing.front
                            : CameraFacing.back;
                      });
                    },
                    icon: Icon(
                      _cameraFacing == CameraFacing.back
                          ? Icons.camera_front
                          : Icons.camera_rear,
                    ),
                    tooltip: 'Switch camera',
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      'Point camera at the customer QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
