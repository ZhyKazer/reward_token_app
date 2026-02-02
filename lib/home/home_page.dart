import 'package:flutter/material.dart';
import 'package:reward_token_app/customer_registration/customer_registration_page.dart';
import 'package:reward_token_app/qr/customer_qr_card_page.dart';
import 'package:reward_token_app/state/customer_store.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CustomerStoreScope.of(context);

    return SafeArea(
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final customers = store.customers;

          if (customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No customers yet',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Register your first customer to start tracking points and generating their QR code.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          CustomerRegistrationPage.routeName,
                        );
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Register customer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final customer = customers[index];
              final name = customer.fullName;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      customer.firstName.isNotEmpty
                          ? customer.firstName.characters.first.toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(name),
                  subtitle: const Text('Current points'),
                  trailing: Chip(
                    label: Text('${customer.points}'),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerQrCardPage(customer: customer),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
