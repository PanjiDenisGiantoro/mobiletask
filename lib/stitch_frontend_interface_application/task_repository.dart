import 'package:flutter/foundation.dart';
import 'widgets/activity_type.dart';
import 'widgets/task_tile.dart';

class TaskEntry {
  final String title;
  final String project;
  final TaskPriority priority;
  final String due;
  final ActivityType? type;
  final Uint8List? photo;
  bool done;

  TaskEntry({
    required this.title,
    required this.project,
    required this.priority,
    required this.due,
    this.type,
    this.photo,
    this.done = false,
  });
}

/// Sumber data tugas bersama, dipakai oleh [TasksScreen] dan form "Tugas
/// Baru" dari tombol + di bottom nav supaya tugas yang baru dibuat langsung
/// tampil di daftar tanpa perlu state management library terpisah.
class TaskRepository extends ChangeNotifier {
  TaskRepository._();
  static final TaskRepository instance = TaskRepository._();

  final List<TaskEntry> tasks = [
    TaskEntry(title: 'Finalize wireframes for onboarding', project: 'Mobile App Redesign', priority: TaskPriority.high, due: 'Today'),
    TaskEntry(title: 'Fix login screen crash on Android', project: 'Mobile App Redesign', priority: TaskPriority.high, due: 'Today'),
    TaskEntry(title: 'Review API documentation', project: 'Backend API v2', priority: TaskPriority.medium, due: 'Today', done: true),
    TaskEntry(title: 'Setup CI/CD pipeline', project: 'Backend API v2', priority: TaskPriority.medium, due: 'May 14'),
    TaskEntry(title: 'Send weekly report to stakeholders', project: 'Marketing Campaign Q2', priority: TaskPriority.low, due: 'Today'),
    TaskEntry(title: 'Design token documentation', project: 'Mobile App Redesign', priority: TaskPriority.low, due: 'May 15'),
    TaskEntry(title: 'Database schema migration', project: 'Backend API v2', priority: TaskPriority.high, due: 'May 14'),
    TaskEntry(title: 'Write unit tests for auth module', project: 'Backend API v2', priority: TaskPriority.medium, due: 'May 16', done: true),
  ];

  void addTask({
    required String title,
    required ActivityType type,
    Uint8List? photo,
  }) {
    tasks.insert(
      0,
      TaskEntry(
        title: title,
        project: type.label,
        priority: TaskPriority.medium,
        due: 'Baru',
        type: type,
        photo: photo,
      ),
    );
    notifyListeners();
  }

  void setDone(TaskEntry task, bool done) {
    task.done = done;
    notifyListeners();
  }

  void deleteTask(TaskEntry task) {
    tasks.remove(task);
    notifyListeners();
  }
}
