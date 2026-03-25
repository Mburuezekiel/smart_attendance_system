// lib/features/attendance/presentation/screens/pages/student_timetable_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

const _kGreen    = Color(0xFF2E7D32);
const _kGreenMid = Color(0xFF43A047);
const _kPurple   = Color(0xFF6A1B9A);
const _kAmber    = Color(0xFFF57C00);
const _kDays     = ['Monday','Tuesday','Wednesday','Thursday','Friday'];
const _kDayShort = ['Mon','Tue','Wed','Thu','Fri'];

int _todayIdx() { final w = DateTime.now().weekday; return w <= 5 ? w - 1 : 0; }

/// Converts "HH:mm" → total minutes. Handles both 24-h and padded strings.
int _toMins(String t) {
  final p = t.trim().split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Returns a sort key string "HH:mm" that sorts lexicographically.
String _sortKey(Map<String, dynamic> e) =>
    (e['startTime'] as String? ?? '00:00').padLeft(5, '0');

ClassStatus _status(Map<String, dynamic> e, {required bool isToday}) {
  if (!isToday) return ClassStatus.none;
  final now   = TimeOfDay.now();
  final nowM  = now.hour * 60 + now.minute;
  final start = _toMins(e['startTime'] as String? ?? '00:00');
  final end   = _toMins(e['endTime']   as String? ?? '00:00');
  if (nowM >= start && nowM < end) return ClassStatus.now;
  if (start > nowM && start - nowM <= 30) return ClassStatus.upNext;
  return ClassStatus.none;
}

enum ClassStatus { now, upNext, none }

Color _unitColor(String code) {
  const cols = [_kGreen, Color(0xFF283593), _kPurple,
                _kAmber, Color(0xFFE53935), Color(0xFF00695C)];
  return cols[code.hashCode.abs() % cols.length];
}

// ─── Page ────────────────────────────────────────────────────────────────────

class StudentTimetablePage extends StatefulWidget {
  const StudentTimetablePage({super.key});
  @override State<StudentTimetablePage> createState() => _State();
}

class _State extends State<StudentTimetablePage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tt = [];
  bool    _loading = true;
  String? _error;
  int     _dayIdx  = _todayIdx();
  late AnimationController _fade;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _load();
  }

  @override void dispose() { _fade.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService().get('/timetable');
    if (!mounted) return;
    setState(() {
      if (r.success) {
        _tt = List<Map<String, dynamic>>.from(r.data?['timetable'] ?? []);
      } else {
        _error = r.error;
      }
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _dayEntries(int dayIdx) =>
      _tt.where((e) => e['day'] == _kDays[dayIdx]).toList()
        ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

  void _switchDay(int i) {
    setState(() => _dayIdx = i);
    _fade..reset()..forward();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _dayEntries(_dayIdx);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(children: [
        _Header(
          dayCount: entries.length,
          onRefresh: _load,
          gradient: const LinearGradient(
            colors: [_kGreen, _kGreenMid],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        _DaySelector(
          dayIdx: _dayIdx, tt: _tt, bg: _kGreen,
          activeColor: _kGreen, onSelect: _switchDay),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : _error != null
            ? _ErrorView(msg: _error!, onRetry: _load)
            : FadeTransition(
                opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
                child: _DayView(
                  entries:  entries,
                  dayName:  _kDays[_dayIdx],
                  isToday:  _dayIdx == _todayIdx(),
                  onRefresh: _load,
                  emptyHint: 'Enjoy your free day!',
                  emptyIcon: Icons.event_available_rounded,
                ),
              )),
      ]),
      bottomNavigationBar: _BottomNav(
        active: 2, accentColor: _kGreen,
        onHome: () => context.go('/home'),
        onHistory: () => context.go('/history'),
        onSettings: () => context.go('/settings'),
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int dayCount;
  final VoidCallback onRefresh;
  final Gradient gradient;
  const _Header({required this.dayCount, required this.onRefresh, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final mon   = now.subtract(Duration(days: now.weekday - 1));
    final fri   = mon.add(const Duration(days: 4));
    const m     = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final range = '${mon.day} – ${fri.day} ${m[fri.month - 1]}';

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.calendar_month_rounded, color: Colors.white.withOpacity(.8), size: 18),
              const SizedBox(width: 8),
              const Text('My Timetable', style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
            const SizedBox(height: 4),
            Text('Week of $range', style: TextStyle(fontSize: 12,
                color: Colors.white.withOpacity(.75))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('$dayCount', style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w900, color: Colors.white)),
              Text('today', style: TextStyle(fontSize: 10,
                  color: Colors.white.withOpacity(.8))),
            ]),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: onRefresh),
        ]),
      )),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int dayIdx;
  final List<Map<String, dynamic>> tt;
  final Color bg, activeColor;
  final void Function(int) onSelect;
  const _DaySelector({required this.dayIdx, required this.tt,
      required this.bg, required this.activeColor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final today = _todayIdx();
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Row(children: List.generate(_kDays.length, (i) {
        final sel   = dayIdx == i;
        final count = tt.where((e) => e['day'] == _kDays[i]).length;
        return Expanded(child: GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < _kDays.length - 1 ? 7 : 0),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.white.withOpacity(.15),
              borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_kDayShort[i], style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? activeColor : Colors.white)),
              if (i == today) ...[
                const SizedBox(height: 2),
                Container(width: 4, height: 4, decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? activeColor : Colors.white)),
              ],
              if (count > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: sel ? activeColor.withOpacity(.15)
                               : Colors.white.withOpacity(.3),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('$count', style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: sel ? activeColor : Colors.white)),
                ),
              ],
            ]),
          ),
        ));
      })),
    );
  }
}

class _DayView extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final String dayName, emptyHint;
  final IconData emptyIcon;
  final bool isToday;
  final Future<void> Function() onRefresh;
  const _DayView({required this.entries, required this.dayName,
      required this.isToday, required this.onRefresh,
      required this.emptyHint, required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text('No classes on $dayName', style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
      const SizedBox(height: 6),
      Text(emptyHint, style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
    ]));
    return RefreshIndicator(
      color: _kGreen,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: entries.length,
        itemBuilder: (_, i) => ClassCard(
          entry: entries[i],
          status: _status(entries[i], isToday: isToday),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String msg; final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onRetry,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 8),
      Text('Tap to retry', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ])),
  );
}

class _BottomNav extends StatelessWidget {
  final int active;
  final Color accentColor;
  final VoidCallback onHome, onHistory, onSettings;
  const _BottomNav({required this.active, required this.accentColor,
      required this.onHome, required this.onHistory, required this.onSettings});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(.07),
          blurRadius: 20, offset: const Offset(0, -4))]),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    child: GNav(
      backgroundColor: Colors.white,
      color: Colors.grey.shade500,
      activeColor: Colors.white,
      tabBackgroundColor: accentColor,
      gap: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      selectedIndex: active,
      onTabChange: (i) {
        if (i == 0) onHome();
        if (i == 1) onHistory();
        if (i == 3) onSettings();
      },
      tabs: const [
        GButton(icon: Icons.home_rounded,           text: 'Home'),
        GButton(icon: Icons.history_rounded,         text: 'History'),
        GButton(icon: Icons.calendar_today_rounded,  text: 'Timetable'),
        GButton(icon: Icons.settings_rounded,        text: 'Settings'),
      ],
    ),
  );
}

// ─── Shared class card (used by student view) ─────────────────────────────────

class ClassCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final ClassStatus status;
  const ClassCard({super.key, required this.entry, required this.status});

  @override
  Widget build(BuildContext context) {
    final unit     = entry['unit']     as Map<String, dynamic>? ?? {};
    final lecturer = entry['lecturer'] as Map<String, dynamic>? ?? {};
    final code     = unit['code'] as String? ?? '';
    final color    = _unitColor(code);
    final start    = entry['startTime'] as String? ?? '';
    final end      = entry['endTime']   as String? ?? '';
    final room     = entry['room']      as String? ?? '';
    final notes    = entry['notes']     as String? ?? '';

    final borderColor = status == ClassStatus.now    ? color
                      : status == ClassStatus.upNext ? _kPurple
                      : Colors.grey.shade100;
    final borderWidth = status != ClassStatus.none ? 2.0 : 1.5;
    final shadowColor = status == ClassStatus.now    ? color.withOpacity(.15)
                      : status == ClassStatus.upNext ? _kPurple.withOpacity(.10)
                      : Colors.black.withOpacity(.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(child: Row(children: [
        // Colour bar
        Container(width: 5, decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)))),
        // Time column
        SizedBox(width: 68, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(start, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
            Container(margin: const EdgeInsets.symmetric(vertical: 3),
                width: 1, height: 10, color: Colors.grey.shade300),
            Text(end, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        )),
        Container(width: 1, color: Colors.grey.shade100),
        // Content
        Expanded(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title row + status badge
            Row(children: [
              Expanded(child: Text(unit['name'] as String? ?? '—',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B)))),
              if (status == ClassStatus.now) _Badge('NOW', color),
              if (status == ClassStatus.upNext) _Badge('UP NEXT', _kPurple),
            ]),
            const SizedBox(height: 4),
            // Unit code
            _CodeChip(code: code, color: color),
            const SizedBox(height: 8),
            // Meta row
            Row(children: [
              if (room.isNotEmpty) ...[
                Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(room, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(width: 10),
              ],
              Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Expanded(child: Text(lecturer['fullName'] as String? ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
            ]),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _NoteBox(notes),
            ],
          ]),
        )),
      ])),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge(this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
    child: Text(label, style: const TextStyle(fontSize: 8,
        fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
  );
}

class _CodeChip extends StatelessWidget {
  final String code; final Color color;
  const _CodeChip({required this.code, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(.1), borderRadius: BorderRadius.circular(5)),
    child: Text(code, style: TextStyle(fontSize: 9,
        fontWeight: FontWeight.w800, color: color)),
  );
}

class _NoteBox extends StatelessWidget {
  final String text;
  const _NoteBox(this.text);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 11, color: _kAmber),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: const TextStyle(
          fontSize: 10, color: Color(0xFF795548)))),
    ]),
  );
}