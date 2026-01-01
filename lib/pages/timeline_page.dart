import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../utils.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({
    super.key,
    required this.schedule,
    required this.habits,
    required this.isDark,
    required this.onToggleTheme,
    this.onAddTask,
    this.onToggleTaskDone,
    this.onToggleHabit,
    this.onDateChanged,
    this.onEditTask,
    this.onDeleteTask,
  });

  final List<DaySchedule> schedule;
  final List<Habit> habits;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onAddTask;
  final Future<void> Function(String dayId, String taskId, bool isDone)?
      onToggleTaskDone;
  final Future<void> Function(Habit habit, DateTime date)? onToggleHabit;
  final ValueChanged<DateTime>? onDateChanged;
  final Future<void> Function(String dayId, Task task)? onEditTask;
  final Future<void> Function(String dayId, Task task)? onDeleteTask;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  String view = 'Today';
  DateTime selectedDate = DateTime.now();
  final List<GlobalKey> _monthKeys = List<GlobalKey>.generate(12, (_) => GlobalKey());
  bool _jumpedToMonth = false;
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToNow = false;

  @override
  void initState() {
    super.initState();
    widget.onDateChanged?.call(selectedDate);
  }

  List<Task> _tasksForDate(DateTime date) {
    final habitsById = {for (final h in widget.habits) if (h.id != null) h.id!: h};
    final day = widget.schedule.firstWhere(
      (d) => isSameDay(d.date, date),
      orElse: () => DaySchedule(date: date, tasks: []),
    );
    final tasks = [...day.tasks];

    tasks.sort((a, b) {
      final aMinutes = a.start.hour * 60 + a.start.minute;
      final bMinutes = b.start.hour * 60 + b.start.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final dayTasks = _tasksForDate(selectedDate);
    final now = DateTime.now();
    final isToday = isSameDay(selectedDate, now);
    final nowMinutes = TimeOfDay.fromDateTime(now).hour * 60 + TimeOfDay.fromDateTime(now).minute;

    final entries = <_TimelineEntry>[];
    for (final task in dayTasks) {
      entries.add(_TimelineEntry(task: task));
    }
    if (isToday) {
      // Insert a marker entry in the correct position.
      entries.add(_TimelineEntry(nowMinutes: nowMinutes));
      entries.sort((a, b) {
        final aKey = a.isNow ? a.nowMinutes! : a.task!.end.hour * 60 + a.task!.end.minute;
        final bKey = b.isNow ? b.nowMinutes! : b.task!.end.hour * 60 + b.task!.end.minute;
        return aKey.compareTo(bKey);
      });
    }

    _maybeScrollToNow(entries);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeaderDelegate(
            minExtent: 70,
            maxExtent: 70,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _HeaderCompactRow(
                selectedDate: selectedDate,
                subtitle: _headerSubtitle(),
                view: view,
                isDark: widget.isDark,
                onToggleTheme: widget.onToggleTheme,
                onViewChanged: (value) {
                  setState(() {
                    view = value;
                    if (value == 'Today') {
                      selectedDate = DateTime.now();
                      _scrolledToNow = false;
                      widget.onDateChanged?.call(selectedDate);
                      _jumpedToMonth = false;
                    } else if (value == 'Month') {
                      _jumpedToMonth = false;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        if (view == 'Today')
          SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  DateFormat("EEEE,  MMMM d").format(selectedDate),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
            ),
          ),
        if (view == 'Today')
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (view == 'Today')
          SliverToBoxAdapter(
            child: _HabitRow(
              habits: widget.habits,
              date: selectedDate,
              onTap: widget.onToggleHabit,
            ),
          ),
        if (view == 'Today') const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (view == 'Today')
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (view == 'Today') ...[
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No tasks yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemBuilder: (_, index) {
                final entry = entries[index];
                if (entry.isNow) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : Colors.black38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Now ${DateFormat('hh:mm a').format(DateTime.now())}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }
                final task = entry.task!;
                final nowMinutes = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
                final taskMinutes = task.end.hour * 60 + task.end.minute;
                final isPast = isToday && taskMinutes < nowMinutes;
                final isFutureDone = isToday && taskMinutes > nowMinutes && task.isDone;
                final isFirst = index == 0;
                final isLast = index == entries.length - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _TimelineTile(
                    task: task,
                    isFirst: isFirst,
                    isLast: isLast,
                    dayId: _dayId(selectedDate),
                    onToggleDone: widget.onToggleTaskDone,
                    onHabitTap: widget.onToggleHabit,
                    habits: widget.habits,
                    date: selectedDate,
                    onEditTask: widget.onEditTask,
                    onDeleteTask: widget.onDeleteTask,
                    isDimmed: isPast || isFutureDone,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: entries.length,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ] else if (view == 'Week') ..._buildWeekView(context) else ..._buildMonthView(context),
      ],
    );
  }

  void _maybeScrollToNow(List<_TimelineEntry> entries) {
    if (!_scrollController.hasClients) return;
    if (_scrolledToNow) return;
    final idx = entries.indexWhere((e) => e.isNow);
    if (idx <= 0) return;
    const estimatedHeight = 140.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = ((idx - 1) * estimatedHeight) - 120;
      _scrollController.jumpTo(target.clamp(0, _scrollController.position.maxScrollExtent));
      _scrolledToNow = true;
    });
  }

  List<Widget> _buildWeekView(BuildContext context) {
    final start = startOfWeek(selectedDate);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    return [
      SliverList.builder(
        itemCount: days.length,
        itemBuilder: (_, index) {
          final date = days[index];
          final tasks = _tasksForDate(date).where((t) => !t.isDone).toList();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: _WeekDayTile(
              date: date,
              tasks: tasks,
              onExpand: () => setState(() {
                selectedDate = date;
                widget.onDateChanged?.call(date);
              }),
              dayId: _dayId(date),
              onToggleDone: widget.onToggleTaskDone,
              onHabitTap: widget.onToggleHabit,
              habits: widget.habits,
              onEditTask: widget.onEditTask,
              onDeleteTask: widget.onDeleteTask,
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  List<Widget> _buildMonthView(BuildContext context) {
    final fakeToday = DateTime.now();
    final months = List.generate(12, (i) => DateTime(fakeToday.year, i + 1, 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_jumpedToMonth && view == 'Month') {
        final ctx = _monthKeys[fakeToday.month - 1].currentContext;
        if (ctx != null) {
          _jumpedToMonth = true;
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 600),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
      }
    });

    return [
      SliverList.builder(
        itemCount: months.length,
        itemBuilder: (context, index) {
          final month = months[index];
          return Padding(
            key: _monthKeys[month.month - 1],
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _MonthGrid(
              month: month,
              selectedDate: selectedDate,
              onSelect: (date) => setState(() {
                selectedDate = date;
                view = 'Today';
                widget.onDateChanged?.call(date);
              }),
              taskCountForDay: (date) =>
                  _tasksForDate(date).where((t) => !t.isDone).length,
              totalCountForDay: (date) => _tasksForDate(date).length,
              today: fakeToday,
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
  }

  List<Widget> _buildYearView(BuildContext context) {
    final year = selectedDate.year;
    final months = List.generate(12, (i) => DateTime(year, i + 1, 1));
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        sliver: SliverToBoxAdapter(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final tasks = _tasksForMonth(month);
              return GestureDetector(
                onTap: () => setState(() {
                  selectedDate = DateTime(month.year, month.month, 1);
                  view = 'Month';
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSameDay(selectedDate, month)
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor.withOpacity(0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.MMM().format(month),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? null
                                  : Colors.black,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${tasks.length} tasks',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                    : Colors.black),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 2,
                        runSpacing: 2,
                        children: tasks.take(8).map((t) {
                          return Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: t.color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  String _headerSubtitle() {
    switch (view) {
      case 'Week':
        return 'Week overview';
      case 'Month':
        return 'Pick a day to jump in';
      default:
        return 'Today at a glance';
    }
  }

  String _dayId(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  List<Task> _tasksForMonth(DateTime month) {
    final days = daysInMonth(month);
    final tasks = <Task>[];
    for (int i = 0; i < days; i++) {
      final date = DateTime(month.year, month.month, i + 1);
      tasks.addAll(_tasksForDate(date));
    }
    return tasks;
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onSelect,
    required this.taskCountForDay,
    required this.totalCountForDay,
    required this.today,
  });

  final DateTime month;
  final DateTime selectedDate;
  final void Function(DateTime date) onSelect;
  final int Function(DateTime date) taskCountForDay;
  final int Function(DateTime date) totalCountForDay;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final totalDays = daysInMonth(month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    final cells = <DateTime?>[
      ...List<DateTime?>.generate(firstWeekday, (_) => null),
      ...List<DateTime?>.generate(
        totalDays,
        (i) => DateTime(month.year, month.month, i + 1),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 3.0;
        final cellSize = (constraints.maxWidth - spacing * 6 - 1) / 7;
        final counts = List.generate(totalDays, (i) {
          final date = DateTime(month.year, month.month, i + 1);
          return taskCountForDay(date);
        });
        final maxCount = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMM().format(month),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cells.map((date) {
                if (date == null) {
                  return SizedBox(width: cellSize, height: cellSize);
                }
                final remaining = taskCountForDay(date);
                final total = totalCountForDay(date);
                final done = (total - remaining).clamp(0, total);
                final effectiveToday = today;
                final isToday = date.year == effectiveToday.year &&
                    date.month == effectiveToday.month &&
                    date.day == effectiveToday.day;
                final isPast = date.isBefore(effectiveToday) && !isToday;
                final color = _colorForCount(remaining, maxCount, Theme.of(context));
                final textOpacity = isPast ? 0.25 : 1.0;
                return GestureDetector(
                  onTap: () => onSelect(date),
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: isPast
                          ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8)
                          : color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.transparent,
                        width: 0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(textOpacity)
                                    : Colors.black.withOpacity(textOpacity),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 3),
                            Text(
                              '$done/$total',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white70.withOpacity(textOpacity)
                                        : Colors.black.withOpacity(textOpacity * 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Color _colorForCount(int count, int max, ThemeData theme) {
    if (max == 0) return theme.colorScheme.surfaceVariant;
    if (count == 0) return theme.colorScheme.surfaceVariant;
    final ratio = (count / max).clamp(0.0, 1.0);
    final base = const Color(0xFFE53935);
    final opacity = 0.12 + 0.6 * ratio;
    return base.withOpacity(opacity);
  }
}

class _TimelineEntry {
  _TimelineEntry({this.task, this.nowMinutes});
  final Task? task;
  final int? nowMinutes;
  bool get isNow => nowMinutes != null;
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.selectedDate,
    required this.subtitle,
    required this.view,
    required this.onViewChanged,
    this.compact = false,
  });

  final DateTime selectedDate;
  final String subtitle;
  final String view;
  final ValueChanged<String> onViewChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.MMMMEEEEd().format(selectedDate),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
            CircleAvatar(
              radius: compact ? 16 : 20,
              backgroundColor: const Color(0xFF1F2635),
              child: Icon(Icons.calendar_today, color: Colors.white, size: compact ? 14 : 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ViewToggle(
          options: const ['Today', 'Week', 'Month'],
          value: view,
          onChanged: onViewChanged,
        ),
      ],
    );
  }
}

class _HeaderCompactRow extends StatelessWidget {
  const _HeaderCompactRow({
    required this.selectedDate,
    required this.subtitle,
    required this.view,
    required this.onViewChanged,
    required this.isDark,
    required this.onToggleTheme,
  });

  final DateTime selectedDate;
  final String subtitle;
  final String view;
  final ValueChanged<String> onViewChanged;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ViewToggle(
          options: const ['Today', 'Week', 'Month'],
          value: view,
          onChanged: onViewChanged,
        ),
        const Spacer(),
        IconButton(
          onPressed: onToggleTheme,
          tooltip: 'Toggle theme',
          icon: Text(isDark ? '☀️' : '🌙', style: const TextStyle(fontSize: 23)),
        ),
      ],
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({
    required this.child,
    required this.minExtent,
    required this.maxExtent,
  });

  final Widget child;
  @override
  final double minExtent;
  @override
  final double maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minExtent != minExtent ||
        oldDelegate.maxExtent != maxExtent;
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options
          .map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                backgroundColor: const Color(0xFF3A7AFE).withOpacity(0.12),
                selectedColor: const Color(0xFF3A7AFE),
                side: const BorderSide(color: Colors.transparent),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: option == value
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
                label: Text(option),
                selected: option == value,
                onSelected: (_) => onChanged(option),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.task,
    required this.isFirst,
    required this.isLast,
    required this.dayId,
    this.onToggleDone,
    this.onHabitTap,
    this.habits,
    required this.date,
    this.onEditTask,
    this.onDeleteTask,
    this.isDimmed = false,
  });

  final Task task;
  final bool isFirst;
  final bool isLast;
  final String dayId;
  final Future<void> Function(String dayId, String taskId, bool isDone)? onToggleDone;
  final Future<void> Function(Habit habit, DateTime date)? onHabitTap;
  final List<Habit>? habits;
  final DateTime date;
  final Future<void> Function(String dayId, Task task)? onEditTask;
  final Future<void> Function(String dayId, Task task)? onDeleteTask;
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    final timeStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w600,
        );
    final lineColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.18);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatTime(task.end),
              style: timeStyle?.copyWith(fontSize: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              SizedBox(
                height: 12,
                child: !isFirst
                    ? Container(width: 2, color: lineColor)
                    : const SizedBox.shrink(),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: task.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: task.color.withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              !isLast
                  ? Container(
                      width: 2,
                      height: 70,
                      color: lineColor,
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ),
        Expanded(
          child: _TaskCard(
            task: task,
            dayId: dayId,
            onToggleDone: onToggleDone,
            onHabitTap: onHabitTap,
            habits: habits,
            date: date,
            onEditTask: onEditTask,
            onDeleteTask: onDeleteTask,
            isDimmed: isDimmed,
          ),
        ),
      ],
    );
    return Opacity(opacity: isDimmed ? 0.4 : 1.0, child: row);
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    this.dayId,
    this.onToggleDone,
    this.onHabitTap,
    this.habits,
    this.date,
    this.onEditTask,
    this.onDeleteTask,
    this.isCompact = false,
    this.isDimmed = false,
  });

  final Task task;
  final String? dayId;
  final Future<void> Function(String dayId, String taskId, bool isDone)? onToggleDone;
  final Future<void> Function(Habit habit, DateTime date)? onHabitTap;
  final List<Habit>? habits;
  final DateTime? date;
  final Future<void> Function(String dayId, Task task)? onEditTask;
  final Future<void> Function(String dayId, Task task)? onDeleteTask;
  final bool isCompact;
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkColor = _checkColor(theme);
    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? task.color.withOpacity(0.12)
                      : task.color.withOpacity(0.2),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(task.icon,
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.onSurface
                        : Colors.black87,
                    size: isCompact ? 18 : 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.isImportant ? '${task.title}   ðŸš©' : task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _onTapCheck,
                        child: Container(
                          padding: EdgeInsets.all(isCompact ? 4 : 6),
                          decoration: BoxDecoration(
                            color: checkColor.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _checkIcon(),
                            color: checkColor,
                            size: isCompact ? 18 : 20,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 2 : 6),
                      Text(
                        formatTime(task.end),
                        style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: task.isHabit
                ? _HabitCountBadge(
                    habit: _habitForTask(),
                    date: date,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    final content = GestureDetector(
      onTap: () => _onCardTap(context),
      child: task.isImportant
          ? _Shake(
              active: !task.isDone,
              child: card,
            )
          : card,
    );
    return isDimmed ? Opacity(opacity: 0.7, child: content) : content;
  }

  Habit? _habitForTask() {
    if (!task.isHabit || task.habitId == null || habits == null) return null;
    try {
      return habits!.firstWhere((h) => h.id == task.habitId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onTapCheck() async {
    if (task.isHabit) {
      if (onHabitTap != null && habits != null && date != null && task.habitId != null) {
        final habit = habits!.firstWhere(
          (h) => h.id == task.habitId,
          orElse: () => habits!.first,
        );
        await onHabitTap!(habit, date!);
      }
      return;
    }
    if (dayId != null && task.id != null && onToggleDone != null) {
      await onToggleDone!(dayId!, task.id!, !task.isDone);
    }
  }

  Future<void> _onCardTap(BuildContext context) async {
    if (task.isHabit || dayId == null || task.id == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Theme.of(ctx).colorScheme.onSurface),
              title: Text('Edit task', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete task', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit' && onEditTask != null) {
      await onEditTask!(dayId!, task);
    } else if (action == 'delete' && onDeleteTask != null) {
      await onDeleteTask!(dayId!, task);
    }
  }

  IconData _checkIcon() {
    return task.isDone ? Icons.check_circle : Icons.radio_button_unchecked;
  }

  Color _checkColor(ThemeData theme) {
    return task.isDone
        ? const Color(0xFF61E294)
        : theme.colorScheme.onSurface.withOpacity(0.6);
  }
}

class _HabitCountBadge extends StatelessWidget {
  const _HabitCountBadge({this.habit, this.date});

  final Habit? habit;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (habit == null || date == null) return const SizedBox.shrink();
    final startOfYear = DateTime(date!.year, 1, 1);
    final idx = date!.difference(startOfYear).inDays;
    final counts = habit!.completionCounts;
    if (idx < 0 || idx >= counts.length) return const SizedBox.shrink();
    final maxPerDay = habit!.timesPerDay <= 0 ? 1 : habit!.timesPerDay;
    final count = counts[idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6)
            : Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count/$maxPerDay',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WeekDayTile extends StatelessWidget {
  const _WeekDayTile({
    required this.date,
    required this.tasks,
    required this.onExpand,
    required this.dayId,
    this.onToggleDone,
    this.onHabitTap,
    this.habits,
    this.onEditTask,
    this.onDeleteTask,
  });

  final DateTime date;
  final List<Task> tasks;
  final VoidCallback onExpand;
  final String dayId;
  final Future<void> Function(String dayId, String taskId, bool isDone)? onToggleDone;
  final Future<void> Function(Habit habit, DateTime date)? onHabitTap;
  final List<Habit>? habits;
  final Future<void> Function(String dayId, Task task)? onEditTask;
  final Future<void> Function(String dayId, Task task)? onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ExpansionTile(
        backgroundColor: Theme.of(context).cardColor,
        collapsedBackgroundColor: Theme.of(context).cardColor,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        onExpansionChanged: (expanded) {
          if (expanded) onExpand();
        },
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.E().format(date),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  DateFormat.MMMd().format(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                ...tasks.take(5).map(
                      (task) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: task.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                if (tasks.length > 5)
                  Text(
                    '+${tasks.length - 5}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                const SizedBox(width: 10),
                Text(
                  '${tasks.length} left',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ),
        children: tasks
            .map(
              (task) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _TaskCard(
                  task: task,
                  isCompact: true,
                  dayId: dayId,
                  onToggleDone: onToggleDone,
                  onHabitTap: onHabitTap,
                  habits: habits,
                  date: date,
                  onEditTask: onEditTask,
                  onDeleteTask: onDeleteTask,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habits, required this.date, this.onTap});

  final List<Habit> habits;
  final DateTime date;
  final Future<void> Function(Habit habit, DateTime date)? onTap;

  @override
  Widget build(BuildContext context) {
    final weekday = date.weekday; // 1=Mon ... 7=Sun
    final todaysHabits = habits.where((h) {
      if (h.recurrenceDays.isEmpty) return true;
      return h.recurrenceDays.contains(weekday);
    }).toList();
    if (todaysHabits.isEmpty) return const SizedBox.shrink();
    final startOfYear = DateTime(date.year, 1, 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: todaysHabits.map((habit) {
            final idx = date.difference(startOfYear).inDays;
            final counts = habit.completionCounts;
            final maxPerDay = habit.timesPerDay <= 0 ? 1 : habit.timesPerDay;
            final count = (idx >= 0 && idx < counts.length) ? counts[idx] : 0;
            final ratio = (count / maxPerDay).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _HabitChip(
                habit: habit,
                ratio: ratio,
                onTap: onTap != null ? () => onTap!(habit, date) : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HabitChip extends StatefulWidget {
  const _HabitChip({required this.habit, required this.ratio, this.onTap});

  final Habit habit;
  final double ratio;
  final VoidCallback? onTap;

  @override
  State<_HabitChip> createState() => _HabitChipState();
}

class _HabitChipState extends State<_HabitChip> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: widget.habit.color.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.habit.color.withOpacity(0.50), width: 1.2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final waveColor =
                      widget.ratio >= 1 ? widget.habit.color : widget.habit.color.withOpacity(1.0);
                  return SizedBox.expand(
                    child: CustomPaint(
                      painter: _WavePainter(
                        color: waveColor,
                        ratio: widget.ratio,
                        phase: _controller.value * 2 * math.pi,
                      ),
                    ),
                  );
                },
              ),
            ),
            Icon(widget.habit.icon, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color, required this.ratio, required this.phase});

  final Color color;
  final double ratio;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final fillRatio = ratio.clamp(0.0, 1.0);
    if (fillRatio <= 0) return;
    final paintFill = Paint()
      ..color = color.withOpacity(0.38)
      ..style = PaintingStyle.fill;

    if (fillRatio >= 0.999) {
      canvas.drawRect(Offset.zero & size, paintFill);
      return;
    }

    final fillHeight = size.height * fillRatio;
    final baseY = size.height - fillHeight;
    final wavePath = Path()..moveTo(0, size.height);
    final amplitude = 3.0;
    final wavelength = size.width / 1.5;
    wavePath.lineTo(0, baseY);

    for (double x = 0; x <= size.width; x += size.width / 24) {
      final y = baseY + math.sin((x / wavelength * 2 * math.pi) + phase) * amplitude;
      final clampedY = y.clamp(0.0, size.height);
      wavePath.lineTo(x, clampedY);
    }

    wavePath
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(wavePath, paintFill);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.ratio != ratio ||
        oldDelegate.phase != phase;
  }
}

class _Shake extends StatefulWidget {
  const _Shake({required this.child, this.active = false});
  final Widget child;
  final bool active;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with TickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _controller == null) {
      return widget.child;
    }
    final shake = _controller!;
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) {
        if (!shake.isAnimating) shake.repeat();
        final wave = math.sin(shake.value * 2 * math.pi * 3);
        final dx = wave * 1.4; // slightly stronger shake
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}





