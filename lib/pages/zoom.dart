import 'package:scheduladi/components/custom_calendar_event_data.dart';
import 'package:scheduladi/components/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:scheduladi/pages/add_event_dialog.dart';
import 'package:scheduladi/pages/day_page.dart';
import 'package:provider/provider.dart';
import '../database/database_provider.dart';
import '../event_manager.dart';

class Homepage extends StatefulWidget {
  final EventController? controller;
  final ValueNotifier<int>? refreshNotifier;
  final VoidCallback? onEventsChanged;

  const Homepage({
    Key? key,
    this.controller,
    this.refreshNotifier,
    this.onEventsChanged
  }) : super(key: key);

  @override
  HomepageState createState() => HomepageState();
}

class HomepageState extends State<Homepage> with WidgetsBindingObserver {
  late EventController _eventController;
  bool _isMonthView = true;
  final ScrollController _monthScrollController = ScrollController();
  final ScrollController _dayScrollController = ScrollController();
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasError = false;
  String? _errorMessage;
  final NotificationService _notificationService = NotificationService();
  final EventManager _eventManager = EventManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventController = widget.controller ?? EventController();
    _setupScrollListeners();
    _loadEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshEvents();
    }
  }

  @override
  void didUpdateWidget(Homepage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNotifier != oldWidget.refreshNotifier) {
      _refreshEvents();
    }
  }

  void _setupScrollListeners() {
    _monthScrollController.addListener(() {
      if (_monthScrollController.position.pixels >=
          _monthScrollController.position.maxScrollExtent - 50) {
        _onScrollToRefresh();
      }
    });

    _dayScrollController.addListener(() {
      if (_dayScrollController.position.pixels >=
          _dayScrollController.position.maxScrollExtent - 50) {
        _onScrollToRefresh();
      }
    });
  }

  Future<void> _loadEvents() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await _eventManager.refreshEvents(context, _eventController);
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load events: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load events: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshEvents() async {
    if (_isLoading) return;

    setState(() {
      _isRefreshing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await _loadEvents();

      if (!_hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Calendar refreshed with ${_eventController.events.length} events",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Refresh failed: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _onScrollToRefresh() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _eventManager.refreshEvents(context, _eventController);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _notifyRefresh();
    }
  }

  Future<void> _addNewEvent() async {
    final newEvent = await showDialog<CustomCalendarEventData>(
      context: context,
      builder: (_) => const AddEventDialog(),
    );

    if (newEvent != null) {
      try {
        await _eventManager.addEvent(context, newEvent, _eventController);
        _notifyRefresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Event '${newEvent.title}' added!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add event: $e")),
        );
      }
    }
  }

  Future<void> _editEvent(CustomCalendarEventData event) async {
    final updatedEvent = await showDialog<CustomCalendarEventData>(
      context: context,
      builder: (_) => AddEventDialog(existingEvent: event),
    );

    if (updatedEvent != null) {
      try {
        await _eventManager.updateEvent(context, event, updatedEvent, _eventController);
        _notifyRefresh();

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

  void _deleteEvent(CustomCalendarEventData event) {
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
                await _eventManager.deleteEvent(context, event, _eventController);
                _notifyRefresh();

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

  void _notifyRefresh() {
    widget.refreshNotifier?.value++;
    widget.onEventsChanged?.call();
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

  void _onEventTapHandler(dynamic eventOrList, DateTime date) {
    final events = _normalizeToList(eventOrList);
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No event data available.")),
      );
      return;
    }

    if (events.length == 1) {
      final event = events.first;
      if (event is CustomCalendarEventData) {
        _showEventDetail(event);
      } else {
        _showGenericEventDetail(event);
      }
    } else {
      _showEventsList(events, date);
    }
  }

  void _showEventDetail(CustomCalendarEventData event) {
    final start = event.startTime ?? event.date;
    final end = event.endTime ?? event.date;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title ?? 'No title',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (event.description?.isNotEmpty ?? false)
                Text(event.description ?? ''),
              if (event.money != null) ...[
                const SizedBox(height: 8),
                Text('Money: TND ${event.money!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
              if (event.diesel != null) ...[
                const SizedBox(height: 8),
                Text(
                    'Diesel Cost: TND ${event.diesel!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
              if (event.additionalItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Additional Items:',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ...event.additionalItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '• ${item.name}: TND ${item.price.toStringAsFixed(2)}'),
                )),
                const SizedBox(height: 4),
                Text(
                    'Items Total: TND ${event.additionalItemsTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
              if (event.diesel != null || event.additionalItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                    'Grand Total: TND ${event.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
              ],
              const SizedBox(height: 12),
              Text('From: ${_formatTime(start)}'),
              Text('To:   ${_formatTime(end)}'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Edit"),
                      onPressed: () {
                        Navigator.pop(context);
                        _editEvent(event);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete,
                          size: 18, color: Colors.red),
                      label: const Text("Delete",
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteEvent(event);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGenericEventDetail(CalendarEventData event) {
    final start = event.startTime ?? event.date;
    final end = event.endTime ?? event.date;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title ?? 'No title',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (event.description?.isNotEmpty ?? false)
                Text(event.description ?? ''),
              const SizedBox(height: 12),
              Text('From: ${_formatTime(start)}'),
              Text('To:   ${_formatTime(end)}'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEventsList(List<CalendarEventData> events, DateTime date) {
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
            _editEvent(event);
          }
        },
        onDelete: (event) {
          Navigator.pop(context);
          if (event is CustomCalendarEventData) {
            _deleteEvent(event);
          }
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildMonthView() {
    return Stack(
      children: [
        MonthView(
          controller: _eventController,
          onCellTap: (events, date) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DayPage(date: date, controller: _eventController),
              ),
            );
          },
        ),
        if (_isLoading || _isRefreshing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isRefreshing ? 'Refreshing events...' : 'Loading events...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_hasError && !_isLoading && !_isRefreshing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load events",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _refreshEvents,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Try Again"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDayView() {
    return Stack(
      children: [
        DayView(
          key: const ValueKey('day'),
          controller: _eventController,
          showVerticalLine: true,
          backgroundColor: Colors.grey.shade100,
          heightPerMinute: 1,
          onEventTap: (eventOrList, date) {
            _onEventTapHandler(eventOrList, date);
          },
        ),
        if (_isLoading || _isRefreshing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isRefreshing ? 'Refreshing events...' : 'Loading events...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_hasError && !_isLoading && !_isRefreshing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Failed to load events",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _refreshEvents,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Try Again"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider(
      controller: _eventController,
      child: Scaffold(

        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isMonthView ? _buildMonthView() : _buildDayView(),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isLoading && !_isRefreshing && !_hasError)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      "Refreshing...",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            FloatingActionButton.extended(
              onPressed: _addNewEvent,
              backgroundColor: Colors.deepPurple,
              label: const Text("Add Event"),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monthScrollController.dispose();
    _dayScrollController.dispose();
    super.dispose();
  }
}

class _EventList extends StatelessWidget {
  final List<CalendarEventData> events;
  final Function(CalendarEventData)? onEdit;
  final Function(CalendarEventData)? onDelete;

  const _EventList({
    required this.events,
    this.onEdit,
    this.onDelete,
    super.key,
  });

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
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(e.title ?? 'No title',
                  style: TextStyle(
                      color: e.color ?? Colors.black,
                      fontWeight: FontWeight.bold)),
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
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  if (customEvent != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 16, color: Colors.blue),
                          onPressed: () => onEdit?.call(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 16, color: Colors.red),
                          onPressed: () => onDelete?.call(e),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                final customEvent = e is CustomCalendarEventData ? e : null;
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title ?? 'No title',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (e.description?.isNotEmpty ?? false)
                          Text(e.description ?? ''),
                        if (customEvent?.money != null) ...[
                          const SizedBox(height: 8),
                          Text(
                              'Money: TND ${customEvent!.money!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                        if (customEvent?.diesel != null) ...[
                          const SizedBox(height: 8),
                          Text(
                              'Diesel Cost: TND ${customEvent!.diesel!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                        if (customEvent?.additionalItems.isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 8),
                          const Text('Additional Items:',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          ...customEvent!.additionalItems.map((item) => Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                                '• ${item.name}: TND ${item.price.toStringAsFixed(2)}'),
                          )),
                          const SizedBox(height: 4),
                          Text(
                              'Items Total: TND ${customEvent.additionalItemsTotal.toStringAsFixed(2)}',
                              style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                        if (customEvent?.diesel != null ||
                            customEvent!.additionalItems.isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 8),
                          Text(
                              'Grand Total: TND - ${customEvent!.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                        const SizedBox(height: 12),
                        Text(
                            'From: ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'),
                        Text(
                            'To:   ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'),
                        const SizedBox(height: 12),
                        if (customEvent != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text("Edit"),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onEdit?.call(e);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  label: const Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onDelete?.call(e);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.bottomRight,
                          child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close')),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}