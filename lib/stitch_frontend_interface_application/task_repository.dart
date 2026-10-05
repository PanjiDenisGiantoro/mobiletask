import 'package:flutter/foundation.dart';
import '../projecthub/ph_models.dart';
import 'widgets/activity_type.dart';
import 'widgets/task_tile.dart';

class TaskEntry {
  final int id;

  /// projects.id di server; 0 untuk task lokal tanpa proyek.
  final int projectId;
  String title;
  final String project;
  TaskPriority priority;
  String due;
  final ActivityType? type;
  final Uint8List? photo;

  /// Kolom papan task: todo | in_progress | review | done (tabel tasks.status).
  String status;
  String assignedTo;
  String milestone;
  String sprint;
  String startDate;
  String dueDate;
  int estimatedHours;
  int storyPoints;
  String description;
  String completionNotes;
  String createdBy;
  final List<TaskDependency> dependencies;
  final List<TaskComment> comments;

  TaskEntry({
    this.id = 0,
    this.projectId = 0,
    required this.title,
    required this.project,
    required this.priority,
    required this.due,
    this.type,
    this.photo,
    bool done = false,
    String? status,
    this.assignedTo = '',
    this.milestone = '',
    this.sprint = '',
    this.startDate = '',
    this.dueDate = '',
    this.estimatedHours = 0,
    this.storyPoints = 0,
    this.description = '',
    this.completionNotes = '',
    this.createdBy = '',
    List<TaskDependency>? dependencies,
    List<TaskComment>? comments,
  })  : status = status ?? (done ? 'done' : 'todo'),
        dependencies = dependencies ?? [],
        comments = comments ?? [];

  bool get done => status == 'done';
  set done(bool value) => status = value ? 'done' : (status == 'done' ? 'todo' : status);
}

/// Sumber data tugas bersama, dipakai oleh [TasksScreen], form "Tugas
/// Baru" dari tombol + di bottom nav, dan layar Detail Proyek/Detail Task
/// supaya tugas yang baru dibuat langsung tampil di semua tempat.
class TaskRepository extends ChangeNotifier {
  TaskRepository._();
  static final TaskRepository instance = TaskRepository._();

  /// Diisi dari API lewat `PhStore.sync()` (ph_remote.dart).
  final List<TaskEntry> tasks = [];

  void replaceAll(List<TaskEntry> fresh) {
    tasks
      ..clear()
      ..addAll(fresh);
    notifyListeners();
  }

  void insertTask(TaskEntry task) {
    tasks.insert(0, task);
    notifyListeners();
  }

  void removeTask(TaskEntry task) {
    tasks.remove(task);
    notifyListeners();
  }

  TaskEntry? byId(int id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<TaskEntry> forProject(String projectName) =>
      tasks.where((t) => t.project == projectName).toList(growable: false);

  void touch() => notifyListeners();
}
