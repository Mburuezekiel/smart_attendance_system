// lib/features/home/presentation/student_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';
import '../../student/student_scan_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});
  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  int  _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _green    = Color(0xFF2E7D32);
  static const _greenMid = Color(0xFF43A047);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    _loadData();
    _pages = [
      _HomeBody(
        fadeCtrl:     _fadeCtrl,
        slideCtrl:    _slideCtrl,
        getFirstName: () => _firstName,
        getRegNumber: () => _regNumber,
        getDashboard: () => _dashboard,
        onRefresh:    _loadData,
      ),
      const StudentScanPage(),
    ];
  }

  @override
  void dispose() { _fadeCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final user   = await ApiService().getUser();
    final result = await ApiService().get('/dashboard/student');
    if (!mounted) return;
    setState(() {
      _user      = user;
      _dashboard = result.success ? result.data : null;
      _loading   = false;
    });
  }

  String get _firstName =>
      (_user?['fullName'] as String? ?? 'Student').split(' ').first;
  String get _regNumber =>
      _user?['registrationNumber'] as String? ?? '—';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator(color: _green)));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _StudentBottomNav(
        selectedIndex: _selectedIndex,
        onTabChange: (i) {
          if (i == 2) { context.go('/history');   return; }
          if (i == 3) { context.go('/timetable'); return; }
          if (i == 4) { context.go('/analytics'); return; } // ✅ new
          if (i == 5) { context.go('/settings');  return; }
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _StudentBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  static const _green = Color(0xFF2E7D32);
  const _StudentBottomNav(
      {required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.07),
                blurRadius: 20, offset: const Offset(0, -4))
          ]),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: Colors.white,
        color: Colors.grey.shade500,
        activeColor: Colors.white,
        tabBackgroundColor: _green,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: selectedIndex,
        onTabChange: onTabChange,
        tabs: const [
          GButton(icon: Icons.home_rounded,            text: 'Home'),
          GButton(icon: Icons.qr_code_scanner_rounded, text: 'Scan'),
          GButton(icon: Icons.history_rounded,         text: 'History'),
          GButton(icon: Icons.calendar_today_rounded,  text: 'Timetable'),
          GButton(icon: Icons.analytics_rounded,       text: 'Analytics'), // ✅ new
          GButton(icon: Icons.settings_rounded,        text: 'Settings'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME BODY — real data
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final AnimationController fadeCtrl;
  final AnimationController slideCtrl;
  final String Function()                    getFirstName;
  final String Function()                    getRegNumber;
  final Map<String, dynamic>? Function()     getDashboard;
  final VoidCallback                         onRefresh;

  static const _green    = Color(0xFF2E7D32);
  static const _greenMid = Color(0xFF43A047);

  const _HomeBody({
    required this.fadeCtrl,
    required this.slideCtrl,
    required this.getFirstName,
    required this.getRegNumber,
    required this.getDashboard,
    required this.onRefresh,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  String _timeAgo(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _colorFromString(String s) {
    const palette = [
      Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFF2E7D32),
      Color(0xFFF57C00), Color(0xFFE53935), Color(0xFF00695C),
    ];
    return palette[s.hashCode.abs() % palette.length];
  }

  IconData _iconForStatus(String status) => switch (status) {
    'present' => Icons.check_circle_rounded,
    'late'    => Icons.watch_later_rounded,
    _         => Icons.cancel_rounded,
  };

  Color _colorForStatus(String status) => switch (status) {
    'present' => _green,
    'late'    => const Color(0xFFF57C00),
    _         => const Color(0xFFE53935),
  };

  @override
  Widget build(BuildContext context) {
    final firstName = getFirstName();
    final regNumber = getRegNumber();
    final dash      = getDashboard();

    final stats    = dash?['stats'] as Map<String, dynamic>? ?? {};
    final present  = stats['present']    ?? 0;
    final absent   = stats['absent']     ?? 0;
    final late     = stats['late']       ?? 0;
    final pct      = stats['percentage'] ?? 0;

    final rawClasses  = dash?['todayClasses']   as List? ?? [];
    final rawActivity = dash?['recentActivity'] as List? ?? [];
    final rawUnits    = dash?['enrolledUnits']  as List? ?? [];

    return RefreshIndicator(
      color: _green,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200, pinned: true,
            backgroundColor: _green, automaticallyImplyLeading: false,
            actions: [
              IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_green, _greenMid, Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                        parent: fadeCtrl, curve: Curves.easeOut),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Good ${_greeting()}, 👋',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.85))),
                            Text(firstName,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text(regNumber,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7))),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('STUDENT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1)),
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
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Attendance overview ──────────────────────────────────────
                SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: slideCtrl, curve: Curves.easeOutCubic)),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4))
                        ]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.bar_chart_rounded,
                            color: _green, size: 20),
                        const SizedBox(width: 8),
                        const Text('Attendance Overview',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1B1B))),
                        const Spacer(),
                        Text('This Semester',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ]),
                      const SizedBox(height: 20),
                      Row(children: [
                        _AttStat(value: '$pct%',   label: 'Overall', color: _green),
                        _vDiv(),
                        _AttStat(value: '$present', label: 'Present',
                            color: const Color(0xFF1565C0)),
                        _vDiv(),
                        _AttStat(value: '$absent',  label: 'Absent',
                            color: const Color(0xFFE53935)),
                        _vDiv(),
                        _AttStat(value: '$late',    label: 'Late',
                            color: const Color(0xFFF57C00)),
                      ]),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (pct as num) / 100,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(_green),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('$pct% attendance · Minimum required: 75%',
                          style: TextStyle(
                              fontSize: 11,
                              color: pct < 75
                                  ? const Color(0xFFE53935)
                                  : Colors.grey.shade500)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Today's classes ──────────────────────────────────────────
                _SectionHeader(
                    title: "Today's Classes",
                    icon: Icons.today_rounded,
                    action: rawClasses.isEmpty ? null : 'View All',
                    onAction: () => context.go('/timetable')),
                const SizedBox(height: 12),

                if (rawClasses.isEmpty)
                  _EmptyCard(
                      icon: Icons.event_available_rounded,
                      message: 'No classes scheduled today')
                else
                  ...rawClasses.map((c) {
                    final m = c as Map<String, dynamic>;
                    return _TodayClassCard(cls: m);
                  }),
                const SizedBox(height: 20),

                // ── My Units ─────────────────────────────────────────────────
                _SectionHeader(
                    title: 'My Units',
                    icon: Icons.menu_book_rounded,
                    action: rawUnits.isEmpty ? null : 'All'),
                const SizedBox(height: 12),

                if (rawUnits.isEmpty)
                  _EmptyCard(
                      icon: Icons.school_outlined,
                      message: 'Not enrolled in any units yet')
                else
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: rawUnits.length,
                      itemBuilder: (_, i) {
                        final u    = rawUnits[i] as Map<String, dynamic>;
                        final unit = u['unit'] as Map<String, dynamic>? ?? {};
                        final lec  = u['lecturer'] as Map<String, dynamic>? ?? {};
                        final code = unit['code'] as String? ?? '—';
                        final name = unit['name'] as String? ?? '—';
                        final col  = _colorFromString(code);
                        return Container(
                          width: 150,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: col.withOpacity(0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: col.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(code,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: col)),
                            ),
                            const SizedBox(height: 6),
                            Text(name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B1B1B))),
                            const Spacer(),
                            Text(
                              lec['fullName'] as String? ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Quick actions ────────────────────────────────────────────
                _SectionHeader(
                    title: 'Quick Actions', icon: Icons.bolt_rounded),
                const SizedBox(height: 12),
                Row(children: [
                  _QuickAction('Scan\nQR',    Icons.qr_code_scanner_rounded,
                      _green, () => {}),
                  _QuickAction('Schedule',    Icons.calendar_month_rounded,
                      const Color(0xFF1565C0),
                      () => context.go('/timetable')),
                  _QuickAction('History',     Icons.history_rounded,
                      const Color(0xFF6A1B9A),
                      () => context.go('/history')),
                  _QuickAction('Analytics',   Icons.analytics_rounded,
                      const Color(0xFFF57C00),
                      () => context.go('/analytics')),
                ]),
                const SizedBox(height: 20),

                // ── Recent activity ──────────────────────────────────────────
                _SectionHeader(
                    title: 'Recent Activity',
                    icon: Icons.history_rounded,
                    action: rawActivity.isEmpty ? null : 'See All',
                    onAction: () => context.go('/history')),
                const SizedBox(height: 12),

                if (rawActivity.isEmpty)
                  _EmptyCard(
                      icon: Icons.inbox_rounded,
                      message: 'No attendance records yet')
                else
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4))
                        ]),
                    child: Column(
                      children: rawActivity.asMap().entries.map((e) {
                        final r       = e.value as Map<String, dynamic>;
                        final status  = r['status'] as String? ?? 'present';
                        final isLast  = e.key == rawActivity.length - 1;
                        return Column(children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                  color: _colorForStatus(status)
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle),
                              child: Icon(_iconForStatus(status),
                                  color: _colorForStatus(status), size: 18),
                            ),
                            title: Text(
                              r['unitName'] as String? ?? '—',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              r['unitCode'] as String? ?? '—',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _timeAgo(r['markedAt']?.toString()),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _colorForStatus(status)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(5)),
                                  child: Text(
                                    status[0].toUpperCase() +
                                        status.substring(1),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: _colorForStatus(status)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(
                                height: 1,
                                indent: 56,
                                color: Colors.grey.shade100),
                        ]);
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade100,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's class card (student)
// ─────────────────────────────────────────────────────────────────────────────

class _TodayClassCard extends StatelessWidget {
  final Map<String, dynamic> cls;
  static const _green = Color(0xFF2E7D32);

  const _TodayClassCard({required this.cls});

  Color _colorFromCode(String code) {
    const palette = [
      Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFF2E7D32),
      Color(0xFFF57C00), Color(0xFFE53935), Color(0xFF00695C),
    ];
    return palette[code.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final code     = cls['unitCode']  as String? ?? '—';
    final name     = cls['unitName']  as String? ?? '—';
    final start    = cls['startTime'] as String? ?? '';
    final end      = cls['endTime']   as String? ?? '';
    final room     = cls['room']      as String? ?? '';
    final lecturer = cls['lecturer']  as String? ?? '';
    final isNow    = cls['isNow']     as bool?   ?? false;
    final isNext   = cls['isNext']    as bool?   ?? false;
    final color    = _colorFromCode(code);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isNow
            ? Border.all(color: color, width: 2)
            : isNext
                ? Border.all(color: color.withOpacity(0.5), width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
              color: isNow
                  ? color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(code.split(' ').last,
              style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w900, color: color))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 2),
          Text(
            '$start – $end${room.isNotEmpty ? ' · $room' : ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          if (lecturer.isNotEmpty)
            Text(lecturer,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
        if (isNow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(8)),
            child: const Text('NOW',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1)),
          )
        else if (isNext)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8)),
            child: Text('NEXT',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AttStat extends StatelessWidget {
  final String value, label; final Color color;
  const _AttStat({required this.value, required this.label, required this.color});
  @override Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          fontSize: 11, color: Colors.grey.shade500)),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  final String? action; final VoidCallback? onAction;
  static const _green = Color(0xFF2E7D32);
  const _SectionHeader({required this.title, required this.icon,
      this.action, this.onAction});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: _green), const SizedBox(width: 8),
    Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: Color(0xFF1B1B1B))),
    const Spacer(),
    if (action != null)
      GestureDetector(
        onTap: onAction,
        child: Text(action!, style: const TextStyle(
            fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
      ),
  ]);
}

class _QuickAction extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.color, this.onTap);
  @override Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B1B1B), height: 1.3)),
        ]),
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon; final String message;
  const _EmptyCard({required this.icon, required this.message});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100)),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: Colors.grey.shade300),
      const SizedBox(height: 10),
      Text(message, style: TextStyle(
          fontSize: 13, color: Colors.grey.shade400)),
    ])),
  );
}