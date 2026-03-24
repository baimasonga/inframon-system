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

    // Inspections table
    await db.execute('''
    CREATE TABLE inspections (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      inspector_id TEXT,
      inspection_date TEXT,
      status TEXT,
      notes TEXT,
      sync_status TEXT DEFAULT 'pending'
    )
    ''');
    
    // Issues table
    await db.execute('''
    CREATE TABLE issues (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      title TEXT NOT NULL,
      description TEXT,
      severity TEXT,
      status TEXT,
      location_lat REAL,
      location_lng REAL,
      sync_status TEXT DEFAULT 'pending'
    )
    ''');
    
    // Workforce Records
    await db.execute('''
    CREATE TABLE workforce_records (
      id TEXT PRIMARY KEY,
      project_id TEXT,
      record_date TEXT,
      role_category TEXT,
      gender TEXT,
      is_youth INTEGER,
      count INTEGER,
      sync_status TEXT DEFAULT 'pending'
    )
    ''');

    // Sync Queue
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
