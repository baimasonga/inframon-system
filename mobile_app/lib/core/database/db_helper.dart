import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inframon.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Projects table
    await db.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      status TEXT,
      created_at TEXT
    )
    ''');

    // Visit Metadata (The master record)
    await db.execute('''
    CREATE TABLE visit_metadata (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      inspector_id TEXT,
      date_time TEXT,
      visit_type TEXT,
      weather_condition TEXT,
      site_supervisor_present INTEGER,
      overall_progress INTEGER,
      overall_status TEXT,
      recommendation TEXT,
      notes TEXT,
      gps_lat REAL,
      gps_lng REAL,
      sync_status TEXT DEFAULT 'pending'
    )
    ''');

    // Milestones Log
    await db.execute('''
    CREATE TABLE milestone_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      visit_id TEXT,
      milestone_name TEXT,
      status TEXT,
      completion_pct INTEGER,
      delay_days INTEGER,
      reason TEXT
    )
    ''');

    // Workforce Records
    await db.execute('''
    CREATE TABLE workforce_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      visit_id TEXT,
      role_category TEXT,
      count INTEGER,
      gender TEXT,
      is_youth INTEGER
    )
    ''');

    // Materials Records
    await db.execute('''
    CREATE TABLE materials_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      visit_id TEXT,
      material_name TEXT,
      verification_status INTEGER,
      notes TEXT
    )
    ''');

    // Defect Logs
    await db.execute('''
    CREATE TABLE defect_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      visit_id TEXT,
      title TEXT,
      category TEXT,
      severity TEXT,
      action_plan TEXT,
      responsible_party TEXT,
      deadline TEXT
    )
    ''');

    // User Profile (for scoping)
    await db.execute('''
    CREATE TABLE user_profile (
      id TEXT PRIMARY KEY,
      full_name TEXT,
      role TEXT,
      assigned_districts TEXT,
      specializations TEXT
    )
    ''');

    // Project Assignments (Local Cache)
    await db.execute('''
    CREATE TABLE project_assignments (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      user_id TEXT,
      role_on_project TEXT
    )
    ''');

    // Inspection Tasks (Local Cache)
    await db.execute('''
    CREATE TABLE inspection_tasks (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      assignee_id TEXT,
      title TEXT,
      description TEXT,
      deadline TEXT,
      priority TEXT,
      status TEXT
    )
    ''');

    // Existing Sync Queue (Legacy Support)
    await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
