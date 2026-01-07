import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  late Database _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance ??= DatabaseHelper._internal();
  }

  Database get database => _database;

  Future<void> initialize() async {
    final dbPath = await _getDatabasePath();
    _database = sqlite3.open(dbPath);

    _createTables();

    print('✅ Database initialized at: $dbPath');
  }

  Future<String> _getDatabasePath() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(path.join(documentsDir.path, 'scheduladi_db'));

    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }

    return path.join(dbDir.path, 'scheduladi.db');
  }

  void _createTables() {
    // Enable foreign keys
    _database.execute('PRAGMA foreign_keys = ON');

    // Create events table - simplified without created_at/updated_at initially
    _database.execute('''
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY,
      date INTEGER NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      start_time INTEGER,
      end_time INTEGER,
      color INTEGER,
      money REAL,
      diesel REAL,
      additional_items TEXT,
      notification_enabled INTEGER DEFAULT 0,
      notification_minutes_before INTEGER DEFAULT 60,
      notification_custom_message TEXT
    )
  ''');

    // Run migration to add missing columns if they don't exist
    _migrateDatabaseSchema();

    // Create notification history table
    _database.execute('''
    CREATE TABLE IF NOT EXISTS notification_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id TEXT NOT NULL,
      event_title TEXT NOT NULL,
      message TEXT NOT NULL,
      shown_at INTEGER NOT NULL,
      was_clicked INTEGER DEFAULT 0,
      event_data TEXT NOT NULL
    )
  ''');

    // Create indexes
    _database.execute('CREATE INDEX IF NOT EXISTS idx_events_date ON events(date)');
    _database.execute('CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time)');
    _database.execute('CREATE INDEX IF NOT EXISTS idx_notification_history_shown_at ON notification_history(shown_at)');

    print('✅ Database tables created and migrated');
  }

// Add this migration method
  void _migrateDatabaseSchema() {
    try {
      print('🔄 Checking database schema...');

      // Check if created_at column exists
      final columns = _database.select('PRAGMA table_info(events)');
      final columnNames = columns.map((col) => col['name'] as String).toList();

      // Add missing columns
      if (!columnNames.contains('created_at')) {
        print('🔧 Adding created_at column...');
        _database.execute('ALTER TABLE events ADD COLUMN created_at INTEGER DEFAULT 0');
      }

      if (!columnNames.contains('updated_at')) {
        print('🔧 Adding updated_at column...');
        _database.execute('ALTER TABLE events ADD COLUMN updated_at INTEGER DEFAULT 0');
      }

      print('✅ Database schema migration complete');
    } catch (e) {
      print('⚠️ Schema migration error: $e');
      // Continue anyway - columns might already exist
    }
  }

  ResultSet executeSelect(String sql, [List<Object?>? params]) {
    try {
      return _database.select(sql, params ?? []);
    } catch (e) {
      print('❌ Database select error: $e\nSQL: $sql\nParams: $params');
      rethrow;
    }
  }

  void executeUpdate(String sql, [List<Object?>? params]) {
    try {
      _database.execute(sql, params ?? []);
    } catch (e) {
      print('❌ Database update error: $e\nSQL: $sql\nParams: $params');
      rethrow;
    }
  }

  void close() {
    _database.dispose();
  }
}