import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart';
import 'package:lottie/lottie.dart';

import '../models.dart';
import '../services/firestore_service.dart';
import '../shared_colors.dart';
import '../utils.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.project,
    required this.firestore,
  });

  final Project project;
  final FirestoreService firestore;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {

  late Project _current;
  late final Ticker _ticker;
  double _phase = 0;
  Duration _lastElapsed = Duration.zero;
  bool _changed = false;
  List<Task> _tasks = const [];
  bool _backSwiping = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.project;
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed - _lastElapsed).inMilliseconds;
      _lastElapsed = elapsed;
      _phase += dt / 600;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = _current;
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed ? true : null);
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (_backSwiping) return;
          if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
            Navigator.pop(context, _changed ? true : null);
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        onHorizontalDragUpdate: (details) {
          if (_backSwiping) return;
          _dragOffset = (_dragOffset + details.delta.dx).clamp(0, 120).toDouble();
          if (_dragOffset > 90) {
            _backSwiping = true;
            Navigator.pop(context, _changed ? true : null);
            return;
          }
          setState(() {});
        },
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          offset: Offset(_dragOffset / 600, 0),
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
                    child: _PulsedLottie(
                      asset: 'assets/lottie/Back.json',
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              title: const Text('Tasks'),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: InkWell(
                    onTap: () => _deleteProject(project),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Lottie.asset(
                        'assets/lottie/Delete.json',
                        height: 40,
                        width: 40,
                        repeat: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: StreamBuilder<List<Task>>(
            stream: project.id != null
                ? widget.firestore.streamProjectTasks(project.id!)
                : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                _tasks = snapshot.data!;
              }
              final tasks = _tasks;
              final done = tasks.where((t) => t.isDone).length;
              final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GestureDetector(
                    onTap: () => _editProject(project),
                    child: _WavyHeaderBar(
                      progress: progress,
                      color: project.color,
                      title: project.name,
                      subtitle: project.description,
                      phase: _phase,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(height: 8),
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
                                lottieAsset: 'assets/lottie/Delete.json',
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
                                  if (task.id != null && project.id != null) {
                                    await widget.firestore.deleteProjectTask(
                                        project.id!, task.id!);
                                    _changed = true;
                                  }
                                  return true;
                                } else if (direction ==
                                    DismissDirection.endToStart) {
                                  await _editProjectTask(project.id!, task);
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
                                            .withOpacity(0.6),
                                  ),
                                  title: Text(
                                    task.title,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  subtitle: Text(
                                    task.subtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                  ),
                                  onTap: () => _toggleTaskDone(task),
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
            child: _PulsedLottie(
              asset: 'assets/lottie/Plus.json',
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _toggleTaskDone(Task task) async {
    if (task.id == null || _current.id == null) return;
    final previous = List<Task>.from(_tasks);
    final updated = _tasks
        .map((t) => t.id == task.id ? _copyTask(t, isDone: !t.isDone) : t)
        .toList();
    setState(() {
      _tasks = updated;
    });
    try {
      await widget.firestore
          .updateProjectTaskDone(_current.id!, task.id!, !task.isDone);
    } catch (_) {
      setState(() {
        _tasks = previous;
      });
      if (mounted) {
        }
    }
  }

  Task _copyTask(Task task, {required bool isDone}) {
    return Task(
      id: task.id,
      habitId: task.habitId,
      title: task.title,
      subtitle: task.subtitle,
      category: task.category,
      color: task.color,
      icon: task.icon,
      isHabit: task.isHabit,
      isDone: isDone,
      isImportant: task.isImportant,
      startDate: task.startDate,
      start: task.start,
      end: task.end,
    );
  }

  // ---------- Dialogs / Sheets ----------

  Future<void> _showAddTask() async {
    final project = _current;
    final task = await showDialog<Task>(
      context: context,
      builder: (context) {
        final titleCtrl = TextEditingController();
        final subtitleCtrl = TextEditingController();

        return AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Add project task'),
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
                    category: 'Project',
                    color: project.color,
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
      await widget.firestore.addProjectTask(project.id!, task);
    }
  }

  Future<void> _editProject(Project project) async {
    final updated = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.6,
        child: _EditProjectSheet(project: project),
      ),
    );

    if (updated != null) {
      final previous = _current;
      if (mounted) {
        setState(() {
          _current = updated;
          _changed = true;
        });
      }
      try {
        await widget.firestore.updateProject(updated);
      } catch (_) {
        if (mounted) {
          setState(() {
            _current = previous;
          });
          }
      }
    }
  }

  Future<void> _deleteProject(Project project) async {
    if (project.id == null) return;

    await widget.firestore.deleteProject(project.id!);
    _changed = true;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _editProjectTask(String projectId, Task task) async {
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
              foregroundColor: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null) {
      await widget.firestore.updateProjectTask(projectId, updated);
      _changed = true;
    }
  }
}

class _EditProjectSheet extends StatefulWidget {
  const _EditProjectSheet({required this.project});
  final Project project;

  @override
  State<_EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<_EditProjectSheet> {
  static const _colorOptions = <Color>[
    Color(0xFFEFDF48),
    Color(0xFFE87F21),
    Color(0xFFD03E40),
    Color(0xFFCD327D),
    Color(0xFF6327E1),
    Color(0xFF2263E3),
    Color(0xFF27B4E0),
    Color(0xFF27E086),
    Color(0xFF129520),
    Color(0xFF646464),
  ];
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late Color _selected;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _descCtrl = TextEditingController(text: widget.project.description);
    _selected = widget.project.color;
  }

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
      initialChildSize: 0.7,
      minChildSize: 0.7,
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
                'Edit project',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              Text(
                'Color',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              _ColorPicker(
                colors: _colorOptions,
                selected: _selected,
                backgroundColor: Theme.of(context).dialogBackgroundColor,
                onPick: (c) => setState(() => _selected = c),
              ),
              const SizedBox(height: 20),
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
                child: const Text(
                  'Save changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    Navigator.pop(
      context,
      Project(
        id: widget.project.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        progress: widget.project.progress,
        color: _selected,
        weeklyBurndown: widget.project.weeklyBurndown,
      ),
    );
  }
}

class _PulsedLottie extends StatefulWidget {
  const _PulsedLottie({
    required this.asset,
    this.size = 40,
    this.color,
  });

  final String asset;
  final double size;
  final Color? color;

  @override
  State<_PulsedLottie> createState() => _PulsedLottieState();
}

class _PulsedLottieState extends State<_PulsedLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 2), _play);
      }
    });
  }

  void _play() {
    if (_duration == Duration.zero) return;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Lottie.asset(
      widget.asset,
      controller: _ctrl,
      repeat: false,
      animate: false,
      onLoaded: (comp) {
        _duration = comp.duration;
        _ctrl.duration = comp.duration;
        _play();
      },
      height: widget.size,
      width: widget.size,
    );
    return widget.color != null
        ? ColorFiltered(
            colorFilter: ColorFilter.mode(widget.color!, BlendMode.srcIn),
            child: child,
          )
        : child;
  }
}

// ---------- Shared small widgets ----------

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
    this.icon,
    this.lottieAsset,
    required this.alignment,
  });

  final Color color;
  final IconData? icon;
  final String? lottieAsset;
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
        child: lottieAsset != null
            ? Lottie.asset(
                lottieAsset!,
                height: 42,
                width: 42,
                repeat: true,
              )
            : Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class _WavyHeaderBar extends StatelessWidget {
  const _WavyHeaderBar({
    required this.progress,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.phase,
  });

  final double progress;
  final Color color;
  final String title;
  final String subtitle;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0.0, 1.0);
                    return SizedBox(
      height: 72,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  size: Size(width, 72),
                  painter: _WavePainter(
                    pct: pct,
                    color: color,
                    phase: phase,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(pct * 100).round()}%',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.pct, required this.color, required this.phase});

  final double pct;
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final fillWidth = size.width * pct;
    final paint = Paint()..color = color.withOpacity(0.7);
    final path = Path();
    final right = fillWidth.clamp(0.0, size.width);
    const waveWidth = 18.0;
    const amp = 6.0;
    const segments = 12;
    final baseX = (right - waveWidth).clamp(0.0, size.width);

    path.moveTo(0, 0);
    path.lineTo(baseX, 0);

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final y = t * size.height;
      final offset = amp * math.sin(phase * 3 + t * 2 * math.pi);
      final x = (baseX + offset).clamp(0.0, size.width);
      path.lineTo(x, y);
    }

    path.lineTo(baseX, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
    canvas.drawPath(path, paint);

    final topPath = Path();
    const topWaveWidth = 32.0;
    const topAmp = 6.0;
    const segmentsTop = 12;
    final topBaseX = (right - topWaveWidth + 22).clamp(0.0, size.width);
    topPath.moveTo(0, 0);
    topPath.lineTo(topBaseX, 0);
    for (int i = 0; i <= segmentsTop; i++) {
      final t = i / segmentsTop;
      final y = t * size.height;
      final offset = topAmp * math.sin(phase * 4.5 + t * 2 * math.pi + math.pi);
      final x = (topBaseX + offset).clamp(0.0, size.width);
      topPath.lineTo(x, y);
    }
    topPath.lineTo(topBaseX, size.height);
    topPath.lineTo(0, size.height);
    topPath.close();
    canvas.drawPath(topPath, Paint()..color = color.withOpacity(0.12));
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.pct != pct ||
        oldDelegate.color != color ||
        oldDelegate.phase != phase;
  }
}
