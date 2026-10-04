import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';

/// Task Selection screen — two-step flow:
///   Step 1 (list): search + categories + checkboxes, "X of Y chosen",
///                  matches figma/Service.png.
///   Step 2 (review): one card per selected task with time picker + note,
///                    "Submit" calls PUT /tasks/selection.
class TaskSelectionScreen extends StatefulWidget {
  static const routeName = '/task-selection';
  const TaskSelectionScreen({super.key});

  @override
  State<TaskSelectionScreen> createState() => _TaskSelectionScreenState();
}

class _TaskSelectionScreenState extends State<TaskSelectionScreen> {
  // ── Catalogue state ───────────────────────────────────────────────────────
  List<Task> _catalogue = [];
  bool _loadingCatalogue = true;
  String? _catalogueError;

  // ── Selection state ───────────────────────────────────────────────────────
  /// task_id → true/false
  final Map<String, bool> _selected = {};

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Step 2 state ─────────────────────────────────────────────────────────
  bool _reviewStep = false;

  /// task_id → review data
  final Map<String, _ReviewData> _reviewData = {};

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
    _loadCatalogue();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    final appState = context.read<AppState>();
    final service = TaskService(appState.apiClient);
    try {
      final tasks = await service.getCatalogue();
      setState(() {
        _catalogue = tasks;
        _loadingCatalogue = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _catalogueError = e.message;
        _loadingCatalogue = false;
      });
    } catch (_) {
      setState(() {
        _catalogueError = 'Could not load services. Check your connection.';
        _loadingCatalogue = false;
      });
    }
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  List<String> get _categories {
    final cats = _catalogue.map((t) => t.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<Task> _tasksForCategory(String category) => _catalogue
      .where((t) =>
          t.category == category &&
          (_searchQuery.isEmpty ||
              t.name.toLowerCase().contains(_searchQuery) ||
              t.description.toLowerCase().contains(_searchQuery)))
      .toList();

  int get _totalSelected => _selected.values.where((v) => v).length;

  List<Task> get _selectedTasks =>
      _catalogue.where((t) => _selected[t.id] == true).toList();

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onConfirm() {
    if (_totalSelected == 0) return;

    // Initialize review data for newly selected tasks
    for (final task in _selectedTasks) {
      _reviewData.putIfAbsent(task.id, () => _ReviewData());
    }

    setState(() {
      _reviewStep = true;
      _submitError = null;
    });
  }

  Future<void> _onSubmit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final appState = context.read<AppState>();
      final service = TaskService(appState.apiClient);

      final items = _selectedTasks.map((task) {
        final rd = _reviewData[task.id]!;
        return TaskSelectionItem(
          taskId: task.id,
          requestedTime: rd.requestedTime,
          note: rd.noteCtrl.text.trim().isEmpty ? null : rd.noteCtrl.text.trim(),
        );
      }).toList();

      await service.saveSelection(items);

      if (!mounted) return;
      // Show success and go back to Home (placeholder)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Services saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      // Navigate to home screen placeholder
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _submitError = e.message);
    } catch (_) {
      setState(() => _submitError = 'Submission failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_reviewStep) return _buildReviewStep();
    return _buildListStep();
  }

  // ── Step 1: task list ─────────────────────────────────────────────────────

  Widget _buildListStep() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Image.asset('assets/images/logo.png', width: 32),
        leadingWidth: 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What do you need handled?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select priorities for your neighborhood concierge runner',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Search bar ──────────────────────────────────────
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search tasks, errands, fixes...',
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textHint, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // ── Catalogue body ───────────────────────────────────────────
          Expanded(child: _buildCatalogueBody()),
        ],
      ),

      // ── Confirm FAB ──────────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _totalSelected > 0
          ? FloatingActionButton.extended(
              onPressed: _onConfirm,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                'Confirm ($_totalSelected)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCatalogueBody() {
    if (_loadingCatalogue) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_catalogueError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(_catalogueError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadCatalogue, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _categories.length,
      itemBuilder: (context, i) => _buildCategory(_categories[i]),
    );
  }

  Widget _buildCategory(String category) {
    final tasks = _tasksForCategory(category);
    if (tasks.isEmpty) return const SizedBox.shrink();

    final total = _catalogue.where((t) => t.category == category).length;
    final chosen = tasks.where((t) => _selected[t.id] == true).length;
    // Count across all (even filtered-out) tasks in category
    final chosenInCat = _catalogue
        .where((t) => t.category == category && _selected[t.id] == true)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              if (chosenInCat > 0)
                Text(
                  '$chosenInCat of $total chosen',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        ...tasks.map((task) => _buildTaskTile(task)),
      ],
    );
  }

  Widget _buildTaskTile(Task task) {
    final isSelected = _selected[task.id] == true;

    return InkWell(
      onTap: () => setState(() => _selected[task.id] = !isSelected),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: review ────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final tasks = _selectedTasks;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(
          onPressed: () => setState(() {
            _reviewStep = false;
            _submitError = null;
          }),
        ),
        title: const Text(
          'Review your selections',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text(
                  'Add a preferred time and note for each service (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Error banner
                if (_submitError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _submitError!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                ...tasks.map((task) => _ReviewCard(
                      task: task,
                      data: _reviewData[task.id]!,
                      onTimeChanged: (dt) => setState(
                          () => _reviewData[task.id]!.requestedTime = dt),
                    )),
              ],
            ),
          ),

          // ── Submit button ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            color: AppColors.background,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Submit ${tasks.length} service${tasks.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mutable review state per task ─────────────────────────────────────────────

class _ReviewData {
  DateTime? requestedTime;
  final TextEditingController noteCtrl = TextEditingController();

  void dispose() => noteCtrl.dispose();
}

// ── Review card widget ────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Task task;
  final _ReviewData data;
  final ValueChanged<DateTime?> onTimeChanged;

  const _ReviewCard({
    required this.task,
    required this.data,
    required this.onTimeChanged,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: data.requestedTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(data.requestedTime ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    onTimeChanged(DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = data.requestedTime != null;
    final dt = data.requestedTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Task header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.badgeBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.handyman_outlined,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Chip(
                        label: Text(task.category),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Time picker row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasTime
                        ? _formatDt(dt!)
                        : 'Preferred date & time (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasTime
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _pickDateTime(context),
                  child: Text(hasTime ? 'Change' : 'Pick'),
                ),
                if (hasTime)
                  IconButton(
                    icon: const Icon(Icons.clear,
                        size: 16, color: AppColors.textSecondary),
                    onPressed: () => onTimeChanged(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // ── Note field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: TextField(
              controller: data.noteCtrl,
              maxLength: 280,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Short note for the runner (optional)',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textHint),
                counterStyle:
                    const TextStyle(fontSize: 11, color: AppColors.textHint),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
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
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDt(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }
}
