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

    // Create events table
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
        notification_custom_message TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create notification history table
    _database.execute('''
      CREATE TABLE IF NOT EXISTS notification_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL,
        event_title TEXT NOT NULL,
        message TEXT NOT NULL,
        shown_at INTEGER NOT NULL,
        was_clicked INTEGER DEFAULT 0,
        event_data TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
      )
    ''');

    // Create indexes
    _database.execute('CREATE INDEX IF NOT EXISTS idx_events_date ON events(date)');
    _database.execute('CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time)');
    _database.execute('CREATE INDEX IF NOT EXISTS idx_notification_history_shown_at ON notification_history(shown_at)');

    print('✅ Database tables created');
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