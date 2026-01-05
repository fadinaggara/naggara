
import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:intl/intl.dart';

import '../components/custom_calendar_event_data.dart';

class StatsPage extends StatefulWidget {
  final EventController controller;
  final ValueNotifier<int>? refreshNotifier;

  const StatsPage({super.key, required this.controller, this.refreshNotifier});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now(); // ADD THIS

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        _onScrollToRefresh();
      }
    });
  }

  Future<void> _onScrollToRefresh() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate a brief loading period
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });
  }

  // ADD MONTH SELECTOR WIDGET
  Widget _buildMonthSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () {
                setState(() {
                  _selectedMonth =
                      DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: () {
                final now = DateTime.now();
                final nextMonth =
                    DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                // Don't allow going to future months
                if (nextMonth.isBefore(DateTime(now.year, now.month + 1))) {
                  setState(() {
                    _selectedMonth = nextMonth;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.refreshNotifier ?? ValueNotifier<int>(0),
      builder: (context, value, child) {
        final events =
            widget.controller.events.cast<CustomCalendarEventData>().toList();
        final now = DateTime.now();
        final upcomingEvents = _getUpcomingEvents(events, now);
        final pastEvents = _getPastEvents(events, now);
        final totalStats = _calculateTotalStats(events);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Statistics"),
            backgroundColor: Colors.deepPurple,
            elevation: 0,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ADD MONTH SELECTOR HERE
                    _buildMonthSelector(),
                    const SizedBox(height: 16),

                    _buildSummaryCard(totalStats),
                    const SizedBox(height: 20),
                    _buildEventsSection("Upcoming Events", upcomingEvents,
                        Colors.green, 'upcoming'),
                    const SizedBox(height: 20),
                    _buildEventsSection(
                        "Past Events", pastEvents, Colors.blue, 'past'),
                    const SizedBox(height: 20),
                    // Add some extra space at the bottom for better scrolling
                    Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.arrow_upward,
                              size: 20, color: Colors.grey),
                          SizedBox(height: 4),
                          Text(
                            "Scroll up to refresh",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: _buildLoadingIndicator(),
                ),
            ],
          ),
        );
      },
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

  Widget _buildSummaryCard(Map<String, double> stats) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  "Financial Summary - ${DateFormat('MMM yyyy').format(_selectedMonth)}", // SHOW SELECTED MONTH
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Money and Expenses Breakdown
            Column(
              children: [
                _buildFinancialRow(
                    "Total Money", stats['totalMoney'] ?? 0, Colors.green),
                _buildFinancialRow(
                    "Total Expenses", stats['totalExpenses'] ?? 0, Colors.red),
                const Divider(),
                _buildFinancialRow("Net Profit", stats['netProfit'] ?? 0,
                    (stats['netProfit'] ?? 0) >= 0 ? Colors.green : Colors.red),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Total Events",
                    stats['totalEvents']?.toInt() ?? 0, Icons.event),
                _buildStatItem(
                    "Avg/Event", stats['averageValue'] ?? 0, Icons.trending_up),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  "Viewing: ${DateFormat('MMM yyyy').format(_selectedMonth)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'TND ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.deepPurple, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value is int
              ? value.toString()
              : 'TND ${(value as double).toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  final Map<String, bool> _showAllEvents = {
    'upcoming': false,
    'past': false,
  };

  Widget _buildEventsSection(String title, List<CustomCalendarEventData> events,
      Color color, String sectionKey) {
    final showAll = _showAllEvents[sectionKey] ?? false;
    final displayEvents = showAll ? events : events.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                events.length.toString(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        events.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "No $title",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            : Column(
                children: [
                  ...displayEvents
                      .map((event) => _buildEventItem(event, color))
                      .toList(),
                  if (events.length > 3)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllEvents[sectionKey] = !showAll;
                        });
                      },
                      child: Text(
                        showAll ? 'Show Less' : 'Show All (${events.length})',
                        style: TextStyle(color: color),
                      ),
                    ),
                ],
              ),
      ],
    );
  }

  Widget _buildEventItem(CustomCalendarEventData event, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          event.title ?? 'No Title',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat('MMM d, y').format(event.startTime ?? event.date),
        ),
        trailing: Text(
          'TND ${event.grandTotal.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  List<CustomCalendarEventData> _getUpcomingEvents(
      List<CustomCalendarEventData> events, DateTime now) {
    return events.where((event) {
      final eventDate = event.startTime ?? event.date;
      return eventDate.isAfter(now);
    }).toList();
  }

  List<CustomCalendarEventData> _getPastEvents(
      List<CustomCalendarEventData> events, DateTime now) {
    return events.where((event) {
      final eventDate = event.startTime ?? event.date;
      return eventDate.isBefore(now);
    }).toList();
  }

  // MODIFIED TO USE SELECTED MONTH
  Map<String, double> _calculateTotalStats(
      List<CustomCalendarEventData> events) {
    final currentMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    // Filter events for selected month only
    final monthlyEvents = events.where((event) {
      final eventDate = event.startTime ?? event.date;
      return eventDate
              .isAfter(currentMonth.subtract(const Duration(seconds: 1))) &&
          eventDate.isBefore(nextMonth);
    }).toList();

    final totalMoney =
        monthlyEvents.fold(0.0, (sum, event) => sum + (event.money ?? 0.0));
    final totalDiesel =
        monthlyEvents.fold(0.0, (sum, event) => sum + (event.diesel ?? 0.0));
    final totalItems = monthlyEvents.fold(
        0.0, (sum, event) => sum + event.additionalItemsTotal);
    final totalExpenses = totalDiesel + totalItems;
    final netProfit = totalMoney - totalExpenses;

    return {
      'totalEvents': monthlyEvents.length.toDouble(),
      'totalMoney': totalMoney,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'averageValue':
          monthlyEvents.isEmpty ? 0.0 : netProfit / monthlyEvents.length,
    };
  }
}
