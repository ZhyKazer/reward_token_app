import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:reward_token_app/audit/audit_log_service.dart';

import 'package:reward_token_app/firebase_options.dart';

enum EmployeeRole { admin, employee }

extension EmployeeRoleLabel on EmployeeRole {
  String get label {
    switch (this) {
      case EmployeeRole.admin:
        return 'Admin';
      case EmployeeRole.employee:
        return 'Employee';
    }
  }

  String get firestoreValue {
    switch (this) {
      case EmployeeRole.admin:
        return 'admin';
      case EmployeeRole.employee:
        return 'employee';
    }
  }
}

class EmployeeRegistrationPage extends StatelessWidget {
  const EmployeeRegistrationPage({super.key});

  static const routeName = '/employee-registration';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Registration')),
      body: const EmployeeRegistrationForm(),
    );
  }
}

class EmployeeRegistrationForm extends StatefulWidget {
  const EmployeeRegistrationForm({super.key});

  @override
  State<EmployeeRegistrationForm> createState() =>
      _EmployeeRegistrationFormState();
}

class _EmployeeRegistrationFormState extends State<EmployeeRegistrationForm> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _pinFormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  EmployeeRole? _role;
  String? _site;

  int _stepIndex = 0;

  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _emailValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Required';
    // Simple sanity check.
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _pinValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Required';
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      return 'PIN must be 4 digits';
    }
    return null;
  }

  Map<String, String> _hashPin(String pin) {
    final rng = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return <String, String>{'pinSalt': salt, 'pinHash': digest.toString()};
  }

  String _authPassword({required String email, required String pin}) {
    // Deterministic password derived from email+PIN.
    // Firebase Auth passwords require >= 6 chars; sha256 hex is 64 chars.
    return sha256
        .convert(utf8.encode('${email.toLowerCase()}:$pin'))
        .toString();
  }

  Future<FirebaseAuth> _secondaryAuth() async {
    const name = 'employee-registration';
    FirebaseApp app;
    try {
      app = Firebase.app(name);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  Future<void> _goNext() async {
    if (_stepIndex == 0) {
      final ok = _detailsFormKey.currentState?.validate() ?? false;
      if (!ok) return;
      if (_role == null) return;
      setState(() => _stepIndex = 1);
      return;
    }

    await _submit();
  }

  void _goBack() {
    if (_stepIndex == 0) return;
    setState(() => _stepIndex -= 1);
  }

  Future<void> _submit() async {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    final detailsValid = _detailsFormKey.currentState?.validate() ?? false;
    if (!detailsValid) return;

    final pinValid = _pinFormKey.currentState?.validate() ?? false;
    if (!pinValid) return;

    final role = _role;
    if (role == null) return;

    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();
    if (pin != confirmPin) return;

    setState(() => _submitting = true);
    try {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final site = _site;

      final existing = await FirebaseFirestore.instance
          .collection('employees')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return;
      }

      final pinData = _hashPin(pin);

      final auth = await _secondaryAuth();
      UserCredential created;
      try {
        created = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _authPassword(email: email, pin: pin),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to create auth user')),
        );
        return;
      } finally {
        await auth.signOut();
      }

      final uid = created.user?.uid;
      if (uid == null) {
        throw StateError('Auth user was created without a uid');
      }

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(uid)
          .set(<String, Object?>{
            'id': uid,
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'username': username,
            'site': site,
            'role': role.firestoreValue,
            'pinSalt': pinData['pinSalt'],
            'pinHash': pinData['pinHash'],
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final actor = await AuditLogService.currentActor();
      await AuditLogService.logRecord(
        type: role == EmployeeRole.admin ? 'admin_created' : 'employee_created',
        title: role == EmployeeRole.admin
            ? 'New admin registered'
            : 'New employee registered',
        actor: actor,
        targetId: uid,
        targetName: '$firstName $lastName'.trim(),
        targetRole: role.firestoreValue,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Registered $firstName $lastName (${role.label})'),
        ),
      );

      _firstNameController.clear();
      _lastNameController.clear();
      _usernameController.clear();
      _emailController.clear();
      _pinController.clear();
      _confirmPinController.clear();
      setState(() {
        _stepIndex = 0;
        _role = null;
        _site = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save to Firebase: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Empty for now (as requested).
    const siteOptions = <String>[];

    return SafeArea(
      child: Stepper(
        currentStep: _stepIndex,
        onStepContinue: _submitting ? null : () async => _goNext(),
        onStepCancel: _submitting ? null : _goBack,
        controlsBuilder: (context, details) {
          final isLast = _stepIndex == 1;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : details.onStepContinue,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isLast ? 'Register' : 'Continue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Details'),
            isActive: _stepIndex >= 0,
            state: _stepIndex > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _detailsFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: _emailValidator,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _site,
                    items: siteOptions
                        .map(
                          (site) => DropdownMenuItem<String>(
                            value: site,
                            child: Text(site),
                          ),
                        )
                        .toList(),
                    onChanged: siteOptions.isEmpty
                        ? null
                        : (value) => setState(() => _site = value),
                    decoration: InputDecoration(
                      labelText: 'Site (place employed)',
                      border: const OutlineInputBorder(),
                      helperText: siteOptions.isEmpty
                          ? 'No sites available yet'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EmployeeRole>(
                    initialValue: _role,
                    items: EmployeeRole.values
                        .map(
                          (role) => DropdownMenuItem<EmployeeRole>(
                            value: role,
                            child: Text(role.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _role = value),
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('PIN Setup'),
            isActive: _stepIndex >= 1,
            content: Form(
              key: _pinFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                    ),
                    validator: _pinValidator,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      final base = _pinValidator(v);
                      if (base != null) return base;
                      if (v != _pinController.text.trim())
                        return 'PINs do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
