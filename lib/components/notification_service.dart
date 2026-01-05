// notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'custom_calendar_event_data.dart';

class NotificationHistory {
  final String eventId;
  final String eventTitle;
  final String message;
  final DateTime shownAt;
  final bool wasClicked;
  final CustomCalendarEventData event; // Add this field to store the full event

  NotificationHistory({
    required this.eventId,
    required this.eventTitle,
    required this.message,
    required this.shownAt,
    required this.event, // Make it required
    this.wasClicked = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Map<int, Timer> _activeTimers = {};
  final List<NotificationHistory> _notificationHistory = [];

  Future<void> initialize() async {
    // Android setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS setup
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  Future<void> scheduleEventNotification(CustomCalendarEventData event) async {
    if (!event.notification.enabled || event.notificationTime == null) {
      return;
    }

    final notificationTime = event.notificationTime!;
    final now = DateTime.now();

    // Don't schedule if it's in the past
    if (notificationTime.isBefore(now)) {
      print('⏰ Notification time is in the past, skipping: $notificationTime');
      return;
    }

    final delay = notificationTime.difference(now);

    // Cancel existing timer for this event
    cancelEventNotification(event.id);

    // Schedule new timer
    final timer = Timer(delay, () {
      _showNotification(event);
    });

    _activeTimers[event.id.hashCode] = timer;

    print(
        '📅 Notification scheduled for "${event.title}" at $notificationTime (in ${delay.inMinutes} minutes)');
  }

  Future<void> _showNotification(CustomCalendarEventData event) async {
    final message = event.notification.customMessage ??
        'Reminder: "${event.title}" starts at ${_formatTime(event.startTime ?? event.date)}';

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'event_channel', // channel id
      'Event Notifications', // channel name
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        event.id.hashCode, // Unique ID
        '📅 Event Reminder: ${event.title}',
        message,
        details,
      );

      // LOG THE NOTIFICATION TO HISTORY WITH THE FULL EVENT
      _logNotificationShown(event, message);

      print('🔔 Notification shown for "${event.title}"');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }

    // Remove timer from active timers
    _activeTimers.remove(event.id.hashCode);
  }

  void _logNotificationShown(CustomCalendarEventData event, String message) {
    _notificationHistory.add(NotificationHistory(
      eventId: event.id,
      eventTitle: event.title ?? 'No Title',
      message: message,
      shownAt: DateTime.now(),
      event: event, // Store the full event object
    ));

    print('📋 Notification logged to history: ${event.title}');
  }

  // Get notification history (newest first)
  List<NotificationHistory> getNotificationHistory() {
    return List.from(_notificationHistory.reversed);
  }

  // Clear notification history
  void clearNotificationHistory() {
    _notificationHistory.clear();
    print('🗑️ Notification history cleared');
  }

  // Get notification statistics
  Map<String, int> getNotificationStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return {
      'today': _notificationHistory
          .where((h) => h.shownAt.isAfter(today))
          .length,
      'thisWeek': _notificationHistory
          .where((h) => h.shownAt.isAfter(startOfWeek))
          .length,
      'total': _notificationHistory.length,
    };
  }

  Future<void> cancelEventNotification(String eventId) async {
    final timer = _activeTimers[eventId.hashCode];
    if (timer != null) {
      timer.cancel();
      _activeTimers.remove(eventId.hashCode);
    }

    // Also cancel any shown notification
    await _notifications.cancel(eventId.hashCode);

    print('❌ Notification cancelled for event: $eventId');
  }

  Future<void> rescheduleAllNotifications(
      List<CustomCalendarEventData> events) async {
    // Cancel all existing timers and notifications
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    await _notifications.cancelAll();

    // Schedule new ones for enabled notifications
    for (final event in events) {
      if (event.notification.enabled) {
        await scheduleEventNotification(event);
      }
    }

    print('🔄 Rescheduled notifications for ${events.length} events');
  }

  void dispose() {
    // Cancel all timers when service is disposed
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }


}