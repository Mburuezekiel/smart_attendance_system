// lib/features/home/presentation/lecturer_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';
import '../../lecturer/lecturer_qr_page.dart';

class LecturerHomePage extends StatefulWidget {
  const LecturerHomePage({super.key});
  @override
  State<LecturerHomePage> createState() => _LecturerHomePageState();
}

class _LecturerHomePageState extends State<LecturerHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  int  _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _indigo = Color(0xFF283593);

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose(); _slideCtrl.dispose(); super.dispose();
  }

  Future<void> _loadData() async {
    final user   = await ApiService().getUser();
    final result = await ApiService().get('/dashboard/lecturer');
    if (!mounted) return;
    setState(() {
      _user      = user;
      _dashboard = result.success ? result.data : null;
      _loading   = false;
    });
    _buildPages();
  }

  void _buildPages() {
    _pages = [
      _LecHomeBody(
        fadeCtrl:     _fadeCtrl,
        slideCtrl:    _slideCtrl,
        getFirstName: () => _firstName,
        getDashboard: () => _dashboard,
        onRefresh:    _loadData,
      ),
      const LecturerQrPage(),
    ];
    if (mounted) setState(() {});
  }

  String get _firstName =>
      (_user?['fullName'] as String? ?? 'Lecturer').split(' ').first;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
              child: CircularProgressIndicator(color: _indigo)));
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
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _LecturerBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  static const _indigo = Color(0xFF283593);
  const _LecturerBottomNav(
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
        tabBackgroundColor: _indigo,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: selectedIndex,
        onTabChange: onTabChange,
        tabs: const [
          GButton(icon: Icons.home_rounded,            text: 'Home'),
          GButton(icon: Icons.qr_code_rounded,         text: 'QR Code'),
          GButton(icon: Icons.assessment_rounded,      text: 'Reports'),
          GButton(icon: Icons.calendar_today_rounded,  text: 'Schedule'),
          GButton(icon: Icons.settings_rounded,        text: 'Settings'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME BODY — real data
// ─────────────────────────────────────────────────────────────────────────────

class _LecHomeBody extends StatelessWidget {
  final AnimationController              fadeCtrl;
  final AnimationController              slideCtrl;
  final String Function()                getFirstName;
  final Map<String, dynamic>? Function() getDashboard;
  final VoidCallback                     onRefresh;

  static const _indigo    = Color(0xFF283593);
  static const _indigoMid = Color(0xFF3949AB);

  const _LecHomeBody({
    required this.fadeCtrl,
    required this.slideCtrl,
    required this.getFirstName,
    required this.getDashboard,
    required this.onRefresh,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  Color _colorFromString(String s) {
    const palette = [
      Color(0xFF2E7D32), Color(0xFFF57C00),
      Color(0xFF1565C0), Color(0xFFE53935),
      Color(0xFF6A1B9A), Color(0xFF00695C),
    ];
    return palette[s.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final firstName = getFirstName();
    final dash      = getDashboard();

    final classesToday  = dash?['classesToday']  ?? 0;
    final totalStudents = dash?['totalStudents']  ?? 0;
    final avgAttendance = dash?['avgAttendance']  ?? 0;
    final rawSchedule   = dash?['todaySchedule']  as List? ?? [];
    final rawUnits      = dash?['unitAttendance'] as List? ?? [];

    return RefreshIndicator(
      color: _indigo,
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220, pinned: true,
            backgroundColor: _indigo, automaticallyImplyLeading: false,
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
                      colors: [_indigo, _indigoMid, Color(0xFF5C6BC0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                        parent: fadeCtrl, curve: Curves.easeOut),
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
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : 'L',
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
                                      color:
                                          Colors.white.withOpacity(0.85))),
                              Text('Dr. $firstName',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                              Text('Computer Science Dept.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withOpacity(0.7))),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('LECTURER',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1)),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        // Stats strip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                            _HeaderStat('$classesToday', 'Today'),
                            Container(
                                width: 1,
                                height: 28,
                                color: Colors.white.withOpacity(0.3)),
                            _HeaderStat('$totalStudents', 'Students'),
                            Container(
                                width: 1,
                                height: 28,
                                color: Colors.white.withOpacity(0.3)),
                            _HeaderStat('$avgAttendance%', 'Avg Att.'),
                          ]),
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

                // ── Today's schedule ─────────────────────────────────────────
                SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: slideCtrl, curve: Curves.easeOutCubic)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _LecSectionHeader(
                        title: "Today's Schedule",
                        icon: Icons.today_rounded,
                        color: _indigo,
                        action: rawSchedule.isEmpty ? null : 'Full View',
                        onAction: () => context.go('/timetable')),
                    const SizedBox(height: 12),
                    if (rawSchedule.isEmpty)
                      _EmptyCard(
                          icon: Icons.event_note_rounded,
                          message: 'No classes scheduled today',
                          color: _indigo)
                    else
                      ...rawSchedule.map((c) {
                        final m       = c as Map<String, dynamic>;
                        final present = m['present'] as num? ?? 0;
                        final total   = m['total']   as num? ?? 0;
                        final isNow   = m['isNow']   as bool? ?? false;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isNow
                                ? Border.all(color: _indigo, width: 1.5)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Row(children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                  color: _indigo.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              child: Center(
                                child: Text(
                                  m['startTime'] as String? ?? '',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _indigo),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                Text(m['unitName'] as String? ?? '—',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${m['unitCode'] ?? '—'}  ·  ${m['room'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ]),
                            ),
                            Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                              Text('$present/$total',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _indigo)),
                              Text('present',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400)),
                              if (isNow) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: _indigo,
                                      borderRadius:
                                          BorderRadius.circular(6)),
                                  child: const Text('NOW',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white)),
                                ),
                              ],
                            ]),
                          ]),
                        );
                      }),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── My students ──────────────────────────────────────────────
                _LecSectionHeader(
                    title: 'My Students',
                    icon: Icons.people_rounded,
                    color: _indigo),
                const SizedBox(height: 12),
                const _LecStudentTeaser(),
                const SizedBox(height: 24),

                // ── Attendance by unit ───────────────────────────────────────
                _LecSectionHeader(
                    title: 'Attendance by Unit',
                    icon: Icons.analytics_rounded,
                    color: _indigo,
                    action: rawUnits.isEmpty ? null : 'Details',
                    onAction: () => context.go('/history')),
                const SizedBox(height: 12),

                if (rawUnits.isEmpty)
                  _EmptyCard(
                      icon: Icons.bar_chart_rounded,
                      message: 'No attendance data yet',
                      color: _indigo)
                else
                  Container(
                    padding: const EdgeInsets.all(16),
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
                      children: rawUnits.map((u) {
                        final m    = u as Map<String, dynamic>;
                        final pct  = (m['pct'] as num?)?.toInt() ?? 0;
                        final name = m['name'] as String? ?? '—';
                        final code = m['code'] as String? ?? '';
                        final col  = _colorFromString(code);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                              Text('$pct%',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: col)),
                            ]),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                minHeight: 7,
                                backgroundColor:
                                    Colors.grey.shade100,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(col),
                              ),
                            ),
                          ]),
                        );
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
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT TEASER (unchanged logic, real API)
// ─────────────────────────────────────────────────────────────────────────────

class _LecStudentTeaser extends StatefulWidget {
  const _LecStudentTeaser();
  @override State<_LecStudentTeaser> createState() => _LecStudentTeaserState();
}

class _LecStudentTeaserState extends State<_LecStudentTeaser> {
  static const _indigo = Color(0xFF283593);
  List<Map<String,dynamic>> _students = [];
  bool _loading = true; int _total = 0; String? _error; String _search = '';
  final _sc = TextEditingController();

  @override void initState() { super.initState(); _fetch(); }
  @override void dispose()   { _sc.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiService().get('/users', queryParams: {
      'role': 'student', 'limit': '6',
      if (_search.isNotEmpty) 'search': _search,
    });
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _students = List<Map<String,dynamic>>.from(r.data?['users'] ?? []);
        _total    = (r.data?['pagination']?['total'] as num?)?.toInt() ?? 0;
        _loading  = false;
      });
    } else {
      setState(() { _error = r.error; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _sc,
            onChanged: (v) { setState(() => _search = v); _fetch(); },
            decoration: InputDecoration(
              hintText: 'Search students…',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 18, color: Colors.grey.shade400),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          size: 16, color: Colors.grey.shade400),
                      onPressed: () {
                        _sc.clear();
                        setState(() => _search = '');
                        _fetch();
                      })
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              filled: true, fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(
                  color: _indigo, strokeWidth: 2)))
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              const SizedBox(height: 8),
              TextButton(onPressed: _fetch,
                  child: const Text('Retry',
                      style: TextStyle(color: _indigo))),
            ])),
          )
        else if (_students.isEmpty)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No students found',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13))))
        else ...[
          ...List.generate(_students.length, (i) {
            final u      = _students[i];
            final name   = u['fullName']           as String? ?? '—';
            final reg    = u['registrationNumber'] as String? ?? '—';
            final init   = name.trim().split(' ').take(2)
                .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
            final isLast = i == _students.length - 1;
            return Column(children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 2),
                leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _indigo.withOpacity(0.1),
                    child: Text(init,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _indigo))),
                title: Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(reg,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
                dense: true,
              ),
              if (!isLast)
                Divider(height: 1, indent: 56, color: Colors.grey.shade100),
            ]);
          }),
          InkWell(
            onTap: () {},
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: _indigo.withOpacity(0.04),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20))),
              child: Center(
                child: Text(
                  _total > 6 ? 'View all $_total students →' : 'View all',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _indigo,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String value, label;
  const _HeaderStat(this.value, this.label);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
    Text(label, style: TextStyle(
        fontSize: 10, color: Colors.white.withOpacity(0.75))),
  ]);
}

class _LecSectionHeader extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  final String? action; final VoidCallback? onAction;
  const _LecSectionHeader({required this.title, required this.icon,
      required this.color, this.action, this.onAction});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color), const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
    const Spacer(),
    if (action != null)
      GestureDetector(
        onTap: onAction,
        child: Text(action!, style: TextStyle(fontSize: 12,
            color: color, fontWeight: FontWeight.w600)),
      ),
  ]);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon; final String message; final Color color;
  const _EmptyCard({required this.icon, required this.message,
      required this.color});
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