import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _alerts = <_Alert>[
    _Alert(type: _AlertType.inspection, title: 'Inspection Assigned', body: 'New inspection: "Structural Integrity Check" assigned to you for Bonthe Bridge. Complete by Apr 2.', time: '10 min ago', read: false),
    _Alert(type: _AlertType.risk, title: 'Risk Alert', body: 'High-risk item logged for Bo-Kenema Highway. Probability × Impact score of 15. Review required.', time: '1h ago', read: false),
    _Alert(type: _AlertType.update, title: 'Project Update', body: 'Freetown Ring Road Phase 2: milestone "Foundation Complete" marked as done by Project Manager.', time: '3h ago', read: true),
    _Alert(type: _AlertType.inspection, title: 'Reminder: Overdue Inspection', body: 'Inspection ID INS-204 was due yesterday. Please complete and submit as soon as possible.', time: '1d ago', read: true),
    _Alert(type: _AlertType.risk, title: 'Safety Incident Reported', body: 'A safety incident was reported at your site by field coordinator. Please review the report.', time: '2d ago', read: true),
  ];

  void _markRead(int index) => setState(() => _alerts[index] = _Alert(type: _alerts[index].type, title: _alerts[index].title, body: _alerts[index].body, time: _alerts[index].time, read: true));
  void _markAllRead() => setState(() { for (int i = 0; i < _alerts.length; i++) { _alerts[i] = _Alert(type: _alerts[i].type, title: _alerts[i].title, body: _alerts[i].body, time: _alerts[i].time, read: true); } });

  @override
  Widget build(BuildContext context) {
    final unread = _alerts.where((a) => !a.read).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Row(children: [
          Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
              child: Text('$unread', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ]),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
            ),
        ],
        elevation: 0,
      ),
      body: _alerts.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.notifications_none, size: 56, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text('No notifications', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = _alerts[i];
                return GestureDetector(
                  onTap: () => _markRead(i),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: a.read ? Colors.white : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: a.read ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: a.type.bgColor, shape: BoxShape.circle),
                          child: Icon(a.type.icon, size: 18, color: a.type.iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(a.title, style: GoogleFonts.inter(fontWeight: a.read ? FontWeight.w500 : FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)))),
                              if (!a.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                            ]),
                            const SizedBox(height: 4),
                            Text(a.body, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4)),
                            const SizedBox(height: 6),
                            Text(a.time, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                          ]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

enum _AlertType { inspection, risk, update }

extension _AlertTypeStyle on _AlertType {
  Color get bgColor => switch (this) { _AlertType.inspection => const Color(0xFFDCFCE7), _AlertType.risk => const Color(0xFFFEE2E2), _AlertType.update => const Color(0xFFEFF6FF) };
  Color get iconColor => switch (this) { _AlertType.inspection => const Color(0xFF16A34A), _AlertType.risk => const Color(0xFFDC2626), _AlertType.update => const Color(0xFF2563EB) };
  IconData get icon => switch (this) { _AlertType.inspection => Icons.assignment_outlined, _AlertType.risk => Icons.warning_amber_outlined, _AlertType.update => Icons.update };
}

class _Alert {
  final _AlertType type;
  final String title, body, time;
  final bool read;
  const _Alert({required this.type, required this.title, required this.body, required this.time, required this.read});
}
