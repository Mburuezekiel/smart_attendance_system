// lib/features/home/presentation/lecturer_home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';
import '../../lecturer/lecturer_qr_page.dart';

// ── Theme-aware color helpers ─────────────────────────────────────────────────
class _LC {
  static bool _d(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;

  static Color bg(BuildContext ctx)         => _d(ctx) ? const Color(0xFF0D1520) : const Color(0xFFF2F4F8);
  static Color surface(BuildContext ctx)    => _d(ctx) ? const Color(0xFF162030) : Colors.white;
  static Color surfaceAlt(BuildContext ctx) => _d(ctx) ? const Color(0xFF1C2B3A) : const Color(0xFFF0F4FF);
  static Color border(BuildContext ctx)     => _d(ctx) ? const Color(0xFF243040) : const Color(0xFFE0E6EF);
  static Color textPri(BuildContext ctx)    => _d(ctx) ? const Color(0xFFE8EEF8) : const Color(0xFF0F1E33);
  static Color textSec(BuildContext ctx)    => _d(ctx) ? const Color(0xFF7A90AA) : const Color(0xFF5A6E88);
  static Color textHint(BuildContext ctx)   => _d(ctx) ? const Color(0xFF3A4E62) : const Color(0xFFAABBCC);
  static Color indigoFill(BuildContext ctx) => _d(ctx) ? const Color(0xFF1A2448) : const Color(0xFFEEF0FF);
  static Color navBg(BuildContext ctx)      => _d(ctx) ? const Color(0xFF162030) : Colors.white;
  static Color navShadow(BuildContext ctx)  => _d(ctx) ? Colors.black54 : Colors.black12;
  static Color cardShadow(BuildContext ctx) => _d(ctx) ? Colors.black54 : Colors.black12;
  static Color divider(BuildContext ctx)    => _d(ctx) ? const Color(0xFF1C2B3A) : const Color(0xFFF0F0F0);
  static Color inputBg(BuildContext ctx)    => _d(ctx) ? const Color(0xFF1C2B3A) : const Color(0xFFF4F6FA);

  static const indigo    = Color(0xFF3949AB);
  static const indigoDark = Color(0xFF283593);
  static const indigoLight = Color(0xFF5C6BC0);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class LecturerHomePage extends StatefulWidget {
  const LecturerHomePage({super.key});
  @override State<LecturerHomePage> createState() => _LecturerHomePageState();
}

class _LecturerHomePageState extends State<LecturerHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  int  _selectedIndex = 0;

  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final AnimationController _slideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))..forward();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
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
      return Scaffold(
        backgroundColor: _LC.bg(context),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: _LC.indigo, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Loading dashboard…',
                style: TextStyle(color: _LC.textSec(context), fontSize: 13)),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _LC.bg(context),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _LecturerBottomNav(
        selectedIndex: _selectedIndex,
        onTabChange: (i) {
          if (i == 2) { context.go('/analytics'); return; }
          if (i == 3) { context.go('/timetable'); return; }
          if (i == 4) { context.go('/history');   return; }
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

class _LecturerBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  const _LecturerBottomNav(
      {required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _LC.navBg(context),
      boxShadow: [
        BoxShadow(
            color: _LC.navShadow(context).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -4))
      ],
      border: Border(top: BorderSide(color: _LC.border(context), width: 0.5)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: GNav(
      backgroundColor: _LC.navBg(context),
      color: _LC.textHint(context),
      activeColor: Colors.white,
      tabBackgroundColor: _LC.indigo,
      gap: 8,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      selectedIndex: selectedIndex,
      onTabChange: onTabChange,
      tabs: const [
        GButton(icon: Icons.home_rounded,           text: 'Home'),
        GButton(icon: Icons.qr_code_rounded,        text: 'QR Code'),
        GButton(icon: Icons.assessment_rounded,     text: 'Reports'),
        GButton(icon: Icons.calendar_today_rounded, text: 'Schedule'),
        GButton(icon: Icons.history_rounded,        text: 'History'),
        GButton(icon: Icons.settings_rounded,       text: 'Settings'),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME BODY
// ─────────────────────────────────────────────────────────────────────────────

class _LecHomeBody extends StatelessWidget {
  final AnimationController fadeCtrl;
  final AnimationController slideCtrl;
  final String Function() getFirstName;
  final Map<String, dynamic>? Function() getDashboard;
  final VoidCallback onRefresh;

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

  Color _unitColor(String s) {
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
      color: _LC.indigo,
      backgroundColor: _LC.surface(context),
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Collapsible App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: _LC.indigoDark,
            automaticallyImplyLeading: false,
            elevation: 0,
            actions: [
              _AppBarAction(
                icon: Icons.notifications_outlined,
                badge: true,
                onTap: () {},
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF283593),
                      Color(0xFF3949AB),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                        parent: fadeCtrl, curve: Curves.easeOut),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile row
                          Row(children: [
                            _AvatarCircle(
                              initial: firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : 'L',
                              color: Colors.white.withOpacity(0.2),
                              radius: 26,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Good ${_greeting()}, 👋',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.8))),
                                  Text('Dr. $firstName',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                  Text('Computer Science Dept.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.65))),
                                ],
                              ),
                            ),
                            _RoleBadge('LECTURER'),
                          ]),
                          const SizedBox(height: 18),
                          // Stats strip
                          _StatsStrip(stats: [
                            _StatItem('$classesToday', 'Today'),
                            _StatItem('$totalStudents', 'Students'),
                            _StatItem('$avgAttendance%', 'Avg Att.'),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Today's Schedule ────────────────────────────────────────
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: slideCtrl, curve: Curves.easeOutCubic)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: "Today's Schedule",
                        icon: Icons.today_rounded,
                        color: _LC.indigo,
                        action: rawSchedule.isEmpty ? null : 'Full View',
                        onAction: () => context.go('/timetable'),
                      ),
                      const SizedBox(height: 12),
                      if (rawSchedule.isEmpty)
                        _EmptyCard(
                          icon: Icons.event_note_rounded,
                          message: 'No classes scheduled today',
                          color: _LC.indigo,
                        )
                      else
                        ...rawSchedule.map((c) {
                          final m       = c as Map<String, dynamic>;
                          final present = m['present'] as num? ?? 0;
                          final total   = m['total']   as num? ?? 0;
                          final isNow   = m['isNow']   as bool? ?? false;
                          return _ScheduleCard(
                            startTime: m['startTime'] as String? ?? '',
                            unitName:  m['unitName']  as String? ?? '—',
                            unitCode:  m['unitCode']  as String? ?? '—',
                            room:      m['room']      as String? ?? '',
                            present:   present.toInt(),
                            total:     total.toInt(),
                            isNow:     isNow,
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── My Students ─────────────────────────────────────────────
                _SectionHeader(
                  title: 'My Students',
                  icon: Icons.people_rounded,
                  color: _LC.indigo,
                ),
                const SizedBox(height: 12),
                _LecStudentTeaser(),
                const SizedBox(height: 24),

                // ── Attendance by Unit ──────────────────────────────────────
                _SectionHeader(
                  title: 'Attendance by Unit',
                  icon: Icons.analytics_rounded,
                  color: _LC.indigo,
                  action: rawUnits.isEmpty ? null : 'Details',
                  onAction: () => context.go('/analytics'),
                ),
                const SizedBox(height: 12),

                if (rawUnits.isEmpty)
                  _EmptyCard(
                    icon: Icons.bar_chart_rounded,
                    message: 'No attendance data yet',
                    color: _LC.indigo,
                  )
                else
                  _SurfaceCard(
                    child: Column(
                      children: rawUnits.map((u) {
                        final m    = u as Map<String, dynamic>;
                        final pct  = (m['pct'] as num?)?.toInt() ?? 0;
                        final name = m['name'] as String? ?? '—';
                        final code = m['code'] as String? ?? '';
                        final col  = _unitColor(code);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _LC.textPri(context))),
                                ),
                                Text('$pct%',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: col)),
                              ]),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  minHeight: 8,
                                  backgroundColor: _LC.border(context),
                                  valueColor: AlwaysStoppedAnimation<Color>(col),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 36),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final String startTime, unitName, unitCode, room;
  final int present, total;
  final bool isNow;

  const _ScheduleCard({
    required this.startTime,
    required this.unitName,
    required this.unitCode,
    required this.room,
    required this.present,
    required this.total,
    required this.isNow,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: _LC.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isNow ? _LC.indigo.withOpacity(0.6) : _LC.border(context),
        width: isNow ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: _LC.cardShadow(context).withOpacity(isNow ? 0.12 : 0.05),
          blurRadius: isNow ? 20 : 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        // Time box
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _LC.indigoFill(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              startTime,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _LC.indigo,
                  height: 1.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(unitName,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _LC.textPri(context))),
            const SizedBox(height: 3),
            Text('$unitCode  ·  $room',
                style: TextStyle(fontSize: 11, color: _LC.textSec(context))),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$present/$total',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _LC.indigo)),
          Text('present',
              style: TextStyle(fontSize: 10, color: _LC.textHint(context))),
          if (isNow) ...[
            const SizedBox(height: 5),
            _NowBadge(),
          ],
        ]),
      ]),
    ),
  );
}

class _NowBadge extends StatefulWidget {
  @override State<_NowBadge> createState() => _NowBadgeState();
}

class _NowBadgeState extends State<_NowBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _LC.indigo.withOpacity(0.85 + _c.value * 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    ),
    child: const Text('LIVE',
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT TEASER
// ─────────────────────────────────────────────────────────────────────────────

class _LecStudentTeaser extends StatefulWidget {
  @override State<_LecStudentTeaser> createState() => _LecStudentTeaserState();
}

class _LecStudentTeaserState extends State<_LecStudentTeaser> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  int  _total = 0;
  String? _error;
  String _search = '';
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
        _students = List<Map<String, dynamic>>.from(r.data?['users'] ?? []);
        _total    = (r.data?['pagination']?['total'] as num?)?.toInt() ?? 0;
        _loading  = false;
      });
    } else {
      setState(() { _error = r.error; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search field
      _SearchField(
        controller: _sc,
        hintText: 'Search students…',
        onChanged: (v) { setState(() => _search = v); _fetch(); },
        onClear: () { _sc.clear(); setState(() => _search = ''); _fetch(); },
        hasText: _search.isNotEmpty,
      ),
      const SizedBox(height: 10),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: _LC.indigo, strokeWidth: 2)),
        )
      else if (_error != null)
        _InlineError(message: _error!, onRetry: _fetch, color: _LC.indigo)
      else if (_students.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No students found',
                style: TextStyle(color: _LC.textHint(context), fontSize: 13)),
          ),
        )
      else ...[
        ...List.generate(_students.length, (i) {
          final u      = _students[i];
          final name   = u['fullName'] as String? ?? '—';
          final reg    = u['registrationNumber'] as String? ?? '—';
          final initials = name.trim().split(' ').take(2)
              .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
          final isLast = i == _students.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                _AvatarCircle(
                    initial: initials,
                    color: _LC.indigoFill(context),
                    textColor: _LC.indigo,
                    radius: 18),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _LC.textPri(context))),
                    Text(reg, style: TextStyle(
                        fontSize: 11, color: _LC.textSec(context))),
                  ],
                )),
                Icon(Icons.chevron_right_rounded, color: _LC.textHint(context), size: 18),
              ]),
            ),
            if (!isLast) Divider(height: 1, color: _LC.divider(context)),
          ]);
        }),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _LC.indigoFill(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _total > 6 ? 'View all $_total students →' : 'View all →',
                style: TextStyle(
                    fontSize: 12,
                    color: _LC.indigo,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _SurfaceCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _LC.surface(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor ?? _LC.border(context), width: 1),
      boxShadow: [
        BoxShadow(
          color: _LC.cardShadow(context).withOpacity(0.07),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: color),
    ),
    const SizedBox(width: 9),
    Text(title,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _LC.textPri(context))),
    const Spacer(),
    if (action != null)
      GestureDetector(
        onTap: onAction,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(action!,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ),
      ),
  ]);
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _EmptyCard({required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 32),
    decoration: BoxDecoration(
      color: _LC.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _LC.border(context)),
    ),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42, color: _LC.textHint(context)),
        const SizedBox(height: 10),
        Text(message,
            style: TextStyle(fontSize: 13, color: _LC.textSec(context))),
      ]),
    ),
  );
}

class _AvatarCircle extends StatelessWidget {
  final String initial;
  final Color color;
  final Color? textColor;
  final double radius;
  const _AvatarCircle({
    required this.initial,
    required this.color,
    this.textColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: color,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w800,
        color: textColor ?? Colors.white,
      ),
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: Text(label,
        style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2)),
  );
}

class _StatsStrip extends StatelessWidget {
  final List<_StatItem> stats;
  const _StatsStrip({required this.stats});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(stats.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Container(
              width: 1, height: 28, color: Colors.white.withOpacity(0.25));
        }
        final s = stats[i ~/ 2];
        return Column(children: [
          Text(s.value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(s.label,
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withOpacity(0.75))),
        ]);
      }),
    ),
  );
}

class _StatItem {
  final String value, label;
  const _StatItem(this.value, this.label);
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;
  const _AppBarAction(
      {required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      if (badge)
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFFFF5252), shape: BoxShape.circle),
          ),
        ),
    ]),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasText;
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    required this.hasText,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: TextStyle(fontSize: 13, color: _LC.textPri(context)),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: _LC.textHint(context)),
      prefixIcon: Icon(Icons.search_rounded, size: 18, color: _LC.textHint(context)),
      suffixIcon: hasText
          ? IconButton(
              icon: Icon(Icons.clear_rounded, size: 16, color: _LC.textHint(context)),
              onPressed: onClear)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: _LC.inputBg(context),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color color;
  const _InlineError(
      {required this.message, required this.onRetry, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _LC.textSec(context))),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    ),
  );
}