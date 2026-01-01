import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../services/firestore_service.dart';
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

class _ProjectDetailPageState extends State<ProjectDetailPage> with SingleTickerProviderStateMixin {
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
  late Project _current;
  late final Ticker _ticker;
  double _phase = 0;
  Duration _lastElapsed = Duration.zero;
  bool _changed = false;

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
                child: const Icon(Icons.arrow_back_ios_new, size: 26, color: Colors.white),
              ),
            ),
          ),
          title: const Text('Tasks'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: InkWell(
                onTap: () => _editProject(project),
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
                onTap: () => _deleteProject(project),
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
          stream: project.id != null
              ? widget.firestore.streamProjectTasks(project.id!)
              : const Stream.empty(),
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? [];
            final done = tasks.where((t) => t.isDone).length;
            final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _WavyHeaderBar(
                  progress: progress,
                  color: project.color,
                  title: project.name,
                  subtitle: project.description,
                  phase: _phase,
                ),
                const SizedBox(height: 18),
                const SizedBox(height: 8),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No tasks yet',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
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
                              final dir = details.direction == DismissDirection.none
                                  ? null
                                  : details.direction;
                              if (dir != swipeDir) setInner(() => swipeDir = dir);
                            },
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                if (task.id != null && project.id != null) {
                                  await widget.firestore
                                      .deleteProjectTask(project.id!, task.id!);
                                  _changed = true;
                                }
                                return true;
                              } else if (direction == DismissDirection.endToStart) {
                                await _editProjectTask(project.id!, task);
                                return false;
                              }
                              return false;
                            },
                            child: Card(
                              color: const Color(0xFF181C24),
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
                                  color:
                                      task.isDone ? const Color(0xFF61E294) : Colors.white70,
                                ),
                                title: Text(task.title),
                                subtitle: Text(task.subtitle),
                                onTap: () async {
                                  await widget.firestore.updateProjectTaskDone(
                                    project.id!,
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
    final project = _current;
    final task = await showDialog<Task>(
      context: context,
      builder: (context) {
        final titleCtrl = TextEditingController();
        final subtitleCtrl = TextEditingController();
        final primaryStyle = ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A7AFE),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
        final cancelStyle = TextButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        );
        return AlertDialog(
          backgroundColor: const Color(0xFF121620),
          title: const Text('Add project task'),
          content: Column(
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: cancelStyle,
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
              style: primaryStyle,
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
    final nameCtrl = TextEditingController(text: project.name);
    final descCtrl = TextEditingController(text: project.description);
    Color selected = project.color;
    final updated = await showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
        void setLocal(Color c) {
          selected = c;
          setState(() {});
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsets + 12),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Edit project',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              Text(
                'Color',
                style: Theme.of(ctx)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setLocal(c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected == c ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A7AFE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    Project(
                      id: project.id,
                      name: nameCtrl.text.trim().isEmpty ? project.name : nameCtrl.text.trim(),
                      description:
                          descCtrl.text.trim().isEmpty ? project.description : descCtrl.text.trim(),
                      progress: project.progress,
                      color: selected,
                      weeklyBurndown: project.weeklyBurndown,
                    ),
                  );
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        );
      },
    );
    if (updated != null) {
      if (mounted) {
        setState(() {
          _current = updated;
          _changed = true;
        });
      }
      await widget.firestore.updateProject(updated);
    }
  }

  Future<void> _deleteProject(Project project) async {
    if (project.id == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF121620),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete project', style: TextStyle(color: Colors.redAccent)),
              subtitle: Text('Remove "${project.name}" and its tasks?'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white70),
              title: const Text('Cancel', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await widget.firestore.deleteProject(project.id!);
      _changed = true;
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _editProjectTask(String projectId, Task task) async {
    final titleCtrl = TextEditingController(text: task.title);
    final subtitleCtrl = TextEditingController(text: task.subtitle);
    final updated = await showDialog<Task>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121620),
        title: const Text('Edit task'),
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
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
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(pct * 100).round()}%',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
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
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
    canvas.drawPath(path, paint);

    // Lighter overlay wave
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
    return oldDelegate.pct != pct || oldDelegate.color != color || oldDelegate.phase != phase;
  }
}
