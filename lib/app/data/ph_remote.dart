import 'auth_repository.dart';
import 'task_repository.dart';
import '../widgets/task_tile.dart';
import 'ph_api.dart';
import '../utils/ph_format.dart';
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
          _api.get('/projects/$id/sprints').catchError((_) => const <dynamic>[]),
        ]);
        p.milestones.addAll([for (final m in (results[0] as List? ?? const [])) _milestone(m as Map<String, dynamic>)]);
        p.sprints.addAll([for (final s in (results[3] as List? ?? const [])) _sprint(s as Map<String, dynamic>)]);
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
        ..category = fresh.category
        ..images = fresh.images;
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
      _api.getAll('/projects/${p.id}/knowledge-base').catchError((_) => <Map<String, dynamic>>[]),
      _api.get('/projects/${p.id}/team').catchError((_) => null),
      _api.getAll('/projects/${p.id}/tickets').catchError((_) => <Map<String, dynamic>>[]),
      _loadUsers(),
    ]);
    final fresh = _project(r[0] as Map<String, dynamic>);
    if (fresh.images.isNotEmpty) p.images = fresh.images;
    final teamRes = r[7];
    final teamList = teamRes is List
        ? teamRes
        : (teamRes is Map ? (teamRes['members'] ?? teamRes['team'] ?? teamRes['data']) : null);
    final mergedMembers = <ProjectMember>[...fresh.members];
    if (teamList is List) {
      for (final raw in teamList.whereType<Map<String, dynamic>>()) {
        final tm = _member(raw);
        final idx = mergedMembers.indexWhere((e) => e.userId == tm.userId || (e.id != 0 && e.id == tm.id));
        if (idx >= 0) {
          if (mergedMembers[idx].photoUrl.isEmpty && tm.photoUrl.isNotEmpty) {
            mergedMembers[idx].photoUrl = tm.photoUrl;
          }
          if (mergedMembers[idx].images.isEmpty && tm.images.isNotEmpty) {
            mergedMembers[idx].images = tm.images;
          }
          if (mergedMembers[idx].role.isEmpty && tm.role.isNotEmpty) {
            mergedMembers[idx].role = tm.role;
          }
        } else {
          mergedMembers.add(tm);
        }
      }
    }
    for (final m in mergedMembers) {
      final u = users[m.userId];
      if (u != null) {
        if (m.photoUrl.isEmpty && u.photoUrl.isNotEmpty) m.photoUrl = u.photoUrl;
        if (m.images.isEmpty && u.images.isNotEmpty) m.images = u.images;
      }
    }
    p.members
      ..clear()
      ..addAll(mergedMembers);
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
    p.kbDocuments
      ..clear()
      ..addAll([for (final j in (r[6] as List)) _kbDocument(j as Map<String, dynamic>)]);
    final rawTickets = (r[8] as List).isNotEmpty
        ? (r[8] as List)
        : ((r[0] is Map ? (r[0]['tickets'] ?? r[0]['bug_tickets']) : null) as List? ?? const []);
    final projTickets = [for (final j in rawTickets.whereType<Map<String, dynamic>>()) _ticket(j, p)];
    if (projTickets.isNotEmpty || (r[8] as List).isNotEmpty) {
      tickets
        ..removeWhere((t) => t.projectId == p.id || t.projectName == p.name)
        ..addAll(projTickets)
        ..sort((a, b) => b.id.compareTo(a.id));
    }
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
        for (final m in list.whereType<Map<String, dynamic>>()) _member(m),
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

  /// Tautan (Figma/GitHub/Docs/dsb.) disimpan di koleksi file yang sama
  /// dengan tipe 'link', tanpa payload file (beda dari [uploadFile]).
  Future<void> addLink(Project p, String folder, String name, String url, String description) async {
    final res = await _api.post('/projects/${p.id}/files', {
      'folder': folder,
      'name': name,
      'url': url,
      'type': 'link',
      'description': description,
    });
    final list = res is List ? res : [res as Map<String, dynamic>];
    p.files.insertAll(0, [for (final j in list) _file(j as Map<String, dynamic>)]);
    changed();
  }

  // ------------------------------------------------------------ knowledge base

  KbDocument _kbDocument(Map<String, dynamic> j) {
    final attachmentsJson = j['attachments'] ?? j['files'];
    return KbDocument(
      id: _int(j['id']),
      category: '${j['category'] ?? 'brd'}',
      title: '${j['title'] ?? ''}',
      summary: '${j['summary'] ?? j['description'] ?? ''}',
      body: '${j['body'] ?? j['content'] ?? ''}',
      version: _int(j['version'], 1),
      authorId: _userId(j['author'] ?? j['user'], j['author_id'] ?? j['user_id']),
      createdAt: _dateTime(j['created_at']),
      attachments: [
        if (attachmentsJson is List)
          for (final a in attachmentsJson)
            if (a is Map) KbAttachment(id: _int(a['id']), name: '${a['name'] ?? a['file_name'] ?? ''}', url: '${a['url'] ?? ''}', size: _int(a['size'])),
      ],
    );
  }

  Future<void> saveKbDocument(Project p, KbDocument? existing, Map<String, Object?> v, {ApiFile? attachment}) async {
    final fields = {
      'category': v['category'],
      'title': v['title'],
      'summary': _nullIfEmpty(v['summary']),
      'body': _nullIfEmpty(v['body']),
    };
    final Map<String, dynamic> res;
    if (existing == null) {
      res = (attachment == null
          ? await _api.post('/projects/${p.id}/knowledge-base', fields)
          : await _api.upload('/projects/${p.id}/knowledge-base', fields, [ApiFile('attachments[]', attachment.name, attachment.bytes)])) as Map<String, dynamic>;
      p.kbDocuments.insert(0, _kbDocument(res));
    } else {
      res = (attachment == null
          ? await _api.put('/projects/${p.id}/knowledge-base/${existing.id}', fields)
          : await _api.upload('/projects/${p.id}/knowledge-base/${existing.id}', fields, [ApiFile('attachments[]', attachment.name, attachment.bytes)])) as Map<String, dynamic>;
      final fresh = _kbDocument(res);
      existing
        ..category = fresh.category
        ..title = fresh.title
        ..summary = fresh.summary
        ..body = fresh.body
        ..version = fresh.version
        ..attachments.clear()
        ..attachments.addAll(fresh.attachments);
    }
    changed();
  }

  Future<void> deleteKbDocument(Project p, KbDocument d) async {
    await _api.delete('/projects/${p.id}/knowledge-base/${d.id}');
    p.kbDocuments.remove(d);
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
        leadId: _userId(j['lead'], j['lead_id']),
        priority: '${j['priority'] ?? ''}',
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

  ProjectFile _file(Map<String, dynamic> j) {
    final url = '${j['url'] ?? j['link'] ?? ''}';
    final mime = '${j['mime_type'] ?? ''}';
    final taskJson = j['task'];
    return ProjectFile(
      id: _int(j['id']),
      url: url,
      folder: '${j['folder'] ?? 'General'}',
      name: '${j['name'] ?? j['title'] ?? ''}',
      mimeType: mime,
      size: _int(j['size']),
      description: '${j['description'] ?? ''}',
      type: '${j['type'] ?? (mime.isEmpty && url.startsWith('http') ? 'link' : 'file')}',
      taskId: j['task_id'] == null ? '' : '${j['task_id']}',
      taskTitle: '${j['task_title'] ?? (taskJson is Map ? taskJson['title'] : null) ?? ''}',
      uploaderId: _userId(j['uploaded_by'] ?? j['user'], j['uploaded_by_id'] ?? j['user_id']),
      createdAt: _dateTime(j['created_at']),
    );
  }

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
    t.commentsCount = t.comments.length;
    t.history
      ..clear()
      ..addAll([
        for (final h in (res['histories'] as List? ?? const []).reversed)
          TicketHistory(
            _userId(h['actor'], h['actor_id']),
            '${h['field_changed'] ?? ''}',
            '${h['old_value'] ?? '-'}',
            '${h['new_value'] ?? '-'}',
            _dateTime(h['created_at']),
            description: '${h['description'] ?? h['notes'] ?? ''}',
          ),
      ]);
    t.checklist
      ..clear()
      ..addAll([
        for (final c in (res['checklists'] as List? ?? const []))
          TicketChecklistItem('${c['body'] ?? ''}', id: _int(c['id']), done: c['is_done'] == true || c['is_done'] == 1),
      ]);
    changed();
  }

  Future<void> saveTicket(Ticket? existing, Map<String, Object?> v, {ApiFile? attachment}) async {
    final project = projectByName('${v['projectName'] ?? ''}');
    if (project == null) throw const ApiException('Pilih proyek');
    final milestoneId = project.milestones.where((m) => m.title == v['milestone']).firstOrNull?.id;
    final rawAssignees = v['assigneeIds'];
    final assigneeIds = <int>[
      if (rawAssignees is List)
        for (final id in rawAssignees)
          if (_intOrNull(id) != null) _intOrNull(id)!,
      if (rawAssignees == null && _intOrNull(v['assigneeId']) != null) _intOrNull(v['assigneeId'])!,
    ];
    final primaryAssignee = assigneeIds.firstOrNull ?? _intOrNull(v['assigneeId']);
    final payload = <String, Object?>{
      'title': v['title'],
      'description': v['description'],
      'type': v['type'],
      'priority': v['priority'],
      if (v['status'] != null && '${v['status']}'.isNotEmpty) 'status': v['status'],
      'error_category': _nullIfEmpty(v['errorCategory']),
      'milestone_id': milestoneId,
      if (primaryAssignee != null) 'assignee_id': primaryAssignee,
      if (assigneeIds.isNotEmpty) 'assignee_ids': assigneeIds,
    };
    Ticket t;
    if (existing == null) {
      final res = (attachment == null
          ? await _api.post('/projects/${project.id}/tickets', payload)
          : await _api.upload('/projects/${project.id}/tickets', payload, [ApiFile('attachments[]', attachment.name, attachment.bytes)])) as Map<String, dynamic>;
      t = _ticket(res, project);
      tickets.insert(0, t);
    } else {
      final prevStatus = existing.status;
      final res = (attachment == null
          ? await _api.put('/tickets/${existing.id}', payload)
          : await _api.upload('/tickets/${existing.id}', payload, [ApiFile('attachments[]', attachment.name, attachment.bytes)])) as Map<String, dynamic>;
      _copyTicket(_ticket(res, project), existing);
      t = existing;
      final newStatus = '${v['status'] ?? ''}'.trim();
      if (newStatus.isNotEmpty && newStatus != prevStatus && t.status != newStatus) {
        await setTicketStatus(t, newStatus, 'Status diperbarui melalui Edit Tiket');
      }
    }
    if (primaryAssignee != null && '$primaryAssignee' != t.assigneeId) {
      final res = await _api.put('/tickets/${t.id}/assign', {
        'assignee_id': primaryAssignee,
        if (assigneeIds.isNotEmpty) 'assignee_ids': assigneeIds,
      }).catchError((_) => null);
      if (res is Map<String, dynamic>) _copyTicket(_ticket(res, project), t);
    }
    if (assigneeIds.isNotEmpty) {
      t.assigneeIds = [for (final id in assigneeIds) '$id'];
      t.assigneeId = '${assigneeIds.first}';
    }
    changed();
  }

  /// Simpan Kategori Error, Solusi / Catatan Perbaikan Teknis, dan lampiran file dari Detail Tiket.
  Future<void> saveTicketSolution(Ticket t, {required String errorCategory, required String solution, ApiFile? attachment}) async {
    final project = t.projectId != 0 ? projectById(t.projectId) : projectByName(t.projectName);
    final payload = <String, Object?>{
      'title': t.title,
      'description': t.description,
      'type': t.type,
      'priority': t.priority,
      'error_category': _nullIfEmpty(errorCategory),
      'solution': _nullIfEmpty(solution),
    };
    final res = attachment == null
        ? await _api.put('/tickets/${t.id}', payload)
        : await _api.upload('/tickets/${t.id}', payload, [ApiFile('attachments[]', attachment.name, attachment.bytes)]);
    if (res is Map<String, dynamic>) {
      _copyTicket(_ticket(res, project), t);
    } else {
      t.errorCategory = errorCategory;
      t.solution = solution;
    }
    await loadTicketDetail(t);
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
    t.commentsCount = t.comments.length;
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
    if (me.raw.isNotEmpty) {
      upsertPhUser(me.raw, fallbackId: me.id, client: me.roles.contains('client'));
      return;
    }
    final id = '${me.id}';
    final prev = users[id];
    users[id] = PhUser(
      id,
      me.name.isNotEmpty ? me.name : (prev?.name ?? '-'),
      isClient: me.roles.contains('client') || (prev?.isClient ?? false),
      email: me.email.isNotEmpty ? me.email : (prev?.email ?? ''),
      photoUrl: prev?.photoUrl ?? '',
      images: prev?.images ?? const [],
      joinedAt: prev?.joinedAt ?? '',
      role: me.roles.isNotEmpty ? me.roles.first : (prev?.role ?? ''),
    );
  }

  /// Simpan atau gabungkan data pengguna dari respons API ke [users] tanpa
  /// menghapus field (`photoUrl`, `images`, `email`, `joinedAt`, `role`) yang
  /// sudah terisi sebelumnya bila respons parsial.
  String upsertPhUser(
    Map<dynamic, dynamic> json, {
    Object? fallbackId,
    bool client = false,
    Map<dynamic, dynamic>? extra,
  }) {
    final rawId = json['user_id'] ?? fallbackId ?? json['id'];
    final id = '${rawId ?? ''}'.trim();
    if (id.isEmpty || id == 'null') return '';
    final prev = users[id];
    final roles = [
      for (final r in (json['roles'] as List? ?? extra?['roles'] as List? ?? const []))
        r is Map ? '${r['name'] ?? ''}' : '$r',
    ].where((s) => s.isNotEmpty).toList();
    final rawName = '${json['name'] ?? json['user_name'] ?? extra?['user_name'] ?? extra?['name'] ?? ''}'.trim();
    final name = rawName.isNotEmpty ? rawName : (prev?.name ?? '-');
    final rawEmail = '${json['email'] ?? extra?['email'] ?? ''}'.trim();
    final email = rawEmail.isNotEmpty ? rawEmail : (prev?.email ?? '');
    final rawPhone = '${json['phone'] ?? json['phone_number'] ?? json['no_hp'] ?? json['whatsapp'] ?? extra?['phone'] ?? ''}'.trim();
    final phone = rawPhone.isNotEmpty ? rawPhone : (prev?.phone ?? '');
    final imgs = <String>[
      ...extractUserImages(json),
      if (extra != null) ...extractUserImages(extra),
      ...(prev?.images ?? const []),
    ];
    final uniqueImgs = <String>[];
    for (final url in imgs) {
      if (url.isNotEmpty && !uniqueImgs.contains(url)) uniqueImgs.add(url);
    }
    final photoUrl = uniqueImgs.isNotEmpty ? uniqueImgs.first : (prev?.photoUrl ?? '');
    final rawJoined = _date(
      json['created_at'] ??
          json['joined_at'] ??
          json['hire_date'] ??
          extra?['created_at'] ??
          extra?['joined_at'] ??
          extra?['hire_date'],
    );
    final joinedAt = rawJoined.isNotEmpty ? rawJoined : (prev?.joinedAt ?? '');
    final rawRole = roles.isNotEmpty ? roles.first : '${json['role'] ?? ''}'.trim();
    final role = rawRole.isNotEmpty ? rawRole : (prev?.role ?? '');
    final rawStatus = '${json['status'] ?? extra?['status'] ?? ''}'.toLowerCase().trim();
    final rawActive = json['is_active'] ?? json['active'] ?? extra?['is_active'] ?? extra?['active'];
    final isActive = rawActive == false || rawActive == 0 || rawStatus == 'inactive' || rawStatus == 'nonaktif' || rawStatus == 'suspended'
        ? false
        : (rawActive == true || rawActive == 1 || rawStatus == 'active' || rawStatus == 'aktif'
            ? true
            : (prev?.isActive ?? true));
    users[id] = PhUser(
      id,
      name,
      isClient: client || roles.contains('client') || role.toLowerCase() == 'client' || (prev?.isClient ?? false),
      isActive: isActive,
      email: email,
      phone: phone,
      photoUrl: photoUrl,
      images: uniqueImgs,
      joinedAt: joinedAt,
      role: role,
    );
    return id;
  }

  Future<void> saveClientUser(PhUser? existing, Map<String, Object?> body) async {
    final name = '${body['name'] ?? ''}'.trim();
    final email = '${body['email'] ?? ''}'.trim();
    final statusStr = '${body['status'] ?? 'active'}';
    final isActive = statusStr != 'inactive';
    final password = '${body['password'] ?? ''}'.trim();
    final payload = <String, Object?>{
      'name': name,
      'email': email,
      'role': 'client',
      'roles': ['client'],
      'is_client': true,
      'is_active': isActive,
      'status': isActive ? 'active' : 'inactive',
      if (password.isNotEmpty) 'password': password,
    };

    try {
      if (existing == null) {
        final res = await _api.post('/clients', payload).catchError((_) => _api.post('/users', payload));
        if (res is Map) {
          final data = res['client'] ?? res['user'] ?? res['data'] ?? res;
          if (data is Map) {
            upsertPhUser(data, client: true);
            changed();
            return;
          }
        }
      } else {
        final res = await _api
            .put('/clients/${existing.id}', payload)
            .catchError((_) => _api.put('/users/${existing.id}', payload));
        if (res is Map) {
          final data = res['client'] ?? res['user'] ?? res['data'] ?? res;
          if (data is Map) {
            upsertPhUser(data, fallbackId: existing.id, client: true);
            changed();
            return;
          }
        }
      }
    } catch (_) {
      // Fallback update di memori bila endpoint khusus admin client belum tersedia
    }

    final id = existing?.id ?? '${nextId()}';
    final prev = users[id];
    users[id] = PhUser(
      id,
      name.isEmpty ? (prev?.name ?? 'Klien Baru') : name,
      isClient: true,
      isActive: isActive,
      email: email,
      photoUrl: prev?.photoUrl ?? '',
      images: prev?.images ?? const [],
      joinedAt: prev?.joinedAt.isNotEmpty == true ? prev!.joinedAt : isoDate(DateTime.now()),
      role: 'client',
    );
    changed();
  }

  Future<void> deleteClientUser(PhUser client) async {
    try {
      await _api.delete('/clients/${client.id}').catchError((_) => _api.delete('/users/${client.id}'));
    } catch (_) {
      // Tetap hapus dari daftar lokal bila endpoint mengembalikan error
    }
    users.remove(client.id);
    changed();
  }

  Future<void> _loadUsers() async {
    try {
      final results = await Future.wait<dynamic>([
        _api.getAll('/users').catchError((_) => <Map<String, dynamic>>[]),
        _api.get('/hris/employees').catchError((_) => const <dynamic>[]),
      ]);
      for (final u in (results[0] as List)) {
        if (u is Map) upsertPhUser(u);
      }
      final empRes = results[1];
      final empList = empRes is List
          ? empRes
          : (empRes is Map ? (empRes['employees'] ?? empRes['data']) : null);
      if (empList is List) {
        for (final e in empList) {
          if (e is Map) upsertPhUser(e);
        }
      }
    } catch (_) {
      // Role client tidak boleh membaca /users; nama diambil dari relasi saja.
    }
  }

  String _userId(Object? json, Object? fallbackId, {bool client = false, Map<dynamic, dynamic>? extra}) {
    if (json is Map) {
      return upsertPhUser(json, fallbackId: fallbackId, client: client, extra: extra);
    }
    if (extra != null && fallbackId != null) {
      return upsertPhUser(extra, fallbackId: fallbackId, client: client);
    }
    return fallbackId == null ? '' : '$fallbackId';
  }

  ProjectMember _member(Map<String, dynamic> m) {
    final pivot = m['pivot'] is Map ? m['pivot'] as Map : null;
    final userMap = m['user'] is Map ? m['user'] as Map : null;
    final rawUserId = userMap?['id'] ?? m['user_id'] ?? pivot?['user_id'] ?? m['id'];
    final uid = _userId(userMap, rawUserId, extra: m);
    final imgs = <String>[
      ...extractUserImages(m),
      ...(users[uid]?.images ?? const []),
    ];
    final uniqueImgs = <String>[];
    for (final url in imgs) {
      if (url.isNotEmpty && !uniqueImgs.contains(url)) uniqueImgs.add(url);
    }
    final role = '${m['role'] ?? pivot?['role'] ?? ''}'.trim();
    final maxHours = _int(m['max_hours_per_day'] ?? pivot?['max_hours_per_day'], 8);
    return ProjectMember(
      id: _int(m['id']),
      userId: uid,
      role: role,
      maxHoursPerDay: maxHours,
      photoUrl: uniqueImgs.isNotEmpty ? uniqueImgs.first : (users[uid]?.photoUrl ?? ''),
      images: uniqueImgs,
    );
  }

  // ------------------------------------------------------------ mapper JSON -> model

  Project _project(Map<String, dynamic> j) {
    final clientId = _userId(j['client'], j['client_id'], client: true);
    final rawMembers = j['members'] ?? j['team'] ?? j['team_members'];
    final members = [
      for (final m in (rawMembers is List ? rawMembers : const []).whereType<Map<String, dynamic>>()) _member(m),
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
      images: _images(j['images']),
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

  Ticket _ticket(Map<String, dynamic> j, Project? p) {
    final pid = p?.id ?? _int(j['project_id'] ?? (j['project'] is Map ? j['project']['id'] : null));
    final proj = p ?? (pid != 0 ? projectById(pid) : null);
    final pname = proj?.name ?? (j['project'] is Map ? '${j['project']['name'] ?? ''}' : '${j['project_name'] ?? ''}');
    final directAssignee = _userId(j['assignee'], j['assignee_id']);
    final assigneeIds = <String>[
      if (directAssignee.isNotEmpty) directAssignee,
      if (j['assignees'] is List)
        for (final a in j['assignees'] as List)
          if (a is Map)
            _userId(a, a['id'])
          else if ('$a'.trim().isNotEmpty)
            '$a'.trim(),
    ];
    final uniqueAssignees = <String>[];
    for (final id in assigneeIds) {
      if (id.isNotEmpty && !uniqueAssignees.contains(id)) uniqueAssignees.add(id);
    }
    final milestone = j['milestone'] is Map
        ? '${j['milestone']['title'] ?? ''}'
        : (proj?.milestones.where((m) => m.id == _int(j['milestone_id'])).firstOrNull?.title ?? '${j['milestone'] ?? ''}');
    final rawAttachments = j['attachments'] ?? j['files'];
    return Ticket(
      id: _int(j['id']),
      projectId: pid,
      projectName: pname,
      milestone: milestone,
      title: '${j['title'] ?? ''}',
      description: '${j['description'] ?? ''}',
      solution: '${j['solution'] ?? ''}',
      type: '${j['type'] ?? 'bug'}',
      errorCategory: '${j['error_category'] ?? ''}',
      priority: '${j['priority'] ?? 'medium'}',
      status: '${j['status'] ?? 'open'}',
      reporterId: _userId(j['reporter'] ?? j['creator'] ?? j['user'], j['reporter_id'] ?? j['created_by'] ?? j['user_id']),
      assigneeId: uniqueAssignees.firstOrNull ?? '',
      assigneeIds: uniqueAssignees,
      createdAt: _dateTime(j['created_at']),
      slaDueAt: _dateTime(j['sla_due_at']),
      slaBreached: j['sla_breached'] == true || j['sla_breached'] == 1,
      slaPaused: j['sla_paused'] == true || j['sla_paused'] == 1,
      escalated: j['escalated_at'] != null,
      resolvedAt: _dateTime(j['resolved_at']),
      meetLink: '${j['google_meet_link'] ?? j['meet_link'] ?? ''}',
      commentsCount: _int(j['comments_count'], j['comments'] is List ? (j['comments'] as List).length : 0),
      attachments: [
        if (rawAttachments is List)
          for (final a in rawAttachments)
            if (a is Map)
              KbAttachment(
                id: _int(a['id']),
                name: '${a['name'] ?? a['file_name'] ?? a['original_name'] ?? ''}',
                url: _resolveMediaUrl('${a['url'] ?? a['path'] ?? a['file_path'] ?? ''}'),
                size: _int(a['size'] ?? a['file_size']),
              ),
      ],
    );
  }

  void _copyTicket(Ticket from, Ticket to) {
    to
      ..title = from.title
      ..description = from.description
      ..solution = from.solution
      ..type = from.type
      ..errorCategory = from.errorCategory
      ..milestone = from.milestone.isEmpty ? to.milestone : from.milestone
      ..priority = from.priority
      ..status = from.status
      ..assigneeId = from.assigneeId.isEmpty ? to.assigneeId : from.assigneeId
      ..assigneeIds = from.assigneeIds.isEmpty ? to.assigneeIds : from.assigneeIds
      ..createdAt = from.createdAt.isEmpty ? to.createdAt : from.createdAt
      ..slaDueAt = from.slaDueAt
      ..slaBreached = from.slaBreached
      ..slaPaused = from.slaPaused
      ..escalated = from.escalated
      ..resolvedAt = from.resolvedAt
      ..meetLink = from.meetLink.isEmpty ? to.meetLink : from.meetLink
      ..commentsCount = from.commentsCount > 0 ? from.commentsCount : to.commentsCount;
    if (from.attachments.isNotEmpty) {
      to.attachments
        ..clear()
        ..addAll(from.attachments);
    }
    if (from.projectId != 0) to.projectId = from.projectId;
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

const _userImageKeys = [
  'images',
  'image',
  'image_url',
  'image_path',
  'avatar',
  'avatar_url',
  'avatar_path',
  'photo',
  'photo_url',
  'photo_path',
  'profile_photo_url',
  'profile_photo_path',
  'user_images',
  'user_image',
  'user_avatar',
  'user_photo',
  'face_photo',
  'face_photo_url',
  'media',
];

/// Ekstrak daftar URL gambar dari objek pengguna/anggota (mendukung field
/// `images`, `image`, `avatar`, `photo`, `profile_photo_url`, `foto`, dsb.,
/// termasuk objek bersarang `user`, `employee`, `profile`).
List<String> extractUserImages(Map<dynamic, dynamic> json) {
  final out = <String>[];
  for (final k in _userImageKeys) {
    for (final url in _images(json[k])) {
      if (url.isNotEmpty && !out.contains(url)) out.add(url);
    }
  }
  for (final entry in json.entries) {
    final k = '${entry.key}'.toLowerCase();
    if (k.contains('descriptor') || k.contains('threshold') || k.contains('enrolled') || k.contains('require') || k.contains('enable')) {
      continue;
    }
    if (k.contains('image') || k.contains('img') || k.contains('avatar') || k.contains('photo') || k.contains('foto') || k.contains('pic') || k.contains('thumb') || k.contains('face')) {
      for (final url in _images(entry.value)) {
        if (url.isNotEmpty && !out.contains(url)) out.add(url);
      }
    }
  }
  for (final nestedKey in const ['user', 'employee', 'profile', 'member', 'data']) {
    final nested = json[nestedKey];
    if (nested is Map) {
      for (final url in extractUserImages(nested)) {
        if (url.isNotEmpty && !out.contains(url)) out.add(url);
      }
    }
  }
  return out;
}

/// Daftar gambar dari server. Nilai bisa berupa List (berisi String URL/path
/// atau Map objek gambar), Map tunggal, atau String URL/path langsung.
List<String> _images(Object? v) {
  if (v is List) {
    final out = <String>[];
    for (final e in v) {
      for (final url in _images(e)) {
        if (url.isNotEmpty && !out.contains(url)) out.add(url);
      }
    }
    return out;
  }
  if (v is Map) {
    final raw = '${v['url'] ?? v['path'] ?? v['image_url'] ?? v['image_path'] ?? v['file_path'] ?? v['file_url'] ?? v['original_url'] ?? v['preview_url'] ?? v['src'] ?? v['image'] ?? v['avatar'] ?? v['photo'] ?? ''}'.trim();
    final resolved = _resolveMediaUrl(raw);
    return resolved.isEmpty ? const [] : [resolved];
  }
  if (v is String) {
    final resolved = _resolveMediaUrl(v);
    return resolved.isEmpty ? const [] : [resolved];
  }
  return const [];
}

/// Path dari API Laravel bisa berupa URL penuh atau path relatif disk publik
/// (mis. "project-images/xxx.jpg" atau "/storage/avatars/xxx.jpg") yang
/// disajikan lewat [kStorageBaseUrl].
String _resolveMediaUrl(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty ||
      trimmed == 'null' ||
      trimmed == 'true' ||
      trimmed == 'false' ||
      trimmed == '0' ||
      trimmed == '1' ||
      trimmed.startsWith('[') ||
      trimmed.startsWith('{')) {
    return '';
  }
  if (trimmed.startsWith('http://flovig.com/')) {
    return 'https://flovig.com/${trimmed.substring('http://flovig.com/'.length)}';
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:')) {
    return trimmed;
  }
  var clean = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  if (clean.startsWith('storage/')) clean = clean.substring('storage/'.length);
  return '$kStorageBaseUrl/$clean';
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
