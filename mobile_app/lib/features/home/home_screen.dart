import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/database/db_helper.dart';
import '../sync/sync_provider.dart';
import '../projects/projects_list_screen.dart';
import '../inspections/inspection_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = 'Inspector';
  int _pendingVisits = 0;
  int _pendingIssues = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalStats();
  }

  Future<void> _loadLocalStats() async {
    final db = await DatabaseHelper.instance.database;

    final profile = await db.query('user_profile', limit: 1);
    if (profile.isNotEmpty && mounted) {
      setState(() {
        _displayName = profile.first['full_name'] as String? ?? 'Inspector';
      });
    } else {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      if (mounted) {
        setState(() {
          _displayName = email.contains('@') ? email.split('@')[0] : 'Inspector';
        });
      }
    }

    final visitsResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM visit_metadata WHERE sync_status = 'pending'",
    );
    final issuesResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM issues WHERE sync_status = 'pending'",
    );

    if (mounted) {
      setState(() {
        _pendingVisits = (visitsResult.first['c'] as int?) ?? 0;
        _pendingIssues = (issuesResult.first['c'] as int?) ?? 0;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<SyncProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
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
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.white60),
                            ),
                            Text(
                              _displayName,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.logout,
                              color: Colors.white54, size: 20),
                          tooltip: 'Sign Out',
                          onPressed: () => _signOut(context),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () async {
                            await syncProvider.syncNow();
                            if (mounted) _loadLocalStats();
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    syncProvider.isSyncing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                color: Colors.white70,
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.sync,
                                            size: 14, color: Colors.white70),
                                    const SizedBox(width: 8),
                                    Text(
                                      syncProvider.isSyncing
                                          ? 'Syncing...'
                                          : 'Sync',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              if (syncProvider.pendingCount > 0)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${syncProvider.pendingCount}',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Pending Uploads Banner ───────────────────────────────
                  if (syncProvider.pendingCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFBBF24)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_upload_outlined,
                              color: Color(0xFFB45309), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${syncProvider.pendingCount} item(s) pending upload. Tap Sync when connected.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF92400E),
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Summary Cards ────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.pending_actions_outlined,
                        label: 'Pending Visits',
                        value: '$_pendingVisits',
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.flag_outlined,
                        label: 'Unsync Issues',
                        value: '$_pendingIssues',
                        color: AppColors.danger,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  Text(
                    'QUICK ACTIONS',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 14),

                  // ── Quick Actions ────────────────────────────────────────
                  _QuickActionCard(
                    icon: Icons.fact_check_outlined,
                    label: 'New Site Inspection',
                    color: AppColors.blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProjectsListScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    icon: Icons.report_problem_outlined,
                    label: 'Report a Site Issue',
                    color: AppColors.danger,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProjectsListScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionCard(
                    icon: Icons.sync_outlined,
                    label: 'Sync Data to Dashboard',
                    color: AppColors.success,
                    onTap: () async {
                      await syncProvider.syncNow();
                      if (mounted) _loadLocalStats();
                    },
                  ),

                  if (syncProvider.lastSyncTime != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Last sync: ${_formatTime(syncProvider.lastSyncTime!)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }
}
