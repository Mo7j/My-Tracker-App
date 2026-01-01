import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatTime(TimeOfDay time) {
  final now = DateTime.now();
  final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return DateFormat('hh:mm a').format(dt);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfWeek(DateTime date) {
  final weekday = date.weekday; // 1 = Mon, 7 = Sun
  final daysFromSunday = weekday % 7; // Sunday => 0, Monday => 1, ..., Saturday => 6
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromSunday));
}

int daysInMonth(DateTime date) {
  final firstDayNextMonth = DateTime(date.year, date.month + 1, 1);
  return firstDayNextMonth.subtract(const Duration(days: 1)).day;
}
