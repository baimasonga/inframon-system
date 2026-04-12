import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
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
      final queue = await db.query('sync_queue', orderBy: 'id ASC');

      for (final item in queue) {
        final id = item['id'] as int;
        final type = item['entity_type'] as String;
        final operation = item['operation'] as String;
        final payload = jsonDecode(item['payload'] as String);

        try {
          if (_supabase != null) {
            if (type == 'field_report') {
              await _supabase!.rpc('submit_field_report', params: {'report': payload});
            } else if (operation == 'INSERT') {
              final String tableName;
              if (type == 'workforce_record') {
                tableName = 'workforce_records';
              } else if (type == 'issue') {
                tableName = 'issues';
              } else if (type == 'inspection') {
                tableName = 'inspections';
              } else if (type == 'attendance_log') {
                tableName = 'attendance_logs';
              } else {
                tableName = type;
              }
              await _supabase!.from(tableName).insert(payload);
            }
          }

          await Future.delayed(const Duration(milliseconds: 500));
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);

          if (type == 'field_report') {
            await db.update(
              'visit_metadata',
              {'sync_status': 'synced'},
              where: 'id = ?',
              whereArgs: [item['entity_id']],
            );
          } else if (type == 'issue') {
            await db.update(
              'issues',
              {'sync_status': 'synced'},
              where: 'id = ?',
              whereArgs: [item['entity_id']],
            );
          } else if (type == 'attendance_log') {
            await db.update(
              'attendance_records',
              {'sync_status': 'synced'},
              where: 'id = ?',
              whereArgs: [item['entity_id']],
            );
          }
        } catch (e) {
          debugPrint('Sync failed for queue item $id: $e');
          break;
        }
      }

      _lastSyncTime = DateTime.now();

      // ── Download Sync ────────────────────────────────────────────────────
      if (_supabase != null) {
        final userId = _supabase!.auth.currentUser?.id;
        if (userId != null) {
          // 1. Fetch Profile
          try {
            final profile = await _supabase!
                .from('users')
                .select()
                .eq('id', userId)
                .single();
            await db.insert(
              'user_profile',
              {
                'id': profile['id'],
                'full_name': profile['full_name'],
                'role': profile['role'],
                'assigned_districts':
                    jsonEncode(profile['assigned_districts'] ?? []),
                'specializations':
                    jsonEncode(profile['specializations'] ?? []),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            debugPrint('Profile fetch failed: $e');
          }

          // 2. Clear local cache for fresh pull
          await db.delete('projects');
          await db.delete('inspection_tasks');

          // 3. Fetch Projects by district and direct assignment
          final profileRows =
              await db.query('user_profile', limit: 1);
          final List<String> districts = profileRows.isNotEmpty
              ? List<String>.from(
                  jsonDecode(profileRows.first['assigned_districts'] as String? ?? '[]'),
                )
              : [];

          final assignedProjResponse = await _supabase!
              .from('project_assignments')
              .select('project_id')
              .eq('user_id', userId);
          final List<String> assignedIds =
              (assignedProjResponse as List<dynamic>)
                  .map((p) => p['project_id'].toString())
                  .toList();

          final Set<String> seenIds = {};
          final List<dynamic> allProjects = [];

          if (districts.isNotEmpty) {
            final districtProjects = await _supabase!
                .from('projects')
                .select()
                .inFilter('district', districts);
            for (var p in districtProjects as List<dynamic>) {
              if (seenIds.add(p['id'].toString())) {
                allProjects.add(p);
              }
            }
          }

          if (assignedIds.isNotEmpty) {
            final directProjects = await _supabase!
                .from('projects')
                .select()
                .inFilter('id', assignedIds);
            for (var p in directProjects as List<dynamic>) {
              if (seenIds.add(p['id'].toString())) {
                allProjects.add(p);
              }
            }
          }

          for (var p in allProjects) {
            await db.insert(
              'projects',
              {
                'id': p['id'],
                'name': p['name'],
                'description': p['description'],
                'status': p['status'],
                'district': p['district'],
                'completion_percentage': p['completion_percentage'] ?? 0,
                'created_at': p['created_at'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // 4. Fetch Tasks
          final tasks = await _supabase!
              .from('inspection_tasks')
              .select()
              .eq('assignee_id', userId);
          for (var t in tasks as List<dynamic>) {
            await db.insert(
              'inspection_tasks',
              {
                'id': t['id'],
                'project_id': t['project_id'],
                'assignee_id': t['assignee_id'],
                'title': t['title'],
                'description': t['description'],
                'deadline': t['deadline'],
                'priority': t['priority'],
                'status': t['status'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Sync critical error: $e');
    } finally {
      _isSyncing = false;
      await updatePendingCount();
      notifyListeners();
    }
  }
}
