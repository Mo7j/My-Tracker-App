import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:async/async.dart';

import '../models.dart';
import '../sample_data.dart';

class FirestoreService {
  FirestoreService(this._db);
  final FirebaseFirestore _db;

  /// Fetch days with tasks. Expected Firestore shape:
  /// /schedule/{yyyy-MM-dd}
  ///   - date: Timestamp
  ///   - tasks (subcollection)
  ///       {autoId}: {
  ///         title, subtitle, category, colorHex, icon, isHabit (bool),
  ///         startMinutes (int), endMinutes (int)
  ///       }
  Future<List<DaySchedule>> fetchSchedule() async {
    try {
      final snap = await _db.collection('schedule').orderBy('date').get();
      final days = <DaySchedule>[];
      for (final doc in snap.docs) {
        final date = (doc.data()['date'] as Timestamp?)?.toDate() ??
            DateTime.tryParse(doc.id) ??
            DateTime.now();
        final tasksSnap = await doc.reference
            .collection('tasks')
            .orderBy('startMinutes')
            .get();
        final tasks = tasksSnap.docs
            .map((t) => _taskFromMap(t.data(), id: t.id))
            .whereType<Task>()
            .toList();
        days.add(DaySchedule(date: date, tasks: tasks));
      }
      if (days.isEmpty) return sampleSchedule;
      return days;
    } catch (_) {
      return sampleSchedule;
    }
  }

  /// Fetch habits. Expected shape: /habits/{autoId} with fields:
  /// name, caption, colorHex, icon, completions (array<bool>)
  Future<List<Habit>> fetchHabits() async {
    try {
      final snap = await _db.collection('habits').get();
      final habits = snap.docs
          .map((d) => _habitFromMap({...d.data(), 'id': d.id}))
          .whereType<Habit>()
          .toList();
      if (habits.isEmpty) return sampleHabits;
      return habits;
    } catch (_) {
      return sampleHabits;
    }
  }

  /// Fetch projects. Expected shape: /projects/{autoId} with fields:
  /// name, description, progress (double 0-1), colorHex, weeklyBurndown (array<num>)
  Future<List<Project>> fetchProjects() async {
    try {
      final snap = await _db.collection('projects').get();
      final projects = snap.docs
          .map((d) => _projectFromMap(d.data(), id: d.id))
          .whereType<Project>()
          .toList();
      if (projects.isEmpty) return sampleProjects;
      return projects;
    } catch (_) {
      return sampleProjects;
    }
  }

  /// Fetch goals. Expected shape: /goals/{autoId} with fields:
  /// name, stat, progress (double 0-1), timeframe, colorHex
  Future<List<Goal>> fetchGoals() async {
    try {
      final snap = await _db.collection('goals').get();
      final goals =
          snap.docs.map((d) => _goalFromMap(d.data(), id: d.id)).whereType<Goal>().toList();
      if (goals.isEmpty) return sampleGoals;
      return goals;
    } catch (_) {
      return sampleGoals;
    }
  }

  Stream<List<DaySchedule>> streamSchedule() {
    return _db.collectionGroup('tasks').snapshots().map((taskSnap) {
      final byDay = <String, List<Task>>{};
      for (final doc in taskSnap.docs) {
        final dayId = doc.reference.parent.parent?.id;
        if (dayId == null) continue;
        final task = _taskFromMap(doc.data(), id: doc.id);
        if (task == null) continue;
        byDay.putIfAbsent(dayId, () => <Task>[]).add(task);
      }
      final days = byDay.entries.map((entry) {
        final date = DateTime.tryParse(entry.key) ?? DateTime.now();
        final tasks = [...entry.value];
        tasks.sort((a, b) {
          final aMinutes = a.start.hour * 60 + a.start.minute;
          final bMinutes = b.start.hour * 60 + b.start.minute;
          return aMinutes.compareTo(bMinutes);
        });
        return DaySchedule(date: date, tasks: tasks);
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return days.isEmpty ? sampleSchedule : days;
    }).handleError((_) => sampleSchedule);
  }

  Stream<List<Habit>> streamHabits() {
    return _db.collection('habits').snapshots().map((snap) {
      final habits = snap.docs
          .map((d) => _habitFromMap({...d.data(), 'id': d.id}))
          .whereType<Habit>()
          .toList();
      return habits.isEmpty ? sampleHabits : habits;
    }).handleError((_) => sampleHabits);
  }

  Stream<List<Project>> streamProjects() {
    return _db.collection('projects').snapshots().map((snap) {
      final projects =
          snap.docs.map((d) => _projectFromMap(d.data(), id: d.id)).whereType<Project>().toList();
      return projects.isEmpty ? sampleProjects : projects;
    }).handleError((_) => sampleProjects);
  }

  Stream<List<Goal>> streamGoals() {
    return _db.collection('goals').snapshots().map((snap) {
      final goals =
          snap.docs.map((d) => _goalFromMap(d.data(), id: d.id)).whereType<Goal>().toList();
      return goals.isEmpty ? sampleGoals : goals;
    }).handleError((_) => sampleGoals);
  }

  // Placeholder for creating a task.
  Future<void> addTask(Task task, {required DateTime date}) async {
    final dayId = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final dayRef = _db.collection('schedule').doc(dayId);
    await dayRef.set({'date': Timestamp.fromDate(date)}, SetOptions(merge: true));
    await dayRef.collection('tasks').add({
      'title': task.title,
      'subtitle': task.subtitle,
      'category': task.category,
      'colorHex': task.color.value,
      'icon': task.icon.codePoint,
      'isHabit': task.isHabit,
      'isDone': task.isDone,
      'isImportant': task.isImportant,
      'startDate': Timestamp.fromDate(task.startDate),
      'startMinutes': task.start.hour * 60 + task.start.minute,
      'endMinutes': task.end.hour * 60 + task.end.minute,
    });
  }

  Future<void> addHabit(Habit habit) async {
    await _db.collection('habits').add({
      'name': habit.name,
      'caption': habit.caption,
      'colorHex': habit.color.value,
      'icon': habit.icon.codePoint,
      'completions': habit.completions,
      'recurrenceDays': habit.recurrenceDays,
      'timesPerDay': habit.timesPerDay,
      'completionCounts': habit.completionCounts.isNotEmpty
          ? habit.completionCounts
          : List<int>.filled(365, 0),
    });
  }

  Future<void> updateHabit(Habit habit) async {
    if (habit.id == null) return;
    await _db.collection('habits').doc(habit.id!).update({
      'name': habit.name,
      'caption': habit.caption,
      'colorHex': habit.color.value,
      'icon': habit.icon.codePoint,
      'recurrenceDays': habit.recurrenceDays,
      'timesPerDay': habit.timesPerDay,
      'completionCounts': habit.completionCounts,
    });
  }

  Future<void> deleteHabit(String habitId) async {
    await _db.collection('habits').doc(habitId).delete();
  }

  Future<void> addProject(Project project) async {
    await _db.collection('projects').add({
      'name': project.name,
      'description': project.description,
      'progress': project.progress,
      'colorHex': project.color.value,
      'weeklyBurndown': project.weeklyBurndown,
    });
  }

  Future<void> updateProject(Project project) async {
    if (project.id == null) return;
    await _db.collection('projects').doc(project.id!).update({
      'name': project.name,
      'description': project.description,
      'progress': project.progress,
      'colorHex': project.color.value,
      'weeklyBurndown': project.weeklyBurndown,
    });
  }

  Future<void> deleteProject(String projectId) async {
    await _db.collection('projects').doc(projectId).delete();
  }

  Future<void> addGoal(Goal goal) async {
    await _db.collection('goals').add({
      'name': goal.name,
      'stat': goal.stat,
      'progress': goal.progress,
      'timeframe': goal.timeframe,
      'colorHex': goal.color.value,
      'deadline': goal.deadline != null ? Timestamp.fromDate(goal.deadline!) : null,
      'createdAt': Timestamp.fromDate(goal.createdAt ?? DateTime.now()),
    });
  }

  Future<void> updateGoal(Goal goal) async {
    if (goal.id == null) return;
    await _db.collection('goals').doc(goal.id!).update({
      'name': goal.name,
      'stat': goal.stat,
      'progress': goal.progress,
      'timeframe': goal.timeframe,
      'colorHex': goal.color.value,
      'deadline': goal.deadline != null ? Timestamp.fromDate(goal.deadline!) : null,
      'createdAt': goal.createdAt != null ? Timestamp.fromDate(goal.createdAt!) : null,
    });
  }

  Future<void> deleteGoal(String goalId) async {
    await _db.collection('goals').doc(goalId).delete();
  }

  Future<void> updateTaskDone({
    required String dayId,
    required String taskId,
    required bool isDone,
  }) async {
    await _db
        .collection('schedule')
        .doc(dayId)
        .collection('tasks')
        .doc(taskId)
        .update({'isDone': isDone});
  }

  Future<void> updateTask(String dayId, Task task) async {
    if (task.id == null) return;
    final dayRef = _db.collection('schedule').doc(dayId);
    await dayRef.set({'date': Timestamp.fromDate(task.startDate)}, SetOptions(merge: true));
    await dayRef.collection('tasks').doc(task.id!).update({
      'title': task.title,
      'subtitle': task.subtitle,
      'category': task.category,
      'colorHex': task.color.value,
      'icon': task.icon.codePoint,
      'isHabit': task.isHabit,
      'isDone': task.isDone,
      'isImportant': task.isImportant,
      'startDate': Timestamp.fromDate(task.startDate),
      'startMinutes': task.start.hour * 60 + task.start.minute,
      'endMinutes': task.end.hour * 60 + task.end.minute,
    });
  }

  Future<void> deleteTask(String dayId, String taskId) async {
    await _db.collection('schedule').doc(dayId).collection('tasks').doc(taskId).delete();
  }

  // Project sub-tasks
  Future<List<Task>> fetchProjectTasks(String projectId) async {
    try {
      final snap = await _db
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .orderBy('title')
          .get();
      return snap.docs.map((d) => _taskFromMap(d.data(), id: d.id)).whereType<Task>().toList();
    } catch (_) {
      return <Task>[];
    }
  }

  Future<void> addProjectTask(String projectId, Task task) async {
    await _db.collection('projects').doc(projectId).collection('tasks').add({
      'title': task.title,
      'subtitle': task.subtitle,
      'category': task.category,
      'colorHex': task.color.value,
      'icon': task.icon.codePoint,
      'isHabit': false,
      'isDone': task.isDone,
      'startMinutes': task.start.hour * 60 + task.start.minute,
      'endMinutes': task.end.hour * 60 + task.end.minute,
    });
  }

  Future<void> updateProjectTaskDone(String projectId, String taskId, bool isDone) async {
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .update({'isDone': isDone});
  }

  Future<void> updateProjectTask(String projectId, Task task) async {
    if (task.id == null) return;
    await _db.collection('projects').doc(projectId).collection('tasks').doc(task.id!).update({
      'title': task.title,
      'subtitle': task.subtitle,
      'colorHex': task.color.value,
      'icon': task.icon.codePoint,
      'isDone': task.isDone,
      'startMinutes': task.start.hour * 60 + task.start.minute,
      'endMinutes': task.end.hour * 60 + task.end.minute,
    });
  }

  Future<void> deleteProjectTask(String projectId, String taskId) async {
    await _db.collection('projects').doc(projectId).collection('tasks').doc(taskId).delete();
  }

  // Goal sub-tasks
  Future<List<Task>> fetchGoalTasks(String goalId) async {
    try {
      final snap = await _db
          .collection('goals')
          .doc(goalId)
          .collection('tasks')
          .orderBy('title')
          .get();
      return snap.docs.map((d) => _taskFromMap(d.data(), id: d.id)).whereType<Task>().toList();
    } catch (_) {
      return <Task>[];
    }
  }

  Future<void> addGoalTask(String goalId, Task task) async {
    await _db.collection('goals').doc(goalId).collection('tasks').add({
      'title': task.title,
      'subtitle': task.subtitle,
      'category': task.category,
      'colorHex': task.color.value,
      'icon': task.icon.codePoint,
      'isHabit': false,
      'isDone': task.isDone,
      'startMinutes': task.start.hour * 60 + task.start.minute,
      'endMinutes': task.end.hour * 60 + task.end.minute,
    });
  }

  Future<void> updateGoalTaskDone(String goalId, String taskId, bool isDone) async {
    await _db
        .collection('goals')
        .doc(goalId)
        .collection('tasks')
        .doc(taskId)
        .update({'isDone': isDone});
  }

  Future<void> updateGoalTask(String goalId, Task task) async {
    if (task.id == null) return;
    await _db.collection('goals').doc(goalId).collection('tasks').doc(task.id!).update({
      'title': task.title,
      'subtitle': task.subtitle,
      'colorHex': task.color.value,
      'icon': task.icon.codePoint,
      'isDone': task.isDone,
      'startMinutes': task.start.hour * 60 + task.start.minute,
      'endMinutes': task.end.hour * 60 + task.end.minute,
    });
  }

  Future<void> deleteGoalTask(String goalId, String taskId) async {
    await _db.collection('goals').doc(goalId).collection('tasks').doc(taskId).delete();
  }

  Future<void> updateHabitCounts(String habitId, List<int> counts) async {
    await _db.collection('habits').doc(habitId).update({'completionCounts': counts});
  }

  Stream<List<Task>> streamProjectTasks(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _taskFromMap(d.data(), id: d.id)).whereType<Task>().toList());
  }

  Stream<List<Task>> streamGoalTasks(String goalId) {
    return _db
        .collection('goals')
        .doc(goalId)
        .collection('tasks')
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _taskFromMap(d.data(), id: d.id)).whereType<Task>().toList());
  }

  // Mappers
  Task? _taskFromMap(Map<String, dynamic>? data, {String? id}) {
    if (data == null) return null;
    final startMinutes = (data['startMinutes'] ?? 0) as int;
    final endMinutes = (data['endMinutes'] ?? 0) as int;
    final ts = data['startDate'] as Timestamp?;
    return Task(
      id: id,
      title: (data['title'] ?? '') as String,
      subtitle: (data['subtitle'] ?? '') as String,
      category: (data['category'] ?? '') as String,
      color: _colorFromHex(data['colorHex']),
      icon: _iconFromCodePoint(data['icon']),
      start: TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60),
      end: TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60),
      isHabit: (data['isHabit'] ?? false) as bool,
      isDone: data['isDone'] == true,
      isImportant: data['isImportant'] == true,
      startDate: ts?.toDate(),
    );
  }

  Habit? _habitFromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final completionsRaw = data['completions'];
    final completions = completionsRaw is List
        ? completionsRaw.map((e) => e == true).toList()
        : <bool>[];
    final completionCountsRaw = data['completionCounts'];
    final completionCounts = completionCountsRaw is List
        ? completionCountsRaw.map((e) => (e as num).toInt()).toList()
        : List<int>.filled(365, 0);
    return Habit(
      id: data['id'] as String?,
      name: (data['name'] ?? '') as String,
      caption: (data['caption'] ?? '') as String,
      color: _colorFromHex(data['colorHex']),
      icon: _iconFromCodePoint(data['icon']),
      completions: completions,
      recurrenceDays: (data['recurrenceDays'] as List?)?.map((e) => e as int).toList() ??
          const <int>[],
      timesPerDay: data['timesPerDay'] as int? ?? 1,
      completionCounts: completionCounts,
    );
  }

  Project? _projectFromMap(Map<String, dynamic>? data, {String? id}) {
    if (data == null) return null;
    final weekly = (data['weeklyBurndown'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        <double>[];
    return Project(
      id: id ?? data['id'] as String?,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      color: _colorFromHex(data['colorHex']),
      weeklyBurndown: weekly,
    );
  }

  Goal? _goalFromMap(Map<String, dynamic>? data, {String? id}) {
    if (data == null) return null;
    return Goal(
      id: id,
      name: (data['name'] ?? '') as String,
      stat: (data['stat'] ?? '') as String,
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      timeframe: (data['timeframe'] ?? '') as String,
      color: _colorFromHex(data['colorHex']),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Color _colorFromHex(Object? raw) {
    if (raw is int) return Color(raw);
    if (raw is String) {
      final value = int.tryParse(raw.replaceFirst('#', ''), radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return const Color(0xFF3A7AFE);
  }

  IconData _iconFromCodePoint(Object? raw) {
    if (raw is int) return IconData(raw, fontFamily: 'MaterialIcons');
    return Icons.circle_outlined;
  }
}
