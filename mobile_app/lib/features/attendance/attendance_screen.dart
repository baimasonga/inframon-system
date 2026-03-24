import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _checkedIn = false;
  String? _checkInTime;
  String? _checkOutTime;
  String? _location;
  bool _loading = false;

  final _logs = <_AttendanceLog>[
    _AttendanceLog(date: 'Mar 23, 2026', checkIn: '07:52', checkOut: '17:10', hours: 9.3, project: 'Freetown Ring Road', verified: true),
    _AttendanceLog(date: 'Mar 22, 2026', checkIn: '08:05', checkOut: '17:00', hours: 8.9, project: 'Freetown Ring Road', verified: true),
    _AttendanceLog(date: 'Mar 21, 2026', checkIn: '08:20', checkOut: '16:50', hours: 8.5, project: 'Bonthe Bridge', verified: true),
  ];

  Future<void> _checkIn() async {
    setState(() => _loading = true);
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _checkedIn = true;
        _checkInTime = DateFormat('HH:mm').format(DateTime.now());
        _location = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _checkedIn = true;
        _checkInTime = DateFormat('HH:mm').format(DateTime.now());
        _location = 'GPS unavailable';
        _loading = false;
      });
    }
  }

  Future<void> _checkOut() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    setState(() {
      _checkOutTime = DateFormat('HH:mm').format(now);
      _checkedIn = false;
      _loading = false;
      _logs.insert(0, _AttendanceLog(
        date: DateFormat('MMM d, yyyy').format(now),
        checkIn: _checkInTime!,
        checkOut: _checkOutTime!,
        hours: 8.2,
        project: 'Active Site',
        verified: _location != 'GPS unavailable',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('Time & Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _checkedIn ? [const Color(0xFF059669), const Color(0xFF10B981)] : [const Color(0xFF1E293B), const Color(0xFF334155)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_checkedIn ? Icons.location_on : Icons.location_off, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Text(_checkedIn ? 'You are Checked In' : 'Not Checked In', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
                  if (_checkInTime != null) ...[
                    const SizedBox(height: 4),
                    Text('Check-in: $_checkInTime  ·  GPS: $_location', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 180,
                    child: ElevatedButton(
                      onPressed: _loading ? null : (_checkedIn ? _checkOut : _checkIn),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _checkedIn ? const Color(0xFF059669) : const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(_checkedIn ? Icons.logout : Icons.login, size: 18),
                              const SizedBox(width: 6),
                              Text(_checkedIn ? 'Check Out' : 'Check In', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                            ]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Attendance Log', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            ..._logs.map((log) => _buildLogCard(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(_AttendanceLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(log.date, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: log.verified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(20)),
              child: Text(log.verified ? '✓ GPS Verified' : '⚠ Unverified', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: log.verified ? const Color(0xFF15803D) : const Color(0xFFB45309))),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              _TimeChip(label: 'In', time: log.checkIn),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              _TimeChip(label: 'Out', time: log.checkOut),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${log.hours}h', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF3B82F6))),
                Text(log.project, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label, time;
  const _TimeChip({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        Text(time, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
      ]),
    );
  }
}

class _AttendanceLog {
  final String date, checkIn, checkOut, project;
  final double hours;
  final bool verified;
  const _AttendanceLog({required this.date, required this.checkIn, required this.checkOut, required this.hours, required this.project, required this.verified});
}
