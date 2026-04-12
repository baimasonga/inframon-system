import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:provider/provider.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../sync/sync_provider.dart';

  class NotificationsScreen extends StatefulWidget {
    const NotificationsScreen({super.key});

    @override
    State<NotificationsScreen> createState() => _NotificationsScreenState();
  }

  class _NotificationsScreenState extends State<NotificationsScreen> {
    List<_Alert> _alerts = [];
    bool _isLoading = true;

    @override
    void initState() {
      super.initState();
      _loadNotifications();
      // Mark unread task count as read
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SyncProvider>().markTasksRead();
      });
    }

    Future<void> _loadNotifications() async {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final List<_Alert> alerts = [];

      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // 1. Load task assignment notifications
        try {
          final tasks = await Supabase.instance.client
              .from('inspection_tasks')
              .select('id, title, description, priority, deadline, status, created_at')
              .eq('assignee_id', userId)
              .order('created_at', ascending: false)
              .limit(15);

          for (final t in tasks as List<dynamic>) {
            final createdAt = DateTime.tryParse(t['created_at'] as String? ?? '') ?? DateTime.now();
            final priority  = t['priority'] as String? ?? 'Normal';
            final deadline  = t['deadline'] != null
                ? DateTime.tryParse(t['deadline'] as String)
                : null;
            final isOverdue = deadline != null && deadline.isBefore(DateTime.now())
                && t['status'] != 'Completed';

            alerts.add(_Alert(
              type: _AlertType.task,
              title: '📋 Task Assigned: ${t['title'] ?? 'Inspection Task'}',
              body: t['description'] as String? ??
                  '${priority} priority task${deadline != null ? ' — due ${_formatDate(deadline)}' : ''}'
                  '${isOverdue ? ' ⚠ Overdue!' : ''}',
              time: _timeAgo(createdAt),
              createdAt: createdAt,
              read: t['status'] != 'Pending',
            ));
          }
        } catch (e) {
          debugPrint('Task notifications load error: $e');
        }

        // 2. Load audit log notifications
        try {
          final data = await Supabase.instance.client
              .from('audit_logs')
              .select()
              .or('user_id.eq.$userId,target_id.eq.$userId')
              .order('created_at', ascending: false)
              .limit(20);

          for (final row in data as List<dynamic>) {
            final action    = (row['action'] as String? ?? '').toLowerCase();
            _AlertType type;
            if (action.contains('inspection') || action.contains('task')) {
              type = _AlertType.inspection;
            } else if (action.contains('risk') || action.contains('issue') || action.contains('incident')) {
              type = _AlertType.risk;
            } else {
              type = _AlertType.update;
            }
            final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
            alerts.add(_Alert(
              type: type,
              title: _humanizeAction(row['action'] as String? ?? ''),
              body: row['details'] as String? ?? row['description'] as String? ?? 'No details provided.',
              time: _timeAgo(createdAt),
              createdAt: createdAt,
              read: false,
            ));
          }
        } catch (e) {
          debugPrint('Audit log load error: $e');
        }

        // Sort combined list newest-first
        alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _alerts = alerts;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Notifications load error: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    }

    String _humanizeAction(String action) {
      return action.split('_').map((w) =>
          w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }

    String _timeAgo(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    }

    String _formatDate(DateTime dt) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    }

    void _markRead(int index) {
      setState(() {
        final a = _alerts[index];
        _alerts[index] = _Alert(
          type: a.type, title: a.title, body: a.body,
          time: a.time, createdAt: a.createdAt, read: true,
        );
      });
    }

    void _markAllRead() {
      setState(() {
        _alerts = _alerts.map((a) => _Alert(
          type: a.type, title: a.title, body: a.body,
          time: a.time, createdAt: a.createdAt, read: true,
        )).toList();
      });
    }

    @override
    Widget build(BuildContext context) {
      final unread = _alerts.where((a) => !a.read).length;
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$unread',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
          actions: [
            if (unread > 0)
              TextButton(
                onPressed: _markAllRead,
                child: Text('Mark all read',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _loadNotifications,
            ),
          ],
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none, size: 56, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text('No notifications',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _loadNotifications, child: const Text('Refresh')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        return InkWell(
                          onTap: () => _markRead(index),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: alert.read ? Colors.white : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: alert.read ? const Color(0xFFE2E8F0) : const Color(0xFF93C5FD)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: alert.type.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(alert.type.icon, color: alert.type.color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(alert.title,
                                                style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: const Color(0xFF0F172A))),
                                          ),
                                          if (!alert.read)
                                            Container(
                                              width: 8, height: 8,
                                              decoration: const BoxDecoration(
                                                  color: Color(0xFF3B82F6), shape: BoxShape.circle),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(alert.body,
                                          style: GoogleFonts.inter(
                                              fontSize: 12, color: const Color(0xFF64748B), height: 1.4)),
                                      const SizedBox(height: 6),
                                      Text(alert.time,
                                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      );
    }
  }

  enum _AlertType {
    task(       icon: Icons.assignment_outlined,  color: Color(0xFF1D6AE5)),
    inspection( icon: Icons.fact_check_outlined,  color: Color(0xFF3B82F6)),
    risk(       icon: Icons.warning_amber_outlined, color: Color(0xFFEF4444)),
    update(     icon: Icons.info_outline,          color: Color(0xFF10B981));

    const _AlertType({required this.icon, required this.color});
    final IconData icon;
    final Color color;
  }

  class _Alert {
    final _AlertType type;
    final String title;
    final String body;
    final String time;
    final DateTime createdAt;
    final bool read;
    const _Alert({
      required this.type,
      required this.title,
      required this.body,
      required this.time,
      required this.createdAt,
      required this.read,
    });
  }
  