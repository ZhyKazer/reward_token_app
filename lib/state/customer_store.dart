import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  Map<String, Object?> toFirestore() {
    return <String, Object?>{
      'uuid': uuid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'points': points,
    };
  }

  static Customer fromFirestore(String uuid, Map<String, dynamic> data) {
    final firstName = (data['firstName'] as String?)?.trim() ?? '';
    final lastName = (data['lastName'] as String?)?.trim() ?? '';
    final email = (data['email'] as String?)?.trim() ?? '';
    final phoneNumber = (data['phoneNumber'] as String?)?.trim() ?? '';
    final rawPoints = data['points'];
    final points = rawPoints is num ? rawPoints.toInt() : 0;

    return Customer(
      uuid: uuid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      points: points,
    );
  }
}

class CustomerStore extends ChangeNotifier {
  final List<Customer> _customers = <Customer>[];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _customersSub;

  static CollectionReference<Map<String, dynamic>> _customersRef() {
    return FirebaseFirestore.instance.collection('customers');
  }

  /// Keeps the local store synced to Firestore in real-time.
  ///
  /// Safe to call multiple times; only one subscription will be active.
  void startSync() {
    if (_customersSub != null) return;
    _customersSub = _customersRef().snapshots().listen(
      (snapshot) {
        final loaded = <Customer>[];
        for (final doc in snapshot.docs) {
          loaded.add(Customer.fromFirestore(doc.id, doc.data()));
        }

        // Stable ordering: most recent first if `createdAt` exists.
        loaded.sort((a, b) {
          final aDoc = snapshot.docs.firstWhere((d) => d.id == a.uuid);
          final bDoc = snapshot.docs.firstWhere((d) => d.id == b.uuid);
          final aTs = aDoc.data()['createdAt'];
          final bTs = bDoc.data()['createdAt'];

          final aMillis = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
          final bMillis = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
          final byTime = bMillis.compareTo(aMillis);
          if (byTime != 0) return byTime;
          return b.uuid.compareTo(a.uuid);
        });

        _customers
          ..clear()
          ..addAll(loaded);
        notifyListeners();
      },
      onError: (_) {
        // Keep existing local state if Firestore stream errors.
      },
    );
  }

  Future<void> stopSync() async {
    final sub = _customersSub;
    _customersSub = null;
    await sub?.cancel();
  }

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

  void _upsertLocalCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.uuid == customer.uuid);
    if (index == -1) {
      _customers.insert(0, customer);
    } else {
      _customers[index] = customer;
    }
    notifyListeners();
  }

  Future<void> addCustomerAndPersist(Customer customer) async {
    await _customersRef().doc(customer.uuid).set(
      <String, Object?>{
        ...customer.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    _upsertLocalCustomer(customer);
  }

  Future<void> loadFromFirebase() async {
    final snapshot = await _customersRef().get();
    final loaded = <Customer>[];
    for (final doc in snapshot.docs) {
      loaded.add(Customer.fromFirestore(doc.id, doc.data()));
    }

    _customers
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Adds [delta] points to a customer identified by [uuid].
  ///
  /// Returns `true` if the customer exists and was updated.
  bool addPoints(String uuid, int delta) {
    if (delta == 0) return false;
    final index = _customers.indexWhere((c) => c.uuid == uuid);
    if (index == -1) return false;

    final existing = _customers[index];
    final updated = Customer(
      uuid: existing.uuid,
      firstName: existing.firstName,
      lastName: existing.lastName,
      email: existing.email,
      phoneNumber: existing.phoneNumber,
      points: existing.points + delta,
    );
    _customers[index] = updated;
    notifyListeners();
    return true;
  }

  Future<bool> addPointsAndPersist(String uuid, int delta) async {
    final ok = addPoints(uuid, delta);
    if (!ok) return false;

    try {
      await _customersRef().doc(uuid).update(
        <String, Object?>{
          'points': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      return true;
    } catch (_) {
      final current = findByUuid(uuid);
      if (current == null) {
        addPoints(uuid, -delta);
        return false;
      }
      try {
        await _customersRef().doc(uuid).set(
              <String, Object?>{
                ...current.toFirestore(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
        return true;
      } catch (e) {
        addPoints(uuid, -delta);
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    // Fire-and-forget; ChangeNotifier.dispose() is sync.
    unawaited(stopSync());
    super.dispose();
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
