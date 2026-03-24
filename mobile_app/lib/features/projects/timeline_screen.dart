import 'package:flutter/material.dart';

class TimelineScreen extends StatelessWidget {
  final String projectId;
  const TimelineScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Timeline')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          TimelineNode(
            title: 'Phase 1: Foundation Grade',
            startDate: '2023-10-01',
            endDate: '2023-10-15',
            status: 'completed',
          ),
          TimelineNode(
            title: 'Phase 2: Structural Framing',
            startDate: '2023-10-16',
            endDate: '2023-11-10',
            status: 'active',
            isDelayed: true,
          ),
          TimelineNode(
            title: 'Phase 3: Electrical & Plumbing',
            startDate: '2023-11-11',
            endDate: '2023-11-30',
            status: 'pending',
          ),
        ],
      ),
    );
  }
}

class TimelineNode extends StatelessWidget {
  final String title;
  final String startDate;
  final String endDate;
  final String status;
  final bool isDelayed;

  const TimelineNode({
    super.key,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.isDelayed = false,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'active':
        statusColor = isDelayed ? Colors.red : Colors.blue;
        statusIcon = isDelayed ? Icons.warning : Icons.play_circle_filled;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(statusIcon, color: statusColor, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('$startDate  to  $endDate\nStatus: ${status.toUpperCase()}'),
        ),
        isThreeLine: true,
        trailing: isDelayed 
            ? const Chip(
                label: Text('Delayed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                backgroundColor: Colors.red
              ) 
            : null,
      ),
    );
  }
}
