import 'package:calendar_view/calendar_view.dart';
import 'package:scheduladi/database/repo/event_repository.dart';

import 'database_helper.dart';
import 'package:scheduladi/components/custom_calendar_event_data.dart';

class MigrationScript {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final EventRepository _eventRepository = EventRepository();

  // Migrate from EventController to Database
  Future<void> migrateFromController(EventController controller) async {
    print('🚀 Starting migration from EventController to Database...');

    try {
      // Get all events from controller
      final events = controller.events.cast<CustomCalendarEventData>();

      // Insert each event into database
      for (final event in events) {
        _eventRepository.insertEvent(event);
      }

      print('✅ Migration completed! ${events.length} events migrated.');
    } catch (e) {
      print('❌ Migration failed: $e');
    }
  }

  // Check if migration is needed
  Future<bool> isMigrationNeeded(EventController controller) async {
    final dbCount = _eventRepository.countEvents();
    final controllerCount = controller.events.length;

    return controllerCount > 0 && dbCount == 0;
  }
}