// lib/features/attendance/presentation/screens/pages/lecturer_timetable_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kIndigo    = Color(0xFF283593);
const _kIndigoMid = Color(0xFF3949AB);
const _kPurpleL   = Color(0xFF6A1B9A);
const _kAmberL    = Color(0xFFF57C00);

// Lecturer includes Saturday
const _kDaysL     = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
const _kDayShortL = ['Mon','Tue','Wed','Thu','Fri','Sat'];

// ─── Pure helpers ─────────────────────────────────────────────────────────────

/// 0=Mon … 4=Fri. Saturday clamps to 5. Sunday clamps to 0.
int _todayIdxL() {
  final w = DateTime.now().weekday; // 1=Mon … 7=Sun
  if (w >= 1 && w <= 6) return w - 1;  // Mon-Sat → 0-5
  return 0;                             // Sun → show Monday
}

/// "HH:mm" or "H:mm" → minutes since midnight.
int _toMinsL(String t) {
  final p = t.trim().split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Zero-padded sort key — lexicographic == chronological.
String _sortKeyL(Map<String, dynamic> e) {
  final raw = (e['startTime'] as String? ?? '00:00').trim().split(':');
  return '${raw[0].padLeft(2, '0')}:${raw[1].padLeft(2, '0')}';
}

/// Deterministic colour from unit code.
Color _unitColorL(String code) {
  const cols = [
    _kIndigo, Color(0xFF2E7D32), _kPurpleL,
    _kAmberL, Color(0xFFE53935), Color(0xFF00695C),
  ];
  return cols[code.hashCode.abs() % cols.length];
}

enum _ClassStatusL { now, upNext, none }

/// Compute statuses for an entire sorted day list at once.
/// Guarantees exactly one UP-NEXT — the first class whose start is in the future.
List<_ClassStatusL> _computeStatusesL(
    List<Map<String, dynamic>> entries, {required bool isToday}) {
  if (!isToday) return List.filled(entries.length, _ClassStatusL.none);

  final nowM     = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
  bool upNextSet = false;

  return entries.map((e) {
    final start = _toMinsL(e['startTime'] as String? ?? '00:00');
    final end   = _toMinsL(e['endTime']   as String? ?? '00:00');
    if (nowM >= start && nowM < end) return _ClassStatusL.now;
    if (start > nowM && !upNextSet) {
      upNextSet = true;
      return _ClassStatusL.upNext;
    }
    return _ClassStatusL.none;
  }).toList();
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class LecturerTimetablePage extends StatefulWidget {
  const LecturerTimetablePage({super.key});
  @override State<LecturerTimetablePage> createState() => _LecturerTimetableState();
}

class _LecturerTimetableState extends State<LecturerTimetablePage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tt = [], _asgn = [];
  bool    _loading  = true;
  String? _error;
  int     _dayIdx   = _todayIdxL();
  bool    _showForm = false;
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _loadAll();
  }

  @override void dispose() { _fade.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    final r0 = await ApiService().get('/timetable');
    final r1 = await ApiService().get('/assignments');
    if (!mounted) return;
    setState(() {
      if (r0.success && r1.success) {
        _tt   = List<Map<String, dynamic>>.from(r0.data?['timetable']   ?? []);
        _asgn = List<Map<String, dynamic>>.from(r1.data?['assignments'] ?? []);
      } else {
        _error = r0.error ?? r1.error ?? 'Failed to load data.';
      }
      _loading = false;
    });
  }

  /// Returns entries for the given day sorted morning → evening.
  List<Map<String, dynamic>> _dayEntries(int idx) =>
      (_tt.where((e) => e['day'] == _kDaysL[idx]).toList()
        ..sort((a, b) => _sortKeyL(a).compareTo(_sortKeyL(b))));

  void _switchDay(int i) {
    setState(() => _dayIdx = i);
    _fade..reset()..forward();
  }

  void _onCreated(Map<String, dynamic> e) =>
      setState(() { _tt.add(e); _showForm = false; });

  void _onUpdated(Map<String, dynamic> u) => setState(() {
    final i = _tt.indexWhere((e) => e['_id'] == u['_id']);
    if (i != -1) _tt[i] = u;
  });

  void _onDeleted(String id) =>
      setState(() => _tt.removeWhere((e) => e['_id'] == id));

  @override
  Widget build(BuildContext context) {
    final entries  = _dayEntries(_dayIdx);
    final isToday  = _dayIdx == _todayIdxL();
    final statuses = _computeStatusesL(entries, isToday: isToday);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: !_showForm && !_loading
          ? FloatingActionButton.extended(
              backgroundColor: _kIndigo,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Slot',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: () => setState(() => _showForm = true),
            )
          : null,
      body: Column(children: [
        _LHeader(totalSlots: _tt.length, todayCount: entries.length,
            onRefresh: _loadAll),
        if (!_showForm)
          _LDaySelector(dayIdx: _dayIdx, tt: _tt, onSelect: _switchDay),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kIndigo))
              : _error != null
                  ? _LErrorView(msg: _error!, onRetry: _loadAll)
                  : _showForm
                      ? _CreateSlotForm(
                          assignments: _asgn,
                          selectedDay: _kDaysL[_dayIdx],
                          onCreated:  _onCreated,
                          onCancel:   () => setState(() => _showForm = false),
                        )
                      : FadeTransition(
                          opacity: CurvedAnimation(
                              parent: _fade, curve: Curves.easeOut),
                          child: _LDayView(
                            entries:   entries,
                            statuses:  statuses,
                            dayName:   _kDaysL[_dayIdx],
                            asgn:      _asgn,
                            onRefresh: _loadAll,
                            onDeleted: _onDeleted,
                            onUpdated: _onUpdated,
                          ),
                        ),
        ),
      ]),
      bottomNavigationBar: _LBottomNav(context),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _LHeader extends StatelessWidget {
  final int totalSlots, todayCount;
  final VoidCallback onRefresh;
  const _LHeader({required this.totalSlots, required this.todayCount,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
          colors: [_kIndigo, _kIndigoMid],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Icon(Icons.calendar_month_rounded,
                color: Colors.white.withOpacity(.8), size: 18),
            const SizedBox(width: 8),
            const Text('My Timetable', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          const SizedBox(height: 4),
          Text('$totalSlots slot${totalSlots != 1 ? 's' : ''} scheduled',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(.75))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('$todayCount', style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('today', style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity(.8))),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: onRefresh,
        ),
      ]),
    )),
  );
}

// ─── Day selector ─────────────────────────────────────────────────────────────

class _LDaySelector extends StatelessWidget {
  final int dayIdx;
  final List<Map<String, dynamic>> tt;
  final void Function(int) onSelect;
  const _LDaySelector({required this.dayIdx, required this.tt,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final today = _todayIdxL();
    return Container(
      color: _kIndigo,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Row(children: List.generate(_kDaysL.length, (i) {
        final sel   = dayIdx == i;
        final count = tt.where((e) => e['day'] == _kDaysL[i]).length;
        return Expanded(child: GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < _kDaysL.length - 1 ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_kDayShortL[i], style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: sel ? _kIndigo : Colors.white)),
              if (i == today) ...[
                const SizedBox(height: 2),
                Container(width: 4, height: 4, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? _kIndigo : Colors.white)),
              ],
              if (count > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: sel ? _kIndigo.withOpacity(.15)
                               : Colors.white.withOpacity(.3),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('$count', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: sel ? _kIndigo : Colors.white)),
                ),
              ],
            ]),
          ),
        ));
      })),
    );
  }
}

// ─── Day view ─────────────────────────────────────────────────────────────────

class _LDayView extends StatelessWidget {
  final List<Map<String, dynamic>> entries, asgn;
  final List<_ClassStatusL>        statuses;
  final String                     dayName;
  final Future<void> Function()    onRefresh;
  final void Function(String)      onDeleted;
  final void Function(Map<String, dynamic>) onUpdated;
  const _LDayView({required this.entries, required this.statuses,
      required this.dayName, required this.asgn,
      required this.onRefresh, required this.onDeleted, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_note_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No classes on $dayName', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
            color: Colors.grey.shade400)),
        const SizedBox(height: 6),
        Text('Tap + New Slot to add one',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ]));
    }
    return RefreshIndicator(
      color: _kIndigo,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: entries.length,
        itemBuilder: (_, i) => _LecturerCard(
          entry:     entries[i],
          status:    statuses[i],
          asgn:      asgn,
          onDeleted: () => onDeleted(entries[i]['_id'] as String),
          onUpdated: onUpdated,
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _LErrorView extends StatelessWidget {
  final String msg; final VoidCallback onRetry;
  const _LErrorView({required this.msg, required this.onRetry});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onRetry,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 8),
      Text('Tap to retry',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ])),
  );
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────

Widget _LBottomNav(BuildContext context) => Container(
  decoration: BoxDecoration(color: Colors.white, boxShadow: [
    BoxShadow(color: Colors.black.withOpacity(.07),
        blurRadius: 20, offset: const Offset(0, -4)),
  ]),
  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
  child: GNav(
    backgroundColor: Colors.white,
    color: Colors.grey.shade500,
    activeColor: Colors.white,
    tabBackgroundColor: _kIndigo,
    gap: 8,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    selectedIndex: 2,
    onTabChange: (i) {
      if (i == 0) context.go('/lecturer-home');
      if (i == 1) context.go('/history');
      if (i == 3) context.go('/settings');
    },
    tabs: const [
      GButton(icon: Icons.home_rounded,           text: 'Home'),
      GButton(icon: Icons.history_rounded,         text: 'History'),
      GButton(icon: Icons.calendar_today_rounded,  text: 'Timetable'),
      GButton(icon: Icons.settings_rounded,        text: 'Settings'),
    ],
  ),
);

// ─── Lecturer card (with edit / delete) ──────────────────────────────────────

class _LecturerCard extends StatelessWidget {
  final Map<String, dynamic>       entry;
  final _ClassStatusL              status;
  final List<Map<String, dynamic>> asgn;
  final VoidCallback               onDeleted;
  final void Function(Map<String, dynamic>) onUpdated;
  const _LecturerCard({required this.entry, required this.status,
      required this.asgn, required this.onDeleted, required this.onUpdated});

  Color get _color =>
      _unitColorL((entry['unit']?['code'] as String? ?? ''));

  Future<void> _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete slot?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will remove the entry for students too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService().delete('/timetable/${entry['_id']}');
    if (ctx.mounted) {
      if (r.success) {
        onDeleted();
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('Slot deleted'), backgroundColor: _kIndigo));
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(r.error ?? 'Failed'), backgroundColor: Colors.red));
      }
    }
  }

  void _edit(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditSlotSheet(
        entry: entry, asgn: asgn, onUpdated: onUpdated),
  );

  @override
  Widget build(BuildContext context) {
    final unit  = entry['unit']  as Map<String, dynamic>? ?? {};
    final code  = unit['code']  as String? ?? '';
    final color = _color;
    final start = entry['startTime'] as String? ?? '';
    final end   = entry['endTime']   as String? ?? '';
    final room  = entry['room']      as String? ?? '';
    final notes = entry['notes']     as String? ?? '';

    final Color  borderColor;
    final double borderWidth;
    final Color  shadowColor;

    switch (status) {
      case _ClassStatusL.now:
        borderColor = color;
        borderWidth = 2.0;
        shadowColor = color.withOpacity(.18);
      case _ClassStatusL.upNext:
        borderColor = _kPurpleL;
        borderWidth = 2.0;
        shadowColor = _kPurpleL.withOpacity(.12);
      case _ClassStatusL.none:
        borderColor = Colors.grey.shade100;
        borderWidth = 1.5;
        shadowColor = Colors.black.withOpacity(.04);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [BoxShadow(
            color: shadowColor, blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(child: Row(children: [

        // Colour bar
        Container(width: 5, decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16)))),

        // Time column
        SizedBox(width: 68, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(start, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
            Container(margin: const EdgeInsets.symmetric(vertical: 3),
                width: 1, height: 10, color: Colors.grey.shade300),
            Text(end, style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
          ]),
        )),

        Container(width: 1, color: Colors.grey.shade100),

        // Content
        Expanded(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Title + status badge
            Row(children: [
              Expanded(child: Text(unit['name'] as String? ?? '—',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B)))),
              if (status == _ClassStatusL.now)
                _LBadge('● ONGOING', color)
              else if (status == _ClassStatusL.upNext)
                _LBadge('▶ UP NEXT', _kPurpleL),
            ]),

            const SizedBox(height: 4),
            _LCodeChip(code: code, color: color),

            if (room.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 12,
                    color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(room, style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ],

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              _LNoteBox(notes),
            ],

            const SizedBox(height: 8),
            // Edit / Delete chips
            Row(children: [
              _ActionChip('Edit', Icons.edit_rounded, _kIndigo,
                  () => _edit(context)),
              const SizedBox(width: 8),
              _ActionChip('Delete', Icons.delete_outline_rounded,
                  const Color(0xFFE53935), () => _delete(context)),
            ]),
          ]),
        )),
      ])),
    );
  }
}

// ─── Create slot form ─────────────────────────────────────────────────────────

class _CreateSlotForm extends StatefulWidget {
  final List<Map<String, dynamic>> assignments;
  final String    selectedDay;
  final void Function(Map<String, dynamic>) onCreated;
  final VoidCallback onCancel;
  const _CreateSlotForm({required this.assignments, required this.selectedDay,
      required this.onCreated, required this.onCancel});
  @override State<_CreateSlotForm> createState() => _CreateSlotFormState();
}

class _CreateSlotFormState extends State<_CreateSlotForm> {
  String? _asgnId;
  String  _day = 'Monday', _start = '08:00', _end = '10:00';
  final   _roomCtrl  = TextEditingController();
  final   _notesCtrl = TextEditingController();
  bool    _saving = false;
  String? _error;

  @override void initState() { super.initState(); _day = widget.selectedDay; }
  @override void dispose() { _roomCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime(bool isStart) async {
    final p = (isStart ? _start : _end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _kIndigo)),
        child: child!),
    );
    if (picked == null) return;
    final f = '${picked.hour.toString().padLeft(2, '0')}'
              ':${picked.minute.toString().padLeft(2, '0')}';
    setState(() => isStart ? _start = f : _end = f);
  }

  Future<void> _submit() async {
    if (_asgnId == null) {
      setState(() => _error = 'Please select a unit.'); return;
    }
    setState(() { _saving = true; _error = null; });
    final r = await ApiService().post('/timetable', {
      'assignmentId': _asgnId, 'day': _day,
      'startTime': _start, 'endTime': _end,
      'room': _roomCtrl.text.trim(), 'notes': _notesCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.success) {
      widget.onCreated(r.data?['entry'] as Map<String, dynamic>? ?? {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slot created!'), backgroundColor: _kIndigo));
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _FormHeader(title: 'Create Timetable Slot',
          icon: Icons.add_box_rounded, onClose: widget.onCancel),
      const SizedBox(height: 14),
      _Label('Unit'),
      DropdownButtonFormField<String>(
        initialValue: _asgnId,
        hint: const Text('Select unit…', style: TextStyle(fontSize: 13)),
        decoration: _dropDec(),
        isExpanded: true,
        items: widget.assignments.map((a) {
          final u = a['unit'] as Map<String, dynamic>? ?? {};
          return DropdownMenuItem(
            value: a['_id'] as String?,
            child: Text('${u['code']} — ${u['name']}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis));
        }).toList(),
        onChanged: (v) => setState(() => _asgnId = v),
      ),
      const SizedBox(height: 12),
      _Label('Day'),
      DropdownButtonFormField<String>(
        initialValue: _day, decoration: _dropDec(),
        items: _kDaysL.map((d) =>
            DropdownMenuItem(value: d, child: Text(d))).toList(),
        onChanged: (v) => setState(() => _day = v!),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [_Label('Start'), _TimeTile(_start, () => _pickTime(true))])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [_Label('End'), _TimeTile(_end, () => _pickTime(false))])),
      ]),
      const SizedBox(height: 12),
      _Label('Room (optional)'),
      _TF(_roomCtrl, 'e.g. LH-3'),
      const SizedBox(height: 12),
      _Label('Notes (optional)'),
      _TF(_notesCtrl, 'Visible to students…', maxLines: 2),
      if (_error != null) ...[const SizedBox(height: 10), _ErrorBanner(_error!)],
      const SizedBox(height: 20),
      _SubmitBtn(label: 'Create Slot', saving: _saving, onTap: _submit),
    ]),
  );
}

// ─── Edit slot bottom sheet ───────────────────────────────────────────────────

class _EditSlotSheet extends StatefulWidget {
  final Map<String, dynamic> entry;
  final List<Map<String, dynamic>> asgn;
  final void Function(Map<String, dynamic>) onUpdated;
  const _EditSlotSheet({required this.entry, required this.asgn,
      required this.onUpdated});
  @override State<_EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends State<_EditSlotSheet> {
  late String _day, _start, _end;
  late TextEditingController _roomCtrl, _notesCtrl;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _day       = widget.entry['day']       as String? ?? 'Monday';
    _start     = widget.entry['startTime'] as String? ?? '08:00';
    _end       = widget.entry['endTime']   as String? ?? '10:00';
    _roomCtrl  = TextEditingController(text: widget.entry['room']  as String? ?? '');
    _notesCtrl = TextEditingController(text: widget.entry['notes'] as String? ?? '');
  }

  @override void dispose() { _roomCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime(bool isStart) async {
    final p = (isStart ? _start : _end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _kIndigo)),
        child: child!),
    );
    if (picked == null) return;
    final f = '${picked.hour.toString().padLeft(2, '0')}'
              ':${picked.minute.toString().padLeft(2, '0')}';
    setState(() => isStart ? _start = f : _end = f);
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final r = await ApiService().patch('/timetable/${widget.entry['_id']}', {
      'day': _day, 'startTime': _start, 'endTime': _end,
      'room': _roomCtrl.text.trim(), 'notes': _notesCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.success) {
      widget.onUpdated(r.data?['entry'] as Map<String, dynamic>? ?? {});
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slot updated!'), backgroundColor: _kIndigo));
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .80, maxChildSize: .95, minChildSize: .5,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
          child: Row(children: [
            const Text('Edit Slot',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Label('Day'),
            DropdownButtonFormField<String>(
              initialValue: _day, decoration: _dropDec(),
              items: _kDaysL.map((d) =>
                  DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _day = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_Label('Start'),
                    _TimeTile(_start, () => _pickTime(true))])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_Label('End'),
                    _TimeTile(_end, () => _pickTime(false))])),
            ]),
            const SizedBox(height: 12),
            _Label('Room'),
            _TF(_roomCtrl, 'e.g. LH-3'),
            const SizedBox(height: 12),
            _Label('Notes'),
            _TF(_notesCtrl, 'Any notes…', maxLines: 2),
            if (_error != null) ...[
              const SizedBox(height: 10), _ErrorBanner(_error!)],
            const SizedBox(height: 20),
            _SubmitBtn(label: 'Save Changes', saving: _saving, onTap: _save),
          ]),
        )),
      ]),
    ),
  );
}

// ─── Tiny shared widgets ──────────────────────────────────────────────────────

class _LBadge extends StatelessWidget {
  final String label; final Color color;
  const _LBadge(this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
    child: Text(label, style: const TextStyle(
        fontSize: 8, fontWeight: FontWeight.w900,
        color: Colors.white, letterSpacing: 0.8)),
  );
}

class _LCodeChip extends StatelessWidget {
  final String code; final Color color;
  const _LCodeChip({required this.code, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(.1), borderRadius: BorderRadius.circular(5)),
    child: Text(code, style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w800, color: color)),
  );
}

class _LNoteBox extends StatelessWidget {
  final String text;
  const _LNoteBox(this.text);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 11, color: _kAmberL),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: const TextStyle(
          fontSize: 10, color: Color(0xFF795548)))),
    ]),
  );
}

class _ActionChip extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _ActionChip(this.label, this.icon, this.color, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

class _FormHeader extends StatelessWidget {
  final String title; final IconData icon; final VoidCallback onClose;
  const _FormHeader({required this.title, required this.icon,
      required this.onClose});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _kIndigo.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kIndigo.withOpacity(.2))),
    child: Row(children: [
      Icon(icon, color: _kIndigo, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800, color: _kIndigo))),
      GestureDetector(
        onTap: onClose,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey)),
      ),
    ]),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
  );
}

class _TimeTile extends StatelessWidget {
  final String time; final VoidCallback onTap;
  const _TimeTile(this.time, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.access_time_rounded, size: 16, color: _kIndigo),
        const SizedBox(width: 6),
        Text(time, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: _kIndigo)),
      ]),
    ),
  );
}

Widget _TF(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
    TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true, fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kIndigo, width: 2)),
      ),
    );

InputDecoration _dropDec() => InputDecoration(
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  filled: true, fillColor: const Color(0xFFF7F7F7),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kIndigo, width: 2)),
);

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10)),
    child: Text(msg, style: const TextStyle(
        fontSize: 12, color: Color(0xFFE53935))),
  );
}

class _SubmitBtn extends StatelessWidget {
  final String label; final bool saving; final VoidCallback onTap;
  const _SubmitBtn({required this.label, required this.saving,
      required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: saving ? null : onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kIndigo, _kIndigoMid]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _kIndigo.withOpacity(.25),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Center(child: saving
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          : Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
    ),
  );
}