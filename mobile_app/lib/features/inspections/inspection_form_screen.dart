import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class InspectionFormScreen extends StatefulWidget {
  final String projectId;
  const InspectionFormScreen({super.key, required this.projectId});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _notesController = TextEditingController();
  final List<Map<String, dynamic>> _checklist = [
    {'task': 'Verify Foundation Grade', 'done': false},
    {'task': 'Inspect Rebar Placement', 'done': false},
    {'task': 'Check Safety Barriers', 'done': false},
  ];

  Future<void> _saveInspection() async {
    final db = await DatabaseHelper.instance.database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await db.insert('inspections', {
      'id': id,
      'project_id': widget.projectId,
      'inspection_date': DateTime.now().toIso8601String(),
      'status': 'submitted',
      'notes': _notesController.text,
      'sync_status': 'pending',
    });

    await db.insert('sync_queue', {
      'entity_type': 'inspection',
      'entity_id': id,
      'operation': 'INSERT',
      'payload': '{"notes": "${_notesController.text}"}',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection Form')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ..._checklist.map((item) {
            return CheckboxListTile(
              title: Text(item['task']),
              value: item['done'],
              onChanged: (val) {
                setState(() => item['done'] = val);
              },
            );
          }),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Additional Notes', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveInspection,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Submit Inspection (Offline Ready)'),
          )
        ],
      ),
    );
  }
}
