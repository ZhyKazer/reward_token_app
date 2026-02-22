import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLoggedIn,
  });

  final void Function({required String employeeId, required String username}) onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _prefsBoxName = 'app_prefs';
  static const String _lastSignedInEmailKey = 'last_signed_in_email';

  final _formKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController();
  final _pinController = TextEditingController();

  String? _rememberedEmail;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final remembered = Hive.box<String>(_prefsBoxName).get(_lastSignedInEmailKey);
    if (remembered != null && remembered.trim().isNotEmpty) {
      _rememberedEmail = remembered.trim().toLowerCase();
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _pinValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Required';
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) return 'PIN must be 4 digits';
    return null;
  }

  String _authPassword({required String email, required String pin}) {
    return sha256.convert(utf8.encode('${email.toLowerCase()}:$pin')).toString();
  }

  Future<void> _login() async {
    final focus = FocusScope.of(context);
    if (!focus.hasPrimaryFocus) focus.unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final identifier = _identifierController.text.trim();
    final pin = _pinController.text.trim();

    setState(() => _submitting = true);
    try {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      final activeIdentifier = _rememberedEmail ?? identifier;
      final isEmail = activeIdentifier.contains('@');
      String email;
      String usernameForCallback = activeIdentifier;

      if (isEmail) {
        email = activeIdentifier.toLowerCase();
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('employees')
            .where('username', isEqualTo: activeIdentifier)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Invalid username/email or PIN')),
          );
          return;
        }

        final data = snapshot.docs.first.data();
        final foundEmail = data['email'] as String?;
        if (foundEmail == null || foundEmail.trim().isEmpty) {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Account is missing an email')),
          );
          return;
        }
        email = foundEmail.trim().toLowerCase();
        usernameForCallback = activeIdentifier;
      }

      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _authPassword(email: email, pin: pin),
        );
      } on FirebaseAuthException {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Invalid username/email or PIN')),
        );
        return;
      }

      final uid = cred.user?.uid;
      if (uid == null) {
        throw StateError('Signed in without a user');
      }

      await Hive.box<String>(_prefsBoxName).put(_lastSignedInEmailKey, email);

      // If user logged in via email, try to fetch their username.
      if (isEmail) {
        final doc = await FirebaseFirestore.instance.collection('employees').doc(uid).get();
        final data = doc.data();
        final u = data?['username'] as String?;
        if (u != null && u.trim().isNotEmpty) {
          usernameForCallback = u.trim();
        }
      }

      widget.onLoggedIn(employeeId: uid, username: usernameForCallback);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usingRememberedEmail = _rememberedEmail != null && _rememberedEmail!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (usingRememberedEmail) ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_rememberedEmail!),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            await Hive.box<String>(_prefsBoxName).delete(_lastSignedInEmailKey);
                            if (!mounted) return;
                            setState(() => _rememberedEmail = null);
                          },
                    child: const Text('Use a different account'),
                  ),
                ),
                const SizedBox(height: 4),
              ] else ...[
                TextFormField(
                  controller: _identifierController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username or Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _pinController,
                textInputAction: usingRememberedEmail ? TextInputAction.done : TextInputAction.next,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
                validator: _pinValidator,
                onFieldSubmitted: (_) => _submitting ? null : _login(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _submitting ? null : _login,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
