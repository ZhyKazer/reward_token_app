import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditActor {
  const AuditActor({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  Map<String, Object?> toFirestore() {
    return <String, Object?>{'id': id, 'name': name, 'role': role};
  }
}

class AuditLogService {
  static CollectionReference<Map<String, dynamic>> _recordsRef() {
    return FirebaseFirestore.instance.collection('activity_logs');
  }

  static Future<AuditActor> currentActor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AuditActor(id: 'unknown', name: 'Unknown', role: 'unknown');
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(user.uid)
          .get();
      final data = doc.data();

      final firstName = (data?['firstName'] as String?)?.trim() ?? '';
      final lastName = (data?['lastName'] as String?)?.trim() ?? '';
      final username = (data?['username'] as String?)?.trim() ?? '';
      final role = (data?['role'] as String?)?.trim() ?? 'employee';

      final fullName = '$firstName $lastName'.trim();
      final name = fullName.isNotEmpty
          ? fullName
          : (username.isNotEmpty ? username : (user.email ?? user.uid));

      return AuditActor(id: user.uid, name: name, role: role);
    } catch (_) {
      return AuditActor(
        id: user.uid,
        name: user.email ?? user.uid,
        role: 'employee',
      );
    }
  }

  static Future<void> logRecord({
    required String type,
    required String title,
    required AuditActor actor,
    String? customerId,
    String? customerName,
    String? targetId,
    String? targetName,
    String? targetRole,
    double? purchasePrice,
    int? pointsAdded,
    Map<String, Object?>? metadata,
  }) async {
    await _recordsRef().add(<String, Object?>{
      'type': type,
      'title': title,
      'actor': actor.toFirestore(),
      'customerId': customerId,
      'customerName': customerName,
      'targetId': targetId,
      'targetName': targetName,
      'targetRole': targetRole,
      'purchasePrice': purchasePrice,
      'pointsAdded': pointsAdded,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
