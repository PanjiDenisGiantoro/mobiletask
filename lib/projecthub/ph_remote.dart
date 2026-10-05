import '../stitch_frontend_interface_application/auth_repository.dart';
import '../stitch_frontend_interface_application/task_repository.dart';
import '../stitch_frontend_interface_application/widgets/task_tile.dart';
import 'ph_api.dart';
import 'ph_format.dart';
import 'ph_models.dart';
import 'ph_store.dart';

final _api = PhApi.instance;

/// Sinkronisasi modul proyek, task, tiket, customer request, dan approval
/// dengan API ProjectHub Pro. HRIS dan chat belum punya endpoint, jadi
/// tetap memakai data lokal di [PhStore].
extension PhRemote on PhStore {
  TaskRepository get _tasks => TaskRepository.instance;

  /// Muat ulang semua data dari server. Galat disimpan di [PhStore.syncError].
  Future<void> sync() async {
    if (!AuthRepository.instance.isLoggedIn || syncing) return;
    syncing = true;
    // Biasanya dipanggil dari initState: tunda notifikasi sampai build selesai.
    await Future<void>.value();
    syncError = null;
    changed();
    try {
      _registerMe();
      await _loadUsers();

      final projectJson = await _api.getAll('/projects');
      final loaded = <Project>[];
      final allTasks = <TaskEntry>[];
      final allTickets = <Ticket>[];
      await Future.wait(projectJson.map((pj) async {
        final p = _project(pj);
        final id = p.id;
        final results = await Future.wait([
          _api.get('/projects/$id/milestones'),
          _api.getAll('/projects/$id/tasks'),
          _api.getAll('/projects/$id/tickets').catchError((_) => <Map<String, dynamic>>[]),
        ]);
        p.milestones.addAll([for (final m in (results[0] as List? ?? const [])) _milestone(m as Map<String, dynamic>)]);
        final tasks = [for (final t in results[1] as List<Map<String, dynamic>>) _task(t, p)];
        p.totalTasks = tasks.length;
        p.doneTasks = tasks.where((t) => t.done).length;
        allTasks.addAll(tasks);
        allTickets.addAll([for (final t in results[2] as List<Map<String, dynamic>>) _ticket(t, p)]);
        loaded.add(p);
      }));
      loaded.sort((a, b) => b.id.compareTo(a.id));
      allTasks.sort((a, b) => b.id.compareTo(a.id));
      allTickets.sort((a, b) => b.id.compareTo(a.id));

      final reqJson = await _api.getAll('/requests').catchError((_) => <Map<String, dynamic>>[]);
      final approvalsLoaded = await _loadApprovals();

      projects
        ..clear()
        ..addAll(loaded);
      tickets
        ..clear()
        ..addAll(allTickets);
      requests
        ..clear()
        ..addAll([for (final r in reqJson) _request(r)]);
      approvals
        ..removeWhere((a) => !a.isLocal)
        ..insertAll(0, approvalsLoaded);
      _tasks.replaceAll(allTasks);
      synced = true;
    } on ApiException catch (e) {
      syncError = e.message;
    } catch (e) {
      syncError = 'Gagal memuat data: $e';
    } finally {
      syncing = false;
      changed();
    }
  }

  // ------------------------------------------------------------ proyek

  Future<void> saveProject(Project? existing, Map<String, Object?> body) async {
    final payload = {
      'name': body['name'],
      'description': _nullIfEmpty(body['description']),
      'client_id': _intOrNull(body['clientId']),
      'manager_id': _intOrNull(body['managerId']),
      'status': body['status'],
      'start_date': _nullIfEmpty(body['startDate']),
      'end_date': _nullIfEmpty(body['endDate']),
      'budget': double.tryParse('${body['budget']}') ?? 0,
      'budget_alert_threshold': int.tryParse('${body['budgetThreshold']}'),
      'github_repo_url': _nullIfEmpty(body['githubUrl']),
    };
    if (existing == null) {
      final res = await _api.post('/projects', payload) as Map<String, dynamic>;
      projects.insert(0, _project(res));
    } else {
      final res = await _api.put('/projects/${existing.id}', payload) as Map<String, dynamic>;
      final fresh = _project(res);
      existing
        ..name = fresh.name
        ..description = fresh.description
        ..clientId = fresh.clientId
        ..managerId = fresh.managerId
        ..status = fresh.status
        ..startDate = fresh.startDate
        ..endDate = fresh.endDate
        ..budget = fresh.budget
        ..budgetThreshold = fresh.budgetThreshold
        ..githubUrl = fresh.githubUrl
        ..category = fresh.category;
    }
    changed();
  }

  Future<void> saveMilestone(Project project, Milestone? existing, Map<String, Object?> body) async {
    final payload = {
      'title': body['title'],
      'description': _nullIfEmpty(body['description']),
      'status': body['status'],
      'start_date': _nullIfEmpty(body['startDate']),
      'due_date': _nullIfEmpty(body['dueDate']),
      'assigned_to': _intOrNull(body['assignedTo']),
    };
    if (existing == null) {
      final res = await _api.post('/projects/${project.id}/milestones', payload) as Map<String, dynamic>;
      project.milestones.add(_milestone(res));
    } else {
      final res = await _api.put('/projects/${project.id}/milestones/${existing.id}', payload) as Map<String, dynamic>;
      final m = _milestone(res);
      existing
        ..title = m.title
        ..description = m.description
        ..status = m.status
        ..startDate = m.startDate
        ..assignedTo = m.assignedTo
        ..dueDate = m.dueDate;
    }
    changed();
  }

  // ------------------------------------------------------------ task

  Map<String, Object?> _taskPayload(Project project, Map<String, Object?> v) => {
        'title': v['title'],
        'description': _nullIfEmpty(v['description']),
        'assigned_to': _intOrNull(v['assignedTo']),
        'milestone_id': project.milestones.where((m) => m.title == v['milestone']).firstOrNull?.id,
        'sprint_id': project.sprints.where((s) => s.name == v['sprint']).firstOrNull?.id,
        'priority': v['priority'],
        'start_date': _nullIfEmpty(v['startDate']),
        'due_date': _nullIfEmpty(v['dueDate']),
        'estimated_hours': _positiveOrNull(v['estimatedHours']),
        'story_points': int.tryParse('${v['storyPoints'] ?? ''}'),
      };

  /// Buat task. API selalu menaruh task baru di kolom pertama papan, jadi
  /// status lain dikirim lewat update setelahnya.
  Future<TaskEntry> createTask(Project project, Map<String, Object?> v) async {
    final res = await _api.post('/projects/${project.id}/tasks', _taskPayload(project, v)) as Map<String, dynamic>;
    var task = _task(res, project);
    final status = v['status'] as String? ?? 'todo';
    if (status != task.status) {
      final upd = await _api.put('/projects/${project.id}/tasks/${task.id}', {'status': status}) as Map<String, dynamic>;
      task = _task(upd, project);
    }
    _tasks.insertTask(task);
    _recount(project);
    return task;
  }

  Future<void> updateTask(TaskEntry task, Map<String, Object?> v) async {
    final project = _projectOf(task);
    final res = await _api.put('/projects/${project.id}/tasks/${task.id}', {
      ..._taskPayload(project, v),
      'status': v['status'],
    }) as Map<String, dynamic>;
    _copyTask(_task(res, project), task);
    _tasks.touch();
    _recount(project);
  }

  Future<void> setTaskStatus(TaskEntry task, String status) async {
    final project = _projectOf(task);
    final res = await _api.put('/projects/${project.id}/tasks/${task.id}', {'status': status}) as Map<String, dynamic>;
    task.status = '${res['status'] ?? status}';
    _tasks.touch();
    _recount(project);
  }

  Future<void> deleteTask(TaskEntry task) async {
    final project = _projectOf(task);
    await _api.delete('/projects/${project.id}/tasks/${task.id}');
    _tasks.removeTask(task);
    _recount(project);
  }

  Project _projectOf(TaskEntry task) {
    final p = task.projectId == 0 ? projectByName(task.project) : projectById(task.projectId);
    if (p == null) throw const ApiException('Proyek task tidak ditemukan');
    return p;
  }

  void _recount(Project p) {
    final list = _tasks.tasks.where((t) => t.projectId == p.id);
    p.totalTasks = list.length;
    p.doneTasks = list.where((t) => t.done).length;
    changed();
  }

  // ------------------------------------------------------------ ruang kerja proyek

  /// Muat sprint, anggota, budget, risiko, file, dan timesheet satu proyek.
  Future<void> loadProjectWorkspace(Project p) async {
    final r = await Future.wait<dynamic>([
      _api.get('/projects/${p.id}'),
      _api.get('/projects/${p.id}/sprints'),
      _api.get('/projects/${p.id}/budget'),
      _api.get('/projects/${p.id}/risks'),
      _api.get('/projects/${p.id}/files'),
      _api.get('/projects/${p.id}/timesheet'),
    ]);
    final fresh = _project(r[0] as Map<String, dynamic>);
    p.members
      ..clear()
      ..addAll(fresh.members);
    p.milestones
      ..clear()
      ..addAll([for (final m in (r[0]['milestones'] as List? ?? const [])) _milestone(m as Map<String, dynamic>)]);
    p.sprints
      ..clear()
      ..addAll([for (final j in (r[1] as List)) _sprint(j as Map<String, dynamic>)]);
    _applyBudget(p, r[2] as Map<String, dynamic>);
    p.risks
      ..clear()
      ..addAll([for (final j in (r[3] as List)) _risk(j as Map<String, dynamic>)]);
    p.files
      ..clear()
      ..addAll([for (final j in (r[4] as List)) _file(j as Map<String, dynamic>)]);
    _applyTimesheet(p, r[5] as Map<String, dynamic>);
    changed();
  }

  Future<void> saveSprint(Project p, Sprint? existing, Map<String, Object?> v) async {
    final body = {
      'name': v['name'],
      'goal': _nullIfEmpty(v['goal']),
      'milestone_id': p.milestones.where((m) => m.title == v['milestone']).firstOrNull?.id,
      'start_date': _nullIfEmpty(v['startDate']),
      'end_date': _nullIfEmpty(v['endDate']),
      'status': v['status'],
    };
    final j = existing == null
        ? await _api.post('/projects/${p.id}/sprints', body)
        : await _api.put('/projects/${p.id}/sprints/${existing.id}', body);
    final s = _sprint(j as Map<String, dynamic>);
    if (existing == null) {
      p.sprints.insert(0, s);
    } else {
      p.sprints[p.sprints.indexOf(existing)] = s;
      // Server menutup sprint aktif lain saat sprint ini diaktifkan.
      if (s.status == 'active') {
        for (final o in p.sprints) {
          if (o.id != s.id && o.status == 'active') o.status = 'completed';
        }
      }
    }
    changed();
  }

  Future<void> deleteSprint(Project p, Sprint s) async {
    await _api.delete('/projects/${p.id}/sprints/${s.id}');
    p.sprints.remove(s);
    for (final t in _tasks.tasks.where((t) => t.projectId == p.id && t.sprint == s.name)) {
      t.sprint = '';
    }
    changed();
  }

  Future<void> addMembers(Project p, List<String> userIds, String role, int maxHours) async {
    final list = await _api.post('/projects/${p.id}/team', {
      'user_id': [for (final id in userIds) int.parse(id)],
      'role': _nullIfEmpty(role),
      'max_hours_per_day': maxHours,
    }) as List;
    p.members
      ..clear()
      ..addAll([
        for (final m in list)
          ProjectMember(id: _int(m['id']), userId: _uid(m['user_id'], m['user_name']), role: '${m['role'] ?? ''}', maxHoursPerDay: _int(m['max_hours_per_day'], 8)),
      ]);
    changed();
  }

  Future<void> removeMember(Project p, ProjectMember m) async {
    await _api.delete('/projects/${p.id}/team/${m.userId}');
    p.members.remove(m);
    changed();
  }

  Future<void> addBudgetEntry(Project p, Map<String, Object?> v) async {
    _applyBudget(p, await _api.post('/projects/${p.id}/budget', {
      'type': v['type'],
      'category': v['category'],
      'description': v['description'],
      'amount': double.tryParse('${v['amount']}') ?? 0,
      'entry_date': v['entryDate'],
      'reference': _nullIfEmpty(v['reference']),
    }) as Map<String, dynamic>);
    changed();
  }

  Future<void> deleteBudgetEntry(Project p, BudgetEntry e) async {
    _applyBudget(p, await _api.delete('/projects/${p.id}/budget/${e.id}') as Map<String, dynamic>);
    changed();
  }

  Future<void> setBudgetThreshold(Project p, int percent) async {
    _applyBudget(p, await _api.patch('/projects/${p.id}/budget/threshold', {'budget_alert_threshold': percent}) as Map<String, dynamic>);
    changed();
  }

  Future<void> saveRisk(Project p, Risk? existing, Map<String, Object?> v) async {
    final body = {
      'title': v['title'],
      'description': _nullIfEmpty(v['description']),
      'category': v['category'],
      'probability': int.tryParse('${v['probability']}') ?? 1,
      'impact': int.tryParse('${v['impact']}') ?? 1,
      'status': v['status'],
      'mitigation_plan': _nullIfEmpty(v['mitigationPlan']),
      'owner': _nullIfEmpty(v['owner']),
    };
    final j = existing == null
        ? await _api.post('/projects/${p.id}/risks', body)
        : await _api.put('/projects/${p.id}/risks/${existing.id}', body);
    final r = _risk(j as Map<String, dynamic>);
    if (existing == null) {
      p.risks.insert(0, r);
    } else {
      p.risks[p.risks.indexOf(existing)] = r;
    }
    changed();
  }

  Future<void> deleteRisk(Project p, Risk r) async {
    await _api.delete('/projects/${p.id}/risks/${r.id}');
    p.risks.remove(r);
    changed();
  }

  Future<void> uploadFile(Project p, String folder, String description, ApiFile file) async {
    final list = await _api.upload('/projects/${p.id}/files', {'folder': folder, 'description': description}, [ApiFile('files[]', file.name, file.bytes)]) as List;
    p.files.insertAll(0, [for (final j in list) _file(j as Map<String, dynamic>)]);
    changed();
  }

  Future<void> deleteFile(Project p, ProjectFile f) async {
    await _api.delete('/projects/${p.id}/files/${f.id}');
    p.files.remove(f);
    changed();
  }

  /// action: start | stop | manual (TimeLogController). Timesheet dimuat ulang sesudahnya.
  Future<void> logTime(Project p, int taskId, String action, {int minutes = 0, String notes = ''}) async {
    await _api.post('/tasks/$taskId/time-logs', {
      'action': action,
      if (action == 'manual') 'minutes': minutes,
      if (notes.isNotEmpty) 'notes': notes,
    });
    _applyTimesheet(p, await _api.get('/projects/${p.id}/timesheet') as Map<String, dynamic>);
    changed();
  }

  Future<List<TaskComment>> loadTaskComments(TaskEntry t) async {
    final list = await _api.get('/projects/${t.projectId}/tasks/${t.id}/comments') as List;
    final comments = [for (final c in list) _comment(c as Map<String, dynamic>)];
    t.comments
      ..clear()
      ..addAll(comments);
    _tasks.touch();
    return comments;
  }

  Future<void> addTaskComment(TaskEntry t, String body) async {
    final c = await _api.post('/projects/${t.projectId}/tasks/${t.id}/comments', {'body': body}) as Map<String, dynamic>;
    t.comments.add(_comment(c));
    _tasks.touch();
  }

  TaskComment _comment(Map<String, dynamic> c) => TaskComment(_uid(c['user_id'], c['user_name']), '${c['body'] ?? ''}', _dateTime(c['created_at']));

  void _applyBudget(Project p, Map<String, dynamic> j) {
    final s = j['summary'] as Map? ?? const {};
    p.budget = (s['budget'] as num?)?.toDouble() ?? p.budget;
    if (s['threshold'] != null) p.budgetThreshold = (s['threshold'] as num).round();
    p.budgetEntries
      ..clear()
      ..addAll([
        for (final e in (j['entries'] as List? ?? const []))
          BudgetEntry(
            id: _int(e['id']),
            type: '${e['type']}',
            category: '${e['category'] ?? ''}',
            description: '${e['description'] ?? ''}',
            amount: (e['amount'] as num?)?.toDouble() ?? 0,
            entryDate: '${e['entry_date'] ?? ''}',
            reference: '${e['reference'] ?? ''}',
          ),
      ]);
  }

  void _applyTimesheet(Project p, Map<String, dynamic> j) {
    p.timeLogs
      ..clear()
      ..addAll([
        for (final l in (j['logs'] as List? ?? const []))
          TimeLog(
            id: _int(l['id']),
            taskId: _int(l['task_id']),
            taskTitle: l['task'] is Map ? '${l['task']['title']}' : 'Task #${l['task_id']}',
            userId: _uid(l['user_id'], l['user'] is Map ? l['user']['name'] : null),
            startedAt: _dateTime(l['started_at']),
            endedAt: l['ended_at'] == null ? null : _dateTime(l['ended_at']),
            minutes: _int(l['minutes']),
            notes: '${l['notes'] ?? ''}',
            running: l['is_running'] == true || l['is_running'] == 1,
            startedAtTime: DateTime.tryParse('${l['started_at'] ?? ''}')?.toLocal(),
          ),
      ]..sort((a, b) => b.startedAt.compareTo(a.startedAt)));
  }

  Sprint _sprint(Map<String, dynamic> j) => Sprint(
        id: _int(j['id']),
        milestoneId: _int(j['milestone_id']),
        name: '${j['name'] ?? ''}',
        goal: '${j['goal'] ?? ''}',
        status: '${j['status'] ?? 'planned'}',
        startDate: '${j['start_date'] ?? ''}',
        endDate: '${j['end_date'] ?? ''}',
        milestone: '${j['milestone'] ?? ''}',
      );

  Risk _risk(Map<String, dynamic> j) => Risk(
        id: _int(j['id']),
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        category: '${j['category'] ?? 'other'}',
        probability: _int(j['probability'], 1),
        impact: _int(j['impact'], 1),
        status: '${j['status'] ?? 'open'}',
        mitigationPlan: '${j['mitigation_plan'] ?? ''}',
        owner: '${j['owner'] ?? ''}',
      );

  ProjectFile _file(Map<String, dynamic> j) => ProjectFile(
        id: _int(j['id']),
        url: '${j['url'] ?? ''}',
        folder: '${j['folder'] ?? 'General'}',
        name: '${j['name'] ?? ''}',
        mimeType: '${j['mime_type'] ?? ''}',
        size: _int(j['size']),
        description: '${j['description'] ?? ''}',
      );

  String _uid(Object? id, Object? name) {
    final key = '${id ?? ''}';
    if (key.isNotEmpty && name != null) users.putIfAbsent(key, () => PhUser(key, '$name'));
    return key;
  }

  // ------------------------------------------------------------ tiket

  Future<void> loadTicketDetail(Ticket t) async {
    if (!AuthRepository.instance.isLoggedIn) return;
    final res = await _api.get('/tickets/${t.id}') as Map<String, dynamic>;
    final fresh = _ticket(res, projectById(_int(res['project_id'])));
    _copyTicket(fresh, t);
    t.comments
      ..clear()
      ..addAll([
        for (final c in (res['comments'] as List? ?? const []))
          TaskComment(_userId(c['user'], c['user_id']), '${c['body'] ?? ''}', _dateTime(c['created_at'])),
      ]);
    t.history
      ..clear()
      ..addAll([
        for (final h in (res['histories'] as List? ?? const []).reversed)
          TicketHistory(_userId(h['actor'], h['actor_id']), '${h['field_changed'] ?? ''}', '${h['old_value'] ?? '-'}',
              '${h['new_value'] ?? '-'}', _dateTime(h['created_at'])),
      ]);
    t.checklist
      ..clear()
      ..addAll([
        for (final c in (res['checklists'] as List? ?? const []))
          TicketChecklistItem('${c['body'] ?? ''}', id: _int(c['id']), done: c['is_done'] == true || c['is_done'] == 1),
      ]);
    changed();
  }

  Future<void> saveTicket(Ticket? existing, Map<String, Object?> v) async {
    final project = projectByName(v['projectName'] as String);
    if (project == null) throw const ApiException('Pilih proyek');
    final payload = {
      'title': v['title'],
      'description': v['description'],
      'type': v['type'],
      'priority': v['priority'],
    };
    final assignee = _intOrNull(v['assigneeId']);
    Ticket t;
    if (existing == null) {
      final res = await _api.post('/projects/${project.id}/tickets', payload) as Map<String, dynamic>;
      t = _ticket(res, project);
      tickets.insert(0, t);
    } else {
      final res = await _api.put('/tickets/${existing.id}', payload) as Map<String, dynamic>;
      _copyTicket(_ticket(res, project), existing);
      t = existing;
    }
    if (assignee != null && '$assignee' != t.assigneeId) {
      final res = await _api.put('/tickets/${t.id}/assign', {'assignee_id': assignee});
      if (res is Map<String, dynamic>) _copyTicket(_ticket(res, project), t);
    }
    changed();
  }

  /// Ubah status tiket. Mengembalikan pesan server bila perubahan
  /// butuh approval (HTTP 202), selain itu null.
  Future<String?> setTicketStatus(Ticket t, String to, String description) async {
    final res = await _api.put('/tickets/${t.id}/status', {'status': to, 'description': description});
    String? pending;
    if (res is Map<String, dynamic>) {
      if (res['approval'] != null) {
        pending = '${res['message'] ?? 'Butuh persetujuan'}';
        final fresh = await _loadApprovals();
        approvals.insertAll(0, fresh.where((a) => approvalById(a.id) == null));
      } else {
        _copyTicket(_ticket(res, projectById(_int(res['project_id']))), t);
      }
    }
    await loadTicketDetail(t);
    return pending;
  }

  Future<void> addTicketComment(Ticket t, String body) async {
    final c = await _api.post('/tickets/${t.id}/comments', {'body': body}) as Map<String, dynamic>;
    t.comments.add(TaskComment(_userId(c['user'], c['user_id']), '${c['body'] ?? body}', _dateTime(c['created_at'])));
    changed();
  }

  Future<void> addChecklistItem(Ticket t, String body) async {
    final res = await _api.post('/tickets/${t.id}/checklists', {
      'items': [
        {'body': body, 'sort_order': t.checklist.length},
      ],
    });
    for (final c in (res as List? ?? const [])) {
      t.checklist.add(TicketChecklistItem('${c['body'] ?? body}', id: _int(c['id'])));
    }
    changed();
  }

  Future<void> toggleChecklistItem(Ticket t, TicketChecklistItem item) async {
    final res = await _api.put('/tickets/${t.id}/checklists/${item.id}/toggle');
    item.done = res is Map ? (res['is_done'] == true || res['is_done'] == 1) : !item.done;
    changed();
  }

  // ------------------------------------------------------------ customer request

  Future<void> createRequest(Map<String, Object?> v) async {
    final project = projectByName(v['projectName'] as String);
    if (project == null) throw const ApiException('Pilih proyek');
    final res = await _api.post('/requests', {
      'project_id': project.id,
      'title': v['title'],
      'description': v['description'],
      'type': v['type'],
      'priority': v['priority'],
    }) as Map<String, dynamic>;
    requests.insert(0, _request(res, projectName: project.name));
    changed();
  }

  Future<void> approveRequest(CustomerRequest r) => _decideRequest(r, 'approve');
  Future<void> rejectRequest(CustomerRequest r, String reason) => _decideRequest(r, 'reject', {'rejection_reason': reason});
  Future<void> completeRequest(CustomerRequest r) => _decideRequest(r, 'complete');

  Future<void> _decideRequest(CustomerRequest r, String action, [Map<String, Object?>? body]) async {
    final res = await _api.put('/requests/${r.id}/$action', body) as Map<String, dynamic>;
    final fresh = _request(res, projectName: r.projectName);
    r
      ..status = fresh.status
      ..rejectionReason = fresh.rejectionReason
      ..approvedBy = fresh.approvedBy
      ..approvedAt = fresh.approvedAt
      ..completedBy = fresh.completedBy
      ..completedAt = fresh.completedAt;
    changed();
  }

  // ------------------------------------------------------------ approval

  Future<void> decideApproval(Approval a, String decision, String notes) async {
    final res = await _api.put('/approvals/${a.id}/${decision == 'approved' ? 'approve' : 'reject'}', {'notes': notes});
    final json = res is Map ? res['approval'] : null;
    if (json is Map<String, dynamic>) {
      final fresh = _approval(json, mine: false);
      a
        ..status = fresh.status
        ..mine = false;
      a.steps
        ..clear()
        ..addAll(fresh.steps);
    } else {
      a
        ..status = decision
        ..mine = false;
    }
    final ref = a.ref;
    if (ref != null && ref.kind == 'ticket') {
      final t = ticketById(ref.id);
      if (t != null) await loadTicketDetail(t);
    }
    changed();
  }

  Future<List<Approval>> _loadApprovals() async {
    final out = <int, Approval>{};
    Future<List<Map<String, dynamic>>> safe(String path) => _api.getAll(path).catchError((_) => <Map<String, dynamic>>[]);
    final results = await Future.wait([safe('/approvals'), safe('/approvals/mine'), safe('/approvals/pending-for-me')]);
    for (final j in results[0]) {
      out[_int(j['id'])] = _approval(j);
    }
    for (final j in results[1]) {
      out[_int(j['id'])] = _approval(j);
    }
    for (final j in results[2]) {
      out[_int(j['id'])] = _approval(j, mine: true);
    }
    return out.values.toList()..sort((a, b) => b.id.compareTo(a.id));
  }

  // ------------------------------------------------------------ pengguna

  void _registerMe() {
    final me = AuthRepository.instance.currentUser;
    if (me == null) return;
    users['${me.id}'] = PhUser('${me.id}', me.name, isClient: me.roles.contains('client'));
  }

  Future<void> _loadUsers() async {
    try {
      for (final u in await _api.getAll('/users')) {
        final roles = [for (final r in (u['roles'] as List? ?? const [])) r is Map ? '${r['name']}' : '$r'];
        users['${u['id']}'] = PhUser('${u['id']}', '${u['name'] ?? '-'}', isClient: roles.contains('client'));
      }
    } on ApiException {
      // Role client tidak boleh membaca /users; nama diambil dari relasi saja.
    }
  }

  String _userId(Object? json, Object? fallbackId, {bool client = false}) {
    if (json is Map) {
      final id = '${json['id']}';
      users.putIfAbsent(id, () => PhUser(id, '${json['name'] ?? '-'}', isClient: client));
      return id;
    }
    return fallbackId == null ? '' : '$fallbackId';
  }

  // ------------------------------------------------------------ mapper JSON -> model

  Project _project(Map<String, dynamic> j) {
    final clientId = _userId(j['client'], j['client_id'], client: true);
    final members = [
      for (final m in (j['members'] as List? ?? const []))
        ProjectMember(
          id: _int(m['id']),
          userId: _userId(m['user'], m['user_id']),
          role: '${m['role'] ?? ''}',
          maxHoursPerDay: _int(m['max_hours_per_day'], 8),
        ),
    ];
    return Project(
      id: _int(j['id']),
      name: '${j['name'] ?? ''}',
      description: '${j['description'] ?? ''}',
      clientId: clientId,
      managerId: _userId(j['manager'], j['manager_id']),
      status: '${j['status'] ?? 'active'}',
      startDate: _date(j['start_date']),
      endDate: _date(j['end_date']),
      budget: double.tryParse('${j['budget']}') ?? 0,
      budgetThreshold: _int(j['budget_alert_threshold'], 80),
      githubUrl: '${j['github_repo_url'] ?? ''}',
      meetLink: '${j['google_meet_link'] ?? ''}',
      meetAt: _dateTime(j['meeting_starts_at']),
      progress: _int(j['progress']),
      category: clientId.isEmpty ? 'Internal' : 'Client',
      memberColors: [for (var i = 0; i < members.length.clamp(1, 4); i++) _palette[(_int(j['id']) + i) % _palette.length]],
      members: members,
    );
  }

  Milestone _milestone(Map<String, dynamic> j) => Milestone(
        id: _int(j['id']),
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        startDate: _date(j['start_date']),
        dueDate: _date(j['due_date']),
        assignedTo: j['assigned_to'] == null ? '' : '${j['assigned_to']}',
        clientApprovedAt: j['client_approved_at'] == null ? null : _dateTime(j['client_approved_at']),
      );

  TaskEntry _task(Map<String, dynamic> j, Project p) {
    final due = _date(j['due_date']);
    final milestone = j['milestone'] is Map
        ? '${j['milestone']['title']}'
        : p.milestones.where((m) => m.id == _int(j['milestone_id'])).firstOrNull?.title ?? '';
    return TaskEntry(
      id: _int(j['id']),
      projectId: p.id,
      title: '${j['title'] ?? ''}',
      project: p.name,
      priority: switch ('${j['priority']}') {
        'urgent' => TaskPriority.urgent,
        'high' => TaskPriority.high,
        'low' => TaskPriority.low,
        _ => TaskPriority.medium,
      },
      due: due.isEmpty ? '-' : fmtDate(due),
      status: '${j['status'] ?? 'todo'}',
      assignedTo: _userId(j['assignee'], j['assigned_to']),
      createdBy: _userId(j['creator'], j['created_by']),
      milestone: milestone,
      sprint: j['sprint'] is Map ? '${j['sprint']['name']}' : p.sprints.where((s) => s.id == _int(j['sprint_id'])).firstOrNull?.name ?? '',
      startDate: _date(j['start_date']),
      dueDate: due,
      estimatedHours: _int(j['estimated_hours']),
      storyPoints: _int(j['story_points']),
      description: '${j['description'] ?? ''}',
      completionNotes: '${j['completion_notes'] ?? ''}',
    );
  }

  void _copyTask(TaskEntry from, TaskEntry to) {
    to
      ..title = from.title
      ..priority = from.priority
      ..due = from.due
      ..status = from.status
      ..assignedTo = from.assignedTo
      ..milestone = from.milestone
      ..sprint = from.sprint
      ..startDate = from.startDate
      ..dueDate = from.dueDate
      ..estimatedHours = from.estimatedHours
      ..storyPoints = from.storyPoints
      ..description = from.description;
  }

  Ticket _ticket(Map<String, dynamic> j, Project? p) => Ticket(
        id: _int(j['id']),
        projectName: p?.name ?? '',
        milestone: p?.milestones.where((m) => m.id == _int(j['milestone_id'])).firstOrNull?.title ?? '',
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        solution: '${j['solution'] ?? ''}',
        type: '${j['type'] ?? 'bug'}',
        errorCategory: '${j['error_category'] ?? 'other'}',
        priority: '${j['priority'] ?? 'medium'}',
        status: '${j['status'] ?? 'open'}',
        reporterId: _userId(j['reporter'], j['reporter_id']),
        assigneeId: _userId(j['assignee'], j['assignee_id']),
        slaDueAt: _dateTime(j['sla_due_at']),
        slaBreached: j['sla_breached'] == true || j['sla_breached'] == 1,
        slaPaused: j['sla_paused'] == true || j['sla_paused'] == 1,
        escalated: j['escalated_at'] != null,
        resolvedAt: _dateTime(j['resolved_at']),
      );

  void _copyTicket(Ticket from, Ticket to) {
    to
      ..title = from.title
      ..description = from.description
      ..solution = from.solution
      ..type = from.type
      ..priority = from.priority
      ..status = from.status
      ..assigneeId = from.assigneeId.isEmpty ? to.assigneeId : from.assigneeId
      ..slaDueAt = from.slaDueAt
      ..slaBreached = from.slaBreached
      ..slaPaused = from.slaPaused
      ..escalated = from.escalated
      ..resolvedAt = from.resolvedAt;
    if (from.projectName.isNotEmpty) to.projectName = from.projectName;
  }

  CustomerRequest _request(Map<String, dynamic> j, {String? projectName}) => CustomerRequest(
        id: _int(j['id']),
        projectName: projectName ?? (j['project'] is Map ? '${j['project']['name']}' : projectById(_int(j['project_id']))?.name ?? ''),
        customerId: _userId(j['customer'], j['customer_id'], client: true),
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        type: '${j['type'] ?? 'feature_request'}',
        priority: '${j['priority'] ?? 'medium'}',
        status: '${j['status'] ?? 'waiting_approval'}',
        rejectionReason: '${j['rejection_reason'] ?? ''}',
        marketingNotes: '${j['marketing_notes'] ?? ''}',
        reviewedBy: j['reviewed_by'] == null ? '' : '${j['reviewed_by']}',
        approvedBy: _userId(j['approver'], j['approved_by']),
        approvedAt: _dateTime(j['approved_at']),
        completedBy: _userId(j['completer'], j['completed_by']),
        completedAt: _dateTime(j['completed_at']),
        attachment: '${j['attachment_path'] ?? ''}'.split('/').last,
        createdAt: _date(j['created_at']),
      );

  Approval _approval(Map<String, dynamic> j, {bool mine = false}) {
    final policy = j['policy'] is Map ? j['policy'] as Map : const {};
    final target = j['approvable'] is Map ? j['approvable'] as Map : const {};
    final type = '${j['approvable_type'] ?? ''}';
    final isTicket = type.endsWith('BugTicket');
    final meta = j['metadata'] is Map ? j['metadata'] as Map : const {};
    final action = '${j['action'] ?? policy['action'] ?? ''}';
    return Approval(
      id: _int(j['id']),
      module: isTicket ? 'Tiket' : _titleCase('${policy['module'] ?? type.split('\\').last}'),
      action: _approvalActions[action] ?? _titleCase(action),
      label: isTicket
          ? 'TK-${j['approvable_id']} ${target['title'] ?? ''}'.trim()
          : '${target['title'] ?? target['name'] ?? '#${j['approvable_id']}'}',
      requestedBy: _userId(j['requester'], j['requested_by']),
      status: '${j['status'] ?? 'pending'}',
      expiresAt: _dateTime(j['expires_at']),
      flowType: '${policy['flow_type'] ?? 'single'}',
      mine: mine,
      ref: isTicket ? ApprovalRef('ticket', _int(j['approvable_id']), to: '${meta['requested_status'] ?? ''}') : null,
      steps: [
        for (final s in (j['steps'] as List? ?? const []))
          ApprovalStep(
            _userId(s['approver'], s['approver_id']),
            '${s['approver_role'] ?? ''}',
            status: '${s['status'] ?? 'pending'}',
            notes: '${s['notes'] ?? ''}',
            decidedAt: _dateTime(s['decided_at']),
          ),
      ],
    );
  }
}

const _approvalActions = {
  'resolve': 'Selesaikan',
  'close': 'Tutup',
  'start_enhancement': 'Mulai enhancement',
  'escalate': 'Eskalasi',
  'sla_extension': 'Perpanjang SLA',
  'security_disclose': 'Buka info keamanan',
};

const _palette = [0xFF0F7BD4, 0xFF14C6BB, 0xFFFB8C00, 0xFF43A047, 0xFFE53935, 0xFF4FA6E8];

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

int _int(Object? v, [int fallback = 0]) => v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;

int? _intOrNull(Object? v) => int.tryParse('${v ?? ''}');

int? _positiveOrNull(Object? v) {
  final n = int.tryParse('${v ?? ''}');
  return n == null || n < 1 ? null : n;
}

String? _nullIfEmpty(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty ? null : s;
}

/// Tanggal dari API disimpan UTC; dikonversi ke zona lokal sebelum dipotong
/// ke "yyyy-MM-dd" supaya 2026-08-28T17:00Z tampil sebagai 29 Agustus (WIB).
String _date(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? '' : isoDate(d.toLocal());
}

String _dateTime(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}');
  if (d == null) return '';
  final l = d.toLocal();
  return '${isoDate(l)} ${hhmm(l)}';
}
