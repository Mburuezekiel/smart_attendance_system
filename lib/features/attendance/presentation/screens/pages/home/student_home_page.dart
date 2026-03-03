// lib/features/home/presentation/student_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../core/services/api_service.dart';
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});
  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _green     = Color(0xFF2E7D32);
  static const _greenLight= Color(0xFFE8F5E9);
  static const _greenMid  = Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadUser();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await ApiService().getUser();
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  Future<void> _logout() async {
    await ApiService().clearSession();
    if (mounted) context.go('/login');
  }

  String get _firstName {
    final full = _user?['fullName'] as String? ?? 'Student';
    return full.split(' ').first;
  }

  String get _regNumber => _user?['registrationNumber'] as String? ?? '—';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _buildAttendanceSummary(),
              const SizedBox(height: 20),
              _buildTodayClasses(),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildRecentActivity(),
              const SizedBox(height: 32),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _green,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: _logout,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_green, _greenMid, Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Good ${_greeting()}, 👋', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                        Text(_firstName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(_regNumber, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('STUDENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: _green, size: 20),
            const SizedBox(width: 8),
            const Text('Attendance Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
            const Spacer(),
            Text('This Semester', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            _AttendanceStat(value: '87%', label: 'Overall', color: _green),
            _vDivider(),
            _AttendanceStat(value: '42', label: 'Present', color: const Color(0xFF1565C0)),
            _vDivider(),
            _AttendanceStat(value: '6',  label: 'Absent',  color: const Color(0xFFE53935)),
            _vDivider(),
            _AttendanceStat(value: '3',  label: 'Late',    color: const Color(0xFFF57C00)),
          ]),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.87,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
          const SizedBox(height: 8),
          Text('87% attendance · Minimum required: 75%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _buildTodayClasses() {
    final classes = [
      _ClassItem('Mathematics 201', '08:00 – 10:00', 'Room LH-3', Icons.calculate_rounded, const Color(0xFF1565C0), true),
      _ClassItem('Computer Networks', '10:00 – 12:00', 'Lab C-2', Icons.lan_rounded, const Color(0xFF6A1B9A), false),
      _ClassItem('Software Engineering', '14:00 – 16:00', 'Room LH-7', Icons.code_rounded, _green, false),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: "Today's Classes", icon: Icons.today_rounded, action: 'View All'),
      const SizedBox(height: 12),
      ...classes.map((c) => _ClassCard(item: c)),
    ]);
  }

  Widget _buildQuickActions() {
    final actions = [
      _Action('Mark\nAttendance', Icons.fingerprint_rounded, _green),
      _Action('My\nSchedule',    Icons.calendar_month_rounded, const Color(0xFF1565C0)),
      _Action('View\nGrades',    Icons.grade_rounded,          const Color(0xFF6A1B9A)),
      _Action('Leave\nRequest',  Icons.event_busy_rounded,     const Color(0xFFF57C00)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Quick Actions', icon: Icons.bolt_rounded),
      const SizedBox(height: 12),
      Row(children: actions.map((a) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: _QuickActionCard(action: a),
      ))).toList()),
    ]);
  }

  Widget _buildRecentActivity() {
    final items = [
      _Activity('Attendance marked', 'Software Eng. — Lab session', '2h ago', Icons.check_circle_rounded, _green),
      _Activity('Absent recorded', 'Database Systems', 'Yesterday', Icons.cancel_rounded, const Color(0xFFE53935)),
      _Activity('Schedule updated', 'Mathematics 201 rescheduled', '2 days ago', Icons.update_rounded, const Color(0xFFF57C00)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Recent Activity', icon: Icons.history_rounded, action: 'See All'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(children: [
            _ActivityTile(activity: e.value),
            if (!isLast) Divider(height: 1, indent: 56, color: Colors.grey.shade100),
          ]);
        }).toList()),
      ),
    ]);
  }

  Widget _vDivider() => Container(
    height: 40, width: 1, color: Colors.grey.shade100, margin: const EdgeInsets.symmetric(horizontal: 8));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─── Supporting data classes ──────────────────────────────────────────────────
class _ClassItem {
  final String name, time, room;
  final IconData icon;
  final Color color;
  final bool isNext;
  const _ClassItem(this.name, this.time, this.room, this.icon, this.color, this.isNext);
}
class _Action {
  final String label; final IconData icon; final Color color;
  const _Action(this.label, this.icon, this.color);
}
class _Activity {
  final String title, subtitle, time; final IconData icon; final Color color;
  const _Activity(this.title, this.subtitle, this.time, this.icon, this.color);
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _AttendanceStat extends StatelessWidget {
  final String value, label; final Color color;
  const _AttendanceStat({required this.value, required this.label, required this.color});
  @override Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]));
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon; final String? action;
  const _SectionHeader({required this.title, required this.icon, this.action});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
    const Spacer(),
    if (action != null) Text(action!, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
  ]);
}

class _ClassCard extends StatelessWidget {
  final _ClassItem item;
  const _ClassCard({required this.item});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: item.isNext ? Border.all(color: const Color(0xFF2E7D32), width: 1.5) : null,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(item.icon, color: item.color, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
        const SizedBox(height: 2),
        Text('${item.time}  ·  ${item.room}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ])),
      if (item.isNext) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
        child: const Text('NEXT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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

class _ActivityTile extends StatelessWidget {
  final _Activity activity;
  const _ActivityTile({required this.activity});
  @override Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: activity.color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(activity.icon, color: activity.color, size: 18)),
    title: Text(activity.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    subtitle: Text(activity.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    trailing: Text(activity.time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
  );
}