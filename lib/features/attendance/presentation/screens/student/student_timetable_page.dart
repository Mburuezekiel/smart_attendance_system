// lib/features/attendance/presentation/screens/pages/student_timetable_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';

class StudentTimetablePage extends StatefulWidget {
  const StudentTimetablePage({super.key});
  @override
  State<StudentTimetablePage> createState() => _StudentTimetablePageState();
}

class _StudentTimetablePageState extends State<StudentTimetablePage>
    with SingleTickerProviderStateMixin {
  static const _green    = Color(0xFF2E7D32);
  static const _greenMid = Color(0xFF43A047);

  List<Map<String, dynamic>> _timetable = [];
  bool    _loading = true;
  String? _error;
  int     _selectedDayIndex = _todayIndex();

  late AnimationController _fadeCtrl;

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  static const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  static int _todayIndex() {
    final w = DateTime.now().weekday;
    return (w <= 5) ? w - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _loadTimetable();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _loadTimetable() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService().get('/timetable');
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _timetable = List<Map<String, dynamic>>.from(r.data?['timetable'] ?? []);
        _loading   = false;
      });
    } else {
      setState(() { _error = r.error; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _todayEntries {
    final day = _days[_selectedDayIndex];
    return _timetable.where((e) => e['day'] == day).toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
  }

  bool _isNow(Map<String, dynamic> entry) {
    final now   = TimeOfDay.now();
    final start = _parseTime(entry['startTime'] as String? ?? '00:00');
    final end   = _parseTime(entry['endTime']   as String? ?? '00:00');
    final nowM  = now.hour * 60 + now.minute;
    return nowM >= start && nowM < end;
  }

  int _parseTime(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  // How many classes are on the currently selected day
  int get _dayCount => _todayEntries.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(children: [
        _buildHeader(),
        _buildDaySelector(),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : _error != null
                ? _buildError()
                : FadeTransition(
                    opacity: CurvedAnimation(
                        parent: _fadeCtrl, curve: Curves.easeOut),
                    child: _buildDayView(),
                  )),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final mon  = DateTime.now().subtract(
        Duration(days: DateTime.now().weekday - 1));
    final fri  = mon.add(const Duration(days: 4));
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final range = '${mon.day} – ${fri.day} ${months[fri.month - 1]}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_green, _greenMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Icon(Icons.calendar_month_rounded,
                    color: Colors.white.withOpacity(0.8), size: 18),
                const SizedBox(width: 8),
                const Text('My Timetable',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
              const SizedBox(height: 4),
              Text('Week of $range',
                  style: TextStyle(fontSize: 12,
                      color: Colors.white.withOpacity(0.75))),
            ])),
            // Classes today badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('$_dayCount',
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                Text('today',
                    style: TextStyle(fontSize: 10,
                        color: Colors.white.withOpacity(0.8))),
              ]),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadTimetable,
            ),
          ]),
        ),
      ),
    );
  }

  // ── Day selector ─────────────────────────────────────────────────────────────
  Widget _buildDaySelector() {
    final today = _todayIndex();
    return Container(
      color: _green,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: List.generate(_days.length, (i) {
        final isSelected = _selectedDayIndex == i;
        final isToday    = i == today;
        // Count entries for this day
        final count = _timetable
            .where((e) => e['day'] == _days[i])
            .length;
        return Expanded(child: GestureDetector(
          onTap: () {
            setState(() => _selectedDayIndex = i);
            _fadeCtrl..reset()..forward();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < 4 ? 8.0 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_dayShort[i], style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: isSelected ? _green : Colors.white)),
              if (isToday) ...[
                const SizedBox(height: 2),
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? _green : Colors.white)),
              ],
              if (count > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _green.withOpacity(0.15)
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$count',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                          color: isSelected ? _green : Colors.white)),
                ),
              ],
            ]),
          ),
        ));
      })),
    );
  }

  // ── Day view ─────────────────────────────────────────────────────────────────
  Widget _buildDayView() {
    final entries = _todayEntries;
    if (entries.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_available_rounded, size: 64,
            color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No classes on ${_days[_selectedDayIndex]}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: Colors.grey.shade400)),
        const SizedBox(height: 6),
        Text('Enjoy your free day!',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ]));
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadTimetable,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: entries.length,
        itemBuilder: (_, i) => _StudentClassCard(
          entry:   entries[i],
          isNow:   _isNow(entries[i]),
        ),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────
  Widget _buildError() => GestureDetector(
    onTap: _loadTimetable,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(_error!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 8),
      Text('Tap to retry',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ])),
  );

  // ── Bottom nav ───────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, -4))]),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: Colors.white,
        color: Colors.grey.shade500,
        activeColor: Colors.white,
        tabBackgroundColor: _green,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: 2,
        onTabChange: (i) {
          if (i == 0) context.go('/home');
          if (i == 1) context.go('/history');
          if (i == 3) context.go('/settings');
        },
        tabs: const [
          GButton(icon: Icons.home_rounded,            text: 'Home'),
          GButton(icon: Icons.history_rounded,          text: 'History'),
          GButton(icon: Icons.calendar_today_rounded,   text: 'Timetable'),
          GButton(icon: Icons.settings_rounded,         text: 'Settings'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student class card
// ─────────────────────────────────────────────────────────────────────────────

class _StudentClassCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isNow;
  static const _green = Color(0xFF2E7D32);

  const _StudentClassCard({required this.entry, required this.isNow});

  // Pick a consistent colour from the unit code
  Color _unitColor() {
    final colors = [
      const Color(0xFF2E7D32), const Color(0xFF283593),
      const Color(0xFF6A1B9A), const Color(0xFFF57C00),
      const Color(0xFFE53935), const Color(0xFF00695C),
    ];
    final code = (entry['unit']?['code'] as String? ?? '');
    return colors[code.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final unit     = entry['unit']     as Map<String, dynamic>? ?? {};
    final lecturer = entry['lecturer'] as Map<String, dynamic>? ?? {};
    final color    = _unitColor();
    final start    = entry['startTime'] as String? ?? '';
    final end      = entry['endTime']   as String? ?? '';
    final room     = entry['room']      as String? ?? '';
    final notes    = entry['notes']     as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isNow
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(
            color: isNow
                ? color.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          // Colour bar
          Container(width: 5, decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18)))),
          // Time column
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(start, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
              Container(margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 1, height: 12, color: Colors.grey.shade300),
              Text(end, style: TextStyle(fontSize: 11,
                  color: Colors.grey.shade500)),
            ]),
          ),
          Container(width: 1, color: Colors.grey.shade100),
          // Content
          Expanded(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  unit['name'] as String? ?? '—',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B)),
                )),
                if (isNow) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(8)),
                  child: const Text('NOW', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1)),
                ),
              ]),
              const SizedBox(height: 4),
              // Unit code chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(unit['code'] as String? ?? '—',
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w800, color: color)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                if (room.isNotEmpty) ...[
                  Icon(Icons.location_on_outlined, size: 13,
                      color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(room, style: TextStyle(fontSize: 12,
                      color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.person_outline_rounded, size: 13,
                    color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  lecturer['fullName'] as String? ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                )),
              ]),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 12, color: Color(0xFFF57C00)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(notes,
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF795548)))),
                  ]),
                ),
              ],
            ]),
          )),
        ]),
      ),
    );
  }
}