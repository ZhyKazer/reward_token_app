import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:reward_token_app/app_config.dart';
import 'package:reward_token_app/state/customer_store.dart';

class CustomerQrCard extends StatelessWidget {
  const CustomerQrCard({
    super.key,
    required this.customer,
    this.companyName = AppConfig.companyName,
  });

  final Customer customer;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              companyName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              customer.fullName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: customer.uuid,
                        version: QrVersions.auto,
                        size: 220,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              customer.uuid,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
