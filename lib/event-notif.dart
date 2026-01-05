// event_notification.dart
class EventNotification {
  final bool enabled;
  final int minutesBefore;
  final String? customMessage;

  const EventNotification({
    required this.enabled,
    required this.minutesBefore,
    this.customMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'minutesBefore': minutesBefore,
      'customMessage': customMessage,
    };
  }

  factory EventNotification.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return EventNotification(enabled: false, minutesBefore: 60);
    }
    return EventNotification(
      enabled: map['enabled'] as bool? ?? false,
      minutesBefore: map['minutesBefore'] as int? ?? 60,
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

  String get displayText {
    if (minutesBefore < 60) {
      return '$minutesBefore minutes before';
    } else if (minutesBefore == 60) {
      return '1 hour before';
    } else {
      return '${minutesBefore ~/ 60} hours before';
    }
  }
}