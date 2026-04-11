import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/db_helper.dart';

class SyncProvider with ChangeNotifier {
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  SyncProvider() {
    updatePendingCount();
  }

  Future<void> updatePendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    _pendingCount = (result.first['count'] as int?) ?? 0;
    notifyListeners();
  }
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      return null;
    }
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      // Get all pending items in the queue
      final queue = await db.query('sync_queue', orderBy: 'id ASC');
      
      for (final item in queue) {
        final id = item['id'] as int;
        final type = item['entity_type'] as String;
        final operation = item['operation'] as String;
        final payload = jsonDecode(item['payload'] as String);

        try {
          if (_supabase != null) {
            if (type == 'field_report') {
              // ── Transactional Sync via RPC ──
              // This pushes the entire relational report (Workforce, Materials, etc.) in one go
              await _supabase!.rpc('submit_field_report', params: {'report': payload});
            } else if (operation == 'INSERT') {
              // Legacy sync for simple tables
              String tableName = type == 'workforce_record' ? 'workforce_records' : 
                                type == 'issue' ? 'issues' : 
                                type == 'inspection' ? 'inspections' : type;
              
              await _supabase!.from(tableName).insert(payload);
            }
          }
          
          // Bandwidth Awareness: Sequential processing with small delay to prevent monopolizing mobile data
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Remove from local queue on success
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
          
          // Update local metadata status
          if (type == 'field_report') {
             await db.update('visit_metadata', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [item['entity_id']]);
          }

        } catch (e) {
          debugPrint('Sync failed for queue item $id: $e');
          // Stop sync on failure to maintain sequence integrity
          break; 
        }
      }

      _lastSyncTime = DateTime.now();

      // ── Download Sync: Fetch assigned profile, projects, and tasks ─────────
      if (_supabase != null) {
        final userId = _supabase!.auth.currentUser?.id;
        if (userId != null) {
          // 1. Fetch Profile
          final profile = await _supabase!.from('users').select().eq('id', userId).single();
          await db.insert('user_profile', {
            'id': profile['id'],
            'full_name': profile['full_name'],
            'role': profile['role'],
            'assigned_districts': jsonEncode(profile['assigned_districts']),
            'specializations': jsonEncode(profile['specializations']),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          // 2. Fetch Assigned Projects
          final projIds = await _supabase!.from('project_assignments').select('project_id').eq('user_id', userId);
          final List<String> assignedIds = projIds.map((p) => p['project_id'].toString()).toList();

          // 3. Fetch Projects in my districts
          final districts = profile['assigned_districts'] as List<dynamic>;
          final projectsResult = await _supabase!
              .from('projects')
              .select()
              .filter('district', 'in', districts);
          
          for (var p in projectsResult) {
            await db.insert('projects', {
              'id': p['id'],
              'name': p['name'],
              'description': p['description'],
              'status': p['status'],
              'created_at': p['created_at'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }

          // 4. Fetch Specific Tasks
          final tasks = await _supabase!.from('inspection_tasks').select().eq('assignee_id', userId);
          for (var t in tasks) {
            await db.insert('inspection_tasks', {
              'id': t['id'],
              'project_id': t['project_id'],
              'assignee_id': t['assignee_id'],
              'title': t['title'],
              'description': t['description'],
              'deadline': t['deadline'],
              'priority': t['priority'],
              'status': t['status'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

    } catch (e) {
      debugPrint('Sync critical error: $e');
    } finally {
      _isSyncing = false;
      await updatePendingCount();
    }
  }
}
