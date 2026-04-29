import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/media_asset.dart';
import '../../../models/scheduled_post.dart';
import '../../../services/post_service.dart';
import '../../../services/settings_service.dart';
import 'dart:collection';

final postsByDayProvider = Provider<LinkedHashMap<DateTime, List<ScheduledPost>>>((ref) {
  final posts = ref.watch(postsProvider).asData?.value ?? [];
  final map = LinkedHashMap<DateTime, List<ScheduledPost>>(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );

  for (final post in posts) {
    if (post.scheduledAt != null) {
      final day = DateTime.utc(post.scheduledAt!.year, post.scheduledAt!.month, post.scheduledAt!.day);
      if (map[day] == null) {
        map[day] = [];
      }
      map[day]!.add(post);
    }
  }
  return map;
});


class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<ScheduledPost> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // We'll initialize _selectedEvents in didChangeDependencies or build since it depends on ref
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        final postsByDay = ref.read(postsByDayProvider);
        _selectedEvents = postsByDay[selectedDay] ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsByDay = ref.watch(postsByDayProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Refresh selected events if posts changed
    if (_selectedDay != null) {
      _selectedEvents = postsByDay[_selectedDay] ?? [];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('calendarView', lang).toUpperCase()),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: TableCalendar<ScheduledPost>(
              locale: lang == 'ar' ? 'ar_SA' : 'en_US',
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              eventLoader: (day) => postsByDay[day] ?? [],
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: primaryColor.withOpacity(0.3), shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                markersAlignment: Alignment.bottomCenter,
                markerDecoration: BoxDecoration(color: primaryColor.withOpacity(0.6), shape: BoxShape.circle),
                outsideDaysVisible: false,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: const TextStyle(fontWeight: FontWeight.bold),
                weekendStyle: TextStyle(color: Colors.red.withOpacity(0.7), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: primaryColor.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(S.tr('noPostsDay', lang), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _selectedEvents.length,
                  itemBuilder: (context, index) {
                    final post = _selectedEvents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            post.mediaType == MediaType.video ? Icons.videocam : Icons.image,
                            color: primaryColor,
                          ),
                        ),
                        title: Text(
                          post.caption ?? S.tr('noCaption', lang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(post.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(post.status, lang).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(post.status),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (post.scheduledAt != null)
                                Text(
                                  TimeOfDay.fromDateTime(post.scheduledAt!).format(context),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: primaryColor.withOpacity(0.5)),
                        onTap: () { /* Navigate to post details */ },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.scheduled: return Colors.blue;
      case PostStatus.published: return Colors.green;
      case PostStatus.failed: return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(PostStatus status, String lang) {
    switch (status) {
      case PostStatus.scheduled: return S.tr('scheduled', lang);
      case PostStatus.published: return S.tr('published', lang);
      case PostStatus.failed: return S.tr('failed', lang);
      default: return status.name;
    }
  }
}
