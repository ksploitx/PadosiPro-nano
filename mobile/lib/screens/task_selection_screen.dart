import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/api_client.dart';
import 'tab_shell.dart';
import 'app_header.dart';

/// Task Selection screen — two-step flow:
///   Step 1 (list): search + categories + checkboxes, "X of Y chosen".
///   Step 2 (review): one card per selected task with date-chip row +
///                    3 slot chips + note, "Submit" calls PUT /tasks/selection.
///
/// [preloadSelection]: calls GET /tasks/selection on init to pre-check tasks.
/// [startAtReview]: after loading, jump directly to the review step
///                 (used by Home → "Edit tasks" so the user lands on the
///                  time/note editor, not the checkbox list).
class TaskSelectionScreen extends StatefulWidget {
  static const routeName = '/task-selection';

  final bool preloadSelection;

  /// When true, skip step 1 and show the review step immediately.
  final bool startAtReview;

  const TaskSelectionScreen({
    super.key,
    this.preloadSelection = false,
    this.startAtReview = false,
  });

  @override
  State<TaskSelectionScreen> createState() => TaskSelectionScreenState();
}

class TaskSelectionScreenState extends State<TaskSelectionScreen> {
  // ── Catalogue state ───────────────────────────────────────────────────────
  List<Task> _catalogue = [];
  bool _loadingCatalogue = true;
  String? _catalogueError;

  // ── Selection state ───────────────────────────────────────────────────────
  /// task_id → true/false (for UI checkbox state)
  final Map<String, bool> _selected = {};

  /// task_ids that were already selected from the backend
  final Set<String> _alreadySelected = {};

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

  void refresh() {
    // Clear out local search and selection so they get reset/re-fetched.
    _searchCtrl.clear();
    _searchQuery = '';
    _selected.clear();
    _reviewData.clear();
    _reviewStep = false;
    _loadCatalogue();
  }

  Future<void> _loadCatalogue() async {
    final appState = context.read<AppState>();
    final service = TaskService(appState.apiClient);
    try {
      final tasks = await service.getCatalogue();
      if (!mounted) return;

      // Load the current selection so we can disable existing ones.
      try {
        final existing = await service.getSelection();
        for (final sel in existing) {
          _selected[sel.id] = true;
          _alreadySelected.add(sel.id);
          // If launched from "Edit tasks", we might want review data, but "Edit tasks" is being changed to "Add more services" which just opens this normally.
          // Pre-fill reviewData just in case startAtReview is still used.
          _reviewData[sel.id] = _ReviewData.fromExisting(sel);
        }
      } catch (_) {
        // Non-fatal: proceed without pre-fill.
      }

      setState(() {
        _catalogue = tasks;
        _loadingCatalogue = false;
        // startAtReview: jump straight to review step once tasks are loaded.
        if (widget.startAtReview && _selected.isNotEmpty) {
          // Ensure all pre-selected tasks have review data.
          for (final task in _catalogue.where((t) => _selected[t.id] == true)) {
            _reviewData.putIfAbsent(task.id, () => _ReviewData());
          }
          _reviewStep = true;
        }
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

  int get _totalSelected => _newlySelectedTasks.length;

  List<Task> get _newlySelectedTasks =>
      _catalogue.where((t) => _selected[t.id] == true && !_alreadySelected.contains(t.id)).toList();

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onConfirm() {
    if (_totalSelected == 0) return;

    // Initialize review data for newly selected tasks
    for (final task in _newlySelectedTasks) {
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

      // Submit each new selection via POST
      for (final task in _newlySelectedTasks) {
        final rd = _reviewData[task.id]!;
        await service.addSelection(
          task.id,
          time: rd.requestedTime,
          note: rd.noteCtrl.text.trim().isEmpty ? null : rd.noteCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Services saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      // If this screen was pushed on top (from Home "Edit tasks"),
      // pop back so Home reloads. If inside TabShell as the Request tab,
      // switch to Home tab. Otherwise (first-time onboarding), push TabShell.
      final shellState = context.findAncestorStateOfType<TabShellState>();
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        // Pushed on top of Home: pop returns to Home which then reloads.
        navigator.pop();
      } else if (shellState != null) {
        setState(() => _reviewStep = false);
        shellState.switchTab(0);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          TabShell.routeName,
          (_) => false,
        );
      }
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
      // Icon-only shared header; avatar in header switches to Profile tab.
      appBar: buildAppHeader(
        extraActions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
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
    // Count chosen across all (even filtered-out) tasks in category
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
    final isAlreadySelected = _alreadySelected.contains(task.id);

    return Opacity(
      opacity: isAlreadySelected ? 0.6 : 1.0,
      child: InkWell(
        onTap: isAlreadySelected ? null : () => setState(() => _selected[task.id] = !isSelected),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isAlreadySelected ? AppColors.badgeBackground : AppColors.surface,
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
                  color: isSelected ? (isAlreadySelected ? AppColors.textHint : AppColors.primary) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? (isAlreadySelected ? AppColors.textHint : AppColors.primary) : AppColors.divider,
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
    ),
    );
  }

  // ── Step 2: review ────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    final tasks = _newlySelectedTasks;

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
  final TextEditingController noteCtrl;

  _ReviewData()
      : requestedTime = null,
        noteCtrl = TextEditingController();

  /// Bug 6: construct from an already-selected task, pre-filling time & note.
  _ReviewData.fromExisting(SelectedTask sel)
      : requestedTime = sel.requestedTime,
        noteCtrl = TextEditingController(text: sel.note ?? '');

  void dispose() => noteCtrl.dispose();
}

// ── Review card widget ────────────────────────────────────────────────────────

/// Bug 2: replaces showDatePicker + showTimePicker with:
///   • A horizontal scrollable row of the next 14 date chips
///   • Three fixed time-slot chips: 9 AM–12 PM / 1 PM–3 PM / 4 PM–6 PM
///
/// The resulting [requestedTime] is a [DateTime] built from the chosen date +
/// the slot's start hour — same type/format as before so backend contract
/// is unchanged.
class _ReviewCard extends StatefulWidget {
  final Task task;
  final _ReviewData data;
  final ValueChanged<DateTime?> onTimeChanged;

  const _ReviewCard({
    required this.task,
    required this.data,
    required this.onTimeChanged,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  // The three fixed time slots (label, start hour for DateTime construction)
  static const _slots = [
    ('9 AM – 12 PM', 9),
    ('1 PM – 3 PM', 13),
    ('4 PM – 6 PM', 16),
  ];

  // Which date chip index is selected (null = none)
  int? _selectedDateIdx;

  // Which slot index is selected (null = none)
  int? _selectedSlotIdx;

  @override
  void initState() {
    super.initState();
    // Bug 6: if reviewData already carries a pre-filled requestedTime, map it
    // back to the closest chip so the UI reflects the existing selection.
    final existing = widget.data.requestedTime;
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

  void _updateTime() {
    if (_selectedDateIdx == null || _selectedSlotIdx == null) {
      widget.onTimeChanged(null);
      return;
    }
    final base = DateTime.now();
    final date = DateTime(base.year, base.month, base.day)
        .add(Duration(days: _selectedDateIdx!));
    final hour = _slots[_selectedSlotIdx!].$2;
    widget.onTimeChanged(DateTime(date.year, date.month, date.day, hour, 0));
  }

  String _dateLabel(int dayOffset) {
    final date =
        DateTime.now().add(Duration(days: dayOffset));
    if (dayOffset == 0) return 'Today';
    if (dayOffset == 1) return 'Tomorrow';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final hasTime = widget.data.requestedTime != null;

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
                        widget.task.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Chip(
                        label: Text(widget.task.category),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Bug 2: Date chip row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'Preferred date',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (_selectedDateIdx != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedDateIdx = null);
                      _updateTime();
                    },
                    child: const Icon(Icons.clear,
                        size: 15, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: 14,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final selected = _selectedDateIdx == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDateIdx = i);
                    _updateTime();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.badgeBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      _dateLabel(i),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ── Bug 2: Slot chips ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'Preferred time slot',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: List.generate(_slots.length, (i) {
                final selected = _selectedSlotIdx == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < _slots.length - 1 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() =>
                            _selectedSlotIdx = selected ? null : i);
                        _updateTime();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _slots[i].$1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          if (hasTime)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDt(widget.data.requestedTime!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // ── Note field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: TextField(
              controller: widget.data.noteCtrl,
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · ${_slots.firstWhere((s) => s.$2 == dt.hour, orElse: () => (_formatHour(dt.hour), dt.hour)).$1}';
  }

  String _formatHour(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }
}
