import '../stitch_frontend_interface_application/auth_repository.dart';
import 'ph_api.dart';
import 'ph_format.dart';
import 'ph_models.dart';
import 'ph_store.dart';
import 'widgets/ph_form.dart';

final _api = PhApi.instance;

/// Sinkronisasi modul HRIS dengan API `/hris/*` ProjectHub Pro: cuti, lembur,
/// reimburse, kasbon, payroll, bonus, gaji, karyawan, hari libur, jadwal
/// shift, dan konfigurasi absensi. Izin user dibaca dari `/hris/me`.
extension HrisRemote on PhStore {
  Future<void> syncHris() async {
    if (hrisSyncing) return;
    // Biasanya dipanggil dari initState: tunda notifikasi sampai build selesai.
    await Future<void>.value();
    if (!AuthRepository.instance.isLoggedIn) {
      hrisError = 'Silakan login untuk memakai HRIS';
      changed();
      return;
    }
    hrisSyncing = true;
    hrisError = null;
    changed();
    try {
      final me = await _api.get('/hris/me') as Map<String, dynamic>;
      hrisPermissions
        ..clear()
        ..addAll([for (final p in (me['permissions'] as List? ?? const [])) '$p']);
      final meId = '${me['id']}';
      users[meId] = PhUser(meId, '${me['name'] ?? '-'}');

      final year = DateTime.now().year;
      final r = await Future.wait<dynamic>([
        _api.get('/hris/leave-types'),
        _api.get('/hris/leaves'),
        _api.get('/hris/overtimes'),
        _api.get('/hris/reimbursements'),
        _api.get('/hris/kasbons'),
        _api.get('/hris/payrolls'),
        _api.get('/hris/bonuses'),
        _api.get('/hris/attendance/holidays?year=$year'),
        _soft('/hris/employees'),
        _soft('/hris/attendance/schedules?from=${isoDate(DateTime(year, DateTime.now().month - 1, 1))}&to=${isoDate(DateTime(year, DateTime.now().month + 2, 0))}'),
      ]);

      leaveTypes
        ..clear()
        ..addAll([for (final t in _list(r[0])) _leaveType(t)]);
      leaveBalances
        ..clear()
        ..addAll([
          for (final t in _list(r[0]))
            if (t['balance'] is Map)
              LeaveBalance(_int(t['id']), _int(t['balance']['year']),
                  quota: _int(t['balance']['quota']), used: _int(t['balance']['used']), carriedOver: _int(t['balance']['carried_over'])),
        ]);
      _replace(leaveRequests, [for (final j in _list(r[1])) _leave(j)]);
      _replace(overtimes, [for (final j in _list(r[2])) _overtime(j)]);
      _replace(reimbursements, [for (final j in _list(r[3])) _reimbursement(j)]);
      _replace(kasbons, [for (final j in _list(r[4])) _kasbon(j)]);
      _replace(payrolls, [for (final j in _list(r[5])) _payroll(j)]);
      _replace(bonuses, [for (final j in _list(r[6])) _bonus(j)]);
      _replace(holidays, [for (final j in _list(r[7])) Holiday(_int(j['id']), '${j['date']}', '${j['name']}')]);
      _replace(employees, [for (final j in _list(r[8])) _employee(j)]);
      _replace(schedules, [
        for (final j in _list(r[9])) ShiftSchedule(_int(j['id']), _uid(j['user_id'], j['user_name']), j['shift_id'] == null ? '' : '${j['shift_id']}', '${j['date']}'),
      ]);
      await _loadSalaries();
      hrisSynced = true;
    } on ApiException catch (e) {
      hrisError = e.message;
    } catch (e) {
      hrisError = 'Gagal memuat data HRIS: $e';
    } finally {
      hrisSyncing = false;
      changed();
    }
  }

  /// GET yang boleh gagal (mis. 403 karena tidak punya izin) tanpa membatalkan sync.
  Future<dynamic> _soft(String path) => _api.get(path).catchError((_) => const <dynamic>[]);

  Future<void> _loadSalaries() async {
    final ids = can('view payroll') ? employees.map((e) => e.id).toList() : [PhStore.meId];
    final results = await Future.wait(ids.map((id) => _soft('/hris/employees/$id/salaries')));
    salaries.clear();
    for (var i = 0; i < ids.length; i++) {
      final list = results[i] is Map ? _list(results[i]['salaries']) : const <Map<String, dynamic>>[];
      if (list.isNotEmpty) salaries[ids[i]] = _salary(list.first);
      if (results[i] is Map && results[i]['status_options'] is Map) {
        ptkpOptions
          ..clear()
          ..addAll({for (final e in (results[i]['status_options'] as Map).entries) '${e.key}': '${e.value}'});
      }
    }
  }

  // ------------------------------------------------------------ cuti

  Future<void> submitLeave(Map<String, Object?> v) async {
    final file = v['attachmentFile'] as PhPickedFile?;
    final fields = {'leave_type_id': v['leaveTypeId'], 'start_date': v['startDate'], 'end_date': v['endDate'], 'reason': v['reason']};
    final res = file == null
        ? await _api.post('/hris/leaves', fields)
        : await _api.upload('/hris/leaves', fields, [ApiFile('attachment', file.name, file.bytes)]);
    leaveRequests.insert(0, _leave(res as Map<String, dynamic>));
    await _refreshLeaveTypes();
  }

  Future<void> decideLeave(LeaveRequest r, String decision, String notes) async {
    final res = decision == 'approved'
        ? await _api.patch('/hris/leaves/${r.id}/approve')
        : await _api.patch('/hris/leaves/${r.id}/reject', {'rejection_reason': notes});
    _swap(leaveRequests, r, _leave(res as Map<String, dynamic>));
    await _refreshLeaveTypes();
  }

  Future<void> cancelLeave(LeaveRequest r) async {
    final res = await _api.delete('/hris/leaves/${r.id}') as Map<String, dynamic>;
    if (res['leave'] is Map<String, dynamic>) {
      _swap(leaveRequests, r, _leave(res['leave'] as Map<String, dynamic>));
    } else {
      leaveRequests.remove(r);
    }
    changed();
  }

  Future<void> _refreshLeaveTypes() async {
    final types = _list(await _api.get('/hris/leave-types'));
    leaveBalances
      ..clear()
      ..addAll([
        for (final t in types)
          if (t['balance'] is Map)
            LeaveBalance(_int(t['id']), _int(t['balance']['year']), quota: _int(t['balance']['quota']), used: _int(t['balance']['used']), carriedOver: _int(t['balance']['carried_over'])),
      ]);
    changed();
  }

  // ------------------------------------------------------------ lembur

  /// Perkiraan upah lembur dari server (jenis hari & tarif mengikuti overtime_rules perusahaan).
  Future<Map<String, dynamic>> previewOvertime(String date, String start, String end) async =>
      await _api.post('/hris/overtimes/preview', {'date': date, 'start_time': start, 'end_time': end}) as Map<String, dynamic>;

  Future<void> submitOvertime(Map<String, Object?> v) async {
    final res = await _api.post('/hris/overtimes', {
      'date': v['date'],
      'start_time': v['startTime'],
      'end_time': v['endTime'],
      'description': v['description'],
    });
    overtimes.insert(0, _overtime(res as Map<String, dynamic>));
    changed();
  }

  Future<void> decideOvertime(Overtime o, String decision, String notes) async {
    final res = decision == 'approved'
        ? await _api.patch('/hris/overtimes/${o.id}/approve')
        : await _api.patch('/hris/overtimes/${o.id}/reject', {'rejection_reason': notes});
    _swap(overtimes, o, _overtime(res as Map<String, dynamic>));
  }

  Future<void> cancelOvertime(Overtime o) async {
    final res = await _api.delete('/hris/overtimes/${o.id}') as Map<String, dynamic>;
    if (res['overtime'] is Map<String, dynamic>) {
      _swap(overtimes, o, _overtime(res['overtime'] as Map<String, dynamic>));
    } else {
      overtimes.remove(o);
      changed();
    }
  }

  // ------------------------------------------------------------ reimburse

  Future<void> submitReimbursement(Map<String, Object?> v) async {
    final file = v['receiptFile'] as PhPickedFile?;
    final fields = {
      'category': v['category'],
      'title': v['title'],
      'description': v['description'],
      'expense_date': v['expenseDate'],
      'amount': v['amount'],
    };
    final res = file == null
        ? await _api.post('/hris/reimbursements', fields)
        : await _api.upload('/hris/reimbursements', fields, [ApiFile('receipt', file.name, file.bytes)]);
    reimbursements.insert(0, _reimbursement(res as Map<String, dynamic>));
    changed();
  }

  Future<void> decideReimbursement(Reimbursement r, String decision, String notes) async {
    final res = decision == 'approved'
        ? await _api.patch('/hris/reimbursements/${r.id}/approve')
        : await _api.patch('/hris/reimbursements/${r.id}/reject', {'rejection_reason': notes});
    _swap(reimbursements, r, _reimbursement(res as Map<String, dynamic>));
  }

  Future<void> cancelReimbursement(Reimbursement r) async {
    final res = await _api.delete('/hris/reimbursements/${r.id}') as Map<String, dynamic>;
    if (res['reimbursement'] is Map<String, dynamic>) {
      _swap(reimbursements, r, _reimbursement(res['reimbursement'] as Map<String, dynamic>));
    } else {
      reimbursements.remove(r);
      changed();
    }
  }

  // ------------------------------------------------------------ kasbon, bonus, payroll, gaji

  Future<void> createKasbon(Map<String, Object?> v) async {
    final res = await _api.post('/hris/kasbons', {
      'user_id': v['userId'],
      'tanggal': v['tanggal'],
      'jumlah': v['jumlah'],
      'cicilan_per_bulan': v['cicilanPerBulan'],
      'keterangan': v['keterangan'],
    });
    kasbons.insert(0, _kasbon(res as Map<String, dynamic>));
    changed();
  }

  Future<void> deleteKasbon(Kasbon k) async {
    await _api.delete('/hris/kasbons/${k.id}');
    kasbons.remove(k);
    changed();
  }

  Future<void> createBonus(Map<String, Object?> v) async {
    final res = await _api.post('/hris/bonuses', {
      'user_id': v['userId'],
      'year': v['year'],
      'month': v['month'],
      'type': v['type'],
      'amount': v['amount'],
      'description': v['description'],
    });
    bonuses.insert(0, _bonus(res as Map<String, dynamic>));
    changed();
  }

  Future<void> deleteBonus(Bonus b) async {
    await _api.delete('/hris/bonuses/${b.id}');
    bonuses.remove(b);
    changed();
  }

  Future<Payroll> generatePayroll(String userId, int year, int month) async {
    final p = _payroll(await _api.post('/hris/payrolls/generate', {'user_id': userId, 'year': year, 'month': month}) as Map<String, dynamic>);
    payrolls
      ..removeWhere((e) => e.id == p.id)
      ..insert(0, p);
    changed();
    return p;
  }

  Future<void> finalizePayroll(Payroll p) async {
    final fresh = _payroll(await _api.patch('/hris/payrolls/${p.id}/finalize') as Map<String, dynamic>);
    final i = payrolls.indexWhere((e) => e.id == p.id);
    if (i >= 0) payrolls[i] = fresh;
    changed();
  }

  /// Simpan gaji karyawan. Data lama diperbarui; [newPeriod] membuat baris
  /// gaji baru (riwayat) dengan tanggal berlaku berbeda.
  Future<void> saveSalary(String userId, Map<String, Object?> v, {bool newPeriod = false}) async {
    final body = {
      'gaji_pokok': v['gajiPokok'],
      'tunjangan_transport': v['tunjanganTransport'],
      'tunjangan_makan': v['tunjanganMakan'],
      'tunjangan_jabatan': v['tunjanganJabatan'],
      'npwp': v['npwp'],
      'status_pajak': v['statusPajak'],
      'bpjs_kesehatan': v['bpjsKesehatan'] == true,
      'bpjs_ketenagakerjaan': v['bpjsKetenagakerjaan'] == true,
      'effective_date': v['effectiveDate'],
    };
    final current = salaries[userId];
    final res = current == null || current.id == 0 || newPeriod
        ? await _api.post('/hris/employees/$userId/salaries', body)
        : await _api.put('/hris/employees/$userId/salaries/${current.id}', body);
    salaries[userId] = _salary(res as Map<String, dynamic>);
    changed();
  }

  // ------------------------------------------------------------ absensi admin

  Future<void> addHoliday(String date, String name) async {
    final j = await _api.post('/hris/attendance/holidays', {'date': date, 'name': name}) as Map<String, dynamic>;
    holidays.add(Holiday(_int(j['id']), '${j['date']}', '${j['name']}'));
    changed();
  }

  Future<void> deleteHoliday(Holiday h) async {
    await _api.delete('/hris/attendance/holidays/${h.id}');
    holidays.remove(h);
    changed();
  }

  /// mode: shift | off | default (hapus jadwal khusus, kembali ke shift profil).
  Future<void> saveSchedule(String userId, String date, String mode, String shiftId) async {
    await _api.post('/hris/attendance/schedules', {
      'user_id': userId,
      'date': date,
      'mode': mode,
      if (mode == 'shift') 'shift_id': shiftId,
    });
    schedules.removeWhere((s) => s.userId == userId && s.date == date);
    if (mode != 'default') schedules.add(ShiftSchedule(nextId(), userId, mode == 'off' ? '' : shiftId, date));
    changed();
  }

  Future<Map<String, dynamic>> loadAttendanceSetting() async => await _api.get('/hris/attendance/setting') as Map<String, dynamic>;

  Future<void> saveAttendanceSetting(Map<String, Object?> v) async {
    await _api.put('/hris/attendance/setting', {
      'is_location_enabled': v['isLocationEnabled'] == true,
      'office_name': v['officeName'],
      'office_latitude': double.tryParse('${v['officeLatitude']}'),
      'office_longitude': double.tryParse('${v['officeLongitude']}'),
      'max_distance_meters': int.tryParse('${v['maxDistanceMeters']}') ?? 100,
      'require_location_for_checkout': v['requireLocationForCheckout'] == true,
      'is_face_recognition_enabled': v['isFaceRecognitionEnabled'] == true,
      'face_recognition_threshold': double.tryParse('${v['faceRecognitionThreshold']}') ?? 0.55,
      'require_face_for_checkout': v['requireFaceForCheckout'] == true,
    });
  }

  // ------------------------------------------------------------ helper & mapper

  void _replace<T>(List<T> target, List<T> fresh) {
    target
      ..clear()
      ..addAll(fresh);
  }

  void _swap<T>(List<T> list, T old, T fresh) {
    final i = list.indexOf(old);
    if (i >= 0) {
      list[i] = fresh;
    } else {
      list.insert(0, fresh);
    }
    changed();
  }

  String _uid(Object? id, Object? name) {
    final key = '${id ?? ''}';
    if (key.isNotEmpty && name != null) users.putIfAbsent(key, () => PhUser(key, '$name'));
    return key;
  }

  LeaveType _leaveType(Map<String, dynamic> j) => LeaveType(
        _int(j['id']),
        '${j['name']}',
        '${j['code'] ?? ''}',
        defaultQuota: _int(j['default_quota']),
        isPaid: j['is_paid'] == true,
        needsAttachment: j['needs_attachment'] == true,
        hasBalance: j['has_balance'] == true,
        eligible: j['eligible'] != false,
        blockedMessage: '${j['blocked_message'] ?? ''}',
      );

  LeaveRequest _leave(Map<String, dynamic> j) => LeaveRequest(
        id: _int(j['id']),
        userId: _uid(j['user_id'], j['user_name']),
        leaveTypeId: _int(j['leave_type_id']),
        startDate: '${j['start_date'] ?? ''}',
        endDate: '${j['end_date'] ?? ''}',
        totalDays: _int(j['total_days']),
        reason: '${j['reason'] ?? ''}',
        attachment: '${j['attachment_url'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        approvedBy: _uid(j['approved_by'], j['approved_by_name']),
        rejectionReason: '${j['rejection_reason'] ?? ''}',
      );

  Overtime _overtime(Map<String, dynamic> j) => Overtime(
        id: _int(j['id']),
        userId: _uid(j['user_id'], j['user_name']),
        date: '${j['date'] ?? ''}',
        dayType: '${j['day_type'] ?? 'weekday'}',
        startTime: '${j['start_time'] ?? ''}',
        endTime: '${j['end_time'] ?? ''}',
        totalHours: (j['total_hours'] as num?)?.toDouble() ?? 0,
        hourlyWage: (j['upah_sejam'] as num?)?.round() ?? 0,
        totalAmount: (j['total_amount'] as num?)?.round() ?? 0,
        breakdown: [
          for (final l in (j['breakdown'] as List? ?? const []))
            OvertimeLine('${l['label']}', (l['hours'] as num?)?.toDouble() ?? 0, (l['multiplier'] as num?)?.toDouble() ?? 0, (l['amount'] as num?)?.round() ?? 0),
        ],
        description: '${j['description'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        approvedBy: _uid(j['approved_by'], j['approved_by_name']),
        rejectionReason: '${j['rejection_reason'] ?? ''}',
      );

  Reimbursement _reimbursement(Map<String, dynamic> j) => Reimbursement(
        id: _int(j['id']),
        userId: _uid(j['user_id'], j['user_name']),
        category: '${j['category'] ?? 'lainnya'}',
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        expenseDate: '${j['expense_date'] ?? ''}',
        amount: (j['amount'] as num?)?.round() ?? 0,
        receipt: '${j['receipt_url'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        approvedBy: _uid(j['approved_by'], j['approved_by_name']),
        rejectionReason: '${j['rejection_reason'] ?? ''}',
        inPayroll: j['in_payroll'] == true,
      );

  Kasbon _kasbon(Map<String, dynamic> j) => Kasbon(
        id: _int(j['id']),
        userId: _uid(j['user_id'], j['user_name']),
        tanggal: '${j['tanggal'] ?? ''}',
        jumlah: (j['jumlah'] as num?)?.round() ?? 0,
        cicilanPerBulan: (j['cicilan_per_bulan'] as num?)?.round() ?? 0,
        sisa: (j['sisa'] as num?)?.round() ?? 0,
        periodeTerakhir: '${j['periode_terakhir'] ?? ''}',
        potonganPeriodeTerakhir: (j['potongan_periode_terakhir'] as num?)?.round() ?? 0,
        status: '${j['status'] ?? 'berjalan'}',
        keterangan: '${j['keterangan'] ?? ''}',
      );

  Bonus _bonus(Map<String, dynamic> j) => Bonus(
        _int(j['id']),
        _uid(j['user_id'], j['user_name']),
        _int(j['year']),
        _int(j['month'], 1),
        '${j['type'] ?? 'bonus'}',
        (j['amount'] as num?)?.round() ?? 0,
        '${j['description'] ?? ''}',
      );

  Payroll _payroll(Map<String, dynamic> j) {
    final pen = j['pendapatan'] as Map? ?? const {};
    final pot = j['potongan'] as Map? ?? const {};
    final tg = j['tanggungan'] as Map? ?? const {};
    final hari = j['hari'] as Map? ?? const {};
    int n(Map m, String k) => (m[k] as num?)?.round() ?? 0;
    final method = '${j['pph21_method'] ?? ''}', scheme = '${j['pph21_scheme'] ?? ''}';
    return Payroll(
      id: _int(j['id']),
      userId: _uid(j['user_id'], j['user_name']),
      year: _int(j['year']),
      month: _int(j['month'], 1),
      status: '${j['status'] ?? 'draft'}',
      paidAt: '${j['paid_at'] ?? ''}',
      gajiPokok: n(pen, 'gaji_pokok'),
      tunjanganTransport: n(pen, 'tunjangan_transport'),
      tunjanganMakan: n(pen, 'tunjangan_makan'),
      tunjanganJabatan: n(pen, 'tunjangan_jabatan'),
      tunjanganLainnya: n(pen, 'tunjangan_lainnya'),
      tunjanganPph21: n(pen, 'tunjangan_pph21'),
      bonus: n(pen, 'bonus'),
      lembur: n(pen, 'lembur'),
      reimburse: n(pen, 'reimburse'),
      hariKerja: n(hari, 'kerja'),
      hariHadir: n(hari, 'hadir'),
      hariCuti: n(hari, 'cuti'),
      hariAlpha: n(hari, 'alpha'),
      potonganAlpha: n(pot, 'alpha'),
      potonganKasbon: n(pot, 'kasbon'),
      potonganBpjsKes: n(pot, 'bpjs_kes'),
      potonganBpjsTk: n(pot, 'bpjs_tk'),
      potonganPph21: n(pot, 'pph21'),
      potonganLainnya: n(pot, 'lainnya'),
      pph21Scheme: [method, scheme].where((e) => e.isNotEmpty).join(' ').toUpperCase(),
      tanggunganBpjsKes: n(tg, 'bpjs_kes'),
      tanggunganBpjsTk: n(tg, 'bpjs_tk'),
      tanggunganPph21: n(tg, 'pph21'),
      serverBruto: (j['penghasilan_bruto'] as num?)?.round(),
      serverTotalPotongan: (j['total_potongan'] as num?)?.round(),
      serverGajiBersih: (j['gaji_bersih'] as num?)?.round(),
      serverTanggungan: (j['total_tanggungan_perusahaan'] as num?)?.round(),
    );
  }

  EmployeeSalary _salary(Map<String, dynamic> j) => EmployeeSalary(
        id: _int(j['id']),
        gajiPokok: (j['gaji_pokok'] as num?)?.round() ?? 0,
        tunjanganTransport: (j['tunjangan_transport'] as num?)?.round() ?? 0,
        tunjanganMakan: (j['tunjangan_makan'] as num?)?.round() ?? 0,
        tunjanganJabatan: (j['tunjangan_jabatan'] as num?)?.round() ?? 0,
        npwp: '${j['npwp'] ?? ''}',
        statusPajak: '${j['status_pajak'] ?? 'TK/0'}',
        bpjsKesehatan: j['bpjs_kesehatan'] == true,
        bpjsKetenagakerjaan: j['bpjs_ketenagakerjaan'] == true,
        effectiveDate: '${j['effective_date'] ?? ''}',
      );

  Employee _employee(Map<String, dynamic> j) {
    final id = _uid(j['id'], j['name']);
    return Employee(
      id: id,
      name: '${j['name'] ?? ''}',
      email: '${j['email'] ?? ''}',
      employmentType: '${j['employment_type'] ?? 'lainnya'}',
      hireDate: '${j['hire_date'] ?? ''}',
      contractEndDate: '${j['contract_end_date'] ?? ''}',
      organizationUnit: '${j['organization_unit'] ?? '-'}',
      structuralLevel: '${j['structural_level'] ?? '-'}',
      shiftId: j['shift_id'] == null ? '' : '${j['shift_id']}',
      shiftName: '${j['shift_name'] ?? ''}',
      isActive: j['is_active'] != false,
      faceEnrolled: j['face_enrolled'] == true,
    );
  }
}

List<Map<String, dynamic>> _list(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

int _int(Object? v, [int fallback = 0]) => v is int ? v : (v is num ? v.round() : int.tryParse('${v ?? ''}') ?? fallback);
