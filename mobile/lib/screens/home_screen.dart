import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';
import 'tab_shell.dart';
import 'task_selection_screen.dart';
import 'app_header.dart';

/// Home tab — shows the user's selected tasks (GET /tasks/selection).
///
/// States: loading → error-with-retry → empty → populated
class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  State<HomeTabScreen> createState() => HomeTabScreenState();
}

class HomeTabScreenState extends State<HomeTabScreen> {
  List<SelectedTask> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void refresh() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final service = TaskService(appState.apiClient);
      final tasks = await service.getSelection();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your services. Check your connection.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Icon-only header; avatar switches to Profile tab via TabShell
      appBar: buildAppHeader(
        extraActions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    if (_tasks.isEmpty) {
      // "Explore →" switches to the Request tab (stays inside TabShell)
      return _EmptyState(
        onExplore: () => TabShell.of(context).switchTab(1),
      );
    }

    return _TaskList(
      tasks: _tasks,
      onEditTask: _openEditSheet,
    );
  }

  /// Opens a bottom sheet to edit or remove a single task.
  void _openEditSheet(SelectedTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => _EditTaskBottomSheet(
        task: task,
        onSuccess: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<SelectedTask> tasks;
  final void Function(SelectedTask) onEditTask;

  const _TaskList({required this.tasks, required this.onEditTask});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // ── "Your Active Services" header row ───────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Your Active Services',
                    style: TextStyle(
                      color: AppColors.badgeText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '${tasks.length} Task${tasks.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Section label ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Selected Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _todayLabel(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Task cards ───────────────────────────────────────────────────────
        ...tasks.map((t) => _TaskCard(task: t, onEdit: () => onEditTask(t))),
        const SizedBox(height: 24),

        // ── Add more services button ─────────────────────────────────────────
        Center(
          child: ElevatedButton.icon(
            onPressed: () => TabShell.of(context).switchTab(1),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add more services'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Today, ${now.day} ${months[now.month - 1]}';
  }
}

class _TaskCard extends StatelessWidget {
  final SelectedTask task;
  final VoidCallback onEdit;
  const _TaskCard({required this.task, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green check circle
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),

          // Task details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.category,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (task.requestedTime != null || task.note != null) ...[
                  const SizedBox(height: 8),
                  if (task.requestedTime != null)
                    _InfoPill(
                      icon: Icons.schedule_outlined,
                      label: _formatTime(task.requestedTime!),
                    ),
                  if (task.note != null && task.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _InfoPill(
                      icon: Icons.notes_outlined,
                      label: task.note!,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour < 12 ? 'AM' : 'PM';
    return 'Scheduled for Today • $h:$m $ampm';
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.badgeBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.badgeText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.badgeText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  /// Called when the user taps "Explore" — should switch to Request tab.
  final VoidCallback onExplore;
  const _EmptyState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(44),
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to PadosiPro!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick the services you want handled —\nyour Lifestyle Manager is ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            // "Explore →" — stays in TabShell, switches to Request tab
            ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Explore',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Task Bottom Sheet ───────────────────────────────────────────────────

class _EditTaskBottomSheet extends StatefulWidget {
  final SelectedTask task;
  final VoidCallback onSuccess;

  const _EditTaskBottomSheet({required this.task, required this.onSuccess});

  @override
  State<_EditTaskBottomSheet> createState() => _EditTaskBottomSheetState();
}

class _EditTaskBottomSheetState extends State<_EditTaskBottomSheet> {
  static const _slots = [
    ('9 AM – 12 PM', 9),
    ('1 PM – 3 PM', 13),
    ('4 PM – 6 PM', 16),
  ];

  int? _selectedDateIdx;
  int? _selectedSlotIdx;
  late final TextEditingController _noteCtrl;

  bool _saving = false;
  bool _removing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.task.note ?? '');

    final existing = widget.task.requestedTime;
    if (existing != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = DateTime(existing.year, existing.month, existing.day)
          .difference(today)
          .inDays;
      if (diff >= 0 && diff < 14) _selectedDateIdx = diff;
      for (int i = 0; i < _slots.length; i++) {
        if (existing.hour == _slots[i].$2) {
          _selectedSlotIdx = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime? _getRequestedTime() {
    if (_selectedDateIdx == null || _selectedSlotIdx == null) return null;
    final base = DateTime.now();
    final date = DateTime(base.year, base.month, base.day).add(Duration(days: _selectedDateIdx!));
    final hour = _slots[_selectedSlotIdx!].$2;
    return DateTime(date.year, date.month, date.day, hour, 0);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final service = TaskService(appState.apiClient);
      final noteText = _noteCtrl.text.trim();
      
      await service.updateSelection(
        widget.task.id,
        time: _getRequestedTime(),
        note: noteText.isEmpty ? null : noteText,
      );
      
      if (!mounted) return;
      widget.onSuccess();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not save. Check connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final service = TaskService(appState.apiClient);
      
      await service.removeSelection(widget.task.id);
      
      if (!mounted) return;
      widget.onSuccess();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not remove. Check connection.');
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  String _dateLabel(int dayOffset) {
    final date = DateTime.now().add(Duration(days: dayOffset));
    if (dayOffset == 0) return 'Today';
    if (dayOffset == 1) return 'Tomorrow';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    // Determine bottom padding for keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Edit ${widget.task.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            
            // Date row
            const Text('Preferred date', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final selected = _selectedDateIdx == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDateIdx = selected ? null : i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.badgeBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                      ),
                      child: Text(
                        _dateLabel(i),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Time slots
            const Text('Preferred time slot', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(_slots.length, (i) {
                final selected = _selectedSlotIdx == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < _slots.length - 1 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSlotIdx = selected ? null : i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _slots[i].$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            
            // Note
            const Text('Note', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLength: 280,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Short note for the runner',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                counterStyle: const TextStyle(fontSize: 11, color: AppColors.textHint),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving || _removing ? null : _remove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _removing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Remove Task', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving || _removing ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
