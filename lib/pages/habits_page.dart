import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({
    super.key,
    required this.habits,
    this.onEditHabit,
    this.onDeleteHabit,
  });

  final List<Habit> habits;
  final Future<void> Function(Habit habit)? onEditHabit;
  final Future<void> Function(Habit habit)? onDeleteHabit;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habits',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Build streaks with a calm heatmap feel.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: habits.length,
          itemBuilder: (context, index) {
            final habit = habits[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: GestureDetector(
                onTap: () => _showHabitMenu(context, habit),
                child: _HabitCard(habit: habit),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  void _showHabitMenu(BuildContext context, Habit habit) {
    if (onEditHabit == null && onDeleteHabit == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).dialogBackgroundColor
          : Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Theme.of(ctx).colorScheme.onSurface),
              title: Text('Edit habit', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(ctx);
                onEditHabit?.call(habit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(
                'Delete habit',
                style: TextStyle(
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.redAccent
                      : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDeleteHabit?.call(habit);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171C25) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(habit.icon, color: habit.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      habit.caption,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              _StreakBadge(
                streak: _streakFromCounts(
                  _normalizeCounts(habit.completionCounts),
                  habit.timesPerDay <= 0 ? 1 : habit.timesPerDay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SnakeHeatmap(habit: habit),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _readableDays(List<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => names[(d - 1).clamp(0, 6)]).join(', ');
  }

  int _streakFromCounts(List<int> counts, int maxPerDay) {
    if (counts.isEmpty) return 0;
    counts = _normalizeCounts(counts);
    int longest = 0;
    int current = 0;
    for (final c in counts) {
      if (c >= maxPerDay) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }
}

class _SnakeHeatmap extends StatelessWidget {
  const _SnakeHeatmap({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final counts = _normalizeCounts(habit.completionCounts);
    const rows = 10;
    final cols = (365 / rows).ceil();
    final maxPerDay = habit.timesPerDay <= 0 ? 1 : habit.timesPerDay;

    const spacing = 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = (cols - 1) * spacing;
        final cellSize =
            ((constraints.maxWidth - totalSpacing) / cols).clamp(4.0, double.infinity);
        final heatmapHeight = rows * cellSize + (rows - 1) * spacing;

        return SizedBox(
          height: heatmapHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(cols, (col) {
              return Padding(
                padding: EdgeInsets.only(right: col == cols - 1 ? 0 : spacing),
                child: SizedBox(
                  height: heatmapHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(rows, (row) {
                      final idx = col * rows + (col.isEven ? row : (rows - 1 - row));
                      if (idx >= 365) {
                        return SizedBox(width: cellSize, height: cellSize);
                      }
                      final count = counts.length > idx ? counts[idx] : 0;
                      final ratio = (count / maxPerDay).clamp(0.0, 1.0);
                      final opacity = 0.12 + 0.78 * ratio;
                      return Container(
                        width: cellSize,
                        height: cellSize,
                        margin: EdgeInsets.only(bottom: row == rows - 1 ? 0 : spacing),
                        decoration: BoxDecoration(
                          color: count == 0
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E2535)
                                  : Colors.grey.shade200)
                              : habit.color.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
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

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge;
    final textStyle = base?.copyWith(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).brightness == Brightness.dark ? const Color.fromARGB(255, 239, 5, 5) : const Color.fromARGB(255, 224, 10, 10),
          fontSize: (base?.fontSize ?? 14) + 2,

        ) ??
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        );
    if (streak <= 0) return const SizedBox.shrink();

    final size = streak == 1
        ? 35.0
        : streak == 2
            ? 40.0
            : 45.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Text('$streak', style: textStyle),
          ),
          const SizedBox(width: 0),
          SizedBox(
            height: size,
            width: size,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Lottie.asset(
                'assets/lottie/Fire.json',
                repeat: true,
                animate: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );

  }
}

List<int> _normalizeCounts(List<int> counts) {
  if (counts.isEmpty) return List<int>.filled(365, 0);
  if (counts.length == 365) return List<int>.from(counts);
  if (counts.length > 365) return counts.take(365).toList();
  return [
    ...counts,
    ...List<int>.filled(365 - counts.length, 0),
  ];
}
