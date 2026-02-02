import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reward_token_app/state/customer_store.dart';
import 'package:reward_token_app/qr/customer_qr_card_page.dart';
import 'package:uuid/uuid.dart';

class CustomerRegistrationPage extends StatelessWidget {
  const CustomerRegistrationPage({super.key});

  static const routeName = '/customer-registration';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Registration'),
      ),
      body: const CustomerRegistrationForm(),
    );
  }
}

class CustomerRegistrationForm extends StatefulWidget {
  const CustomerRegistrationForm({super.key});

  @override
  State<CustomerRegistrationForm> createState() => _CustomerRegistrationFormState();
}

class _CustomerRegistrationFormState extends State<CustomerRegistrationForm> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _numberController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _emailValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required';

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) return 'Enter a valid email';

    return null;
  }

  String? _numberValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required';
    if (trimmed.length < 7) return 'Enter a valid number';
    return null;
  }

  Future<void> _submit() async {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _submitting = true);
    try {
      // Placeholder: replace with your API/database call.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final phoneNumber = _numberController.text.trim();
      final uuid = const Uuid().v4();

      final customer = Customer(
        uuid: uuid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        points: 0,
      );

      CustomerStoreScope.of(context).addCustomer(customer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registered ${customer.fullName}')),
      );

      _formKey.currentState?.reset();
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _numberController.clear();

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CustomerQrCardPage(customer: customer),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
              controller: _emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Number',
                hintText: 'e.g. 0712345678',
                border: OutlineInputBorder(),
              ),
              validator: _numberValidator,
              onFieldSubmitted: (_) => _submitting ? null : _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(_submitting ? 'Submitting...' : 'Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
