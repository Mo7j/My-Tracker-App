import 'package:flutter/material.dart';

import '../models.dart';
import '../services/firestore_service.dart';

class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({
    super.key,
    required this.goal,
    required this.firestore,
  });

  final Goal goal;
  final FirestoreService firestore;

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  static const _colorOptions = [
    Color(0xFF7EE6A1),
    Color(0xFFB784FF),
    Color(0xFFFF9F6E),
    Color(0xFFE7E167),
    Color(0xFF7AE1FF),
    Color(0xFFFF7A8A),
    Color(0xFF61E294),
    Color(0xFF3A7AFE),
    Color(0xFFEF5350),
    Color(0xFF26C6DA),
    Color(0xFF42A5F5),
    Color(0xFFFFB74D),
    Color(0xFF8D6E63),
    Color(0xFFFFC107),
    Color(0xFFA1887F),
    Color(0xFF9C27B0),
    Color(0xFF00BFA5),
    Color(0xFF607D8B),
    Color(0xFFCE93D8),
    Color(0xFF80CBC4),
    Color(0xFFD4E157),
  ];

  late Goal _current;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _current = widget.goal;
  }

  @override
  Widget build(BuildContext context) {
    final goal = _current;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed ? true : null);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          actionsIconTheme: const IconThemeData(size: 22),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 12),
          toolbarHeight: 72,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 14),
            child: InkWell(
              onTap: () => Navigator.pop(context, _changed ? true : null),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF3A7AFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 26, color: Colors.white),
              ),
            ),
          ),
          title: const Text('Tasks'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: InkWell(
                onTap: () => _editGoal(goal),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B7280),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit, size: 20, color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: InkWell(
                onTap: () => _deleteGoal(goal),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.delete, size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        body: StreamBuilder<List<Task>>(
          stream: goal.id != null
              ? widget.firestore.streamGoalTasks(goal.id!)
              : const Stream.empty(),
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? [];
            final done = tasks.where((t) => t.isDone).length;
            final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (goal.stat.isNotEmpty)
                  Text(
                    goal.stat,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7)),
                  ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    valueColor: AlwaysStoppedAnimation(goal.color),
                    backgroundColor: Theme.of(context).brightness ==
                            Brightness.dark
                        ? Colors.white10
                        : Colors.black12,
                  ),
                ),
                const SizedBox(height: 18),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No tasks yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7)),
                    ),
                  )
                else
                  ...tasks.map((task) {
                    DismissDirection? swipeDir;
                    return StatefulBuilder(
                      builder: (ctx, setInner) {
                        BorderRadius radius;
                        if (swipeDir == DismissDirection.startToEnd) {
                          radius = const BorderRadius.only(
                            topLeft: Radius.circular(0),
                            bottomLeft: Radius.circular(0),
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          );
                        } else if (swipeDir == DismissDirection.endToStart) {
                          radius = const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                            topRight: Radius.circular(0),
                            bottomRight: Radius.circular(0),
                          );
                        } else {
                          radius = BorderRadius.circular(12);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Dismissible(
                            key: ValueKey(task.id ?? task.title),
                            background: _SwipeBackground(
                              color: Colors.redAccent,
                              icon: Icons.delete,
                              alignment: Alignment.centerLeft,
                            ),
                            secondaryBackground: _SwipeBackground(
                              color: Colors.blueAccent,
                              icon: Icons.edit,
                              alignment: Alignment.centerRight,
                            ),
                            onUpdate: (details) {
                              final dir = details.direction ==
                                      DismissDirection.none
                                  ? null
                                  : details.direction;
                              if (dir != swipeDir) setInner(() => swipeDir = dir);
                            },
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                if (task.id != null && goal.id != null) {
                                  await widget.firestore
                                      .deleteGoalTask(goal.id!, task.id!);
                                  _changed = true;
                                }
                                return true;
                              } else if (direction ==
                                  DismissDirection.endToStart) {
                                await _editGoalTask(goal.id!, task);
                                return false;
                              }
                              return false;
                            },
                            child: Card(
                              color: Theme.of(context).cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: radius,
                              ),
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                leading: Icon(
                                  task.isDone
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: task.isDone
                                      ? const Color(0xFF61E294)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                ),
                                title: Text(task.title),
                                subtitle: Text(task.subtitle),
                                onTap: () async {
                                  await widget.firestore.updateGoalTaskDone(
                                    goal.id!,
                                    task.id!,
                                    !task.isDone,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddTask,
          child: const Icon(Icons.add, size: 30),
        ),
      ),
    );
  }

  Future<void> _showAddTask() async {
    final goal = _current;
    final task = await showDialog<Task>(
      context: context,
      builder: (context) {
        final titleCtrl = TextEditingController();
        final subtitleCtrl = TextEditingController();

        return AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Add goal task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: subtitleCtrl,
                  decoration: const InputDecoration(labelText: 'Details'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  Task(
                    title: titleCtrl.text.trim(),
                    subtitle: subtitleCtrl.text.trim(),
                    category: 'Goal',
                    color: goal.color,
                    icon: Icons.check_circle,
                    start: const TimeOfDay(hour: 9, minute: 0),
                    end: const TimeOfDay(hour: 10, minute: 0),
                    isDone: false,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A7AFE),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (task != null) {
      await widget.firestore.addGoalTask(_current.id!, task);
    }
  }

  Future<void> _editGoal(Goal goal) async {
    final nameCtrl = TextEditingController(text: goal.name);
    DateTime? selectedDeadline = goal.deadline;

    final updated = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).dialogBackgroundColor, // follows theme
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
        Color selected = goal.color;

        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final handleColor =
                Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white24
                    : Colors.black26;

            Future<void> pickDate() async {
              final now = DateTime.now();
              final base = selectedDeadline ?? now;
              final picked = await showDatePicker(
                context: ctx,
                initialDate: base,
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) {
                setLocalState(() => selectedDeadline = picked);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, viewInsets + 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle (visible in light & dark)
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Text(
                            'Edit goal',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedDeadline == null
                                      ? 'No due date'
                                      : 'Due: ${selectedDeadline!.month}/${selectedDeadline!.day}/${selectedDeadline!.year}',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7)),
                                ),
                              ),
                              TextButton(
                                onPressed: pickDate,
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(ctx)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                child: const Text('Change date'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Color picker (NO animation, cutout border, matches background)
                          _ColorPicker(
                            colors: _colorOptions,
                            selected: selected,
                            backgroundColor:
                                Theme.of(ctx).dialogBackgroundColor,
                            onPick: (c) => setLocalState(() => selected = c),
                          ),

                          const SizedBox(height: 14),
                        ],
                      ),
                    ),

                    // Bottom button always at bottom
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A7AFE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(
                            ctx,
                            Goal(
                              id: goal.id,
                              name: nameCtrl.text.trim().isEmpty
                                  ? goal.name
                                  : nameCtrl.text.trim(),
                              stat: goal.stat,
                              progress: goal.progress,
                              timeframe: goal.timeframe,
                              color: selected,
                              deadline: selectedDeadline,
                              createdAt: goal.createdAt,
                            ),
                          );
                        },
                        child: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updated != null) {
      await widget.firestore.updateGoal(updated);
      if (mounted) {
        setState(() {
          _current = updated;
          _changed = true;
        });
      }
    }
  }

  Future<void> _deleteGoal(Goal goal) async {
    if (goal.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).dialogBackgroundColor,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Delete goal?'),
        content: Text('Remove "${goal.name}" and its tasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.firestore.deleteGoal(goal.id!);
      _changed = true;
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _editGoalTask(String goalId, Task task) async {
    final titleCtrl = TextEditingController(text: task.title);
    final subtitleCtrl = TextEditingController(text: task.subtitle);

    final updated = await showDialog<Task>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).dialogBackgroundColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Edit task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: subtitleCtrl,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                Task(
                  id: task.id,
                  habitId: task.habitId,
                  title: titleCtrl.text.trim(),
                  subtitle: subtitleCtrl.text.trim(),
                  start: task.start,
                  end: task.end,
                  category: task.category,
                  color: task.color,
                  icon: task.icon,
                  isHabit: task.isHabit,
                  isDone: task.isDone,
                  isImportant: task.isImportant,
                  startDate: task.startDate,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A7AFE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) {
      await widget.firestore.updateGoalTask(goalId, updated);
      _changed = true;
    }
  }
}

// ---------- Shared widgets ----------

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.backgroundColor,
    required this.onPick,
  });

  final List<Color> colors;
  final Color selected;
  final Color backgroundColor;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onPick(c),
          child: Container(
            padding: isSelected ? const EdgeInsets.all(3) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isSelected ? backgroundColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: isLeft ? const Radius.circular(12) : const Radius.circular(8),
      bottomLeft: isLeft ? const Radius.circular(12) : const Radius.circular(8),
      topRight: isLeft ? const Radius.circular(8) : const Radius.circular(12),
      bottomRight: isLeft ? const Radius.circular(8) : const Radius.circular(12),
    );
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
