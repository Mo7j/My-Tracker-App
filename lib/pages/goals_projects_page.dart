import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models.dart';
import '../pages/goal_detail_page.dart';
import '../pages/project_detail_page.dart';
import '../services/firestore_service.dart';

class GoalsProjectsPage extends StatelessWidget {
  const GoalsProjectsPage({
    super.key,
    required this.projects,
    required this.goals,
    required this.firestore,
    required this.onRefresh,
  });

  final List<Project> projects;
  final List<Goal> goals;
  final FirestoreService firestore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        Text(
          'Goals & Projects',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Track project tasks and goal milestones.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black.withOpacity(0.7)),
        ),
        const SizedBox(height: 20),
        ...projects.map(
          (project) => _ProjectCard(
            project: project,
            firestore: firestore,
            onTap: project.id == null
                ? null
                : () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                      builder: (_) => ProjectDetailPage(
                        project: project,
                        firestore: firestore,
                      ),
                    ))
                        .then((value) {
                      if (value == true) onRefresh();
                    });
                  },
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            return _GoalCard(
              goal: goal,
              firestore: firestore,
              onTap: goal.id == null
                  ? null
                  : () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                        builder: (_) => GoalDetailPage(
                          goal: goal,
                          firestore: firestore,
                        ),
                      ))
                          .then((value) {
                        if (value == true) onRefresh();
                      });
                    },
            );
          },
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.firestore, this.onTap});

  final Project project;
  final FirestoreService firestore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<List<Task>>(
              stream: project.id != null
                  ? firestore.streamProjectTasks(project.id!)
                  : const Stream.empty(),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? const <Task>[];
                final progress = tasks.isEmpty
                    ? project.progress
                    : tasks.where((t) => t.isDone).length / tasks.length;
                return _WavyProgressBar(
                  progress: progress,
                  color: project.color,
                  label: '${(progress * 100).round()}%',
                  title: project.name,
                  subtitle: project.description,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.firestore, this.onTap});

  final Goal goal;
  final FirestoreService firestore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ringSize = (constraints.maxWidth * 0.8).clamp(140.0, 200.0);
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                StreamBuilder<List<Task>>(
                  stream: goal.id != null
                      ? firestore.streamGoalTasks(goal.id!)
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    final tasks = snapshot.data ?? const <Task>[];
                    final progress = tasks.isEmpty
                        ? goal.progress
                        : tasks.where((t) => t.isDone).length / tasks.length;
                    final remainingLabel = _remainingLabel(goal);
                    return GoalProgressRing(
                      progress: progress,
                      color: goal.color,
                      size: ringSize,
                      label: goal.name,
                      remainingText: remainingLabel,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _remainingLabel(Goal goal) {
    final deadline = goal.deadline;
    if (deadline == null) return 'No deadline';
    final days = deadline.difference(DateTime.now()).inDays;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }
}

class GoalProgressRing extends StatelessWidget {
  const GoalProgressRing({
    required this.progress,
    required this.color,
    required this.size,
    required this.label,
    required this.remainingText,
  });

  final double progress;
  final Color color;
  final double size;
  final String label;
  final String remainingText;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100);
    final percentText = pct.toStringAsFixed(0);
    final strokeWidth = (size * 0.055).clamp(6.0, 12.0);
    final percentFont = (size * 0.26).clamp(32.0, 52.0);
    final percentSymbolFont = (size * 0.1).clamp(16.0, 22.0);
    final remainingFont = (size * 0.09).clamp(12.0, 16.0);
    final labelFont = (size * 0.085).clamp(12.0, 14.0);
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: GoalRingPainter(
              progress: progress.clamp(0.0, 1.0),
              color: color,
              strokeWidth: strokeWidth,
              ringSize: size,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [

                  Text(
                    percentText,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: percentFont,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                  ),

                  const SizedBox(width: 4),
                  Text(
                    '%',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white60
                                : Colors.black54,
                            fontWeight: FontWeight.w500,
                            fontSize: percentSymbolFont),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                remainingText,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white60
                            : Colors.black54,
                        fontWeight: FontWeight.w500,
                        fontSize: remainingFont),
              ),
            ],
          ),
          Positioned(
            bottom: 4,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: labelFont),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalRingPainter extends CustomPainter {
  GoalRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.ringSize,
    required this.isDark,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final double ringSize;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    const threshold = 0.8;
    final gapAngle = (ringSize < 170 ? 0.7 : 0.5) * math.pi; // larger cut on phones
    final usableSweep = 2 * math.pi - gapAngle;

    // Gap centered at bottom so the label fits there.
    final startAngle = math.pi / 2 + gapAngle / 2;
    final sweep = usableSweep * p;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.2);
    canvas.drawArc(rect, startAngle, usableSweep, false, trackPaint);

    if (p <= 0) return;

    final headFrac = ((usableSweep * threshold) / (2 * math.pi)).clamp(0.0, 1.0);

    final bodyShader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + 2 * math.pi, // full definition
      tileMode: TileMode.clamp,
      colors: [
        color.withOpacity(0.35),
        color.withOpacity(0.40),
        color.withOpacity(0.65),
        color.withOpacity(1.0),
        color.withOpacity(1.0),
      ],
      stops: [
        0.0,
        (headFrac * 0.55).clamp(0.0, 1.0),
        (headFrac * 0.85).clamp(0.0, 1.0),
        headFrac,
        1.0,
      ],
    ).createShader(rect);


    final bodyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = bodyShader;
    final gradSweep = usableSweep * math.min(p, threshold);
    final bodyGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = bodyShader
        ..color = Colors.white.withOpacity(1.0) // no extra tint; shader stays
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.45);

    canvas.drawArc(rect, startAngle, gradSweep, false, bodyGlowPaint);
    canvas.drawArc(rect, startAngle, gradSweep, false, bodyPaint);

    // Head glow + dot
    final center = Offset(size.width / 2, size.height / 2);
    final radius = rect.width / 2;
    final headAngle = startAngle + sweep;
    final headPos =
        center + Offset(math.cos(headAngle), math.sin(headAngle)) * radius;

    final headGlowPaint = Paint()
      ..color = color.withOpacity(0.65)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.2);
    canvas.drawCircle(headPos, strokeWidth * 1.10, headGlowPaint); // a bit larger


    final dotPaint = Paint()..color = color.withOpacity(0.95);
    canvas.drawCircle(headPos, strokeWidth * 0.7, dotPaint); // bigger head


    if (p > threshold) {
  final extraSweep = usableSweep * (p - threshold);

  final solidStart = startAngle + sweep - extraSweep;

  final solidPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.butt // straight start
    ..color = color.withOpacity(1.0);

  canvas.drawArc(rect, solidStart, extraSweep, false, solidPaint);
}
  }

  @override
  bool shouldRepaint(covariant GoalRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.ringSize != ringSize ||
        oldDelegate.isDark != isDark;
  }
}






class _WavyProgressBar extends StatefulWidget {
  const _WavyProgressBar({
    required this.progress,
    required this.color,
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final double progress;
  final Color color;
  final String label;
  final String title;
  final String subtitle;

  @override
  State<_WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<_WavyProgressBar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _phase = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed - _lastElapsed).inMilliseconds;
      _lastElapsed = elapsed;
      _phase += dt / 600; // speed factor
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
    final pct = widget.progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.transparent),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  size: Size(width, 64),
                  painter: _WavePainter(
                    pct: pct,
                    color: widget.color,
                    phase: _phase,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.title,
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
                              widget.subtitle,
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
                        widget.label,
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
