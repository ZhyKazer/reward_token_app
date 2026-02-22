import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:reward_token_app/audit/audit_log_service.dart';
import 'package:reward_token_app/qr/customer_qr_card_page.dart';
import 'package:reward_token_app/state/customer_store.dart';

class QrScanPage extends StatelessWidget {
  const QrScanPage({super.key});

  static const routeName = '/qr-scan';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scan')),
      body: const QrScanBody(active: true),
    );
  }
}

class QrScanBody extends StatefulWidget {
  const QrScanBody({super.key, required this.active, this.onOperationSuccess});

  final bool active;
  final ValueChanged<String>? onOperationSuccess;

  @override
  State<QrScanBody> createState() => _QrScanBodyState();
}

class _QrScanBodyState extends State<QrScanBody> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final ImagePicker _imagePicker = ImagePicker();

  bool _handlingScan = false;
  String? _lastValue;
  bool _torchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  bool _looksLikeUuid(String value) {
    // Accept a standard UUID string (case-insensitive).
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value.trim());
  }

  int _pointsFromPurchase(double purchasePrice) {
    // Rule: every 200 pesos spent earns 5 points.
    final blocks = (purchasePrice / 200).floor();
    return (blocks * 5).clamp(0, 1 << 30);
  }

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

  Future<_ScanSheetResult> _showScanResultSheet(
    BuildContext context, {
    required String scannedValue,
    required Customer? customer,
  }) async {
    final result = await Navigator.of(context).push<_ScanSheetResult>(
      MaterialPageRoute(
        builder: (_) => _ScanResultSheet(
          scannedValue: scannedValue,
          initialCustomer: customer,
          pointsFromPurchase: _pointsFromPurchase,
        ),
      ),
    );

    return result ?? const _ScanSheetResult(action: _ScanSheetAction.scanAgain);
  }

  Future<void> _processScannedValue(String value) async {
    if (!mounted) return;
    if (!widget.active) return;
    if (_handlingScan) return;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == _lastValue) return;

    _handlingScan = true;
    _lastValue = trimmed;

    await _controller.stop();
    if (!mounted) return;

    if (!_looksLikeUuid(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid QR code.')));
      _handlingScan = false;
      _lastValue = null;
      if (widget.active) {
        await _controller.start();
      }
      return;
    }

    final store = CustomerStoreScope.of(context);
    final customer = store.findByUuid(trimmed);

    final result = await _showScanResultSheet(
      context,
      scannedValue: trimmed,
      customer: customer,
    );
    if (!mounted) return;

    if (result.action == _ScanSheetAction.openCustomer && customer != null) {
      final updatedCustomer = store.findByUuid(trimmed) ?? customer;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CustomerQrCardPage(customer: updatedCustomer),
        ),
      );
      if (!mounted) return;
    }

    if (result.action == _ScanSheetAction.updatedPointsAndGoHome) {
      final message = result.message ?? 'Points has been successfully added.';
      widget.onOperationSuccess?.call(message);
    }

    _handlingScan = false;
    _lastValue = null;
    if (widget.active &&
        result.action != _ScanSheetAction.updatedPointsAndGoHome) {
      await _controller.start();
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    String? value;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        value = v.trim();
        break;
      }
    }
    if (value == null) return;
    await _processScannedValue(value);
  }

  Future<void> _importQrFromGallery() async {
    if (!mounted) return;
    if (!widget.active) return;
    if (_handlingScan) return;

    try {
      await _controller.stop();
      if (!mounted) return;

      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;

      if (image == null) {
        if (widget.active) await _controller.start();
        return;
      }

      final capture = await _controller.analyzeImage(image.path);
      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in that image.')),
        );
        if (widget.active) await _controller.start();
        return;
      }

      await _handleDetect(capture);
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import QR not supported on this device.'),
        ),
      );
      if (widget.active) await _controller.start();
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'channel-error') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Import QR is not ready. Fully stop the app and run again (native plugin registration).',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import QR: ${e.message ?? e.code}'),
          ),
        );
      }
      if (widget.active) await _controller.start();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to import QR: $e')));
      if (widget.active) await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Important: `IndexedStack` keeps inactive tabs mounted. Avoid building the
    // scanner widget while inactive so the camera isn't opened in the
    // background.
    if (!widget.active) {
      return const SizedBox.shrink();
    }

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
                        Text(error.toString(), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Positioned.fill(
              child: IgnorePointer(child: _QrScanOverlay()),
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
                    onPressed: _importQrFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    tooltip: 'Import QR from gallery',
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
                      'Align the QR code inside the frame',
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

class _QrScanOverlay extends StatelessWidget {
  const _QrScanOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final shortest = width < height ? width : height;

        final cutOutSize = shortest * 0.68;
        final left = (width - cutOutSize) / 2;
        final top = (height - cutOutSize) / 2;
        final cutOut = Rect.fromLTWH(left, top, cutOutSize, cutOutSize);

        return CustomPaint(
          painter: _QrScanOverlayPainter(
            cutOut: cutOut,
            maskColor: Colors.black.withValues(alpha: 0.55),
            borderColor: theme.colorScheme.primary.withValues(alpha: 0.95),
          ),
        );
      },
    );
  }
}

class _QrScanOverlayPainter extends CustomPainter {
  _QrScanOverlayPainter({
    required this.cutOut,
    required this.maskColor,
    required this.borderColor,
  });

  final Rect cutOut;
  final Color maskColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(cutOut, const Radius.circular(16)));

    final maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, maskPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOut, const Radius.circular(16)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final inset = 10.0;
    final cornerLen = cutOut.width * 0.13;
    final tl = cutOut.topLeft + Offset(inset, inset);
    final tr = cutOut.topRight + Offset(-inset, inset);
    final bl = cutOut.bottomLeft + Offset(inset, -inset);
    final br = cutOut.bottomRight + Offset(-inset, -inset);

    // Top-left
    canvas.drawLine(tl, tl + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(tl, tl + Offset(0, cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(tr, tr + Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(tr, tr + Offset(0, cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(bl, bl + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(bl, bl + Offset(0, -cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(br, br + Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(br, br + Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _QrScanOverlayPainter oldDelegate) {
    return oldDelegate.cutOut != cutOut ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class _ScanResultSheet extends StatefulWidget {
  const _ScanResultSheet({
    required this.scannedValue,
    required this.initialCustomer,
    required this.pointsFromPurchase,
  });

  final String scannedValue;
  final Customer? initialCustomer;
  final int Function(double purchasePrice) pointsFromPurchase;

  @override
  State<_ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<_ScanResultSheet> {
  static const Duration _addPointsCooldown = Duration(seconds: 2);

  final GlobalKey<FormState> _detailsFormKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _productController;

  Customer? _customer;
  bool _submitting = false;
  DateTime? _lastAddPointsAt;
  _PointsOperationMode? _mode;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _productController = TextEditingController();
    _customer = widget.initialCustomer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep points/name fresh if the store updated.
    if (_customer != null) {
      final store = CustomerStoreScope.of(context);
      _customer = store.findByUuid(_customer!.uuid) ?? _customer;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _productController.dispose();
    super.dispose();
  }

  Future<void> _continueStep() async {
    if (_stepIndex == 0) {
      if (_mode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an action first.')),
        );
        return;
      }
      setState(() => _stepIndex = 1);
      return;
    }

    await _submitAction();
  }

  void _cancelStep() {
    if (_stepIndex == 0) {
      Navigator.of(
        context,
      ).pop(const _ScanSheetResult(action: _ScanSheetAction.scanAgain));
      return;
    }
    setState(() => _stepIndex = 0);
  }

  Future<bool> _confirmAddPoints({
    required double purchasePrice,
    required int points,
    required String customerName,
    required String employeeName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm points update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: $customerName'),
              const SizedBox(height: 6),
              Text('Employee: $employeeName'),
              const SizedBox(height: 6),
              Text('Purchase Price: ${purchasePrice.toStringAsFixed(2)} pesos'),
              const SizedBox(height: 6),
              Text('Points to add: $points'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<bool> _confirmUsePoints({
    required int pointsToUse,
    required String customerName,
    required String employeeName,
    required String productName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm points usage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: $customerName'),
              const SizedBox(height: 6),
              Text('Employee: $employeeName'),
              const SizedBox(height: 6),
              Text('Product: $productName'),
              const SizedBox(height: 6),
              Text('Points to use: $pointsToUse'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _submitAction() async {
    if (_submitting) return;
    final mode = _mode;
    if (mode == null) return;
    if (!(_detailsFormKey.currentState?.validate() ?? false)) return;

    final customer = _customer;
    if (customer == null) return;

    final raw = _amountController.text.trim().replaceAll(',', '');

    double purchaseValue = 0;
    int pointsToAdd = 0;
    int pointsToUse = 0;
    String productName = '';

    if (mode == _PointsOperationMode.purchase) {
      final value = double.tryParse(raw);
      if (value == null || value <= 0) return;
      purchaseValue = value;
      pointsToAdd = widget.pointsFromPurchase(value);
      if (pointsToAdd <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase does not earn points.')),
        );
        return;
      }
    } else {
      final value = int.tryParse(raw);
      if (value == null || value <= 0) return;
      pointsToUse = value;

      productName = _productController.text.trim();
      if (productName.isEmpty) return;

      if (pointsToUse > customer.points) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer does not have enough points.'),
          ),
        );
        return;
      }
    }

    final now = DateTime.now();
    final lastAdd = _lastAddPointsAt;
    if (lastAdd != null && now.difference(lastAdd) < _addPointsCooldown) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment before adding points again.'),
        ),
      );
      return;
    }

    final actor = await AuditLogService.currentActor();
    if (!mounted) return;

    final computedName = customer.fullName.trim();
    final customerName = computedName.isNotEmpty
        ? computedName
        : (customer.firstName.isNotEmpty || customer.lastName.isNotEmpty)
        ? '${customer.firstName} ${customer.lastName}'.trim()
        : 'Unknown customer';

    if (mode == _PointsOperationMode.purchase) {
      final confirmed = await _confirmAddPoints(
        purchasePrice: purchaseValue,
        points: pointsToAdd,
        customerName: customerName,
        employeeName: actor.name,
      );
      if (!confirmed) return;
    } else {
      final confirmed = await _confirmUsePoints(
        pointsToUse: pointsToUse,
        customerName: customerName,
        employeeName: actor.name,
        productName: productName,
      );
      if (!confirmed) return;
    }

    if (!mounted) return;

    _lastAddPointsAt = DateTime.now();

    setState(() => _submitting = true);
    try {
      final store = CustomerStoreScope.of(context);
      final delta = mode == _PointsOperationMode.purchase
          ? pointsToAdd
          : -pointsToUse;
      final ok = await store.addPointsAndPersist(widget.scannedValue, delta);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Customer not found.')));
        return;
      }

      _customer = store.findByUuid(widget.scannedValue);

      if (mode == _PointsOperationMode.purchase) {
        await AuditLogService.logRecord(
          type: 'points_added',
          title: 'Customer points added',
          actor: actor,
          customerId: widget.scannedValue,
          customerName: customerName,
          purchasePrice: purchaseValue,
          pointsAdded: pointsToAdd,
        );
      } else {
        await AuditLogService.logRecord(
          type: 'points_used',
          title: 'Customer points used',
          actor: actor,
          customerId: widget.scannedValue,
          customerName: customerName,
          pointsAdded: -pointsToUse,
          metadata: <String, Object?>{'productName': productName},
        );
      }

      if (!mounted) return;
      final message = mode == _PointsOperationMode.purchase
          ? 'Points has been successfully added.'
          : 'Customer points has been successfully used.';

      Navigator.of(context).pop(
        _ScanSheetResult(
          action: _ScanSheetAction.updatedPointsAndGoHome,
          message: message,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;

    return Scaffold(
      appBar: AppBar(title: const Text('Scanned Customer')),
      body: SafeArea(
        child: customer == null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Scanned QR',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(widget.scannedValue),
                    const SizedBox(height: 16),
                    Text(
                      'Invalid user: QR does not match any customer in the system on this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        const _ScanSheetResult(
                          action: _ScanSheetAction.scanAgain,
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan again'),
                    ),
                  ],
                ),
              )
            : Stepper(
                currentStep: _stepIndex,
                onStepContinue: _submitting
                    ? null
                    : () async => _continueStep(),
                onStepCancel: _submitting ? null : _cancelStep,
                controlsBuilder: (context, details) {
                  final lastStep = _stepIndex == 1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : details.onStepContinue,
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(lastStep ? 'Submit' : 'Continue'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : details.onStepCancel,
                            child: Text(_stepIndex == 0 ? 'Cancel' : 'Back'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Choose Action'),
                    isActive: _stepIndex >= 0,
                    state: _stepIndex > 0
                        ? StepState.complete
                        : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${customer.firstName} ${customer.lastName}'.trim(),
                        ),
                        const SizedBox(height: 4),
                        Text('Current points: ${customer.points}'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Purchased product'),
                              selected: _mode == _PointsOperationMode.purchase,
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() {
                                  _mode = _PointsOperationMode.purchase;
                                  _amountController.clear();
                                  _productController.clear();
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Use points'),
                              selected: _mode == _PointsOperationMode.usePoints,
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() {
                                  _mode = _PointsOperationMode.usePoints;
                                  _amountController.clear();
                                  _productController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Enter Details'),
                    isActive: _stepIndex >= 1,
                    content: Form(
                      key: _detailsFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _amountController,
                            keyboardType: _mode == _PointsOperationMode.purchase
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                  )
                                : TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _mode == _PointsOperationMode.purchase
                                  ? 'Purchase Price'
                                  : 'Points to use',
                              prefixIcon: Icon(
                                _mode == _PointsOperationMode.purchase
                                    ? Icons.attach_money
                                    : Icons.remove_circle_outline,
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final mode = _mode;
                              if (mode == null) {
                                return 'Please choose an action';
                              }
                              final raw = (value ?? '').trim().replaceAll(
                                ',',
                                '',
                              );
                              if (raw.isEmpty) {
                                return mode == _PointsOperationMode.purchase
                                    ? 'Enter purchase price'
                                    : 'Enter points to use';
                              }
                              if (mode == _PointsOperationMode.purchase) {
                                final parsed = double.tryParse(raw);
                                if (parsed == null) {
                                  return 'Enter a valid number';
                                }
                                if (parsed <= 0) {
                                  return 'Must be greater than 0';
                                }
                              } else {
                                final parsed = int.tryParse(raw);
                                if (parsed == null) {
                                  return 'Enter a whole number';
                                }
                                if (parsed <= 0) {
                                  return 'Must be greater than 0';
                                }
                              }
                              return null;
                            },
                            textInputAction:
                                _mode == _PointsOperationMode.usePoints
                                ? TextInputAction.next
                                : TextInputAction.done,
                          ),
                          if (_mode == _PointsOperationMode.usePoints) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _productController,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Product used for points',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (_mode != _PointsOperationMode.usePoints) {
                                  return null;
                                }
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter product name';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop(
                                const _ScanSheetResult(
                                  action: _ScanSheetAction.openCustomer,
                                ),
                              );
                            },
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Open customer card'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum _PointsOperationMode { purchase, usePoints }

enum _ScanSheetAction { scanAgain, openCustomer, updatedPointsAndGoHome }

class _ScanSheetResult {
  const _ScanSheetResult({required this.action, this.message});

  final _ScanSheetAction action;
  final String? message;
}
