import 'api_client.dart';
import '../models/task.dart';

/// Wraps all task-related API calls (catalogue + selection).
class TaskService {
  final ApiClient _api;
  const TaskService(this._api);

  /// GET /tasks/catalogue — returns all available tasks (no auth).
  Future<List<Task>> getCatalogue() async {
    final body = await _api.get('/tasks/catalogue');
    return (body as List<dynamic>)
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /tasks/selection — add a new selection (or update if exists).
  Future<SelectedTask> addSelection(String taskId, {DateTime? time, String? note}) async {
    final body = await _api.post(
      '/tasks/selection',
      {
        'task_id': taskId,
        'requested_time': time?.toUtc().toIso8601String(),
        'note': note,
      },
      auth: true,
    );
    return SelectedTask.fromJson(body as Map<String, dynamic>);
  }

  /// PATCH /tasks/selection/{task_id} — update an existing selection.
  Future<SelectedTask> updateSelection(String taskId, {DateTime? time, String? note}) async {
    final body = await _api.patch(
      '/tasks/selection/$taskId',
      {
        'requested_time': time?.toUtc().toIso8601String(),
        'note': note,
      },
      auth: true,
    );
    return SelectedTask.fromJson(body as Map<String, dynamic>);
  }

  /// DELETE /tasks/selection/{task_id} — remove a selection.
  Future<void> removeSelection(String taskId) async {
    await _api.delete('/tasks/selection/$taskId', auth: true);
  }

  /// GET /tasks/selection — returns the user's current selection (with time/note).
  Future<List<SelectedTask>> getSelection() async {
    final body = await _api.get('/tasks/selection', auth: true);
    return (body as List<dynamic>)
        .map((e) => SelectedTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
