import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:async/async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'pages/habits_page.dart';
import 'pages/goal_detail_page.dart';
import 'pages/project_detail_page.dart';
import 'pages/goals_projects_page.dart';
import 'pages/timeline_page.dart';
import 'project_goal_sheet.dart';
import 'project_goal_result.dart';
import 'shared_colors.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyTrackerApp());
}

class _ThemeSwitcher extends StatefulWidget {
  const _ThemeSwitcher({required this.childBuilder});

  final Widget Function(ThemeMode mode, VoidCallback toggle) childBuilder;

  @override
  State<_ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<_ThemeSwitcher> {
  ThemeMode _mode = ThemeMode.dark;

  void _toggle() {
    setState(() {
      _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.childBuilder(_mode, _toggle);
  }
}

class MyTrackerApp extends StatelessWidget {
  const MyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _ThemeSwitcher(
      childBuilder: (mode, toggle) => MaterialApp(
        title: 'My Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(dark: false),
        darkTheme: buildAppTheme(dark: true),
        themeMode: mode,
        home: HomeShell(onToggleTheme: toggle, themeMode: mode),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onToggleTheme, required this.themeMode});

  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final FirestoreService _firestore = FirestoreService(FirebaseFirestore.instance);
  int _index = 0;
  late Stream<_AppData> _stream = _loadStream();
  _AppData? _data;
  DateTime _timelineDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_AppData>(
      stream: _stream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _data;
        if (data == null) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        final pages = [
          TimelinePage(
            schedule: data.schedule,
            habits: data.habits,
            isDark: widget.themeMode == ThemeMode.dark,
            onToggleTheme: widget.onToggleTheme,
            onAddTask: () {
              _handleAddTask(context);
            },
            onToggleTaskDone: _handleToggleTaskDone,
            onToggleHabit: _handleHabitTap,
            onDateChanged: (d) => _timelineDate = d,
            onEditTask: _handleEditTask,
            onDeleteTask: _handleDeleteTask,
          ),
          HabitsPage(
            habits: data.habits,
            onEditHabit: _handleEditHabit,
            onDeleteHabit: _handleDeleteHabit,
          ),
          GoalsProjectsPage(
            projects: data.projects,
            goals: data.goals,
            firestore: _firestore,
            onRefresh: () => setState(() {
              _stream = _loadStream();
            }),
          ),
        ];

        return Scaffold(
          body: SafeArea(child: pages[_index]),
          floatingActionButton: _index == 0
              ? FloatingActionButton(
                  onPressed: () => _handleAddTask(context),
                  child: const Icon(Icons.add, size: 35),
                )
              : _index == 1
                  ? FloatingActionButton(
                      onPressed: () => _handleAddHabit(context),
                      child: const Icon(Icons.add, size: 35),
                    )
          : _index == 2
              ? FloatingActionButton(
                  onPressed: () => _showGoalsActions(context),
                  child: const Icon(Icons.add, size: 35),
                )
              : null,
          bottomNavigationBar: _SegmentedNavBar(
            index: _index,
            onChanged: (value) => setState(() => _index = value),
          ),
        );
      },
    );
  }

  Future<void> _handleAddTask(BuildContext context) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _AddTaskSheet(
          initialDate: _timelineDate,
          expand: true,
        ),
      ),
    );
    if (result != null) {
      await _firestore.addTask(result, date: result.startDate);
      if (mounted) {
        }
    }
  }

  Future<_AppData> _loadData() async {
    final results = await Future.wait([
      _firestore.fetchSchedule(),
      _firestore.fetchHabits(),
      _firestore.fetchProjects(),
      _firestore.fetchGoals(),
    ]);
    final data = _AppData(
      schedule: results[0] as List<DaySchedule>,
      habits: results[1] as List<Habit>,
      projects: results[2] as List<Project>,
      goals: results[3] as List<Goal>,
    );
    _data = data;
    return data;
  }

  Stream<_AppData> _loadStream() {
    final schedule$ = _firestore.streamSchedule();
    final habits$ = _firestore.streamHabits();
    final projects$ = _firestore.streamProjects();
    final goals$ = _firestore.streamGoals();

    return Stream.multi((controller) {
      List<DaySchedule>? schedule;
      List<Habit>? habits;
      List<Project>? projects;
      List<Goal>? goals;

      void emit() {
        if (schedule != null && habits != null && projects != null && goals != null) {
          final data = _AppData(
            schedule: schedule!,
            habits: habits!,
            projects: projects!,
            goals: goals!,
          );
          _data = data;
          controller.add(data);
        }
      }

      final sub1 = schedule$.listen((v) {
        schedule = v;
        emit();
      }, onError: (_) {});
      final sub2 = habits$.listen((v) {
        habits = v;
        emit();
      }, onError: (_) {});
      final sub3 = projects$.listen((v) {
        projects = v;
        emit();
      }, onError: (_) {});
      final sub4 = goals$.listen((v) {
        goals = v;
        emit();
      }, onError: (_) {});

      controller.onCancel = () async {
        await sub1.cancel();
        await sub2.cancel();
        await sub3.cancel();
        await sub4.cancel();
      };
    });
  }

  Future<void> _handleAddHabit(BuildContext context) async {
    final result = await showModalBottomSheet<Habit>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: _AddHabitSheet(expand: true),
      ),
    );
    if (result != null) {
      await _firestore.addHabit(result);
      if (mounted) {
        }
    }
  }

  Future<void> _handleEditHabit(Habit habit) async {
    final updated = await showModalBottomSheet<Habit>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _AddHabitSheet(initialHabit: habit, expand: true),
      ),
    );
    if (updated != null) {
      await _firestore.updateHabit(updated);
      if (mounted) {
        }
    }
  }

  Future<void> _handleDeleteHabit(Habit habit) async {
    if (habit.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text('Delete habit?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Remove "${habit.name}" and its progress?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteHabit(habit.id!);
    }
  }

  Future<void> _handleAddProject(BuildContext context) async {
    final result = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.5,
        child: _AddProjectSheet(),
      ),
    );
    if (result != null) {
      final current = _data;
      final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
      final optimisticProject = Project(
        id: result.id ?? tempId,
        name: result.name,
        description: result.description,
        progress: result.progress,
        color: result.color,
        weeklyBurndown: result.weeklyBurndown,
      );
      if (current != null) {
        final updated = _AppData(
          schedule: current.schedule,
          habits: current.habits,
          projects: [...current.projects, optimisticProject],
          goals: current.goals,
        );
        setState(() {
          _data = updated;
        });
      }
      try {
        await _firestore.addProject(result);
        if (mounted) {
          }
      } catch (_) {
        if (current != null) {
          setState(() {
            _data = current;
          });
        }
        if (mounted) {
          }
      }
    }
  }

  Future<void> _handleAddGoal(BuildContext context) async {
    final result = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FractionallySizedBox(
        heightFactor: 0.8,
        child: _AddGoalSheet(),
      ),
    );
    if (result != null) {
      final current = _data;
      final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
      final optimisticGoal = Goal(
        id: result.id ?? tempId,
        name: result.name,
        stat: result.stat,
        progress: result.progress,
        timeframe: result.timeframe,
        color: result.color,
        deadline: result.deadline,
        createdAt: result.createdAt,
      );
      if (current != null) {
        final updated = _AppData(
          schedule: current.schedule,
          habits: current.habits,
          projects: current.projects,
          goals: [...current.goals, optimisticGoal],
        );
        setState(() {
          _data = updated;
        });
      }
      try {
        await _firestore.addGoal(result);
        if (mounted) {
          }
      } catch (_) {
        if (current != null) {
          setState(() {
            _data = current;
          });
        }
        if (mounted) {
          }
      }
    }
  }

  Future<void> _handleToggleTaskDone(String dayId, String taskId, bool isDone) async {
    final current = _data;
    if (current == null) return;
    final updatedSchedule = current.schedule.map((day) {
      final id = _dayIdFromDate(day.date);
      if (id != dayId) return day;
      final updatedTasks = day.tasks.map((task) {
        if (task.id != taskId) return task;
        return _copyTask(task, isDone: isDone);
      }).toList();
      return DaySchedule(date: day.date, tasks: updatedTasks);
    }).toList();
    final updated = _AppData(
      schedule: updatedSchedule,
      habits: current.habits,
      projects: current.projects,
      goals: current.goals,
    );
    setState(() {
      _data = updated;
    });
    try {
      await _firestore.updateTaskDone(dayId: dayId, taskId: taskId, isDone: isDone);
    } catch (e) {
      // Roll back if the network update fails so the UI stays consistent.
      setState(() {
        _data = current;
      });
      if (mounted) {
        }
    }
  }

  Task _copyTask(Task task, {bool? isDone}) {
    return Task(
      id: task.id,
      habitId: task.habitId,
      title: task.title,
      subtitle: task.subtitle,
      category: task.category,
      color: task.color,
      icon: task.icon,
      isHabit: task.isHabit,
      isDone: isDone ?? task.isDone,
      isImportant: task.isImportant,
      startDate: task.startDate,
      start: task.start,
      end: task.end,
    );
  }

  String _dayIdFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleEditTask(String dayId, Task task) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _AddTaskSheet(
          initialDate: task.startDate,
          initialTask: task,
          expand: true,
        ),
      ),
    );
    if (result != null) {
      final updated = Task(
        id: task.id,
        habitId: task.habitId,
        title: result.title,
        subtitle: result.subtitle,
        category: result.category,
        color: result.color,
        icon: result.icon,
        start: result.start,
        end: result.end,
        startDate: result.startDate,
        isHabit: task.isHabit,
        isDone: task.isDone,
        isImportant: result.isImportant,
      );
      await _firestore.updateTask(dayId, updated);
    }
  }

  Future<void> _handleDeleteTask(String dayId, Task task) async {
    if (task.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121620),
        title: const Text('Delete task?'),
        content: Text('Remove "${task.title}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteTask(dayId, task.id!);
    }
  }

  Future<void> _handleHabitTap(Habit habit, DateTime date) async {
    if (habit.id == null) return;
    final currentData = _data;
    var counts = List<int>.from(
        habit.completionCounts.isNotEmpty ? habit.completionCounts : List<int>.filled(365, 0));
    if (counts.length < 365) {
      counts = [
        ...counts,
        ...List<int>.filled(365 - counts.length, 0),
      ];
    } else if (counts.length > 365) {
      counts = counts.take(365).toList();
    }
    final startOfYear = DateTime(date.year, 1, 1);
    final index = date.difference(startOfYear).inDays;
    if (index < 0 || index >= counts.length) return;
    final maxPerDay = habit.timesPerDay <= 0 ? 1 : habit.timesPerDay;
    final current = counts[index];
    final next = current >= maxPerDay ? 0 : current + 1;
    counts[index] = next;

    final updatedHabit = Habit(
      id: habit.id,
      name: habit.name,
      caption: habit.caption,
      color: habit.color,
      icon: habit.icon,
      completions: habit.completions,
      recurrenceDays: habit.recurrenceDays,
      timesPerDay: habit.timesPerDay,
      completionCounts: counts,
    );

    if (currentData != null) {
      final updatedHabits = currentData.habits
          .map((h) => h.id == habit.id ? updatedHabit : h)
          .toList();
      final optimistic = _AppData(
        schedule: currentData.schedule,
        habits: updatedHabits,
        projects: currentData.projects,
        goals: currentData.goals,
      );
      setState(() {
        _data = optimistic;
      });
    }

    try {
      await _firestore.updateHabitCounts(habit.id!, counts);
    } catch (_) {
      if (currentData != null) {
        setState(() {
          _data = currentData;
        });
      }
      if (mounted) {
        }
    }
  }

  Future<void> _showGoalsActions(BuildContext context) async {
    final result = await showModalBottomSheet<ProjectGoalResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FractionallySizedBox(
        heightFactor: 0.6,
        child: ProjectGoalSheet(),
      ),
    );

    if (result == null) return;
    if (result.project != null) {
      await _firestore.addProject(result.project!);
    } else if (result.goal != null) {
      await _firestore.addGoal(result.goal!);
    }
  }
}

class _AppData {
  _AppData({
    required this.schedule,
    required this.habits,
    required this.projects,
    required this.goals,
  });

  final List<DaySchedule> schedule;
  final List<Habit> habits;
  final List<Project> projects;
  final List<Goal> goals;
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({this.initialDate, this.initialTask, this.expand = false});

  final DateTime? initialDate;
  final Task? initialTask;
  final bool expand;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  late DateTime _date;
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  int _durationMinutes = 60;
  Color _color = const Color(0xFF3A7AFE);
  IconData _icon = Icons.calendar_today_rounded;
  bool _important = false;
  late String _category;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTask;
    _category = t?.category ?? 'Task';
    _date = t?.startDate ?? widget.initialDate ?? DateTime.now();
    if (t != null) {
      _titleCtrl.text = t.title;
      _subtitleCtrl.text = t.subtitle;
      _color = t.color;
      _icon = t.icon;
      _end = t.end;
      _important = t.isImportant;
      final startMinutes = t.start.hour * 60 + t.start.minute;
      final endMinutes = t.end.hour * 60 + t.end.minute;
      _durationMinutes = ((endMinutes - startMinutes).clamp(15, 12 * 60)).toInt();
    }
    // Default icon if none provided
    _icon = _icon == Icons.check_circle ? Icons.calendar_today_rounded : _icon;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTask != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.8,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + viewInsets),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit task' : 'Add task',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Title',
                controller: _titleCtrl,
                hint: 'e.g., Deep work',
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Subtitle',
                controller: _subtitleCtrl,
                hint: 'Optional details',
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as important'),
                value: _important,
                onChanged: (v) => setState(() => _important = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PickerButton(
                      label: 'Date',
                      value: '${_date.month}/${_date.day}/${_date.year}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerButton(
                      label: 'End',
                      value: _end.format(context),
                      onTap: _pickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Icon',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _taskIconOptions
                    .map(
                      (icon) => ChoiceChip(
                        label: Icon(icon,
                            size: 18, color: Theme.of(context).colorScheme.onSurface),
                        selected: _icon == icon,
                        onSelected: (_) => setState(() => _icon = icon),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'Color',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kColorOptions
                    .map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => _color = color),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == color
                                  ? Theme.of(context).scaffoldBackgroundColor
                                  : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7AFE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  isEditing ? 'Save changes' : 'Add task',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      return;
    }
    final endMinutes = _end.hour * 60 + _end.minute;
    final adjustedStart = endMinutes - _durationMinutes;
    final safeStartMinutes = adjustedStart < 0 ? 0 : adjustedStart;
    final safeStart = TimeOfDay(hour: safeStartMinutes ~/ 60, minute: safeStartMinutes % 60);
    final category = _category.isEmpty ? 'Task' : _category;
    final task = Task(
      title: _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      category: category,
      color: _color,
      icon: _icon,
      start: safeStart,
      end: _end,
      startDate: _date,
      isImportant: _important,
    );
    Navigator.of(context).pop(task);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end,
    );
    if (picked != null) {
      setState(() => _end = picked);
    }
  }
}

class _AddHabitSheet extends StatefulWidget {
  const _AddHabitSheet({this.initialHabit, this.expand = false});

  final Habit? initialHabit;
  final bool expand;

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _nameCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  late Set<int> _selectedDays;
  int _timesPerDay = 1;
  late Color _selectedColor;
  late IconData _selectedIcon;
  late List<int> _completionCounts;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final h = widget.initialHabit;
    _nameCtrl.text = h?.name ?? '';
    _captionCtrl.text = h?.caption ?? '';
    _selectedDays = Set<int>.from(h?.recurrenceDays ?? const [1, 3, 5]);
    _timesPerDay = h?.timesPerDay ?? 1;
    _selectedColor = h?.color ?? const Color(0xFF7EE6A1);
    _selectedIcon = h?.icon ?? Icons.self_improvement;
    _completionCounts = List<int>.from(h?.completionCounts ?? List<int>.filled(365, 0));
    if (_completionCounts.length < 365) {
      _completionCounts = [
        ..._completionCounts,
        ...List<int>.filled(365 - _completionCounts.length, 0),
      ];
    } else if (_completionCounts.length > 365) {
      _completionCounts = _completionCounts.take(365).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialHabit != null;
    const initialSize = 0.8;
    const minSize = 0.8;
    const maxSize = 0.9;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + viewInsets),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit habit' : 'Add habit',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Name',
                controller: _nameCtrl,
                hint: 'e.g., Daily walk',
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Caption',
                controller: _captionCtrl,
                hint: 'e.g., 20 minutes outside',
              ),
              const SizedBox(height: 16),
              Text(
                'Repeat on',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  const dayOrder = [7, 1, 2, 3, 4, 5, 6]; // start on Sunday
                  const labelMap = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};
                  final day = dayOrder[i];
                  final selected = _selectedDays.contains(day);
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(labelMap[day]!),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedDays.remove(day);
                        } else {
                          _selectedDays.add(day);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                Text(
                  'Times per day',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: _timesPerDay,
                  dropdownColor: Theme.of(context).dialogBackgroundColor,
                  items: [1, 2, 3, 4]
                      .map((n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text('$n',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _timesPerDay = v ?? 1;
                  }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Icon',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions
                    .map(
                      (icon) => ChoiceChip(
                        label: Icon(icon,
                            size: 18, color: Theme.of(context).colorScheme.onSurface),
                        selected: _selectedIcon == icon,
                        onSelected: (_) => setState(() => _selectedIcon = icon),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Color',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kColorOptions
                    .map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7AFE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  isEditing ? 'Save changes' : 'Add habit',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      return;
    }
    final habit = Habit(
      id: widget.initialHabit?.id,
      name: _nameCtrl.text.trim(),
      caption: _captionCtrl.text.trim(),
      color: _selectedColor,
      icon: _selectedIcon,
      completions: List<bool>.filled(42, false),
      completionCounts: _completionCounts,
      recurrenceDays: _selectedDays.toList(),
      timesPerDay: _timesPerDay,
    );
    Navigator.of(context).pop(habit);
  }
}

class _SegmentedNavBar extends StatelessWidget {
  const _SegmentedNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addBlue = theme.colorScheme.primary;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 75 + bottomInset,
      padding: EdgeInsets.fromLTRB(10, 8, 10, 15 + bottomInset),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          _SegmentItem(
            icon: Icons.timeline,
            label: '',
            selected: index == 0,
            onTap: () => onChanged(0),
            primary: addBlue,
          ),
          _SegmentItem(
            icon: Icons.local_fire_department_rounded,
            label: '🔥',
            selected: index == 1,
            onTap: () => onChanged(1),
            primary: addBlue,
          ),
          _SegmentItem(
            icon: Icons.track_changes,
            label: '🎯',
            selected: index == 2,
            onTap: () => onChanged(2),
            primary: addBlue,
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: double.infinity,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: radius,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: selected ? 34 : 26,
                  color: selected
                      ? primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProjectSheet extends StatefulWidget {
  @override
  State<_AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends State<_AddProjectSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Color _projectColor = const Color(0xFF7AE1FF);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.8,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + viewInsets),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add project',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Name',
                controller: _nameCtrl,
                hint: 'e.g., Launch v1',
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Description',
                controller: _descCtrl,
                hint: 'Short summary',
              ),
              const SizedBox(height: 12),
              Text(
                'Color',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kColorOptions
                    .map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => _projectColor = color),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _projectColor == color
                                  ? Theme.of(context).dialogBackgroundColor
                                  : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7AFE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: const Text('Add project'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      return;
    }
    final project = Project(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      progress: 0.0,
      color: _projectColor,
      weeklyBurndown: const [6, 5, 4, 3, 2, 1, 0],
    );
    Navigator.of(context).pop(project);
  }
}

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _nameCtrl = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  Color _goalColor = const Color(0xFF61E294);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.8,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + viewInsets),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add goal',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Name',
                controller: _nameCtrl,
                hint: 'e.g., Ship v1',
              ),
              const SizedBox(height: 12),
              _PickerButton(
                label: 'Deadline',
                value: '${_deadline.month}/${_deadline.day}/${_deadline.year}',
                onTap: _pickDeadline,
              ),
              const SizedBox(height: 12),
              Text(
                'Color',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kColorOptions
                    .map(
                      (color) => GestureDetector(
                        onTap: () => setState(() => _goalColor = color),
                        child: Container(
                          padding: _goalColor == color ? const EdgeInsets.all(3) : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: _goalColor == color
                                ? Theme.of(context).dialogBackgroundColor
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7AFE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: const Text('Add goal'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      return;
    }
    final goal = Goal(
      name: _nameCtrl.text.trim(),
      stat: '',
      progress: 0.0,
      timeframe: 'Due ${_deadline.month}/${_deadline.day}/${_deadline.year}',
      color: _goalColor,
      deadline: _deadline,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pop(goal);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }
}
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


const _iconOptions = <IconData>[
  Icons.self_improvement,
  Icons.fitness_center,
  Icons.restaurant,
  Icons.menu_book,
  //Icons.music_note,
  //Icons.timer,
  //Icons.nightlight_round,
  //Icons.spa,
  //Icons.directions_run,
  //Icons.local_florist,
  //Icons.water_drop,
  //Icons.piano,
  //Icons.pets,
  //Icons.brush,
  //Icons.bookmark_added,
  //Icons.emoji_nature,
  //Icons.emoji_people,
];

const _taskIconOptions = <IconData>[
  Icons.event,
  Icons.work,
  Icons.school,
  Icons.fitness_center,
  Icons.timer,
  Icons.star,
  //Icons.book,
  //Icons.alarm,
  //Icons.laptop_mac,
  //Icons.restaurant,
  //Icons.flight_takeoff,
  //Icons.meeting_room,
  //Icons.directions_run,
  //Icons.music_note,
  //Icons.brush,
  //Icons.shopping_bag,
  //Icons.nightlight_round,
  //Icons.self_improvement,
  //Icons.edit_calendar,
];
