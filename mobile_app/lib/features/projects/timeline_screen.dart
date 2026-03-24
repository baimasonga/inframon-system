import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

class TimelineScreen extends StatelessWidget {
  final String projectId;
  const TimelineScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    const phases = [
      {
        'title': 'Phase 1: Site Preparation',
        'start': 'Oct 1',
        'end': 'Oct 15',
        'status': 'completed',
        'delay': false,
        'inspections': 4,
        'issues': 0,
        'note': null,
      },
      {
        'title': 'Phase 2: Structural Framing',
        'start': 'Oct 16',
        'end': 'Nov 10',
        'status': 'active',
        'delay': true,
        'inspections': 9,
        'issues': 1,
        'note': 'Approval blocked: Pending raw material delivery',
      },
      {
        'title': 'Phase 3: Electrical & Plumbing',
        'start': 'Nov 11',
        'end': 'Nov 30',
        'status': 'pending',
        'delay': false,
        'inspections': 0,
        'issues': 0,
        'note': null,
      },
      {
        'title': 'Phase 4: Interior Finishing',
        'start': 'Dec 1',
        'end': 'Dec 22',
        'status': 'pending',
        'delay': false,
        'inspections': 0,
        'issues': 0,
        'note': null,
      },
    ];

    const completedCount = 1;
    final progress = completedCount / phases.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Project Timeline')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Progress Summary Card ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Highway Renovation A1',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('● Active',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.blue)),
                    ),
                    const SizedBox(width: 10),
                    Text('Phase 2 of 4',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: AppColors.blueSoft,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${(progress * 100).round()}%',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Timeline Phases ───────────────────────────────────────────
          ...phases.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final isLast = i == phases.length - 1;
            return _TimelinePhase(phase: p, isLast: isLast);
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _TimelinePhase extends StatelessWidget {
  final Map<String, dynamic> phase;
  final bool isLast;
  const _TimelinePhase({required this.phase, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final status = phase['status'] as String;
    final isDelay = phase['delay'] == true;
    final note = phase['note'] as String?;

    Color dotColor;
    IconData dotIcon;
    Color cardBorderColor = AppColors.border;

    switch (status) {
      case 'completed':
        dotColor = AppColors.success;
        dotIcon = Icons.check_circle;
        break;
      case 'active':
        dotColor = isDelay ? AppColors.danger : AppColors.blue;
        dotIcon = isDelay ? Icons.warning_rounded : Icons.play_circle_filled;
        if (isDelay) cardBorderColor = const Color(0xFFFECACA);
        break;
      default:
        dotColor = const Color(0xFFCBD5E1);
        dotIcon = Icons.radio_button_unchecked;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left connector line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: Icon(dotIcon, size: 16, color: dotColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'completed' ? AppColors.success : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Phase card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(phase['title'],
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'pending'
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary)),
                        ),
                        if (isDelay)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text('Delayed',
                                style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${phase['start']} – ${phase['end']}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    if (note != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Text(note,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF92400E), fontWeight: FontWeight.w500)),
                      ),
                    ],
                    if (status != 'pending') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _PhaseStat(
                              label: '${phase['inspections']} Inspections', color: AppColors.blue),
                          const SizedBox(width: 16),
                          _PhaseStat(
                              label: '${phase['issues']} Issues',
                              color: (phase['issues'] as int) > 0 ? AppColors.danger : AppColors.textSecondary),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseStat extends StatelessWidget {
  final String label;
  final Color color;
  const _PhaseStat({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color));
  }
}
