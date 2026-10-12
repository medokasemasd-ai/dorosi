// Data model for the app. Everything is stored locally as one JSON document.

enum GroupKind { individual, group, review }

enum PayType { monthly, perLesson }

/// A lesson that repeats every week on [weekday] (DateTime.monday..sunday).
class WeeklySlot {
  WeeklySlot({required this.weekday, required this.startMin, required this.durationMin});

  int weekday;
  int startMin;
  int durationMin;

  int get endMin => startMin + durationMin;

  Map<String, dynamic> toJson() => {'w': weekday, 's': startMin, 'd': durationMin};

  factory WeeklySlot.fromJson(Map<String, dynamic> j) =>
      WeeklySlot(weekday: j['w'] as int, startMin: j['s'] as int, durationMin: j['d'] as int);

  WeeklySlot copy() => WeeklySlot(weekday: weekday, startMin: startMin, durationMin: durationMin);
}

/// A one-off lesson on a specific date (used for review lessons before exams).
class DatedSession {
  DatedSession({required this.date, required this.startMin, required this.durationMin});

  DateTime date; // date only
  int startMin;
  int durationMin;

  Map<String, dynamic> toJson() => {'date': dateKey(date), 's': startMin, 'd': durationMin};

  factory DatedSession.fromJson(Map<String, dynamic> j) =>
      DatedSession(date: parseDateKey(j['date'] as String), startMin: j['s'] as int, durationMin: j['d'] as int);

  DatedSession copy() => DatedSession(date: date, startMin: startMin, durationMin: durationMin);
}

/// A price that applies from [fromMonth] onwards, so changing the price
/// does not rewrite what was owed in earlier months.
class PriceChange {
  PriceChange({required this.fromMonth, required this.amount});

  String fromMonth; // yyyy-MM
  double amount;

  Map<String, dynamic> toJson() => {'from': fromMonth, 'amount': amount};

  factory PriceChange.fromJson(Map<String, dynamic> j) =>
      PriceChange(fromMonth: j['from'] as String, amount: (j['amount'] as num).toDouble());
}

/// A class: one student (individual), several students (group), or a short
/// series of review lessons before an exam.
class Group {
  Group({
    required this.id,
    required this.name,
    this.stage = '',
    this.kind = GroupKind.group,
    this.payType = PayType.monthly,
    List<PriceChange>? prices,
    List<WeeklySlot>? slots,
    List<DatedSession>? sessions,
    List<String>? studentIds,
    this.remindStart = true,
    this.remindEnd = true,
    this.archived = false,
    this.archivedAt,
    this.notes = '',
    DateTime? createdAt,
  }) : prices = prices ?? [],
       slots = slots ?? [],
       sessions = sessions ?? [],
       studentIds = studentIds ?? [],
       createdAt = createdAt ?? DateTime.now();

  String id;
  String name;
  String stage;
  GroupKind kind;
  PayType payType;
  List<PriceChange> prices;
  List<WeeklySlot> slots;
  List<DatedSession> sessions;
  List<String> studentIds;
  bool remindStart;
  bool remindEnd;
  bool archived;
  DateTime? archivedAt;
  String notes;

  /// First day this class counts for billing.
  DateTime createdAt;

  /// Price in effect for [month] (yyyy-MM).
  double priceFor(String month) {
    if (prices.isEmpty) return 0;
    final sorted = [...prices]..sort((a, b) => a.fromMonth.compareTo(b.fromMonth));
    double p = sorted.first.amount;
    for (final c in sorted) {
      if (c.fromMonth.compareTo(month) <= 0) p = c.amount;
    }
    return p;
  }

  double get currentPrice => priceFor(monthKey(DateTime.now()));

  /// Sets the price from the current month on, keeping earlier months as they were.
  void setPrice(double amount, {DateTime? now}) {
    final m = monthKey(now ?? DateTime.now());
    prices.removeWhere((p) => p.fromMonth.compareTo(m) >= 0);
    if (prices.isEmpty || priceFor(m) != amount) {
      prices.add(PriceChange(fromMonth: prices.isEmpty ? '0000-00' : m, amount: amount));
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stage': stage,
    'kind': kind.name,
    'payType': payType.name,
    'prices': prices.map((e) => e.toJson()).toList(),
    'slots': slots.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'students': studentIds,
    'remindStart': remindStart,
    'remindEnd': remindEnd,
    'archived': archived,
    'archivedAt': archivedAt == null ? null : dateKey(archivedAt!),
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Group.fromJson(Map<String, dynamic> j) => Group(
    id: j['id'] as String,
    name: j['name'] as String,
    stage: (j['stage'] ?? '') as String,
    kind: GroupKind.values.byName((j['kind'] ?? 'group') as String),
    payType: PayType.values.byName((j['payType'] ?? 'monthly') as String),
    prices: ((j['prices'] ?? []) as List).map((e) => PriceChange.fromJson(e as Map<String, dynamic>)).toList(),
    slots: ((j['slots'] ?? []) as List).map((e) => WeeklySlot.fromJson(e as Map<String, dynamic>)).toList(),
    sessions: ((j['sessions'] ?? []) as List).map((e) => DatedSession.fromJson(e as Map<String, dynamic>)).toList(),
    studentIds: ((j['students'] ?? []) as List).cast<String>(),
    remindStart: (j['remindStart'] ?? true) as bool,
    remindEnd: (j['remindEnd'] ?? true) as bool,
    archived: (j['archived'] ?? false) as bool,
    archivedAt: j['archivedAt'] == null ? null : parseDateKey(j['archivedAt'] as String),
    notes: (j['notes'] ?? '') as String,
    createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String) ?? DateTime(2000),
  );
}

class Student {
  Student({
    required this.id,
    required this.name,
    this.phone = '',
    this.stage = '',
    this.family = '',
    this.notes = '',
    Map<String, double>? priceOverrides,
    Map<String, double>? hoursOverrides,
    this.archived = false,
    DateTime? joinedAt,
  }) : priceOverrides = priceOverrides ?? {},
       hoursOverrides = hoursOverrides ?? {},
       joinedAt = joinedAt ?? dateOnly(DateTime.now());

  String id;
  String name;
  String phone;
  String stage;

  /// Students sharing the same family name are siblings.
  String family;
  String notes;

  /// Special price for this student in a given group (e.g. a sibling discount).
  Map<String, double> priceOverrides;

  /// Hours this student is taught in a given group, when shorter than the
  /// lesson (e.g. three siblings sharing a three-hour lesson, one hour each).
  Map<String, double> hoursOverrides;
  bool archived;
  DateTime joinedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'stage': stage,
    'family': family,
    'notes': notes,
    'priceOverrides': priceOverrides,
    'hoursOverrides': hoursOverrides,
    'archived': archived,
    'joinedAt': dateKey(joinedAt),
  };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: (j['phone'] ?? '') as String,
    stage: (j['stage'] ?? '') as String,
    family: (j['family'] ?? '') as String,
    notes: (j['notes'] ?? '') as String,
    priceOverrides: ((j['priceOverrides'] ?? {}) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    hoursOverrides: ((j['hoursOverrides'] ?? {}) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    archived: (j['archived'] ?? false) as bool,
    joinedAt: j['joinedAt'] == null ? DateTime(2000) : parseDateKey(j['joinedAt'] as String),
  );
}

class Payment {
  Payment({
    required this.id,
    required this.studentId,
    required this.month,
    required this.amount,
    DateTime? paidAt,
    this.note = '',
  }) : paidAt = paidAt ?? DateTime.now();

  String id;
  String studentId;
  String month; // yyyy-MM the payment counts for
  double amount;
  DateTime paidAt;
  String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'student': studentId,
    'month': month,
    'amount': amount,
    'paidAt': paidAt.toIso8601String(),
    'note': note,
  };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'] as String,
    studentId: j['student'] as String,
    month: j['month'] as String,
    amount: (j['amount'] as num).toDouble(),
    paidAt: DateTime.tryParse((j['paidAt'] ?? '') as String),
    note: (j['note'] ?? '') as String,
  );
}

class Settings {
  Settings({
    this.remindStart = true,
    this.remindEnd = true,
    this.remindPayment = true,
    this.startLeadMin = 10,
    this.paymentDay = 0,
    this.paymentHour = 20,
    this.currency = 'ج.م',
    this.themeColor = 0,
    this.themeMode = 0,
    this.teacherName = '',
  });

  bool remindStart;
  bool remindEnd;
  bool remindPayment;

  /// Minutes before the lesson start to send the start reminder.
  int startLeadMin;

  /// Day of month for the payment reminder; 0 means the last day of the month.
  int paymentDay;
  int paymentHour;
  String currency;

  /// Index into the app's accent colours.
  int themeColor;

  /// 0 follows the phone, 1 is always light, 2 is always dark.
  int themeMode;

  /// Shown in the greeting on the schedule page.
  String teacherName;

  Map<String, dynamic> toJson() => {
    'remindStart': remindStart,
    'remindEnd': remindEnd,
    'remindPayment': remindPayment,
    'startLeadMin': startLeadMin,
    'paymentDay': paymentDay,
    'paymentHour': paymentHour,
    'currency': currency,
    'themeColor': themeColor,
    'themeMode': themeMode,
    'teacherName': teacherName,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    remindStart: (j['remindStart'] ?? true) as bool,
    remindEnd: (j['remindEnd'] ?? true) as bool,
    remindPayment: (j['remindPayment'] ?? true) as bool,
    startLeadMin: (j['startLeadMin'] ?? 10) as int,
    paymentDay: (j['paymentDay'] ?? 0) as int,
    paymentHour: (j['paymentHour'] ?? 20) as int,
    currency: (j['currency'] ?? 'ج.م') as String,
    themeColor: (j['themeColor'] ?? 0) as int,
    themeMode: (j['themeMode'] ?? 0) as int,
    teacherName: (j['teacherName'] ?? '') as String,
  );
}

// ---- date helpers ----

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int n) => n.toString().padLeft(2, '0');

String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String monthKey(DateTime d) => '${d.year}-${_two(d.month)}';

DateTime parseMonthKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1]);
}
