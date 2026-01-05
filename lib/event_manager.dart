import 'package:calendar_view/calendar_view.dart';
import 'package:scheduladi/components/custom_calendar_event_data.dart';
import 'package:scheduladi/components/notification_service.dart';
import 'database/database_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class EventManager {
  static final EventManager _instance = EventManager._internal();
  factory EventManager() => _instance;
  EventManager._internal();

  final NotificationService _notificationService = NotificationService();

  Future<void> addEvent(
      BuildContext context,
      CustomCalendarEventData event,
      EventController eventController,
      ) async {
    try {
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // Save to database
      await databaseProvider.addEvent(event);

      // Update EventController for immediate UI update
      eventController.add(event);

      // Schedule notification if enabled
      if (event.notification.enabled && event.notificationTime != null) {
        print('🔔 Scheduling notification for new event: ${event.title}');
        await _notificationService.scheduleEventNotification(event);
      }

      print('✅ Event added: ${event.title}');
    } catch (e) {
      print('❌ Error adding event: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(
      BuildContext context,
      CustomCalendarEventData oldEvent,
      CustomCalendarEventData updatedEvent,
      EventController eventController,
      ) async {
    try {
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // Cancel old notification
      await _notificationService.cancelEventNotification(oldEvent.id);

      // Update in database
      await databaseProvider.updateEvent(updatedEvent);

      // Update EventController
      eventController.remove(oldEvent);
      eventController.add(updatedEvent);

      // Schedule new notification if enabled
      if (updatedEvent.notification.enabled && updatedEvent.notificationTime != null) {
        print('🔔 Rescheduling notification for updated event: ${updatedEvent.title}');
        await _notificationService.scheduleEventNotification(updatedEvent);
      }

      print('✅ Event updated: ${updatedEvent.title}');
    } catch (e) {
      print('❌ Error updating event: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(
      BuildContext context,
      CustomCalendarEventData event,
      EventController eventController,
      ) async {
    try {
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // Cancel notification
      await _notificationService.cancelEventNotification(event.id);

      // Delete from database
      await databaseProvider.deleteEvent(event.id);

      // Update EventController
      eventController.remove(event);

      print('✅ Event deleted: ${event.title}');
    } catch (e) {
      print('❌ Error deleting event: $e');
      rethrow;
    }
  }

  Future<void> refreshEvents(
      BuildContext context,
      EventController eventController,
      ) async {
    try {
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // Load fresh events from database
      await databaseProvider.loadEvents();

      // Clear existing events in controller
      final eventsToRemove = List.from(eventController.events);
      for (var event in eventsToRemove) {
        eventController.remove(event);
      }

      // Add fresh events to controller
      final allEvents = databaseProvider.events;
      eventController.addAll(allEvents);

      // Reschedule all notifications
      await _notificationService.rescheduleAllNotifications(allEvents);

      print('✅ Refreshed events: ${allEvents.length} events loaded');
    } catch (e) {
      print('❌ Error refreshing events: $e');
      rethrow;
    }
  }

  Future<void> initializeNotifications() async {
    try {
      await _notificationService.initialize();
      print('🔔 Notification service initialized');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }
}