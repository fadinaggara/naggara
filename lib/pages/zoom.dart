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
    super.key,
    this.controller,
    this.refreshNotifier,
    this.onEventsChanged
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  late EventController _eventController;
  bool _isMonthView = true;
  final ScrollController _monthScrollController = ScrollController();
  final ScrollController _dayScrollController = ScrollController();
  bool _isLoading = false;
  final NotificationService _notificationService = NotificationService();
  late DatabaseProvider _databaseProvider;
  final EventManager _eventManager = EventManager();

  @override
  void initState() {
    super.initState();
    _eventController = widget.controller ?? EventController();
    _setupScrollListeners();
    // Load events from database when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEventsFromDatabase();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the DatabaseProvider from context
    _databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
  }

  Future<void> _loadEventsFromDatabase() async {
    try {
      // First refresh the provider to load events from database
      await _databaseProvider.loadEvents();

      // Get events from provider
      final events = _databaseProvider.events;

      // Clear existing events and add all from database
      _eventController;
      if (events.isNotEmpty) {
        _eventController.addAll(events);
      }

      print('📊 Loaded ${events.length} events from database');
    } catch (e) {
      print('❌ Error loading events from database: $e');
      // If database fails, load sample events (fallback)
      _loadSampleEvents();
    }
  }

  void _loadSampleEvents() {
    final now = DateTime.now();
    _eventController.addAll([
      CustomCalendarEventData(
        id: CustomCalendarEventData.generateId(),
        date: now.add(const Duration(days: 1)),
        title: "Client Demo",
        description: "Showcase new features to client.",
        startTime: DateTime(now.year, now.month, now.day + 1, 14, 0),
        endTime: DateTime(now.year, now.month, now.day + 1, 15, 0),
        color: Colors.deepOrangeAccent,
        money: 1500.00,
        diesel: 120.50,
        additionalItems: [
          AdditionalItem(name: "Software License", price: 500.00),
          AdditionalItem(name: "Consulting", price: 300.00),
        ],
      ),
      CustomCalendarEventData(
        id: CustomCalendarEventData.generateId(),
        date: now.add(const Duration(days: 2)),
        title: "Code Review",
        description: "Review code for the latest PRs.",
        startTime: DateTime(now.year, now.month, now.day + 2, 9, 30),
        endTime: DateTime(now.year, now.month, now.day + 2, 10, 30),
        color: Colors.green,
        money: 800.00,
        diesel: 80.25,
        additionalItems: [
          AdditionalItem(name: "Code Analysis", price: 200.00),
        ],
      ),
    ]);
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

  Future<void> _onScrollToRefresh() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Refresh events from database
    await _loadEventsFromDatabase();

    // Add a small delay to show the refresh animation
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _isLoading = false;
    });

    // Notify other pages about the refresh
    _notifyRefresh();
  }

  Future<void> _addNewEvent() async {
    final newEvent = await showDialog<CustomCalendarEventData>(
      context: context,
      builder: (_) => const AddEventDialog(),
    );

    if (newEvent != null) {
      try {
        await _eventManager.addEvent(context, newEvent, _eventController);

        // Notify other pages
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

        // Notify other pages
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

                // Notify other pages
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
      // Check if it's a CustomCalendarEventData
      if (event is CustomCalendarEventData) {
        _showEventDetail(event);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot edit this event type")),
        );
      }
    } else {
      _showEventsList(events, date);
    }
  }

  void _showEventDetail(CustomCalendarEventData event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final start = event.startTime ?? event.date;
        final end = event.endTime ?? event.date;
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
                        Navigator.pop(context); // Close detail sheet
                        _editEvent(event); // Now this will work
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
                        Navigator.pop(context); // Close detail sheet
                        _deleteEvent(event); // Now this will work
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

  void _showEventsList(List<CalendarEventData> events, DateTime date) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EventList(
        events: events,
        onEdit: (event) {
          Navigator.pop(context); // Close list sheet
          if (event is CustomCalendarEventData) {
            _editEvent(event);
          }
        },
        onDelete: (event) {
          Navigator.pop(context); // Close list sheet
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
        if (_isLoading)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _buildLoadingIndicator(),
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
        if (_isLoading)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _buildLoadingIndicator(),
          ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              "Refreshing...",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider(
      controller: _eventController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "My Professional Calendar",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          actions: [
            IconButton(
              icon: Icon(
                _isMonthView ? Icons.calendar_view_day : Icons.calendar_month,
              ),
              onPressed: () {
                setState(() => _isMonthView = !_isMonthView);
              },
              tooltip:
              _isMonthView ? 'Switch to Day View' : 'Switch to Month View',
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isMonthView ? _buildMonthView() : _buildDayView(),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isLoading)
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