import 'package:flutter/material.dart';
import 'package:scheduladi/components/custom_calendar_event_data.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../components/notification_service.dart';
import '../event-notif.dart' hide EventNotification;
import 'database_helper.dart';

class DatabaseProvider extends ChangeNotifier {
  Database? _database;
  List<CustomCalendarEventData> _events = [];
  bool _isLoading = false;

  List<CustomCalendarEventData> get events => _events;
  bool get isLoading => _isLoading;

  DatabaseProvider() {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      _isLoading = true;
      notifyListeners();

      final dbHelper = DatabaseHelper();
      await dbHelper.initialize();
      _database = dbHelper.database;

      await _loadEventsFromDb();

      _isLoading = false;
      notifyListeners();

      print('✅ DatabaseProvider initialized with ${_events.length} events');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('❌ Error initializing database: $e');
    }
  }

  Future<void> _loadEventsFromDb() async {
    if (_database == null) return;

    try {
      final results = _database!.select('SELECT * FROM events ORDER BY date');

      _events = results.map((row) {
        List<AdditionalItem> additionalItems = [];

        if (row['additional_items'] != null && row['additional_items'].toString().isNotEmpty) {
          try {
            final itemsJson = jsonDecode(row['additional_items'].toString()) as List;
            additionalItems = itemsJson.map((item) => AdditionalItem(
              name: item['name'] as String,
              price: (item['price'] as num).toDouble(),
            )).toList();
          } catch (e) {
            print('❌ Error parsing additional items: $e');
          }
        }

        return CustomCalendarEventData(
          id: row['id'].toString(),
          date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
          title: row['title'].toString(),
          description: row['description']?.toString(),
          startTime: row['start_time'] != null
              ? DateTime.fromMillisecondsSinceEpoch(row['start_time'] as int)
              : null,
          endTime: row['end_time'] != null
              ? DateTime.fromMillisecondsSinceEpoch(row['end_time'] as int)
              : null,
          color: row['color'] != null ? Color(row['color'] as int) : null,
          money: (row['money'] as num?)?.toDouble(),
          diesel: (row['diesel'] as num?)?.toDouble(),
          additionalItems: additionalItems,
          notification: EventNotification(
            enabled: (row['notification_enabled'] as int) == 1,
            minutesBefore: row['notification_minutes_before'] as int,
            customMessage: row['notification_custom_message']?.toString(),
          ),
        );
      }).toList();
    } catch (e) {
      print('❌ Error loading events from database: $e');
      _events = [];
    }
  }

  Future<void> loadEvents() async {
    await _loadEventsFromDb();
    notifyListeners();
  }

  Future<void> addEvent(CustomCalendarEventData event) async {
    if (_database == null) return;

    try {
      final map = _eventToMap(event);

      _database!.execute('''
        INSERT INTO events (
          id, date, title, description, start_time, end_time, color,
          money, diesel, additional_items, notification_enabled,
          notification_minutes_before, notification_custom_message,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        map['id'],
        map['date'],
        map['title'],
        map['description'],
        map['start_time'],
        map['end_time'],
        map['color'],
        map['money'],
        map['diesel'],
        map['additional_items'],
        map['notification_enabled'],
        map['notification_minutes_before'],
        map['notification_custom_message'],
        map['created_at'],
        map['updated_at'],
      ]);

      // Add to local list
      _events.add(event);
      notifyListeners();

      print('✅ Event added to database: ${event.title}');

    } catch (e) {
      print('❌ Error adding event: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(CustomCalendarEventData event) async {
    if (_database == null) return;

    try {
      final map = _eventToMap(event);

      _database!.execute('''
        UPDATE events SET
          date = ?,
          title = ?,
          description = ?,
          start_time = ?,
          end_time = ?,
          color = ?,
          money = ?,
          diesel = ?,
          additional_items = ?,
          notification_enabled = ?,
          notification_minutes_before = ?,
          notification_custom_message = ?,
          updated_at = ?
        WHERE id = ?
      ''', [
        map['date'],
        map['title'],
        map['description'],
        map['start_time'],
        map['end_time'],
        map['color'],
        map['money'],
        map['diesel'],
        map['additional_items'],
        map['notification_enabled'],
        map['notification_minutes_before'],
        map['notification_custom_message'],
        map['updated_at'],
        map['id'],
      ]);

      // Update in local list
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = event;
      }
      notifyListeners();

      print('✅ Event updated in database: ${event.title}');

    } catch (e) {
      print('❌ Error updating event: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (_database == null) return;

    try {
      _database!.execute('DELETE FROM events WHERE id = ?', [eventId]);

      // Remove from local list
      _events.removeWhere((event) => event.id == eventId);
      notifyListeners();

      print('✅ Event deleted from database: $eventId');

    } catch (e) {
      print('❌ Error deleting event: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _eventToMap(CustomCalendarEventData event) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Basic fields that always exist
    final map = {
      'id': event.id,
      'date': event.date.millisecondsSinceEpoch,
      'title': event.title ?? '',
      'description': event.description ?? '',
      'start_time': event.startTime?.millisecondsSinceEpoch,
      'end_time': event.endTime?.millisecondsSinceEpoch,
      'color': event.color?.value,
      'money': event.money,
      'diesel': event.diesel,
      'additional_items': jsonEncode(event.additionalItems.map((item) => {
        'name': item.name,
        'price': item.price,
      }).toList()),
      'notification_enabled': event.notification.enabled ? 1 : 0,
      'notification_minutes_before': event.notification.minutesBefore,
      'notification_custom_message': event.notification.customMessage,
    };

    // Try to add timestamp fields (they may not exist in older schema)
    try {
      map['created_at'] = now;
      map['updated_at'] = now;
    } catch (e) {
      print('⚠️ Timestamp fields not available in schema: $e');
    }

    return map;
  }

  Future<List<CustomCalendarEventData>> getUpcomingEvents() async {
    await _loadEventsFromDb();
    final now = DateTime.now();
    return _events.where((event) {
      final eventDate = event.startTime ?? event.date;
      return eventDate.isAfter(now);
    }).toList();
  }

  Future<List<CustomCalendarEventData>> getPastEvents() async {
    await _loadEventsFromDb();
    final now = DateTime.now();
    return _events.where((event) {
      final eventDate = event.startTime ?? event.date;
      return eventDate.isBefore(now);
    }).toList();
  }

  Future<List<CustomCalendarEventData>> getAllEvents() async {
    await _loadEventsFromDb();
    return _events;
  }

  Future<List<CustomCalendarEventData>> getEventsForDate(DateTime date) async {
    await _loadEventsFromDb();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _events.where((event) {
      final eventDate = event.startTime ?? event.date;
      return eventDate.isAfter(startOfDay) && eventDate.isBefore(endOfDay);
    }).toList();
  }
}