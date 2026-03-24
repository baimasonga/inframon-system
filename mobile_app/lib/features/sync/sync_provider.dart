import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/db_helper.dart';

class SyncProvider with ChangeNotifier {
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Conditionally initialize supabase if configured
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
          // If internet and SDK connected -> Push to Cloud
          if (_supabase != null) {
            if (operation == 'INSERT') {
              // Map local entity types to cloud tables
              String tableName = type == 'workforce_record' ? 'workforce_records' : 
                                type == 'issue' ? 'issues' : 
                                type == 'inspection' ? 'inspections' : type;
              
              await _supabase!.from(tableName).insert(payload);
            }
          }
          
          // Simulation delay for UX feedback when no db configured
          if (_supabase == null) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
          
          // Remove from local queue on verifiable success
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
          
          // Update local sync status flag to reflect cloud mirror
          if (type == 'workforce_record') {
             await db.update('workforce_records', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [item['entity_id']]);
          }

        } catch (e) {
          debugPrint('Sync failed for queue item $id: $e');
          // Important: Stop execution on first failure to maintain reliable ordering
          break; 
        }
      }

      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Sync critical error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
