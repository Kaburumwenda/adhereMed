import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _desc.dispose(); _amount.dispose(); _category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/expenses/expenses/', data: {
        'description': _desc.text.trim(),
        'amount': _amount.text.trim(),
        'category_name': _category.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added')));
        context.go('/expenses');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _desc, decoration: const InputDecoration(labelText: 'Description *'), validator: (v) => v?.isEmpty == true ? 'Required' : null, maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (KSH) *', prefixText: 'KSH '), validator: (v) => v?.isEmpty == true ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 24),
            FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Expense')),
          ],
        ),
      ),
    );
  }
}
