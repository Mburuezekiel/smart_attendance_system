// lib/features/home/presentation/lecturer_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _indigo     = Color(0xFF283593);
  static const _indigoMid  = Color(0xFF3949AB);
  static const _indigoLight= Color(0xFFE8EAF6);

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadUser();
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _indigo)));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildTodaySchedule(),
              const SizedBox(height: 20),
              _buildClassAttendanceSnapshot(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 32),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    expandedHeight: 200,
    pinned: true,
    backgroundColor: _indigo,
    automaticallyImplyLeading: false,
    actions: [
      IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
      IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
    ],
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_indigo, _indigoMid, Color(0xFF5C6BC0)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(_firstName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Good ${_greeting()}, 👋', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                  Text('Dr. $_firstName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
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
  );

  Widget _buildStatsRow() {
    final stats = [
      _Stat('4',   'Classes\nToday',   Icons.class_rounded,       _indigo),
      _Stat('127', 'Students',         Icons.people_rounded,       const Color(0xFF2E7D32)),
      _Stat('82%', 'Avg Attendance',   Icons.bar_chart_rounded,    const Color(0xFFF57C00)),
      _Stat('3',   'Pending\nReports', Icons.pending_actions_rounded, const Color(0xFFE53935)),
    ];
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic)),
      child: Row(children: stats.map((s) => Expanded(child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(s.icon, color: s.color, size: 20),
          const SizedBox(height: 8),
          Text(s.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: s.color)),
          const SizedBox(height: 2),
          Text(s.label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.3)),
        ]),
      ))).toList()),
    );
  }

  Widget _buildTodaySchedule() {
    final classes = [
      _LecClass('Mathematics 201',      'Yr 2 · Sec A', '08:00',  'Room LH-3', 48,  52, true),
      _LecClass('Computer Networks',    'Yr 3 · Sec B', '10:00',  'Lab C-2',   31,  35, false),
      _LecClass('Software Engineering', 'Yr 4 · Sec A', '14:00',  'Room LH-7', 40,  40, false),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: "Today's Schedule", icon: Icons.today_rounded, color: _indigo, action: 'Full View'),
      const SizedBox(height: 12),
      ...classes.map((c) => _LecClassCard(cls: c, accentColor: _indigo)),
    ]);
  }

  Widget _buildClassAttendanceSnapshot() {
    final units = [
      _UnitAttendance('Mathematics 201',      87, const Color(0xFF2E7D32)),
      _UnitAttendance('Computer Networks',    74, const Color(0xFFF57C00)),
      _UnitAttendance('Software Engineering', 91, const Color(0xFF1565C0)),
      _UnitAttendance('Database Systems',     68, const Color(0xFFE53935)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Attendance by Unit', icon: Icons.analytics_rounded, color: _indigo, action: 'Details'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(children: units.map((u) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(u.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text('${u.pct}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: u.color)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: u.pct / 100, minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(u.color),
              ),
            ),
          ]),
        )).toList()),
      ),
    ]);
  }

  Widget _buildQuickActions() {
    final actions = [
      _Action('Take\nAttendance', Icons.fingerprint_rounded,     _indigo),
      _Action('View\nReports',   Icons.assessment_rounded,       const Color(0xFF2E7D32)),
      _Action('Send\nNotice',    Icons.campaign_rounded,         const Color(0xFFF57C00)),
      _Action('Student\nList',   Icons.people_alt_rounded,       const Color(0xFF6A1B9A)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Quick Actions', icon: Icons.bolt_rounded, color: _indigo),
      const SizedBox(height: 12),
      Row(children: actions.map((a) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: _QuickActionCard(action: a),
      ))).toList()),
    ]);
  }
}

class _Stat {
  final String value, label; final IconData icon; final Color color;
  const _Stat(this.value, this.label, this.icon, this.color);
}
class _LecClass {
  final String name, group, time, room; final int present, total; final bool isNow;
  const _LecClass(this.name, this.group, this.time, this.room, this.present, this.total, this.isNow);
}
class _UnitAttendance {
  final String name; final int pct; final Color color;
  const _UnitAttendance(this.name, this.pct, this.color);
}
class _Action {
  final String label; final IconData icon; final Color color;
  const _Action(this.label, this.icon, this.color);
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon; final Color color; final String? action;
  const _SectionHeader({required this.title, required this.icon, required this.color, this.action});
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
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: cls.isNow ? Border.all(color: accentColor, width: 1.5) : null,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
    ),
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

class _QuickActionCard extends StatelessWidget {
  final _Action action;
  const _QuickActionCard({required this.action});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: action.color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(action.icon, color: action.color, size: 22)),
        const SizedBox(height: 8),
        Text(action.label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1B1B1B), height: 1.3)),
      ]),
    ),
  );
}