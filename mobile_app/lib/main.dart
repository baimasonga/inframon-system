import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/db_helper.dart';
import 'features/inspections/inspection_form_screen.dart';
import 'features/issues/issue_report_screen.dart';
import 'features/sync/sync_provider.dart';
import 'features/projects/timeline_screen.dart';
import 'features/workforce/workforce_entry_screen.dart';
import 'features/projects/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite
  await DatabaseHelper.instance.database;

  runApp(const InfraMonApp());
}

class InfraMonApp extends StatelessWidget {
  const InfraMonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => DatabaseHelper.instance),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: MaterialApp(
        title: 'InfraMon Field Tool',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InfraMon Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.construction, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ProjectListScreen())
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('Login to Field Tool', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync), 
            onPressed: () {
              context.read<SyncProvider>().syncNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...'))
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const MapScreen()
              ));
            }
          ),
        ],
      ),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text('Highway Renovation A1'),
            subtitle: const Text('In Progress'),
            children: [
              ListTile(
                leading: const Icon(Icons.fact_check),
                title: const Text('New Inspection Form'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const InspectionFormScreen(projectId: 'proj-1')
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.red),
                title: const Text('Report Issue'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const IssueReportScreen(projectId: 'proj-1')
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline, color: Colors.blue),
                title: const Text('Project Timeline'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const TimelineScreen(projectId: 'proj-1')
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_alt, color: Colors.purple),
                title: const Text('Log Daily Workforce'),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const WorkforceEntryScreen(projectId: 'proj-1')
                  ));
                },
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('City Hall Extension'),
            subtitle: const Text('Planned'),
            children: [
              ListTile(
                leading: const Icon(Icons.fact_check),
                title: const Text('New Inspection Form'),
                onTap: () {},
              )
            ],
          ),
        ],
      ),
    );
  }
}
