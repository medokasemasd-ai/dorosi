import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'data.dart';
import 'models.dart';

/// Where the app's JSON document lives.
abstract class DataStorage {
  Future<String?> read();
  Future<void> write(String json);
}

class FileStorage implements DataStorage {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/dorosi.json');
  }

  @override
  Future<String?> read() async {
    final f = await _file();
    if (await f.exists()) return f.readAsString();
    // Fall back to the previous good copy if the main file is missing.
    final bak = File('${f.path}.bak');
    if (await bak.exists()) return bak.readAsString();
    return null;
  }

  @override
  Future<void> write(String json) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    if (await f.exists()) await f.copy('${f.path}.bak');
    await tmp.rename(f.path);
  }
}

class MemoryStorage implements DataStorage {
  MemoryStorage([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;
}

class AppStore extends ChangeNotifier {
  AppStore(this._storage);

  final DataStorage _storage;
  AppData data = AppData();
  bool loaded = false;

  /// Called after every change, e.g. to reschedule reminders and refresh the widget.
  void Function(AppData data)? onChanged;

  Timer? _sideEffects;
  final _rand = Random();

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw != null && raw.isNotEmpty) {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('load failed: $e');
    }
    loaded = true;
    notifyListeners();
    onChanged?.call(data);
  }

  Future<void> _commit() async {
    notifyListeners();
    await _storage.write(jsonEncode(data.toJson()));
    _sideEffects?.cancel();
    _sideEffects = Timer(const Duration(milliseconds: 400), () => onChanged?.call(data));
  }

  String exportJson() => const JsonEncoder.withIndent(' ').convert(data.toJson());

  /// Replaces all data with a backup. Throws if the text is not a valid backup.
  Future<void> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || !decoded.containsKey('students')) {
      throw const FormatException('ليس ملف نسخة احتياطية من دروسي');
    }
    data = AppData.fromJson(decoded);
    await _commit();
  }

  // ---- classes ----

  Future<void> saveGroup(Group g) async {
    final i = data.groups.indexWhere((e) => e.id == g.id);
    if (i >= 0) {
      data.groups[i] = g;
    } else {
      data.groups.add(g);
    }
    await _commit();
  }

  Future<void> setGroupArchived(Group g, bool archived) async {
    g.archived = archived;
    g.archivedAt = archived ? dateOnly(DateTime.now()) : null;
    await _commit();
  }

  Future<void> deleteGroup(Group g) async {
    data.groups.removeWhere((e) => e.id == g.id);
    for (final s in data.students) {
      s.priceOverrides.remove(g.id);
      s.hoursOverrides.remove(g.id);
    }
    data.absences.removeWhere((k) => k.startsWith('${g.id}|'));
    data.cancelled.removeWhere((k) => k.startsWith('${g.id}|'));
    await _commit();
  }

  Future<void> setGroupReminder(Group g, {bool? start, bool? end}) async {
    if (start != null) g.remindStart = start;
    if (end != null) g.remindEnd = end;
    await _commit();
  }

  // ---- students ----

  /// Saves [s] and makes it a member of exactly [groupIds].
  Future<void> saveStudent(Student s, Set<String> groupIds) async {
    final i = data.students.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      data.students[i] = s;
    } else {
      data.students.add(s);
    }
    for (final g in data.groups) {
      final has = g.studentIds.contains(s.id);
      if (groupIds.contains(g.id) && !has) g.studentIds.add(s.id);
      if (!groupIds.contains(g.id) && has) g.studentIds.remove(s.id);
    }
    s.priceOverrides.removeWhere((gid, _) => !groupIds.contains(gid));
    s.hoursOverrides.removeWhere((gid, _) => !groupIds.contains(gid));
    await _commit();
  }

  Future<void> setStudentArchived(Student s, bool archived) async {
    s.archived = archived;
    await _commit();
  }

  Future<void> deleteStudent(Student s) async {
    data.students.removeWhere((e) => e.id == s.id);
    for (final g in data.groups) {
      g.studentIds.remove(s.id);
    }
    data.payments.removeWhere((p) => p.studentId == s.id);
    data.absences.removeWhere((k) => k.endsWith('|${s.id}'));
    await _commit();
  }

  // ---- payments ----

  Future<void> addPayment(String studentId, String month, double amount, {String note = ''}) async {
    data.payments.add(Payment(id: newId(), studentId: studentId, month: month, amount: amount, note: note));
    await _commit();
  }

  Future<void> deletePayment(Payment p) async {
    data.payments.removeWhere((e) => e.id == p.id);
    await _commit();
  }

  // ---- attendance and cancellations ----

  Future<void> toggleAbsent(Lesson l, String studentId) async {
    final k = absenceKey(l, studentId);
    if (!data.absences.remove(k)) data.absences.add(k);
    await _commit();
  }

  Future<void> toggleCancelled(Lesson l) async {
    if (!data.cancelled.remove(l.key)) data.cancelled.add(l.key);
    await _commit();
  }

  Future<void> setAbsent(Lesson l, String studentId, bool absent) async {
    final k = absenceKey(l, studentId);
    absent ? data.absences.add(k) : data.absences.remove(k);
    await _commit();
  }

  Future<void> setCancelled(Lesson l, bool cancelled) async {
    cancelled ? data.cancelled.add(l.key) : data.cancelled.remove(l.key);
    await _commit();
  }

  /// Adds a one-off lesson for [g] on [date], e.g. a make-up lesson.
  Future<void> addExtraLesson(Group g, DateTime date, int startMin, int durationMin) async {
    g.sessions.add(DatedSession(date: dateOnly(date), startMin: startMin, durationMin: durationMin));
    await _commit();
  }

  /// Moves [l] to another day and time: a weekly lesson is cancelled for that
  /// day and a make-up lesson is added; an extra lesson is simply moved.
  Future<void> moveLesson(Lesson l, DateTime date, int startMin) async {
    _removeSession(l);
    if (!l.extra && l.group.slots.isNotEmpty) data.cancelled.add(l.key);
    l.group.sessions.add(DatedSession(date: dateOnly(date), startMin: startMin, durationMin: l.durationMin));
    await _commit();
  }

  Future<void> removeExtraLesson(Lesson l) async {
    _removeSession(l);
    data.absences.removeWhere((k) => k.startsWith('${l.key}|'));
    data.cancelled.remove(l.key);
    await _commit();
  }

  void _removeSession(Lesson l) {
    final i = l.group.sessions.indexWhere((s) => dateOnly(s.date) == l.date && s.startMin == l.startMin);
    if (i >= 0) l.group.sessions.removeAt(i);
  }

  Future<void> updateSettings(void Function(Settings s) change) async {
    change(data.settings);
    await _commit();
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
