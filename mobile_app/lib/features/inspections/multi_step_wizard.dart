import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/database/db_helper.dart';

class MultiStepInspectionWizard extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String projectType;

  const MultiStepInspectionWizard({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.projectType,
  });

  @override
  State<MultiStepInspectionWizard> createState() =>
      _MultiStepInspectionWizardState();
}

class _MultiStepInspectionWizardState extends State<MultiStepInspectionWizard> {
  int _currentStep = 0;
  bool _isSaving = false;

  // ── Form State ────────────────────────────────────────────────────────────
  final _notesController = TextEditingController();
  String _visitType = 'Routine';
  String _weather = 'Clear / Sunny';
  bool _supervisorPresent = true;
  double _overallProgress = 0.5;
  final String _overallStatus = 'Fair';
  final String _recommendation = 'Continue work';

  // Dynamic Data
  List<Map<String, dynamic>> _milestones = [];
  List<Map<String, dynamic>> _qualityChecks = [];
  final List<Map<String, dynamic>> _defects = [];
  final Map<String, dynamic> _workforce = {
    'total': 0,
    'male': 0,
    'female': 0,
    'youth': 0,
    'local': 0,
    'ppe': 80,
  };
  List<Map<String, dynamic>> _materials = [];
  final List<File> _photos = [];

  @override
  void initState() {
    super.initState();
    _initializeChecklists();
  }

  void _initializeChecklists() {
    // Mocking template logic similar to web dashboard
    _milestones = [
      {
        'id': 'm0000000-0000-0000-0000-000000000001',
        'name': 'Site Clearance',
        'status': 'Completed',
        'pct': 100,
        'delay': 0,
      },
      {
        'id': 'm0000000-0000-0000-0000-000000000002',
        'name': 'Foundation Work',
        'status': 'In Progress',
        'pct': 45,
        'delay': 2,
      },
      {
        'id': 'm0000000-0000-0000-0000-000000000003',
        'name': 'Structural Framing',
        'status': 'Not Started',
        'pct': 0,
        'delay': 0,
      },
    ];
    _qualityChecks = [
      {'item': 'Concrete Grade (C25/30)', 'pass': true},
      {'item': 'Rebar Diameter Conformity', 'pass': true},
      {'item': 'Safety Signage Visibility', 'pass': false},
    ];
    _materials = [
      {'item': 'Cement (Grade 42.5)', 'pass': true},
      {'item': 'Aggregate (Grain size)', 'pass': true},
      {'item': 'Reinforcement Steel', 'pass': true},
    ];
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  Future<void> _saveFinalReport() async {
    setState(() => _isSaving = true);

    // Fetch real GPS before building payload
    double gpsLat = 8.484;
    double gpsLng = -13.234;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          gpsLat = pos.latitude;
          gpsLng = pos.longitude;
        }
      }
    } catch (e) {
      debugPrint('GPS fetch failed, using default: $e');
    }

    final db = await DatabaseHelper.instance.database;
    final visitId = DateTime.now().millisecondsSinceEpoch.toString();

    // 1. Prepare Payload for Cloud RPC
    final payload = {
      'project_id': widget.projectId,
      'inspector_id': Supabase.instance.client.auth.currentUser?.id,
      'date_time': DateTime.now().toIso8601String(),
      'visit_type': _visitType,
      'weather_condition': _weather,
      'site_supervisor_present': _supervisorPresent,
      'overall_progress': (_overallProgress * 100).toInt(),
      'overall_status': _overallStatus,
      'recommendation': _recommendation,
      'notes': _notesController.text,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'milestones': _milestones
          .map(
            (m) => {
              'id': m['id'],
              'status': m['status'],
              'pct': m['pct'],
              'delay_days': m['delay'],
              'reason': '',
            },
          )
          .toList(),
      'issues': _defects
          .map(
            (d) => {
              'title': d['title'],
              'category': d['category'],
              'severity': d['severity'],
              'action': d['action'],
              'responsible': d['responsible'],
              'deadline': d['deadline'],
            },
          )
          .toList(),
      'workforce_details': [
        {
          'role': 'Total Labor',
          'count': _workforce['total'],
          'gender': 'Male',
          'is_youth': false,
        },
        {
          'role': 'Female Participation',
          'count': _workforce['female'],
          'gender': 'Female',
          'is_youth': false,
        },
        {
          'role': 'Youth Labor',
          'count': _workforce['youth'],
          'gender': 'Mixed',
          'is_youth': true,
        },
      ],
      'materials': _materials
          .map((m) => {'item': m['item'], 'pass': m['pass'], 'notes': ''})
          .toList(),
    };

    // 2. Save Locally for Resilience
    await db.insert('visit_metadata', {
      'id': visitId,
      'project_id': widget.projectId,
      'inspector_id': Supabase.instance.client.auth.currentUser?.id,
      'date_time': DateTime.now().toIso8601String(),
      'visit_type': _visitType,
      'weather_condition': _weather,
      'site_supervisor_present': _supervisorPresent ? 1 : 0,
      'overall_progress': (_overallProgress * 100).toInt(),
      'overall_status': _overallStatus,
      'recommendation': _recommendation,
      'notes': _notesController.text,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'sync_status': 'pending',
    });

    // 3. Queue for Sync
    await db.insert('sync_queue', {
      'entity_type': 'field_report',
      'entity_id': visitId,
      'operation': 'RPC_SUBMIT',
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report saved and queued for synchronization!'),
        ),
      );
      Navigator.pop(context);
    }
  }

  // ── UI Components ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Site Inspection Wizard',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentStep + 1} / 7',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 7,
            backgroundColor: AppColors.blue.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            minHeight: 6,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),
          _buildNavigation(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _stepMetadata();
      case 1:
        return _stepProgress();
      case 2:
        return _stepQuality();
      case 3:
        return _stepDefects();
      case 4:
        return _stepWorkforce();
      case 5:
        return _stepMaterials();
      case 6:
        return _stepSummary();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 0: Metadata ──
  Widget _stepMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Visit Information',
          'Capture the baseline context of this site visit.',
        ),
        const SizedBox(height: 24),
        _buildDropdown('Visit Type', _visitType, [
          'Routine',
          'Milestone',
          'Ad-hoc',
          'Follow-up',
        ], (v) => setState(() => _visitType = v!)),
        const SizedBox(height: 16),
        _buildDropdown('Weather Condition', _weather, [
          'Clear / Sunny',
          'Overcast',
          'Light Rain',
          'Heavy Rain / Storm',
        ], (v) => setState(() => _weather = v!)),
        const SizedBox(height: 16),
        _buildSwitch(
          'Site Supervisor Present',
          _supervisorPresent,
          (v) => setState(() => _supervisorPresent = v),
        ),
      ],
    );
  }

  // ── STEP 1: Progress ──
  Widget _stepProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Physical Progress',
          'Verify completion percentages for active milestones.',
        ),
        const SizedBox(height: 24),
        Text(
          'Overall Site Completion: ${(_overallProgress * 100).toInt()}%',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _overallProgress,
          onChanged: (v) => setState(() => _overallProgress = v),
          activeColor: AppColors.blue,
        ),
        const SizedBox(height: 24),
        Text(
          'Milestone Tracking',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ..._milestones.map(
          (m) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m['name'],
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${m['pct']}%',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statusTag(m['status']),
                    const Spacer(),
                    _delayTag(m['delay']),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Quality ──
  Widget _stepQuality() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Technical Quality',
          'Pass/Fail checks for critical technical specifications.',
        ),
        const SizedBox(height: 24),
        ..._qualityChecks.map(
          (qc) => CheckboxListTile(
            title: Text(
              qc['item'],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            value: qc['pass'],
            onChanged: (v) => setState(() => qc['pass'] = v),
            secondary: Icon(
              qc['pass'] ? Icons.check_circle : Icons.error_outline,
              color: qc['pass'] ? AppColors.success : AppColors.danger,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ── STEP 3: Defects ──
  Widget _stepDefects() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Site Defects & Issues',
          'Record any non-compliance or structural hazards found.',
        ),
        const SizedBox(height: 16),
        if (_defects.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.none,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'No issues detected so far.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ..._defects.map((d) => _buildDefectCard(d)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _showAddDefectModal(),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Defect Record'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 4: Workforce ──
  Widget _stepWorkforce() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Workforce & Social Impact',
          'Capture headcount and compliance metrics.',
        ),
        const SizedBox(height: 24),
        _buildCounter(
          'Total Workers Active',
          _workforce['total'],
          (v) => setState(() => _workforce['total'] = v),
        ),
        _buildCounter(
          'Female Participation',
          _workforce['female'],
          (v) => setState(() => _workforce['female'] = v),
        ),
        _buildCounter(
          'Youth Training (<25)',
          _workforce['youth'],
          (v) => setState(() => _workforce['youth'] = v),
        ),
        _buildCounter(
          'Local District Labor',
          _workforce['local'],
          (v) => setState(() => _workforce['local'] = v),
        ),
        const SizedBox(height: 16),
        _pageTitle('Safety Protection', 'PPE compliance percentage.'),
        Slider(
          value: _workforce['ppe'].toDouble(),
          min: 0,
          max: 100,
          onChanged: (v) => setState(() => _workforce['ppe'] = v.toInt()),
          activeColor: AppColors.success,
        ),
        Center(
          child: Text(
            '${_workforce['ppe']}% Protection Ratio',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 5: Materials ──
  Widget _stepMaterials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Materials Verification',
          'Confirm quality of raw materials arrived on site.',
        ),
        const SizedBox(height: 24),
        ..._materials.map(
          (m) => ListTile(
            title: Text(m['item'], style: GoogleFonts.inter(fontSize: 14)),
            trailing: Switch(
              value: m['pass'],
              onChanged: (v) => setState(() => m['pass'] = v),
              activeThumbColor: AppColors.blue,
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 6: Summary ──
  Widget _stepSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(
          'Review & Finalise',
          'Summary of indices captured. Please review before submission.',
        ),
        const SizedBox(height: 24),
        _buildSummaryCard(),
        const SizedBox(height: 24),
        _SectionTitle('Additional Inspector Remarks'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Describe general site mood, complex delays, or urgent needs...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        _pageTitle(
          'Visual Evidence',
          'Capture photos to backup your findings.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._photos.map(
              (f) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(f, width: 80, height: 80, fit: BoxFit.cover),
              ),
            ),
            InkWell(
              onTap: _pickPhoto,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: AppColors.blue,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _pageTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: items
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: GoogleFonts.inter(fontSize: 14)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(
        label,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.blue,
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onChanged(value > 0 ? value - 1 : 0),
              ),
              SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    '$value',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.blue,
                ),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTag(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status == 'Completed'
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: status == 'Completed' ? AppColors.success : AppColors.blue,
        ),
      ),
    );
  }

  Widget _delayTag(int days) {
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 12,
          color: days > 0 ? AppColors.danger : AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          days > 0 ? '+$days days' : 'On Track',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: days > 0 ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDefectCard(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                d['title'],
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF991B1B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF991B1B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  d['severity'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d['action'],
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(
                label: 'Progress',
                value: '${(_overallProgress * 100).toInt()}%',
                color: Colors.blue,
              ),
              _SummaryItem(
                label: 'Issues',
                value: '${_defects.length}',
                color: Colors.red,
              ),
              _SummaryItem(
                label: 'QC Pass',
                value:
                    '${_qualityChecks.where((q) => q['pass']).length}/${_qualityChecks.length}',
                color: AppColors.success,
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Workforce Presence',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '${_workforce['total']} Active Workers',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDefectModal() {
    final titleC = TextEditingController();
    final actionC = TextEditingController();
    final respC = TextEditingController();
    String sev = 'Medium';
    String cat = 'Structural defects';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Site Defect',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleC,
              decoration: const InputDecoration(labelText: 'Issue Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: actionC,
              decoration: const InputDecoration(labelText: 'Mitigation Plan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: respC,
              decoration: const InputDecoration(
                labelText: 'Responsible Entity',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(
                  () => _defects.add({
                    'title': titleC.text,
                    'category': cat,
                    'severity': sev,
                    'action': actionC.text,
                    'responsible': respC.text,
                    'deadline': '2026-05-01',
                  }),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Record Defect'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (_currentStep < 6) {
                        setState(() => _currentStep++);
                      } else {
                        _saveFinalReport();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 6
                    ? AppColors.success
                    : AppColors.blue,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentStep == 6
                          ? 'SUBMIT REPORT'
                          : 'Continue Verification',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
