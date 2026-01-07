import 'package:calendar_view/calendar_view.dart';
import 'package:flutter/material.dart';

class AdditionalItem {
  final String name;
  final double price;

  const AdditionalItem({required this.name, required this.price});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory AdditionalItem.fromMap(Map<String, dynamic> map) {
    return AdditionalItem(
      name: (map['name'] ?? '') as String,
      price: (map['price'] ?? 0.0) as double,
    );
  }
}

class EventNotification {
  final bool enabled;
  final int minutesBefore;
  final String? customMessage;

  const EventNotification({
    this.enabled = false,
    this.minutesBefore = 60,
    this.customMessage,
  });

  String get displayText {
    if (minutesBefore < 60) {
      return '$minutesBefore minute${minutesBefore == 1 ? '' : 's'} before';
    } else if (minutesBefore < 1440) {
      final hours = minutesBefore ~/ 60;
      return '$hours hour${hours == 1 ? '' : 's'} before';
    } else {
      final days = minutesBefore ~/ 1440;
      return '$days day${days == 1 ? '' : 's'} before';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'minutesBefore': minutesBefore,
      'customMessage': customMessage,
    };
  }

  factory EventNotification.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const EventNotification(enabled: false, minutesBefore: 60);
    }
    return EventNotification(
      enabled: (map['enabled'] ?? false) as bool,
      minutesBefore: (map['minutesBefore'] ?? 60) as int,
      customMessage: map['customMessage'] as String?,
    );
  }

  EventNotification copyWith({
    bool? enabled,
    int? minutesBefore,
    String? customMessage,
  }) {
    return EventNotification(
      enabled: enabled ?? this.enabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      customMessage: customMessage ?? this.customMessage,
    );
  }
}

class CustomCalendarEventData extends CalendarEventData {
  final String id;
  final double? money;
  final double? diesel;
  final List<AdditionalItem> additionalItems;
  final EventNotification notification;

  CustomCalendarEventData({
    required this.id,
    required DateTime date,
    required String title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    Color? color,
    this.money,
    this.diesel,
    this.additionalItems = const [],
    EventNotification? notification,
  }) :
        notification = notification ?? const EventNotification(enabled: false, minutesBefore: 60),
        super(
        date: date,
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        color: color ?? Colors.blue,
      ) {
    assert(id.isNotEmpty, 'ID cannot be empty');
  }

  double get additionalItemsTotal {
    return additionalItems.fold(0.0, (sum, item) => sum + item.price);
  }

  double get totalExpenses {
    return (diesel ?? 0.0) + additionalItemsTotal;
  }

  double get grandTotal {
    return (money ?? 0.0) - totalExpenses;
  }

  DateTime? get notificationTime {
    if (!notification.enabled) return null;
    final eventTime = startTime ?? date;
    return eventTime.subtract(Duration(minutes: notification.minutesBefore));
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'title': title,
      'description': description,
      'startTime': startTime?.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'color': color?.value,
      'money': money,
      'diesel': diesel,
      'additionalItems': additionalItems.map((item) => item.toMap()).toList(),
      'notification': notification.toMap(),
    };
  }

  factory CustomCalendarEventData.fromMap(Map<String, dynamic> map) {
    List<AdditionalItem> additionalItems = [];

    if (map['additionalItems'] is List) {
      additionalItems = (map['additionalItems'] as List).map((item) {
        if (item is Map<String, dynamic>) {
          return AdditionalItem.fromMap(item);
        }
        return const AdditionalItem(name: '', price: 0.0);
      }).toList();
    }

    Color? color;
    if (map['color'] != null) {
      try {
        color = Color(map['color'] as int);
      } catch (e) {
        color = null;
      }
    }

    return CustomCalendarEventData(
      id: (map['id'] ?? CustomCalendarEventData.generateId()) as String,
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] ?? 0) as int),
      title: (map['title'] ?? 'No Title') as String,
      description: map['description'] as String?,
      startTime: map['startTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int)
          : null,
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int)
          : null,
      color: color,
      money: (map['money'] as num?)?.toDouble(),
      diesel: (map['diesel'] as num?)?.toDouble(),
      additionalItems: additionalItems,
      notification: EventNotification.fromMap(map['notification'] as Map<String, dynamic>?),
    );
  }
}