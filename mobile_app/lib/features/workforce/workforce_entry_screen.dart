import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class WorkforceEntryScreen extends StatefulWidget {
  final String projectId;
  const WorkforceEntryScreen({super.key, required this.projectId});

  @override
  State<WorkforceEntryScreen> createState() => _WorkforceEntryScreenState();
}

class _WorkforceEntryScreenState extends State<WorkforceEntryScreen> {
  final _countController = TextEditingController();
  String _role = 'laborer';
  String _gender = 'male';
  bool _isYouth = false;
  bool _isSaving = false;

  Future<void> _saveEntry() async {
    if (_countController.text.isEmpty) return;
    setState(() => _isSaving = true);

    final db = await DatabaseHelper.instance.database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('workforce_records', {
      'id': id,
      'project_id': widget.projectId,
      'record_date': DateTime.now().toIso8601String().split('T').first,
      'role_category': _role,
      'gender': _gender,
      'is_youth': _isYouth ? 1 : 0,
      'count': int.parse(_countController.text),
      'sync_status': 'pending',
    });

    await db.insert('sync_queue', {
      'entity_type': 'workforce_record',
      'entity_id': id,
      'operation': 'INSERT',
      'payload': '{"role":"$_role","gender":"$_gender","count":${_countController.text},"youth":$_isYouth}',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Daily Workforce')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Role Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              items: const [
                DropdownMenuItem(value: 'mason', child: Text('Mason')),
                DropdownMenuItem(value: 'carpenter', child: Text('Carpenter')),
                DropdownMenuItem(value: 'laborer', child: Text('Laborer')),
                DropdownMenuItem(value: 'engineer', child: Text('Engineer / Supervisor')),
              ],
              onChanged: (val) => setState(() => _role = val!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            
            const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
              ],
              onChanged: (val) => setState(() => _gender = val!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            SwitchListTile(
              title: const Text('Youth Worker (Under 25)'),
              subtitle: const Text('Toggle if this count represents youth workers'),
              value: _isYouth,
              onChanged: (val) => setState(() => _isYouth = val),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Headcount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isSaving ? null : _saveEntry,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Log Daily Entry (Offline Ready)', style: TextStyle(fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}
