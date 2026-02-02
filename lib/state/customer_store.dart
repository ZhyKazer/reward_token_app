import 'package:flutter/widgets.dart';

class Customer {
  const Customer({
    required this.uuid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.points,
  });

  final String uuid;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final int points;

  String get fullName => '$firstName $lastName'.trim();
}

class CustomerStore extends ChangeNotifier {
  final List<Customer> _customers = <Customer>[];

  List<Customer> get customers => List<Customer>.unmodifiable(_customers);

  Customer? findByUuid(String uuid) {
    for (final customer in _customers) {
      if (customer.uuid == uuid) return customer;
    }
    return null;
  }

  void addCustomer(Customer customer) {
    _customers.insert(0, customer);
    notifyListeners();
  }
}

class CustomerStoreScope extends InheritedNotifier<CustomerStore> {
  const CustomerStoreScope({
    super.key,
    required CustomerStore super.notifier,
    required super.child,
  });

  static CustomerStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CustomerStoreScope>();
    assert(scope != null, 'CustomerStoreScope not found in widget tree');
    return scope!.notifier!;
  }
}
