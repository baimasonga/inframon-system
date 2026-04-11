import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../sync/sync_provider.dart';
import '../projects/timeline_screen.dart';
import '../inspections/inspection_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.navy,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.navy, Color(0xFF0A3260)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Good morning,',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                            ),
                            Text(
                              Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'Inspector',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            // Navigator.pushReplacement inside a StatelessWidget needs a context that works
                          },
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => syncProvider.syncNow(),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.sync, size: 14, color: Colors.white70),
                                    const SizedBox(width: 8),
                                    Text(
                                      syncProvider.isSyncing ? 'Syncing...' : 'Sync',
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              if (syncProvider.pendingCount > 0 && !syncProvider.isSyncing)
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    child: Center(
                                      child: Text(
                                        '${syncProvider.pendingCount}',
                                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Field Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats Row ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Inspections',
                          value: '14',
                          icon: Icons.fact_check_outlined,
                          color: AppColors.blue,
                          bgColor: AppColors.blueSoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Open Issues',
                          value: '3',
                          icon: Icons.warning_amber_outlined,
                          color: AppColors.danger,
                          bgColor: const Color(0xFFFEF2F2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Projects',
                          value: '2',
                          icon: Icons.folder_outlined,
                          color: AppColors.success,
                          bgColor: const Color(0xFFECFDF5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Recent Inspections ──────────────────────────────────
                  _SectionHeader(
                    title: 'Recent Inspections',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _InspectionTile(
                    projectName: 'Highway Renovation A1',
                    date: 'Today, 08:30 AM',
                    itemsChecked: 6,
                    total: 8,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const InspectionFormScreen(projectId: 'proj-1'),
                    )),
                  ),
                  const SizedBox(height: 8),
                  _InspectionTile(
                    projectName: 'City Hall Extension',
                    date: 'Yesterday, 02:15 PM',
                    itemsChecked: 8,
                    total: 8,
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),

                  // ── Active Issues ───────────────────────────────────────
                  _SectionHeader(title: 'Active Issues', onTap: () {}),
                  const SizedBox(height: 12),
                  _IssueTile(
                    title: 'Scaffolding collapse hazard',
                    project: 'Highway A1, Sec 4',
                    severity: 'critical',
                  ),
                  const SizedBox(height: 8),
                  _IssueTile(
                    title: 'Unauthorized workers on site',
                    project: 'City Hall, Floor 2',
                    severity: 'high',
                  ),
                  const SizedBox(height: 8),
                  _IssueTile(
                    title: 'Missing PPE – hardhats',
                    project: 'Bridge Foundation',
                    severity: 'medium',
                  ),
                  const SizedBox(height: 24),

                  // ── Quick Actions ───────────────────────────────────────
                  _SectionHeader(title: 'Quick Actions', onTap: null),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.fact_check,
                          label: 'New\nInspection',
                          color: AppColors.blue,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const InspectionFormScreen(projectId: 'proj-1'),
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.timeline,
                          label: 'View\nTimeline',
                          color: AppColors.amber,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const TimelineScreen(projectId: 'proj-1'),
                          )),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const Spacer(),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Text('See all',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _InspectionTile extends StatelessWidget {
  final String projectName;
  final String date;
  final int itemsChecked;
  final int total;
  final VoidCallback onTap;

  const _InspectionTile({
    required this.projectName,
    required this.date,
    required this.itemsChecked,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = itemsChecked / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fact_check, color: AppColors.blue, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(projectName,
                          style:
                              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(date,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text('$itemsChecked/$total',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppColors.blueSoft,
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct == 1.0 ? AppColors.success : AppColors.blue,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  final String title;
  final String project;
  final String severity;

  const _IssueTile({required this.title, required this.project, required this.severity});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    Color chipBg;
    String label;
    switch (severity) {
      case 'critical':
        chipColor = AppColors.danger;
        chipBg = const Color(0xFFFEF2F2);
        label = 'Critical';
        break;
      case 'high':
        chipColor = const Color(0xFFEA580C);
        chipBg = const Color(0xFFFFF7ED);
        label = 'High';
        break;
      default:
        chipColor = AppColors.amber;
        chipBg = const Color(0xFFFFFBEB);
        label = 'Medium';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(project, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: chipColor)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
