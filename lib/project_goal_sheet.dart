import 'package:flutter/material.dart';

import 'models.dart';
import 'project_goal_result.dart';
import 'shared_colors.dart';

class ProjectGoalSheet extends StatefulWidget {
  const ProjectGoalSheet({super.key});

  @override
  State<ProjectGoalSheet> createState() => ProjectGoalSheetState();
}

class ProjectGoalSheetState extends State<ProjectGoalSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  Color _selectedColor = const Color(0xFF7AE1FF);
  String _type = 'project'; // or 'goal'

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.dialogBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + viewInsets),
      child: ListView(
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add ${_type == 'project' ? 'project' : 'goal'}',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'project', child: Text('Project')),
              DropdownMenuItem(value: 'goal', child: Text('Goal')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() => _type = val);
            },
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Title',
            controller: _titleCtrl,
            hint: 'e.g., Launch v1',
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Description',
            controller: _descCtrl,
            hint: 'Short summary',
          ),
          if (_type == 'goal') ...[
            const SizedBox(height: 12),
            _PickerButton(
              label: 'Deadline',
              value: '${_deadline.month}/${_deadline.day}/${_deadline.year}',
              onTap: _pickDeadline,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Color',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w700),
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
                      padding: _selectedColor == color ? const EdgeInsets.all(3) : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: _selectedColor == color ? theme.dialogBackgroundColor : Colors.transparent,
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
          const SizedBox(height: 14),
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
              _type == 'project' ? 'Add project' : 'Add goal',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      return;
    }
    if (_type == 'project') {
      final project = Project(
        id: null,
        name: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        progress: 0.0,
        color: _selectedColor,
        weeklyBurndown: List<double>.filled(7, 0.0),
      );
      Navigator.of(context).pop(ProjectGoalResult(project: project));
    } else {
      final goal = Goal(
        id: null,
        name: _titleCtrl.text.trim(),
        stat: '',
        progress: 0.0,
        timeframe: 'Due ${_deadline.month}/${_deadline.day}/${_deadline.year}',
        color: _selectedColor,
        deadline: _deadline,
        createdAt: DateTime.now(),
      );
      Navigator.of(context).pop(ProjectGoalResult(goal: goal));
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
