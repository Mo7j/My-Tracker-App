import 'package:flutter/material.dart';

class DaySchedule {
  DaySchedule({required this.date, required this.tasks});
  final DateTime date;
  final List<Task> tasks;
}

class Task {
  Task({
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.category,
    required this.color,
    required this.icon,
    this.isHabit = false,
    this.isDone = false,
    this.id,
    this.habitId,
    this.isImportant = false,
    DateTime? startDate,
  }) : startDate = startDate ?? DateTime.now();

  final String? id;
  final String? habitId;
  final String title;
  final String subtitle;
  final TimeOfDay start;
  final TimeOfDay end;
  final String category;
  final Color color;
  final IconData icon;
  final bool isHabit;
  final bool isDone;
  final bool isImportant;
  final DateTime startDate;
}

class Habit {
  Habit({
    this.id,
    required this.name,
    required this.caption,
    required this.color,
    required this.icon,
    required this.completions,
    this.recurrenceDays = const <int>[],
    this.timesPerDay = 1,
    List<int>? completionCounts,
  }) : completionCounts = completionCounts ?? const <int>[];

  final String? id;
  final String name;
  final String caption;
  final Color color;
  final IconData icon;
  final List<bool> completions;
  final List<int> recurrenceDays; // 1=Mon ... 7=Sun
  final int timesPerDay;
  final List<int> completionCounts;

  int get streak => completions.reversed.takeWhile((value) => value).length;
}

class Project {
  Project({
    this.id,
    required this.name,
    required this.description,
    required this.progress,
    required this.color,
    required this.weeklyBurndown,
  });

  final String? id;
  final String name;
  final String description;
  final double progress;
  final Color color;
  final List<double> weeklyBurndown;
}

class Goal {
  Goal({
    this.id,
    required this.name,
    required this.stat,
    required this.progress,
    required this.timeframe,
    required this.color,
    this.deadline,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String stat;
  final double progress;
  final String timeframe;
  final Color color;
  final DateTime? deadline;
  final DateTime? createdAt;
}
