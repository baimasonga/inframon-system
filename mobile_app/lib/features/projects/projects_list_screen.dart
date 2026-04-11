import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../inspections/inspection_form_screen.dart';
import '../inspections/multi_step_wizard.dart';
import '../issues/issue_report_screen.dart';
import 'timeline_screen.dart';
import '../workforce/workforce_entry_screen.dart';
import 'map_screen.dart';

const _mockProjects = [
  {
    'id': 'proj-1',
    'name': 'Highway Renovation A1',
    'status': 'active',
    'phase': 'Phase 2: Structural Framing',
    'progress': 0.45,
    'inspections': 9,
    'issues': 2,
    'location': 'Freeway Junction, Sector 4',
  },
  {
    'id': 'proj-2',
    'name': 'City Hall Extension',
    'status': 'planned',
    'phase': 'Phase 1: Site Preparation',
    'progress': 0.12,
    'inspections': 2,
    'issues': 1,
    'location': 'Downtown District, Block 7',
  },
];

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final localProjects = await db.query('projects', orderBy: 'created_at DESC');

      if (localProjects.isNotEmpty) {
        final mapped = localProjects.map((p) => {
              'id': p['id'],
              'name': p['name'],
              'status': p['status'].toString().toLowerCase(),
              'phase': p['status'] == 'Completed' ? 'Completed' : 'Phase 1: Tracking',
              'progress': 0.0, // Progress might need a separate fetch or join
              'inspections': 0,
              'issues': 0,
              'location': 'Assigned District',
            }).toList();

        if (mounted) {
          setState(() {
            _projects = List<Map<String, dynamic>>.from(mapped);
            _isLoading = false;
          });
        }
      } else {
        // Fallback to Supabase if local is empty (e.g., first run before sync)
        final data = await Supabase.instance.client
            .from('projects')
            .select()
            .order('created_at', ascending: false);

        if (data.isNotEmpty) {
          final mapped = data.map((p) => {
                'id': p['id'],
                'name': p['name'],
                'status': p['status'].toString().toLowerCase(),
                'phase': p['status'] == 'Completed' ? 'Completed' : 'Phase 1: Tracking',
                'progress': ((p['completion_percentage'] ?? 0) / 100).toDouble(),
                'inspections': 0,
                'issues': 0,
                'location': p['district'],
              }).toList();

          if (mounted) {
            setState(() {
              _projects = List<Map<String, dynamic>>.from(mapped);
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      if (mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(_mockProjects);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _projects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = _projects[i];
              return _ProjectCard(project: p);
            },
          ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  const _ProjectCard({required this.project});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final isActive = p['status'] == 'active';
    final progress = (p['progress'] as double);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppColors.blue.withValues(alpha: 0.3) : AppColors.border,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.blueSoft : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? '● Active' : 'Planned',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.blue : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p['name'],
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(p['location'],
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 14),
                // Progress
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['phase'],
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.blueSoft,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isActive ? AppColors.blue : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${(progress * 100).round()}%',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Mini stats
                Row(
                  children: [
                    _MiniStat(icon: Icons.fact_check_outlined, label: '${p['inspections']} Inspections', color: AppColors.blue),
                    const SizedBox(width: 16),
                    _MiniStat(icon: Icons.flag_outlined, label: '${p['issues']} Issues', color: AppColors.danger),
                  ],
                ),
              ],
            ),
          ),

          // ── Expanded actions ─────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.fact_check,
                    label: 'New Site Inspection Report',
                    iconColor: AppColors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MultiStepInspectionWizard(
                        projectId: p['id'], 
                        projectName: p['name'],
                        projectType: p['phase'],
                      ),
                    )),
                  ),
                  _ActionTile(
                    icon: Icons.report_problem,
                    label: 'Report Issue',
                    iconColor: AppColors.danger,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => IssueReportScreen(projectId: p['id']),
                    )),
                  ),
                  _ActionTile(
                    icon: Icons.timeline,
                    label: 'Project Timeline',
                    iconColor: AppColors.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TimelineScreen(projectId: p['id']),
                    )),
                  ),
                  _ActionTile(
                    icon: Icons.people_alt,
                    label: 'Log Daily Workforce',
                    iconColor: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => WorkforceEntryScreen(projectId: p['id']),
                    )),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
