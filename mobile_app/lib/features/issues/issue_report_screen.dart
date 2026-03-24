import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/location_service.dart';
import '../../core/database/db_helper.dart';

class IssueReportScreen extends StatefulWidget {
  final String projectId;
  const IssueReportScreen({super.key, required this.projectId});

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _severity = 'medium';
  File? _imageFile;
  Position? _currentPosition;
  bool _isSaving = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _getLocation() async {
    final pos = await LocationService.getCurrentLocation();
    setState(() {
      _currentPosition = pos;
    });
  }

  Future<void> _saveIssueLocally() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _isSaving = true);
    
    // Save to local SQLite
    final db = await DatabaseHelper.instance.database;
    final issueId = DateTime.now().millisecondsSinceEpoch.toString(); // simplified ID
    
    await db.insert('issues', {
      'id': issueId,
      'project_id': widget.projectId,
      'title': _titleController.text,
      'description': _descController.text,
      'severity': _severity,
      'status': 'open',
      'location_lat': _currentPosition?.latitude,
      'location_lng': _currentPosition?.longitude,
      'sync_status': 'pending',
    });

    // Queue sync
    await db.insert('sync_queue', {
      'entity_type': 'issue',
      'entity_id': issueId,
      'operation': 'INSERT',
      'payload': '{"title": "${_titleController.text}", "severity": "$_severity"}', // mock payload
      'created_at': DateTime.now().toIso8601String(),
    });

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Issue Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
              items: ['low', 'medium', 'high', 'critical']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _severity = val!),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Photo'),
                ),
                ElevatedButton.icon(
                  onPressed: _getLocation,
                  icon: const Icon(Icons.location_on),
                  label: const Text('GPS'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imageFile != null) ...[
              const Text('Photo attached!'),
              const SizedBox(height: 8),
            ],
            if (_currentPosition != null) ...[
              Text('Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}'),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveIssueLocally,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isSaving 
                ? const CircularProgressIndicator() 
                : const Text('Save Offline & Queue Sync', style: TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }
}
