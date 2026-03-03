// lib/features/home/presentation/lecturer_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';

class LecturerHomePage extends StatefulWidget {
  const LecturerHomePage({super.key});
  @override
  State<LecturerHomePage> createState() => _LecturerHomePageState();
}

class _LecturerHomePageState extends State<LecturerHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  int  _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _indigo      = Color(0xFF283593);
  static const _indigoMid   = Color(0xFF3949AB);
  static const _indigoLight = Color(0xFFE8EAF6);

  // Only Home(0) and QR(1) live inside this page.
  // Tabs 2-4 navigate via GoRouter to existing routes.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadUser();
    _pages = [
      _LecHomebody(fadeCtrl: _fadeCtrl, slideCtrl: _slideCtrl, getFirstName: () => _firstName),
      const _GenerateQrPage(),       // Lecturer generates QR for class
    ];
  }

  @override
  void dispose() { _fadeCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

  Future<void> _loadUser() async {
    final user = await ApiService().getUser();
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  Future<void> _logout() async {
    await ApiService().clearSession();
    if (mounted) context.go('/login');
  }

  String get _firstName => (_user?['fullName'] as String? ?? 'Lecturer').split(' ').first;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _indigo)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _LecturerBottomNav(
        selectedIndex: _selectedIndex,
        onTabChange: (i) {
          if (i == 2) { context.go('/history');   return; }
          if (i == 3) { context.go('/timetable'); return; }
          if (i == 4) { context.go('/settings');  return; }
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LECTURER BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _LecturerBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  static const _indigo = Color(0xFF283593);

  const _LecturerBottomNav({required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: Colors.white,
        color: Colors.grey.shade500,
        activeColor: Colors.white,
        tabBackgroundColor: _indigo,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: selectedIndex,
        onTabChange: onTabChange,
        tabs: const [
          GButton(icon: Icons.home_rounded,          text: 'Home'),
          // "QR" — lecturer generates the QR code that students scan
          GButton(icon: Icons.qr_code_rounded,        text: 'QR Code'),
          GButton(icon: Icons.assessment_rounded,     text: 'Reports'),
          GButton(icon: Icons.calendar_today_rounded, text: 'Schedule'),
          GButton(icon: Icons.settings_rounded,       text: 'Settings'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME BODY
// ─────────────────────────────────────────────────────────────────────────────

class _LecHomebody extends StatelessWidget {
  final AnimationController fadeCtrl;
  final AnimationController slideCtrl;
  final String Function() getFirstName;

  static const _indigo    = Color(0xFF283593);
  static const _indigoMid = Color(0xFF3949AB);

  const _LecHomebody({required this.fadeCtrl, required this.slideCtrl, required this.getFirstName});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = getFirstName();
    final stats = [
      _Stat('4',   'Classes\nToday',   Icons.class_rounded,          _indigo),
      _Stat('127', 'Students',          Icons.people_rounded,         const Color(0xFF2E7D32)),
      _Stat('82%', 'Avg Attendance',    Icons.bar_chart_rounded,      const Color(0xFFF57C00)),
      _Stat('3',   'Pending\nReports',  Icons.pending_actions_rounded, const Color(0xFFE53935)),
    ];
    final classes = [
      _LecClass('Mathematics 201',      'Yr 2 · Sec A', '08:00', 'Room LH-3', 48, 52, true),
      _LecClass('Computer Networks',    'Yr 3 · Sec B', '10:00', 'Lab C-2',   31, 35, false),
      _LecClass('Software Engineering', 'Yr 4 · Sec A', '14:00', 'Room LH-7', 40, 40, false),
    ];
    final units = [
      _UnitAttendance('Mathematics 201',      87, const Color(0xFF2E7D32)),
      _UnitAttendance('Computer Networks',    74, const Color(0xFFF57C00)),
      _UnitAttendance('Software Engineering', 91, const Color(0xFF1565C0)),
      _UnitAttendance('Database Systems',     68, const Color(0xFFE53935)),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 200, pinned: true, backgroundColor: _indigo, automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_indigo, _indigoMid, Color(0xFF5C6BC0)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: fadeCtrl, curve: Curves.easeOut),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(children: [
                      CircleAvatar(radius: 28, backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(firstName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Good ${_greeting()}, 👋', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                        Text('Dr. $firstName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('Computer Science Dept.', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('LECTURER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Stats row
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(CurvedAnimation(parent: slideCtrl, curve: Curves.easeOutCubic)),
              child: Row(children: stats.map((s) => Expanded(child: Container(
                margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(s.icon, color: s.color, size: 20), const SizedBox(height: 8),
                  Text(s.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: s.color)),
                  const SizedBox(height: 2),
                  Text(s.label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.3)),
                ]),
              ))).toList()),
            ),
            const SizedBox(height: 20),

            // Today's schedule
            _LecSectionHeader(title: "Today's Schedule", icon: Icons.today_rounded, color: _indigo, action: 'Full View'),
            const SizedBox(height: 12),
            ...classes.map((c) => _LecClassCard(cls: c, accentColor: _indigo)),
            const SizedBox(height: 20),

            // Attendance by unit
            _LecSectionHeader(title: 'Attendance by Unit', icon: Icons.analytics_rounded, color: _indigo, action: 'Details'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Column(children: units.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(u.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    Text('${u.pct}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: u.color)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: u.pct / 100, minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(u.color))),
                ]),
              )).toList()),
            ),
            const SizedBox(height: 32),
          ])),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERATE QR PAGE  (Lecturer generates QR for a class session)
// ─────────────────────────────────────────────────────────────────────────────

class _GenerateQrPage extends StatefulWidget {
  const _GenerateQrPage();
  @override State<_GenerateQrPage> createState() => _GenerateQrPageState();
}

class _GenerateQrPageState extends State<_GenerateQrPage> {
  String? _selectedClass;
  bool    _qrGenerated = false;
  bool    _sessionActive = false;
  int     _scanned = 0;
  static const _indigo = Color(0xFF283593);

  final _classes = [
    'Mathematics 201 — Room LH-3',
    'Computer Networks — Lab C-2',
    'Software Engineering — Room LH-7',
  ];

  void _generateQr() => setState(() { _qrGenerated = true; _sessionActive = true; _scanned = 0; });
  void _endSession() => setState(() { _sessionActive = false; _qrGenerated = false; _selectedClass = null; });
  void _simulateScan() => setState(() => _scanned++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(backgroundColor: _indigo, automaticallyImplyLeading: false,
          title: const Text('Generate QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _qrGenerated ? _buildActiveSession() : _buildSetup(),
      ),
    );
  }

  Widget _buildSetup() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _indigo.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.qr_code_rounded, color: _indigo, size: 32),
          const SizedBox(height: 12),
          const Text('Start Attendance Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
          const SizedBox(height: 4),
          Text('Select a class to generate a unique QR code\nfor students to scan',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedClass,
            hint: const Text('Select class…'),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _indigo, width: 2)),
              filled: true, fillColor: const Color(0xFFF7F7F7),
            ),
            items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _selectedClass = v),
          ),
          const SizedBox(height: 16),
          // Duration hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, color: _indigo, size: 14),
              const SizedBox(width: 6),
              Text('QR code expires in 15 minutes', style: const TextStyle(fontSize: 11, color: _indigo, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _selectedClass == null ? null : _generateQr,
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _selectedClass == null
                    ? [Colors.grey.shade300, Colors.grey.shade400]
                    : [_indigo, const Color(0xFF3949AB)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _selectedClass == null ? [] :
                [BoxShadow(color: _indigo.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Generate QR Code', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
    ],
  );

  Widget _buildActiveSession() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _indigo.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.circle, color: Color(0xFF2E7D32), size: 8),
                SizedBox(width: 6),
                Text('LIVE SESSION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32), letterSpacing: 1)),
              ])),
            Text('$_scanned scanned', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _indigo)),
          ]),
          const SizedBox(height: 16),
          // QR placeholder (real impl uses qr_flutter package)
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: _indigo, width: 3),
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE8EAF6),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.qr_code_2_rounded, size: 120, color: _indigo),
              SizedBox(height: 8),
              Text('Show to students', style: TextStyle(fontSize: 11, color: _indigo, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 16),
          Text(_selectedClass ?? '', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
          const SizedBox(height: 4),
          _CountdownTimer(minutes: 15),
          const SizedBox(height: 20),
          // Live counter
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _QrStat('$_scanned', 'Scanned', const Color(0xFF2E7D32)),
              Container(width: 1, height: 36, color: Colors.grey.shade200),
              _QrStat('35', 'Expected', _indigo),
              Container(width: 1, height: 36, color: Colors.grey.shade200),
              _QrStat('${35 - _scanned}', 'Remaining', const Color(0xFFE53935)),
            ]),
          ),
          const SizedBox(height: 20),
          // Simulate a student scan (dev helper)
          OutlinedButton.icon(
            onPressed: _simulateScan,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Simulate Student Scan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _indigo,
              side: const BorderSide(color: _indigo),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _endSession,
            child: Container(height: 48,
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.4))),
              child: const Center(child: Text('End Session', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700, fontSize: 14)))),
          ),
        ]),
      ),
    ],
  );
}

class _QrStat extends StatelessWidget {
  final String value, label; final Color color;
  const _QrStat(this.value, this.label, this.color);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]);
}

class _CountdownTimer extends StatelessWidget {
  final int minutes;
  const _CountdownTimer({required this.minutes});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF57C00)),
    const SizedBox(width: 4),
    Text('Expires in ${minutes}m 00s', style: const TextStyle(fontSize: 12, color: Color(0xFFF57C00), fontWeight: FontWeight.w600)),
  ]);
}

// Reports, Schedule, and Settings navigate to existing routes via GoRouter.
// See _LecturerHomePageState.build() → onTabChange for i == 2/3/4.

// ─────────────────────────────────────────────────────────────────────────────
// Shared data + widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Stat { final String value, label; final IconData icon; final Color color;
  const _Stat(this.value, this.label, this.icon, this.color); }
class _LecClass { final String name, group, time, room; final int present, total; final bool isNow;
  const _LecClass(this.name, this.group, this.time, this.room, this.present, this.total, this.isNow); }
class _UnitAttendance { final String name; final int pct; final Color color;
  const _UnitAttendance(this.name, this.pct, this.color); }

class _LecSectionHeader extends StatelessWidget {
  final String title; final IconData icon; final Color color; final String? action;
  const _LecSectionHeader({required this.title, required this.icon, required this.color, this.action});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color), const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
    const Spacer(),
    if (action != null) Text(action!, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  ]);
}

class _LecClassCard extends StatelessWidget {
  final _LecClass cls; final Color accentColor;
  const _LecClassCard({required this.cls, required this.accentColor});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: cls.isNow ? Border.all(color: accentColor, width: 1.5) : null,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(cls.time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accentColor)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cls.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('${cls.group}  ·  ${cls.room}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${cls.present}/${cls.total}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor)),
        Text('present', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        if (cls.isNow) Container(margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(6)),
          child: const Text('NOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    ]),
  );
}