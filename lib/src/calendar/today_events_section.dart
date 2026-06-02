import 'package:flutter/cupertino.dart';

import '../localization/strings.dart';
import '../models/event.dart';
import '../tasks/calendar_date_picker.dart' show formatDoTime;
import '../utils/fast_route.dart';
import 'event_controller.dart';
import 'event_detail_view.dart';

/// A collapsible "Events" section listing the events on [date]. Used by
/// Tasks → Today (between uncompleted and completed tasks). Tapping a row opens
/// the event; renders nothing when no events are scheduled that day.
class TodayEventsSection extends StatefulWidget {
  const TodayEventsSection({
    super.key,
    required this.controller,
    required this.date,
    this.initiallyExpanded = true,
  });

  final EventController controller;
  final DateTime date;
  final bool initiallyExpanded;

  @override
  State<TodayEventsSection> createState() => _TodayEventsSectionState();
}

class _TodayEventsSectionState extends State<TodayEventsSection> {
  late bool _expanded = widget.initiallyExpanded;

  void _open(Event event) {
    Navigator.of(context).push(
      FastRoute<void>(
        builder: (_) => EventDetailView(
          event: event,
          controller: widget.controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final events = widget.controller.eventsForDate(widget.date)
          ..sort((a, b) => (a.doTime ?? -1).compareTo(b.doTime ?? -1));
        if (events.isEmpty) return const SizedBox.shrink();
        final s = S.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              label: s.tabCalendar,
              count: events.length,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded)
              for (final e in events) _Row(event: e, onTap: () => _open(e)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(
          children: [
            Icon(
              expanded
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_right,
              size: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (event.doTime != null) ...[
              const SizedBox(width: 8),
              Text(
                formatDoTime(event.doTime!),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
