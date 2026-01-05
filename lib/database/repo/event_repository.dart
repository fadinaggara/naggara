import 'dart:convert';
import 'dart:ui';

import '../../event-notif.dart';
import '../database_helper.dart';
import '../models/db_event.dart';
import 'package:scheduladi/components/custom_calendar_event_data.dart';

class EventRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Insert new event
  void insertEvent(CustomCalendarEventData event) {
    final dbEvent = DbEvent.fromCalendarEvent(event);
    final map = dbEvent.toMap();

    _dbHelper.executeUpdate('''
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
  }

  // Update existing event
  void updateEvent(CustomCalendarEventData event) {
    final dbEvent = DbEvent.fromCalendarEvent(event);
    final map = dbEvent.toMap();

    _dbHelper.executeUpdate('''
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
  }

  // Delete event
  void deleteEvent(String eventId) {
    _dbHelper.executeUpdate('DELETE FROM events WHERE id = ?', [eventId]);
  }

  // Get single event by ID
  CustomCalendarEventData? getEventById(String eventId) {
    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE id = ?',
      [eventId],
    );

    if (result.isEmpty) return null;
    return DbEvent.fromMap(result.first).toCalendarEvent();
  }

  // Get all events
  List<CustomCalendarEventData> getAllEvents() {
    final results = _dbHelper.executeSelect('SELECT * FROM events');

    return results.map((row) {
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
  }

  // Get events by date range
  List<CustomCalendarEventData> getEventsByDateRange(DateTime start, DateTime end) {
    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE date BETWEEN ? AND ? OR start_time BETWEEN ? AND ?',
      [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
    return result.map((row) => DbEvent.fromMap(row).toCalendarEvent()).toList();
  }

  // Get upcoming events (after current time)
  List<CustomCalendarEventData> getUpcomingEvents() {
    final now = DateTime.now().millisecondsSinceEpoch;

    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE start_time > ? OR (start_time IS NULL AND date > ?) ORDER BY COALESCE(start_time, date) ASC',
      [now, now],
    );

    return result.map((row) => DbEvent.fromMap(row).toCalendarEvent()).toList();
  }

  // Get past events (before current time)
  List<CustomCalendarEventData> getPastEvents() {
    final now = DateTime.now().millisecondsSinceEpoch;

    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE start_time < ? OR (start_time IS NULL AND date < ?) ORDER BY COALESCE(start_time, date) DESC',
      [now, now],
    );

    return result.map((row) => DbEvent.fromMap(row).toCalendarEvent()).toList();
  }

  // Get events for specific date
  List<CustomCalendarEventData> getEventsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE (start_time BETWEEN ? AND ?) OR (date BETWEEN ? AND ?)',
      [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );

    return result.map((row) => DbEvent.fromMap(row).toCalendarEvent()).toList();
  }

  // Count total events
  int countEvents() {
    final result = _dbHelper.executeSelect('SELECT COUNT(*) as count FROM events');
    return result.first['count'] as int;
  }

  // Search events by title or description
  List<CustomCalendarEventData> searchEvents(String query) {
    final searchQuery = '%$query%';

    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE title LIKE ? OR description LIKE ?',
      [searchQuery, searchQuery],
    );

    return result.map((row) => DbEvent.fromMap(row).toCalendarEvent()).toList();
  }

  // Get events with notifications enabled
  List<CustomCalendarEventData> getEventsWithNotifications() {
    final result = _dbHelper.executeSelect(
      'SELECT * FROM events WHERE notification_enabled = 1',
    );

    return result.map((row) => DbEvent.fromMap(row).toCalendarEvent()).toList();
  }
}