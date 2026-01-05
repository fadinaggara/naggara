  import 'package:flutter/material.dart';
  import 'package:calendar_view/calendar_view.dart';

import '../components/custom_calendar_event_data.dart';
import '../event_manager.dart';
import 'add_event_dialog.dart';

  class DayPage extends StatelessWidget {
    final DateTime date;
    final EventController controller;

    const DayPage({super.key, required this.date, required this.controller});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Events on ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
          ),
          backgroundColor: Colors.deepPurple,
        ),
        body: DayView(
          controller: controller,
          initialDay: date,
          showVerticalLine: true,
          heightPerMinute: 1,
          backgroundColor: Colors.grey.shade100,
          onEventTap: (eventOrList, date) {
            final events = _normalizeToList(eventOrList);
            if (events.isEmpty) return;
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => _EventList(
                events: events,
                onEdit: (event) {
                  Navigator.pop(context);
                  if (event is CustomCalendarEventData) {
                    _editEvent(context, event);
                  }
                },
                onDelete: (event) {
                  Navigator.pop(context);
                  if (event is CustomCalendarEventData) {
                    _deleteEvent(context, event);
                  }
                },
              ),
            );
          },
        ),
      );
    }

    Future<void> _editEvent(BuildContext context, CustomCalendarEventData event) async {
      final updatedEvent = await showDialog<CustomCalendarEventData>(
        context: context,
        builder: (_) => AddEventDialog(existingEvent: event),
      );

      if (updatedEvent != null) {
        try {
          final eventManager = EventManager();
          await eventManager.updateEvent(context, event, updatedEvent, controller);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Event '${updatedEvent.title}' updated!")),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update event: $e")),
          );
        }
      }
    }

    void _deleteEvent(BuildContext context, CustomCalendarEventData event) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Delete Event"),
          content: Text("Are you sure you want to delete '${event.title}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final eventManager = EventManager();
                  await eventManager.deleteEvent(context, event, controller);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Event '${event.title}' deleted!")),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to delete event: $e")),
                  );
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    List<CalendarEventData> _normalizeToList(dynamic eventOrList) {
      if (eventOrList == null) return <CalendarEventData>[];
      if (eventOrList is CalendarEventData) return [eventOrList];
      if (eventOrList is List) {
        try {
          return eventOrList.cast<CalendarEventData>();
        } catch (_) {
          return eventOrList.whereType<CalendarEventData>().toList();
        }
      }
      return <CalendarEventData>[];
    }
  }

  // Event list bottom sheet
  class _EventList extends StatelessWidget {
    final List<CalendarEventData> events;
    final Function(CalendarEventData)? onEdit;
    final Function(CalendarEventData)? onDelete;

    const _EventList({required this.events, this.onEdit, this.onDelete});

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final e = events[index];
            final start = e.startTime ?? e.date;
            final end = e.endTime ?? e.date;
            final color = (e.color ?? Colors.blue).withOpacity(0.12);

            final customEvent = e is CustomCalendarEventData ? e : null;

            return Card(
              color: color,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  e.title ?? 'No title',
                  style: TextStyle(
                    color: e.color ?? Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.description?.isNotEmpty ?? false)
                      Text(e.description ?? ''),
                    const SizedBox(height: 4),
                    if (customEvent?.money != null)
                      Text(
                          'Money: TND ${customEvent!.money!.toStringAsFixed(2)}'),
                    if (customEvent?.diesel != null)
                      Text(
                          'Diesel Cost: TND ${customEvent!.diesel!.toStringAsFixed(2)}'),
                    if (customEvent?.additionalItems.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      ...customEvent!.additionalItems.map((item) => Text(
                          '• ${item.name}: TND ${item.price.toStringAsFixed(2)}')),
                      const SizedBox(height: 2),
                      Text(
                        'Items Total: TND ${customEvent.additionalItemsTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (customEvent?.diesel != null ||
                            customEvent!.additionalItems.isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Grand Total: TND - ${customEvent!.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - "
                      "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (customEvent != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => onEdit?.call(e),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.edit,
                                    size: 18, color: Colors.blue),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => onDelete?.call(e),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.delete,
                                    size: 18, color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
  }
