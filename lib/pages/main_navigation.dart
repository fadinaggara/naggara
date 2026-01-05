import 'package:scheduladi/pages/stats_page.dart';
import 'package:scheduladi/pages/upcoming_events_page.dart';
import 'package:scheduladi/pages/zoom.dart';

import '../components/custom_calendar_event_data.dart';

import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:intl/intl.dart';

import '../components/notification_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  final EventController _eventController = EventController();
  final ValueNotifier<int> _refreshNotifier = ValueNotifier<int>(0);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshStats() {
    _refreshNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshNotifier,
      builder: (context, value, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "My Calendar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: Colors.deepPurple,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2.0,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero, // Remove default padding
              tabs: const [
                Tab(
                  icon: Icon(Icons.upcoming), // Let TabBar control the size
                ),
                Tab(
                  icon: Icon(Icons.analytics),
                ),
                Tab(
                  icon: Icon(Icons.calendar_month),
                ),
                Tab(
                  icon: Icon(Icons.notifications),
                ),
                Tab(
                  icon: Icon(Icons.menu),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              UpcomingEventsPage(
                controller: _eventController,
                refreshNotifier: _refreshNotifier,
              ),
              StatsPage(
                controller: _eventController,
                refreshNotifier: _refreshNotifier,
              ),
              Homepage(
                controller: _eventController,
                refreshNotifier: _refreshNotifier,
                onEventsChanged: _refreshStats,
              ),
              _buildNotificationsPage(),
              _buildViewsPage(),
            ],
          ),
        );
      },
    );
  }

  // Placeholder for Notifications Page
Widget _buildNotificationsPage() {
  final notificationService = NotificationService();

  return ValueListenableBuilder<int>(
    valueListenable: _refreshNotifier,
    builder: (context, value, child) {
      final notificationHistory = notificationService.getNotificationHistory();

      

      if (notificationHistory.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No Notification History",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Notifications that appear will be logged here",
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  "Notification History (${notificationHistory.length})",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 20),
                  onPressed: () {
                    notificationService.clearNotificationHistory();
                    _refreshNotifier.value++;
                  },
                  tooltip: 'Clear History',
                ),
              ],
            ),
          ),

          // Notification History List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notificationHistory.length,
              itemBuilder: (context, index) {
                final history = notificationHistory[index];
                final now = DateTime.now();
                final difference = now.difference(history.shownAt);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      history.eventTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          history.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              _getTimeAgo(difference), // Use existing method
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${history.shownAt.hour.toString().padLeft(2, '0')}:${history.shownAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${history.shownAt.day}/${history.shownAt.month}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _showEventDetails(context, history.event);
                    },
                  ),
                );
              },
            ),
          ),

          // Stats Footer - USE EXISTING _buildStatItem METHOD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem( // Use the existing method
                  'Today',
                  _getTodayCount(notificationHistory).toString(),
                ),
                _buildStatItem( // Use the existing method
                  'This Week',
                  _getThisWeekCount(notificationHistory).toString(),
                ),
                _buildStatItem( // Use the existing method
                  'Total',
                  notificationHistory.length.toString(),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
// ADD THESE METHODS TO YOUR _MainNavigationState CLASS:

void _showEventDetails(BuildContext context, CustomCalendarEventData event) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return _buildEventDetailSheet(event);
    },
  );
}

Widget _buildEventDetailSheet(CustomCalendarEventData event) {
  final start = event.startTime ?? event.date;
  final end = event.endTime ?? event.date;
  
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
              child: Text(
                event.title ?? 'No Title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        
        if (event.description?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(
            event.description!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              '${start.day}/${start.month}/${start.year}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - '
              '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        
        if (event.money != null) ...[
          const SizedBox(height: 12),
          Text(
            'Money: TND ${event.money!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
        
        if (event.diesel != null) ...[
          const SizedBox(height: 8),
          Text(
            'Diesel Cost: TND ${event.diesel!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.orange,
            ),
          ),
        ],
        
        if (event.additionalItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Additional Items:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...event.additionalItems.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '• ${item.name}: TND ${item.price.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),
          )),
          const SizedBox(height: 8),
          Text(
            'Items Total: TND ${event.additionalItemsTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        
        if (event.money != null || event.diesel != null || event.additionalItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Grand Total: TND ${event.grandTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: event.grandTotal >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}


String _getTimeAgo(Duration difference) {
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${difference.inDays ~/ 7}w ago';
}

int _getTodayCount(List<NotificationHistory> history) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return history.where((h) => h.shownAt.isAfter(today)).length;
}

int _getThisWeekCount(List<NotificationHistory> history) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  return history.where((h) => h.shownAt.isAfter(startOfWeek)).length;
}

// Helper methods
Widget _buildStatItem(String label, String value) {
  return Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    ],
  );
}

String _formatTimeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat('MMM d').format(date);
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool _isThisWeek(DateTime date) {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  return date.isAfter(startOfWeek);
}

  // Placeholder for Views/Filters Page
  Widget _buildViewsPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "View Options",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Customize your calendar views and filters",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
