import 'package:flutter/material.dart';
import 'package:reward_token_app/audit/audit_log_service.dart';
import 'package:reward_token_app/state/customer_store.dart';

class UsePointsPage extends StatefulWidget {
  const UsePointsPage({super.key, required this.customerUuid});

  final String customerUuid;

  @override
  State<UsePointsPage> createState() => _UsePointsPageState();
}

class _UsePointsPageState extends State<UsePointsPage> {
  final TextEditingController _pointsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final points = int.tryParse(_pointsController.text.trim());
    if (points == null || points <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid points.')));
      return;
    }

    final store = CustomerStoreScope.of(context);
    final customer = store.findByUuid(widget.customerUuid);
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer not found.')),
      );
      return;
    }

    if (points > customer.points) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient points for this user.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await store.addPointsAndPersist(customer.uuid, -points);

      final actor = await AuditLogService.currentActor();
      await AuditLogService.logRecord(
        type: 'points_used',
        title: 'Used customer points',
        actor: actor,
        customerId: customer.uuid,
        customerName: customer.fullName,
        pointsAdded: points,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Used $points points from ${customer.fullName}.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to use points.')));
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = CustomerStoreScope.of(context).findByUuid(widget.customerUuid);

    return Scaffold(
      appBar: AppBar(title: const Text('Use Points')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: customer == null
            ? const Center(child: Text('Customer not found.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User: ${customer.fullName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Current points: ${customer.points}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points to use',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm Use Points'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}