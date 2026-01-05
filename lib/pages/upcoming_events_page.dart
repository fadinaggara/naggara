import 'package:scheduladi/components/custom_calendar_event_data.dart';
import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:scheduladi/pages/add_event_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/database_provider.dart';
import '../event_manager.dart';

class UpcomingEventsPage extends StatelessWidget {
  final EventController controller;
  final ValueNotifier<int>? refreshNotifier;

  const UpcomingEventsPage({
    super.key,
    required this.controller,
    this.refreshNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: refreshNotifier ?? ValueNotifier<int>(0),
      builder: (context, value, child) {
        return Consumer<DatabaseProvider>(
          builder: (context, databaseProvider, child) {
            return FutureBuilder<List<CustomCalendarEventData>>(
              future: databaseProvider.getUpcomingEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 80, color: Colors.red),
                        const SizedBox(height: 20),
                        const Text(
                          "Error Loading Events",
                          style: TextStyle(fontSize: 20, color: Colors.red),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            databaseProvider.loadEvents();
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  );
                }

                final upcomingEvents = snapshot.data ?? [];

                return _UpcomingEventsContent(
                  controller: controller,
                  upcomingEvents: upcomingEvents,
                  databaseProvider: databaseProvider,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UpcomingEventsContent extends StatefulWidget {
  final EventController controller;
  final List<CustomCalendarEventData> upcomingEvents;
  final DatabaseProvider databaseProvider;

  const _UpcomingEventsContent({
    required this.controller,
    required this.upcomingEvents,
    required this.databaseProvider,
  });

  @override
  State<_UpcomingEventsContent> createState() => _UpcomingEventsContentState();
}

class _UpcomingEventsContentState extends State<_UpcomingEventsContent> {
  late List<CustomCalendarEventData> _upcomingEvents;
  int _pastEventsCount = 0;
  final EventManager _eventManager = EventManager();

  @override
  void initState() {
    super.initState();
    _upcomingEvents = widget.upcomingEvents;
    _loadPastEventsCount();
  }

  Future<void> _loadPastEventsCount() async {
    final pastEvents = await widget.databaseProvider.getPastEvents();
    setState(() {
      _pastEventsCount = pastEvents.length;
    });
  }

  Future<void> _onRefresh() async {
    try {
      // Use EventManager to refresh
      await _eventManager.refreshEvents(context, widget.controller);

      // Get updated events
      final upcomingEvents = await widget.databaseProvider.getUpcomingEvents();
      final pastEvents = await widget.databaseProvider.getPastEvents();

      setState(() {
        _upcomingEvents = upcomingEvents;
        _pastEventsCount = pastEvents.length;
      });

    } catch (e) {
      print('Error refreshing events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh: $e')),
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Upcoming Events",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final totalEvents = _upcomingEvents.length + _pastEventsCount;

    if (totalEvents == 0) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    "No Events Found",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Go to the Calendar tab and click the + button to create your first event",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _onRefresh,
                    child: const Text("Refresh"),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_upcomingEvents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upcoming, size: 80, color: Colors.orange),
                  const SizedBox(height: 20),
                  const Text(
                    "No Upcoming Events",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You have $_pastEventsCount event${_pastEventsCount == 1 ? '' : 's'} in the past",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Pull down to refresh",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Column(
        children: [
          // Summary card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.upcoming, color: Colors.green, size: 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_upcomingEvents.length} Upcoming ${_upcomingEvents.length == 1 ? 'Event' : 'Events'}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_pastEventsCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              "$_pastEventsCount past event${_pastEventsCount == 1 ? '' : 's'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      // Total value of upcoming events
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "TND ${_calculateTotalValue(_upcomingEvents).toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Text(
                            "Total Value",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.refresh, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        "Pull down to refresh",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Events list
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _upcomingEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = _upcomingEvents[index];
                return _UpcomingEventCard(
                  event: event,
                  onEdit: () => _editEvent(context, event),
                  onDelete: () => _deleteEvent(context, event),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalValue(List<CustomCalendarEventData> events) {
    return events.fold(0.0, (total, event) => total + (event.grandTotal));
  }

  Future<void> _editEvent(BuildContext context, CustomCalendarEventData event) async {
    final updatedEvent = await showDialog<CustomCalendarEventData>(
      context: context,
      builder: (_) => AddEventDialog(existingEvent: event),
    );

    if (updatedEvent != null) {
      try {
        // Use EventManager to update
        await _eventManager.updateEvent(context, event, updatedEvent, widget.controller);

        // Update local list
        final index = _upcomingEvents.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          setState(() {
            _upcomingEvents[index] = updatedEvent;
          });
        }

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
                // Use EventManager to delete
                await _eventManager.deleteEvent(context, event, widget.controller);

                // Update local list
                setState(() {
                  _upcomingEvents.removeWhere((e) => e.id == event.id);
                });

                // Update past events count
                await _loadPastEventsCount();

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
}

// Keep your existing _UpcomingEventCard and _InfoChip classes
class _UpcomingEventCard extends StatelessWidget {
  final CustomCalendarEventData event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UpcomingEventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final start = event.startTime ?? event.date;
    final end = event.endTime ?? event.date;
    final now = DateTime.now();
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: event.color ?? Colors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(start, isToday),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatTime(start)} - ${_formatTime(end)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit')
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete')
                      ]),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                ),
              ],
            ),
            if (event.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(event.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (event.money != null)
                  _InfoChip(
                      icon: Icons.attach_money,
                      label: 'Money: TND ${event.money!.toStringAsFixed(2)}',
                      color: Colors.blue),
                if (event.diesel != null)
                  _InfoChip(
                      icon: Icons.local_gas_station,
                      label: 'Diesel: TND ${event.diesel!.toStringAsFixed(2)}',
                      color: Colors.orange),
                if (event.additionalItems.isNotEmpty)
                  _InfoChip(
                      icon: Icons.list,
                      label:
                      'Items: TND ${event.additionalItemsTotal.toStringAsFixed(2)}',
                      color: Colors.purple),
                _InfoChip(
                    icon: Icons.calculate,
                    label: 'Total: TND ${event.grandTotal.toStringAsFixed(2)}',
                    color: Colors.green),
              ],
            ),
            if (event.additionalItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                  'Items: ${event.additionalItems.map((item) => item.name).join(', ')}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, bool isToday) {
    final now = DateTime.now();
    final difference = date.difference(DateTime(now.year, now.month, now.day));
    if (isToday) return 'Today';
    if (difference.inDays == 1) return 'Tomorrow';
    if (difference.inDays == 2) return 'Day after tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500))
      ]),
    );
  }
}