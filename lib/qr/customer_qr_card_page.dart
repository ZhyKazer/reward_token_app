import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reward_token_app/app_config.dart';
import 'package:reward_token_app/qr/customer_qr_card.dart';
import 'package:reward_token_app/qr/customer_qr_print.dart';
import 'package:reward_token_app/state/customer_store.dart';

class CustomerQrCardPage extends StatefulWidget {
  const CustomerQrCardPage({
    super.key,
    required this.customer,
    this.companyName = AppConfig.companyName,
  });

  final Customer customer;
  final String companyName;

  @override
  State<CustomerQrCardPage> createState() => _CustomerQrCardPageState();
}

class _CustomerQrCardPageState extends State<CustomerQrCardPage> {
  final GlobalKey _cardKey = GlobalKey();
  bool _saving = false;

  Future<Uint8List> _captureCardPng() async {
    final pixelRatio = View.of(context).devicePixelRatio;
    await WidgetsBinding.instance.endOfFrame;

    final renderObject = _cardKey.currentContext!.findRenderObject();
    final boundary = renderObject! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _savePng() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final bytes = await _captureCardPng();

      if (!mounted) return;

      Directory? directory;
      if (Platform.isMacOS) {
        directory = await getDownloadsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        final file = File('${directory.path}/qr_card.png');
        await file.writeAsBytes(bytes);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved to ${file.path}')),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get directory')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer QR'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _cardKey,
                    child: CustomerQrCard(
                      customer: widget.customer,
                      companyName: widget.companyName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await CustomerQrPrint.printCustomerCard(
                          widget.customer,
                          companyName: widget.companyName,
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _savePng,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_saving ? 'Saving...' : 'Save as image'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
