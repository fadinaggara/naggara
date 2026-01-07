import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:convert';
import 'custom_calendar_event_data.dart';

class NotificationHistory {
  final String eventId;
  final String eventTitle;
  final String message;
  final DateTime shownAt;
  final bool wasClicked;
  final String eventData;

  NotificationHistory({
    required this.eventId,
    required this.eventTitle,
    required this.message,
    required this.shownAt,
    required this.eventData,
    this.wasClicked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'event_title': eventTitle,
      'message': message,
      'shown_at': shownAt.millisecondsSinceEpoch,
      'was_clicked': wasClicked ? 1 : 0,
      'event_data': eventData,
    };
  }

  factory NotificationHistory.fromMap(Map<String, dynamic> map) {
    return NotificationHistory(
      eventId: map['event_id'] as String,
      eventTitle: map['event_title'] as String,
      message: map['message'] as String,
      shownAt: DateTime.fromMillisecondsSinceEpoch(map['shown_at'] as int),
      eventData: map['event_data'] as String,
      wasClicked: (map['was_clicked'] as int) == 1,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();
  final Map<String, Timer> _activeTimers = {};
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

    // Request permissions
    await _requestPermissions();

    print('🔔 Notification service initialized');
  }

  Future<void> _requestPermissions() async {
    try {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      print('🔔 Notification permission: $result');
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
    }
  }

  Future<void> scheduleEventNotification(CustomCalendarEventData event) async {
    if (!event.notification.enabled) {
      print('🔕 Notifications disabled for event: ${event.title}');
      return;
    }

    final notificationTime = event.notificationTime;
    if (notificationTime == null) {
      print('⏰ No notification time for event: ${event.title}');
      return;
    }

    final now = DateTime.now();

    // Don't schedule if it's in the past
    if (notificationTime.isBefore(now)) {
      print('⏰ Notification time is in the past, skipping');
      return;
    }

    final delay = notificationTime.difference(now);

    // If delay is too long, don't schedule
    if (delay.inDays > 30) {
      print('⏰ Notification too far in future (${delay.inDays} days), skipping');
      return;
    }

    // Cancel existing timer for this event
    cancelEventNotification(event.id);

    print('📅 Notification scheduled for "${event.title}" at $notificationTime (in ${delay.inMinutes} minutes)');

    // Schedule the notification using Timer
    final timer = Timer(delay, () {
      _showNotification(event);
    });

    _activeTimers[event.id] = timer;
  }

  Future<void> _showNotification(CustomCalendarEventData event) async {
    try {
      final message = event.notification.customMessage ??
          'Reminder: "${event.title}" starts at ${_formatTime(event.startTime ?? event.date)}';

      // Android notification details
      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'event_channel',
        'Event Notifications',
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

      await _notifications.show(
        event.id.hashCode,
        '📅 Event Reminder: ${event.title}',
        message,
        details,
      );

      // Log to history
      _notificationHistory.add(NotificationHistory(
        eventId: event.id,
        eventTitle: event.title ?? 'No Title',
        message: message,
        shownAt: DateTime.now(),
        eventData: jsonEncode(event.toMap()),
      ));

      print('🔔 Notification shown for "${event.title}"');

      // Remove timer from active timers
      _activeTimers.remove(event.id);
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  Future<void> cancelEventNotification(String eventId) async {
    // Cancel timer if exists
    final timer = _activeTimers[eventId];
    if (timer != null) {
      timer.cancel();
      _activeTimers.remove(eventId);
    }

    // Cancel notification from system
    await _notifications.cancel(eventId.hashCode);

    print('❌ Notification cancelled for event: $eventId');
  }

  Future<void> rescheduleAllNotifications(List<CustomCalendarEventData> events) async {
    print('🔄 Rescheduling notifications for ${events.length} events');

    // Cancel all existing timers
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();

    // Cancel all notifications from system
    await _notifications.cancelAll();

    // Schedule new ones
    for (final event in events) {
      if (event.notification.enabled) {
        await scheduleEventNotification(event);
      }
    }

    print('✅ Notifications rescheduled');
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

  void dispose() {
    // Cancel all timers
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}