/// Data models for the tasks feature.

class Task {
  final String id;
  final String name;
  final String category;
  final String description;

  const Task({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
      );
}

/// A selected task as returned by GET/PUT /tasks/selection.
/// Carries the task fields plus optional scheduling metadata.
class SelectedTask {
  final String id;
  final String name;
  final String category;
  final String description;
  final DateTime? requestedTime;
  final String? note;

  const SelectedTask({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.requestedTime,
    this.note,
  });

  factory SelectedTask.fromJson(Map<String, dynamic> json) => SelectedTask(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        requestedTime: json['requested_time'] != null
            ? DateTime.parse(json['requested_time'] as String)
            : null,
        note: json['note'] as String?,
      );
}

/// One item in the PUT /tasks/selection request body.
class TaskSelectionItem {
  final String taskId;
  final DateTime? requestedTime;
  final String? note;

  const TaskSelectionItem({
    required this.taskId,
    this.requestedTime,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'requested_time': requestedTime?.toUtc().toIso8601String(),
        'note': note,
      };
}
