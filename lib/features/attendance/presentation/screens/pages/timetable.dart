// lib/features/attendance/presentation/screens/pages/timetable.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';

class TimeTablePage extends StatefulWidget {
  const TimeTablePage({super.key});
  @override
  State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  int _selectedDayIndex = _todayIndex();
  late AnimationController _fadeCtrl;

  // ── Role helpers ────────────────────────────────────────────────────────────
  String get _role  => _user?['role'] as String? ?? 'student';
  bool get _isAdmin => _role == 'admin';
  bool get _isLecturer => _role == 'lecturer';

  Color get _accent => switch (_role) {
    'lecturer' => const Color(0xFF283593),
    'admin'    => const Color(0xFF00695C),
    _          => const Color(0xFF2E7D32),
  };
  Color get _accentMid => switch (_role) {
    'lecturer' => const Color(0xFF3949AB),
    'admin'    => const Color(0xFF00796B),
    _          => const Color(0xFF43A047),
  };
  Color get _accentLight => switch (_role) {
    'lecturer' => const Color(0xFFE8EAF6),
    'admin'    => const Color(0xFFE0F2F1),
    _          => const Color(0xFFE8F5E9),
  };
  String get _homePath => switch (_role) {
    'lecturer' => '/lecturer-home',
    'admin'    => '/admin-home',
    _          => '/home',
  };

  static int _todayIndex() {
    final w = DateTime.now().weekday; // 1=Mon…5=Fri
    return (w <= 5) ? w - 1 : 0;
  }

  // ── Static schedule data (replace with API call later) ─────────────────────
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  // Student / Lecturer schedule keyed by day index
  static const _schedule = {
    0: [ // Monday
      _Class('Software Engineering',   '08:00', '10:00', 'Lab C-1',     'Dr. Mwangi',   Color(0xFF2E7D32)),
      _Class('Computer Networks',      '10:00', '12:00', 'Room LH-3',   'Dr. Ochieng',  Color(0xFF283593)),
      _Class('Database Systems',       '13:00', '15:00', 'Lab A-2',     'Dr. Kamau',    Color(0xFF6A1B9A)),
    ],
    1: [ // Tuesday
      _Class('Operating Systems',      '09:00', '11:00', 'Room LH-7',   'Dr. Njoroge',  Color(0xFFF57C00)),
      _Class('Mobile Development',     '13:00', '15:00', 'Lab C-2',     'Dr. Waweru',   Color(0xFF2E7D32)),
    ],
    2: [ // Wednesday
      _Class('Software Engineering',   '08:00', '10:00', 'Lab C-1',     'Dr. Mwangi',   Color(0xFF2E7D32)),
      _Class('Computer Networks',      '11:00', '13:00', 'Room LH-3',   'Dr. Ochieng',  Color(0xFF283593)),
      _Class('Algorithms',             '14:00', '16:00', 'Room LH-5',   'Dr. Kariuki',  Color(0xFFE53935)),
    ],
    3: [ // Thursday
      _Class('Database Systems',       '08:00', '10:00', 'Lab A-2',     'Dr. Kamau',    Color(0xFF6A1B9A)),
      _Class('Mobile Development',     '10:00', '12:00', 'Lab C-2',     'Dr. Waweru',   Color(0xFF2E7D32)),
    ],
    4: [ // Friday
      _Class('Operating Systems',      '08:00', '10:00', 'Room LH-7',   'Dr. Njoroge',  Color(0xFFF57C00)),
      _Class('Algorithms',             '11:00', '13:00', 'Room LH-5',   'Dr. Kariuki',  Color(0xFFE53935)),
    ],
  };

  // Admin: all registered units
  static const _allUnits = [
    _AdminUnit('CS 201', 'Software Engineering',   'Dr. Mwangi',   127, Color(0xFF2E7D32)),
    _AdminUnit('CS 301', 'Computer Networks',      'Dr. Ochieng',   98, Color(0xFF283593)),
    _AdminUnit('CS 211', 'Database Systems',       'Dr. Kamau',    112, Color(0xFF6A1B9A)),
    _AdminUnit('CS 322', 'Operating Systems',      'Dr. Njoroge',   88, Color(0xFFF57C00)),
    _AdminUnit('CS 401', 'Mobile Development',     'Dr. Waweru',    76, Color(0xFF2E7D32)),
    _AdminUnit('CS 311', 'Algorithms & DS',        'Dr. Kariuki',  104, Color(0xFFE53935)),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..forward();
    _loadUser();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _loadUser() async {
    final user = await ApiService().getUser();
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : Column(children: [
              _buildHeader(isDark),
              if (!_isAdmin) _buildDaySelector(isDark),
              Expanded(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
                  child: _isAdmin
                      ? _buildAdminView(isDark)
                      : _buildScheduleView(isDark),
                ),
              ),
            ]),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final title = _isAdmin ? 'Class Management' : 'Timetable';
    final subtitle = _isAdmin
        ? 'All registered units'
        : 'Week of ${_weekRange()}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, _accentMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                  _isAdmin ? Icons.school_rounded : Icons.calendar_month_rounded,
                  color: Colors.white.withOpacity(0.8), size: 18,
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.3)),
              ]),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
            ])),
            if (!_isAdmin) _buildWeekStats(isDark),
          ]),
        ),
      ),
    );
  }

  Widget _buildWeekStats(bool isDark) {
    final totalToday = (_schedule[_selectedDayIndex] ?? []).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Text('$totalToday', style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        Text('classes today', style: TextStyle(
            fontSize: 10, color: Colors.white.withOpacity(0.8))),
      ]),
    );
  }

  // ── Day selector ─────────────────────────────────────────────────────────────
  Widget _buildDaySelector(bool isDark) {
    final today = _todayIndex();
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : _accent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: List.generate(_days.length, (i) {
        final isSelected = _selectedDayIndex == i;
        final isToday    = i == today;
        return Expanded(child: GestureDetector(
          onTap: () {
            setState(() { _selectedDayIndex = i; });
            _fadeCtrl..reset()..forward();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_days[i],
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isSelected ? _accent : Colors.white,
                  )),
              if (isToday) ...[
                const SizedBox(height: 3),
                Container(width: 4, height: 4,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? _accent : Colors.white)),
              ],
            ]),
          ),
        ));
      })),
    );
  }

  // ── Schedule view (student / lecturer) ───────────────────────────────────────
  Widget _buildScheduleView(bool isDark) {
    final classes = _schedule[_selectedDayIndex] ?? [];

    if (classes.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_available_rounded, size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No classes scheduled', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade400)),
          const SizedBox(height: 6),
          Text('Enjoy your free day!', style: TextStyle(
              fontSize: 13, color: isDark ? Colors.white24 : Colors.grey.shade400)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: classes.length,
      itemBuilder: (_, i) => _ClassCard(
        cls: classes[i],
        isDark: isDark,
        isLecturer: _isLecturer,
        accentColor: _accent,
      ),
    );
  }

  // ── Admin view ───────────────────────────────────────────────────────────────
  Widget _buildAdminView(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _allUnits.length,
      itemBuilder: (_, i) => _AdminUnitCard(
        unit: _allUnits[i],
        isDark: isDark,
        accentColor: _accent,
        accentLight: _accentLight,
      ),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────────
  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        color: Colors.grey.shade500,
        activeColor: Colors.white,
        tabBackgroundColor: _accent,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: 2,
        onTabChange: (i) {
          if (i == 0) context.go(_homePath);
          if (i == 1) context.go('/history');
          if (i == 3) context.go('/settings');
        },
        tabs: const [
          GButton(icon: Icons.home_rounded,          text: 'Home'),
          GButton(icon: Icons.history_rounded,        text: 'History'),
          GButton(icon: Icons.calendar_today_rounded, text: 'Calendar'),
          GButton(icon: Icons.settings_rounded,       text: 'Settings'),
        ],
      ),
    );
  }

  String _weekRange() {
    final now  = DateTime.now();
    final mon  = now.subtract(Duration(days: now.weekday - 1));
    final fri  = mon.add(const Duration(days: 4));
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mon.day} – ${fri.day} ${months[fri.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASS CARD  (student / lecturer)
// ─────────────────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final _Class cls;
  final bool isDark;
  final bool isLecturer;
  final Color accentColor;

  const _ClassCard({
    required this.cls, required this.isDark,
    required this.isLecturer, required this.accentColor,
  });

  bool get _isNow {
    final now = TimeOfDay.now();
    final start = _parseTime(cls.startTime);
    final end   = _parseTime(cls.endTime);
    final nowMins = now.hour * 60 + now.minute;
    return nowMins >= start && nowMins < end;
  }

  int _parseTime(String t) {
    final parts = t.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: _isNow
            ? Border.all(color: cls.color, width: 2)
            : Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _isNow
                  ? cls.color.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          // Left colour bar
          Container(
            width: 5,
            decoration: BoxDecoration(
              color: cls.color,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18)),
            ),
          ),
          // Time column
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(cls.startTime,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
              Container(margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 1, height: 12, color: isDark ? Colors.white24 : Colors.grey.shade300),
              Text(cls.endTime,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
            ]),
          ),
          // Divider
          Container(width: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(cls.subject,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
                  ),
                  if (_isNow) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: cls.color, borderRadius: BorderRadius.circular(8)),
                    child: const Text('NOW', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(cls.room,
                      style: TextStyle(fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline_rounded, size: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    isLecturer ? 'Your class' : cls.lecturer,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600),
                  )),
                ]),
                if (isLecturer) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    _LecturerAction(
                      label: 'Take Attendance',
                      icon: Icons.qr_code_rounded,
                      color: accentColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _LecturerAction(
                      label: 'View Report',
                      icon: Icons.bar_chart_rounded,
                      color: Colors.grey.shade500,
                      isDark: isDark,
                    ),
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LecturerAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _LecturerAction({required this.label, required this.icon,
      required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN UNIT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AdminUnitCard extends StatelessWidget {
  final _AdminUnit unit;
  final bool isDark;
  final Color accentColor;
  final Color accentLight;

  const _AdminUnitCard({
    required this.unit, required this.isDark,
    required this.accentColor, required this.accentLight,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        // Code badge
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: unit.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(
            unit.code.split(' ').last, // e.g. "201"
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: unit.color),
          )),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(unit.name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
          const SizedBox(height: 3),
          Text('${unit.code}  ·  ${unit.lecturer}',
              style: TextStyle(fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade500)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.people_outline_rounded, size: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('${unit.enrolled} students',
                style: TextStyle(fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600)),
          ]),
        ])),
        // Edit button
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: accentLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.edit_outlined, color: accentColor, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _Class {
  final String subject, startTime, endTime, room, lecturer;
  final Color color;
  const _Class(this.subject, this.startTime, this.endTime,
      this.room, this.lecturer, this.color);
}

class _AdminUnit {
  final String code, name, lecturer;
  final int enrolled;
  final Color color;
  const _AdminUnit(this.code, this.name, this.lecturer, this.enrolled, this.color);
}