import 'package:scheduladi/pages/stats_page.dart';
import 'package:scheduladi/pages/upcoming_events_page.dart';
import 'package:scheduladi/components/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:scheduladi/pages/zoom.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final EventController _eventController = EventController();
  final ValueNotifier<int> _refreshNotifier = ValueNotifier<int>(0);
  final GlobalKey<HomepageState> _calendarPageKey = GlobalKey();

  late TabController _tabController;
  int _currentTabIndex = 2;
  bool _isCalendarRefreshing = false;
  bool _isInitialLoad = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCalendarData();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _isInitialLoad = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentTabIndex == 2) {
      _refreshCalendarData();
    }
  }

  void _handleTabChange() {
    final newIndex = _tabController.index;

    if (newIndex == 2 && _currentTabIndex != 2) {
      _refreshCalendarData();
    } else if (newIndex == 2 && _currentTabIndex == 2 && !_isInitialLoad) {
      _refreshCalendarData();
    }

    _currentTabIndex = newIndex;
  }

  Future<void> _refreshCalendarData() async {
    if (_isCalendarRefreshing) return;

    setState(() {
      _isCalendarRefreshing = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await _loadEventsIntoController();

      _refreshNotifier.value++;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(''),
          backgroundColor: Colors.transparent,
          duration: Duration(seconds: 1),
        ),
      );

    } catch (error) {
      print('Error refreshing calendar: $error');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to refresh: $error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh calendar: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Always hide the spinner, even on error
      setState(() {
        _isCalendarRefreshing = false;
      });
    }
  }

  Future<void> _loadEventsIntoController() async {
    // Simulate a potential error (remove this in production)
    // throw Exception("Simulated database error");



    // You would normally load from database here
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildTabIcon(IconData icon, int tabIndex, {bool showRefresh = false}) {
    return Stack(
      children: [
        Icon(
          icon,
          color: _currentTabIndex == tabIndex ? Colors.white : Colors.white70,
        ),
        if (showRefresh && _isCalendarRefreshing && !_hasError)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(
                minWidth: 12,
                minHeight: 12,
              ),
              child: const SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        if (_hasError && tabIndex == 2)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.error,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _refreshNotifier,
      builder: (context, value, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text(
                  "My Calendar",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 8),
                if (_isCalendarRefreshing && !_hasError && _currentTabIndex == 2)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                if (_hasError && _currentTabIndex == 2)
                  const Icon(
                    Icons.error,
                    color: Colors.orange,
                    size: 20,
                  ),
              ],
            ),
            backgroundColor: Colors.deepPurple,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2.0,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(
                  icon: _buildTabIcon(Icons.upcoming, 0),
                  iconMargin: EdgeInsets.zero,
                ),
                Tab(
                  icon: _buildTabIcon(Icons.analytics, 1),
                  iconMargin: EdgeInsets.zero,
                ),
                Tab(
                  icon: _buildTabIcon(Icons.calendar_month, 2, showRefresh: true),
                  iconMargin: EdgeInsets.zero,
                ),
                Tab(
                  icon: _buildTabIcon(Icons.notifications, 3),
                  iconMargin: EdgeInsets.zero,
                ),
                Tab(
                  icon: _buildTabIcon(Icons.menu, 4),
                  iconMargin: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              TabBarView(
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
                    key: _calendarPageKey,
                    controller: _eventController,
                    refreshNotifier: _refreshNotifier,
                    onEventsChanged: () {
                      _refreshNotifier.value++;
                    },
                  ),
                  _buildNotificationsPage(),
                  _buildViewsPage(),
                ],
              ),

              // Full-screen loading overlay when refreshing calendar
              if (_isCalendarRefreshing && _currentTabIndex == 2 && !_hasError)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),

                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

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
                                _getTimeAgo(difference),
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
                    ),
                  );
                },
              ),
            ),

            // Stats Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Today',
                    _getTodayCount(notificationHistory).toString(),
                  ),
                  _buildStatItem(
                    'This Week',
                    _getThisWeekCount(notificationHistory).toString(),
                  ),
                  _buildStatItem(
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