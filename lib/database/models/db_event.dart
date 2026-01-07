import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:scheduladi/components/custom_calendar_event_data.dart';
import 'package:scheduladi/event-notif.dart' hide EventNotification;

class DbEvent {
  final String id;
  final DateTime date;
  final String title;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final Color? color;
  final double? money;
  final double? diesel;
  final List<AdditionalItem> additionalItems;
  final bool notificationEnabled;
  final int notificationMinutesBefore;
  final String? notificationCustomMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  DbEvent({
    required this.id,
    required this.date,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.color,
    this.money,
    this.diesel,
    required this.additionalItems,
    required this.notificationEnabled,
    required this.notificationMinutesBefore,
    this.notificationCustomMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to CustomCalendarEventData
  CustomCalendarEventData toCalendarEvent() {
    return CustomCalendarEventData(
      id: id,
      date: date,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      color: color,
      money: money,
      diesel: diesel,
      additionalItems: additionalItems,
      notification: EventNotification(
        enabled: notificationEnabled,
        minutesBefore: notificationMinutesBefore,
        customMessage: notificationCustomMessage,
      ),
    );
  }

  // Convert from CustomCalendarEventData
  factory DbEvent.fromCalendarEvent(CustomCalendarEventData event) {
    return DbEvent(
      id: event.id,
      date: event.date,
      title: event.title ?? 'No Title',
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      color: event.color,
      money: event.money,
      diesel: event.diesel,
      additionalItems: event.additionalItems,
      notificationEnabled: event.notification.enabled,
      notificationMinutesBefore: event.notification.minutesBefore,
      notificationCustomMessage: event.notification.customMessage,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'title': title,
      'description': description,
      'start_time': startTime?.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'color': color?.value,
      'money': money,
      'diesel': diesel,
      'additional_items': jsonEncode(
        additionalItems.map((item) => {
          'name': item.name,
          'price': item.price,
        }).toList(),
      ),
      'notification_enabled': notificationEnabled ? 1 : 0,
      'notification_minutes_before': notificationMinutesBefore,
      'notification_custom_message': notificationCustomMessage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Convert from Map from database
  factory DbEvent.fromMap(Map<String, dynamic> map) {
    List<AdditionalItem> additionalItems = [];

    if (map['additional_items'] != null && map['additional_items'] is String) {
      final itemsJson = jsonDecode(map['additional_items'] as String) as List;
      additionalItems = itemsJson.map((item) =>
          AdditionalItem(
            name: item['name'] as String,
            price: (item['price'] as num).toDouble(),
          )
      ).toList();
    }

    return DbEvent(
      id: map['id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      title: map['title'] as String,
      description: map['description'] as String?,
      startTime: map['start_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int)
          : null,
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
          : null,
      color: map['color'] != null ? Color(map['color'] as int) : null,
      money: (map['money'] as num?)?.toDouble(),
      diesel: (map['diesel'] as num?)?.toDouble(),
      additionalItems: additionalItems,
      notificationEnabled: (map['notification_enabled'] as int) == 1,
      notificationMinutesBefore: map['notification_minutes_before'] as int,
      notificationCustomMessage: map['notification_custom_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}