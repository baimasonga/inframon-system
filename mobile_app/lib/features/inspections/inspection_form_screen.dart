import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../main.dart';
import '../../core/database/db_helper.dart';

class InspectionFormScreen extends StatefulWidget {
  final String projectId;
  const InspectionFormScreen({super.key, required this.projectId});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _notesController = TextEditingController();
  final _inspectorController = TextEditingController();
  File? _photo;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _checklist = [
    {'task': 'Verify Foundation Grade & Level', 'done': false},
    {'task': 'Inspect Rebar Placement & Cover', 'done': false},
    {'task': 'Check Safety Barriers & Fencing', 'done': false},
    {'task': 'PPE Compliance (Hardhats, Vests)', 'done': false},
    {'task': 'Scaffolding Stability Assessment', 'done': false},
    {'task': 'Concrete Mix Batch Records', 'done': false},
    {'task': 'Drainage & Water Management', 'done': false},
    {'task': 'Site Cleanliness & Housekeeping', 'done': false},
  ];

  int get _doneCount => _checklist.where((i) => i['done'] == true).length;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _saveInspection() async {
    setState(() => _isSaving = true);
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
      'payload': '{"notes": "${_notesController.text}", "inspector": "${_inspectorController.text}"}',
      'created_at': DateTime.now().toIso8601String(),
    });
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _doneCount / _checklist.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Inspection Form')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Progress Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue, Color(0xFF0A3260)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Checklist Progress',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_doneCount',
                        style: GoogleFonts.inter(
                            fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(' / ${_checklist.length} items',
                          style: GoogleFonts.inter(fontSize: 16, color: Colors.white60)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? AppColors.success : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Inspector Name ───────────────────────────────────────────
          _FormCard(
            child: TextField(
              controller: _inspectorController,
              decoration: const InputDecoration(
                labelText: 'Inspector Name',
                prefixIcon: Icon(Icons.person_outline),
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Checklist ────────────────────────────────────────────────
          _SectionTitle('Safety Checklist'),
          const SizedBox(height: 8),
          _FormCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _checklist.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isLast = i == _checklist.length - 1;
                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => item['done'] = !(item['done'] as bool)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: item['done'] == true ? AppColors.success : Colors.transparent,
                                border: Border.all(
                                  color: item['done'] == true ? AppColors.success : AppColors.border,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: item['done'] == true
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item['task'],
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: item['done'] == true
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: item['done'] == true
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 52, color: AppColors.border),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Photo Capture ─────────────────────────────────────────────
          _SectionTitle('Inspection Photo'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(16),
            child: _photo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Image.file(_photo!, width: double.infinity, height: 200, fit: BoxFit.cover),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('Retake', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 8),
                        Text('Tap to take inspection photo',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // ── Notes ─────────────────────────────────────────────────────
          _SectionTitle('Additional Notes'),
          const SizedBox(height: 8),
          _FormCard(
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add any additional observations or remarks...',
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Submit ───────────────────────────────────────────────────
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveInspection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _doneCount == _checklist.length ? AppColors.success : AppColors.blue,
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      _doneCount == _checklist.length
                          ? 'Submit Complete Inspection ✓'
                          : 'Submit Inspection (Offline Ready)',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary));
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _FormCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
