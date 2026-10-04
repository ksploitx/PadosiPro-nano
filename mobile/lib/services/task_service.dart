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

  /// PUT /tasks/selection — full-replace the user's selection.
  /// [items] must be non-empty; each item may carry optional requestedTime and note.
  /// Returns the saved [SelectedTask] list (with time/note echoed back).
  Future<List<SelectedTask>> saveSelection(List<TaskSelectionItem> items) async {
    final body = await _api.put(
      '/tasks/selection',
      {'selections': items.map((i) => i.toJson()).toList()},
      auth: true,
    );
    return (body as List<dynamic>)
        .map((e) => SelectedTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /tasks/selection — returns the user's current selection (with time/note).
  Future<List<SelectedTask>> getSelection() async {
    final body = await _api.get('/tasks/selection', auth: true);
    return (body as List<dynamic>)
        .map((e) => SelectedTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
