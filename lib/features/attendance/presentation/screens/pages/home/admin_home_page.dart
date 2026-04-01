// lib/features/home/presentation/admin_home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';
import '../../admin/admin_assignments_page.dart';

// ── Theme-aware color helpers ─────────────────────────────────────────────────
class _AC {
  static bool _d(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;

  static Color bg(BuildContext ctx)         => _d(ctx) ? const Color(0xFF091614) : const Color(0xFFF0F5F4);
  static Color surface(BuildContext ctx)    => _d(ctx) ? const Color(0xFF112620) : Colors.white;
  static Color surfaceAlt(BuildContext ctx) => _d(ctx) ? const Color(0xFF193028) : const Color(0xFFEDF7F5);
  static Color border(BuildContext ctx)     => _d(ctx) ? const Color(0xFF1E3830) : const Color(0xFFD6EDEA);
  static Color textPri(BuildContext ctx)    => _d(ctx) ? const Color(0xFFE0F0EE) : const Color(0xFF0B2220);
  static Color textSec(BuildContext ctx)    => _d(ctx) ? const Color(0xFF6A9A94) : const Color(0xFF4A7A74);
  static Color textHint(BuildContext ctx)   => _d(ctx) ? const Color(0xFF2E5050) : const Color(0xFFAACAC8);
  static Color tealFill(BuildContext ctx)   => _d(ctx) ? const Color(0xFF163028) : const Color(0xFFE0F2F1);
  static Color navBg(BuildContext ctx)      => _d(ctx) ? const Color(0xFF112620) : Colors.white;
  static Color inputBg(BuildContext ctx)    => _d(ctx) ? const Color(0xFF193028) : const Color(0xFFF4F8F7);
  static Color divider(BuildContext ctx)    => _d(ctx) ? const Color(0xFF193028) : const Color(0xFFF0F0F0);
  static Color cardShadow(BuildContext ctx) => _d(ctx) ? Colors.black54 : Colors.black12;

  static const teal      = Color(0xFF00796B);
  static const tealDark  = Color(0xFF00695C);
  static const tealLight = Color(0xFF26A69A);
  static const tealPale  = Color(0xFFE0F2F1);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});
  @override State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboardStats;
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
    final user        = await ApiService().getUser();
    final statsResult = await ApiService().get('/users/dashboard-stats');
    if (!mounted) return;
    _user = user;
    if (statsResult.success) _dashboardStats = statsResult.data;
    setState(() => _loading = false);
    _buildPages();
  }

  void _buildPages() {
    _pages = [
      _AdminHomeBody(
        fadeCtrl:     _fadeCtrl,
        slideCtrl:    _slideCtrl,
        getFirstName: () => _firstName,
        getStats:     () => _dashboardStats,
      ),
      const _ManageUsersPage(),
      const AdminAssignmentsPage(),
    ];
    if (mounted) setState(() {});
  }

  String get _firstName =>
      (_user?['fullName'] as String? ?? 'Admin').split(' ').first;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _AC.bg(context),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _AC.teal, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Loading dashboard…',
                style: TextStyle(color: _AC.textSec(context), fontSize: 13)),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _AC.bg(context),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _AdminBottomNav(
        selectedIndex: _selectedIndex,
        onTabChange: (i) {
          if (i == 3) { context.go('/notifications'); return; }
          if (i == 4) { context.go('/settings');      return; }
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  const _AdminBottomNav(
      {required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _AC.navBg(context),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -4))
      ],
      border: Border(top: BorderSide(color: _AC.border(context), width: 0.5)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: GNav(
      backgroundColor: _AC.navBg(context),
      color: _AC.textHint(context),
      activeColor: Colors.white,
      tabBackgroundColor: _AC.teal,
      gap: 8,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      selectedIndex: selectedIndex,
      onTabChange: onTabChange,
      tabs: const [
        GButton(icon: Icons.dashboard_rounded,            text: 'Dashboard'),
        GButton(icon: Icons.manage_accounts_rounded,      text: 'Users'),
        GButton(icon: Icons.assignment_rounded,           text: 'Assign'),
        GButton(icon: Icons.notifications_active_rounded, text: 'Alerts'),
        GButton(icon: Icons.settings_rounded,             text: 'Settings'),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN HOME BODY
// ─────────────────────────────────────────────────────────────────────────────

class _AdminHomeBody extends StatelessWidget {
  final AnimationController fadeCtrl;
  final AnimationController slideCtrl;
  final String Function() getFirstName;
  final Map<String, dynamic>? Function() getStats;

  const _AdminHomeBody({
    required this.fadeCtrl,
    required this.slideCtrl,
    required this.getFirstName,
    required this.getStats,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = getFirstName();
    final s         = getStats();

    final totalStudents   = s?['totalStudents']     ?? 0;
    final totalLecturers  = s?['totalLecturers']    ?? 0;
    final overallAtt      = s?['overallAttendance'] ?? 0;
    final activeAlerts    = s?['activeAlerts']      ?? 0;
    final studentDelta    = s?['studentDelta']      as String? ?? '+0 this week';
    final lecturerDelta   = s?['lecturerDelta']     as String? ?? '+0 this month';
    final attendanceDelta = s?['attendanceDelta']   as String? ?? '↑ 0% vs last week';
    final alertDetail     = s?['alertDetail']       as String? ?? '0 critical';

    final kpis = [
      _KpiData('$totalStudents',  'Total Students',     Icons.school_rounded,            _AC.teal,                   studentDelta),
      _KpiData('$totalLecturers', 'Lecturers',           Icons.person_pin_rounded,        const Color(0xFF3949AB),     lecturerDelta),
      _KpiData('$overallAtt%',    'Overall Attendance',  Icons.bar_chart_rounded,         const Color(0xFF2E7D32),     attendanceDelta),
      _KpiData('$activeAlerts',   'Active Alerts',       Icons.warning_amber_rounded,     const Color(0xFFE53935),     alertDetail),
    ];

    final healthChecks = [
      _HealthData('Database',       true,  'Connected · 12ms'),
      _HealthData('Auth Service',   true,  'Operational'),
      _HealthData('Biometric API',  true,  'Operational'),
      _HealthData('Backup Service', false, 'Last backup: 2h ago'),
    ];

    final rawDepts  = s?['deptAttendance'] as List?;
    final deptColors = [
      const Color(0xFF2E7D32), const Color(0xFF1565C0), _AC.teal,
      const Color(0xFFF57C00), const Color(0xFF6A1B9A),
    ];
    final depts = rawDepts != null
        ? rawDepts.asMap().entries.map((e) => _DeptData(
              e.value['name'] as String,
              (e.value['pct'] as num).toInt(),
              deptColors[e.key % deptColors.length]))
            .toList()
        : [
            _DeptData('Computer Science', 92, const Color(0xFF2E7D32)),
            _DeptData('Mathematics',       84, const Color(0xFF1565C0)),
            _DeptData('Engineering',       78, _AC.teal),
            _DeptData('Business Admin',   71, const Color(0xFFF57C00)),
            _DeptData('Social Sciences',  65, const Color(0xFF6A1B9A)),
          ];

    final alerts = [
      _AlertData('Low Attendance',   'CS-301: 3 students below 60%', _AlertLevel.critical),
      _AlertData('Missed Session',   'Dr. Kamau — Networks (Mon)',    _AlertLevel.warning),
      _AlertData('New Registration', '14 new student accounts today', _AlertLevel.info),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Collapsible App Bar ────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          backgroundColor: _AC.tealDark,
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: [
            _AppBarIconBtn(icon: Icons.notifications_outlined, badge: true, onTap: () {}),
            const SizedBox(width: 4),
            _AppBarIconBtn(icon: Icons.settings_outlined, onTap: () {}),
            const SizedBox(width: 10),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: fadeCtrl, curve: Curves.easeOut),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.shield_rounded,
                                color: Colors.white, size: 26),
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
                                Text(firstName,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                Text('System Administrator',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.65))),
                              ],
                            ),
                          ),
                          _RoleBadge('ADMIN'),
                        ]),
                        const SizedBox(height: 18),
                        _StatsStrip(stats: [
                          _StatItem('$totalStudents',  'Students'),
                          _StatItem('$totalLecturers', 'Lecturers'),
                          _StatItem('$overallAtt%',    'Attendance'),
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
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: slideCtrl, curve: Curves.easeOutCubic)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KPI Cards Grid ───────────────────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: kpis.map((k) => _KpiCard(kpi: k)).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── System Health ────────────────────────────────────────
                    _SectionHeader(
                      title: 'System Health',
                      icon: Icons.monitor_heart_rounded,
                      color: _AC.teal,
                    ),
                    const SizedBox(height: 12),
                    _SurfaceCard(
                      child: Column(
                        children: healthChecks.asMap().entries.map((e) {
                          final c      = e.value;
                          final isLast = e.key == healthChecks.length - 1;
                          return Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                // Status dot
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.ok
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFF57C00),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (c.ok
                                                ? const Color(0xFF2E7D32)
                                                : const Color(0xFFF57C00))
                                            .withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(c.name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _AC.textPri(context))),
                                ),
                                Text(c.detail,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _AC.textSec(context))),
                                const SizedBox(width: 8),
                                _StatusBadge(ok: c.ok),
                              ]),
                            ),
                            if (!isLast)
                              Divider(height: 1, color: _AC.divider(context)),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Dept. Attendance ─────────────────────────────────────
                    _SectionHeader(
                      title: 'Department Attendance',
                      icon: Icons.domain_rounded,
                      color: _AC.teal,
                      action: 'Full Report',
                      onAction: () {},
                    ),
                    const SizedBox(height: 12),
                    _SurfaceCard(
                      child: Column(
                        children: depts.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(children: [
                            SizedBox(
                              width: 120,
                              child: Text(d.name,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _AC.textPri(context))),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: d.pct / 100,
                                  minHeight: 9,
                                  backgroundColor: _AC.border(context),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(d.color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 38,
                              child: Text('${d.pct}%',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: d.color)),
                            ),
                          ]),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Recent Alerts ────────────────────────────────────────
                    _SectionHeader(
                      title: 'Recent Alerts',
                      icon: Icons.notifications_active_rounded,
                      color: _AC.teal,
                      action: 'View All',
                      onAction: () {},
                    ),
                    const SizedBox(height: 12),
                    _SurfaceCard(
                      child: Column(
                        children: alerts.asMap().entries.map((e) {
                          final a      = e.value;
                          final isLast = e.key == alerts.length - 1;
                          final (color, bg, icon) = switch (a.level) {
                            _AlertLevel.critical => (
                              const Color(0xFFE53935),
                              const Color(0xFFFFEBEE),
                              Icons.error_rounded
                            ),
                            _AlertLevel.warning => (
                              const Color(0xFFF57C00),
                              const Color(0xFFFFF8E1),
                              Icons.warning_rounded
                            ),
                            _AlertLevel.info => (
                              _AC.teal,
                              _AC.tealPale,
                              Icons.info_rounded
                            ),
                          };
                          return Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                      color: bg, shape: BoxShape.circle),
                                  child: Icon(icon, color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(a.title,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _AC.textPri(context))),
                                      const SizedBox(height: 2),
                                      Text(a.body,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: _AC.textSec(context))),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: _AC.textHint(context), size: 18),
                              ]),
                            ),
                            if (!isLast)
                              Divider(height: 1, color: _AC.divider(context)),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE USERS PAGE (tab 1)
// ─────────────────────────────────────────────────────────────────────────────

class _ManageUsersPage extends StatefulWidget {
  const _ManageUsersPage();
  @override State<_ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<_ManageUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _roleFilter = 'all';
  String _search = '';
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loadingMore = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _fetchUsers(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetchUsers({int page = 1, bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() { _loading = true; _error = null; });
    }
    final result = await ApiService().get('/users', queryParams: {
      'page': '$page',
      'limit': '20',
      if (_roleFilter != 'all') 'role': _roleFilter,
      if (_search.isNotEmpty) 'search': _search,
    });
    if (!mounted) return;
    if (result.success) {
      final incoming =
          List<Map<String, dynamic>>.from(result.data?['users'] ?? []);
      setState(() {
        _users      = append ? [..._users, ...incoming] : incoming;
        _page       = result.data?['pagination']?['page']  ?? 1;
        _totalPages = result.data?['pagination']?['pages'] ?? 1;
        _total      = result.data?['pagination']?['total'] ?? 0;
        _loading    = false;
        _loadingMore = false;
      });
    } else {
      setState(() {
        _error       = result.error;
        _loading     = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearch(String val) {
    setState(() => _search = val);
    _fetchUsers();
  }

  void _onRoleFilter(String role) {
    setState(() { _roleFilter = role; _search = ''; _searchCtrl.clear(); });
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _AC.bg(context),
    appBar: AppBar(
      backgroundColor: _AC.tealDark,
      automaticallyImplyLeading: false,
      elevation: 0,
      centerTitle: false,
      title: const Text('Manage Users',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_total users',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
    body: Column(children: [
      // Filter bar
      Container(
        color: _AC.surface(context),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(children: [
          _SearchField(
            controller: _searchCtrl,
            hintText: 'Search name, email or reg. no…',
            onChanged: _onSearch,
            onClear: () { _searchCtrl.clear(); _onSearch(''); },
            hasText: _search.isNotEmpty,
          ),
          const SizedBox(height: 12),
          Row(children: [
            _RoleChip(label: 'All',       value: 'all',      current: _roleFilter, onTap: _onRoleFilter),
            const SizedBox(width: 8),
            _RoleChip(label: 'Students',  value: 'student',  current: _roleFilter, onTap: _onRoleFilter),
            const SizedBox(width: 8),
            _RoleChip(label: 'Lecturers', value: 'lecturer', current: _roleFilter, onTap: _onRoleFilter),
          ]),
        ]),
      ),
      // List area
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _AC.teal, strokeWidth: 2.5))
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _fetchUsers)
                : _users.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline_rounded,
                              size: 52, color: _AC.textHint(context)),
                          const SizedBox(height: 12),
                          Text('No users found',
                              style: TextStyle(
                                  color: _AC.textSec(context), fontSize: 14)),
                        ]),
                      )
                    : RefreshIndicator(
                        color: _AC.teal,
                        backgroundColor: _AC.surface(context),
                        onRefresh: () => _fetchUsers(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length + (_page < _totalPages ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            if (i == _users.length) {
                              return _loadingMore
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator(
                                              color: _AC.teal, strokeWidth: 2)))
                                  : Center(
                                      child: TextButton(
                                        onPressed: () => _fetchUsers(
                                            page: _page + 1, append: true),
                                        child: Text('Load more',
                                            style: TextStyle(
                                                color: _AC.teal,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    );
                            }
                            return _UserTile(user: _users[i]);
                          },
                        ),
                      ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI CARD
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final _KpiData kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _AC.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _AC.border(context)),
      boxShadow: [
        BoxShadow(
          color: _AC.cardShadow(context).withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kpi.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(kpi.icon, color: kpi.color, size: 16),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: kpi.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            kpi.trend,
            style: TextStyle(
                fontSize: 9, color: kpi.color, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      const Spacer(),
      Text(kpi.value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: kpi.color)),
      const SizedBox(height: 2),
      Text(kpi.label,
          style: TextStyle(fontSize: 11, color: _AC.textSec(context))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// USER TILE
// ─────────────────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserTile({required this.user});

  Color get _roleColor => switch (user['role'] as String? ?? 'student') {
    'admin'    => const Color(0xFF6A1B9A),
    'lecturer' => const Color(0xFF283593),
    _          => _AC.teal,
  };
  IconData get _roleIcon => switch (user['role'] as String? ?? 'student') {
    'admin'    => Icons.shield_rounded,
    'lecturer' => Icons.person_pin_rounded,
    _          => Icons.school_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final name      = user['fullName'] as String? ?? '—';
    final email     = user['email']    as String? ?? '—';
    final regNo     = user['registrationNumber'] as String? ?? '—';
    final roleLabel = (user['role'] as String? ?? 'student').toUpperCase();
    final initials  = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: _AC.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AC.border(context)),
        boxShadow: [
          BoxShadow(
            color: _AC.cardShadow(context).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: _roleColor.withOpacity(0.12),
          child: Text(initials,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _roleColor)),
        ),
        title: Text(name,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _AC.textPri(context))),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(email,
              style: TextStyle(fontSize: 11, color: _AC.textSec(context))),
          Text(regNo,
              style: TextStyle(fontSize: 11, color: _AC.textHint(context))),
        ]),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_roleIcon, size: 11, color: _roleColor),
            const SizedBox(width: 4),
            Text(roleLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _roleColor)),
          ]),
        ),
      ),
    );
  }
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
      color: _AC.surface(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor ?? _AC.border(context), width: 1),
      boxShadow: [
        BoxShadow(
          color: _AC.cardShadow(context).withOpacity(0.07),
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
            color: _AC.textPri(context))),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
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

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;
  const _AppBarIconBtn(
      {required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
      if (badge)
        Positioned(
          top: 5,
          right: 5,
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

class _StatusBadge extends StatelessWidget {
  final bool ok;
  const _StatusBadge({required this.ok});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      ok ? 'OK' : 'WARN',
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: ok ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)),
    ),
  );
}

class _RoleChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _RoleChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _AC.teal : _AC.surfaceAlt(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? _AC.teal : _AC.border(context)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _AC.textSec(context))),
      ),
    );
  }
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
    style: TextStyle(fontSize: 13, color: _AC.textPri(context)),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: _AC.textHint(context)),
      prefixIcon: Icon(Icons.search_rounded, size: 18, color: _AC.textHint(context)),
      suffixIcon: hasText
          ? IconButton(
              icon: Icon(Icons.clear_rounded, size: 16, color: _AC.textHint(context)),
              onPressed: onClear)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: _AC.inputBg(context),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: _AC.textHint(context)),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _AC.textSec(context), fontSize: 13)),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: _AC.teal),
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

enum _AlertLevel { critical, warning, info }

class _KpiData {
  final String value, label, trend;
  final IconData icon;
  final Color color;
  const _KpiData(this.value, this.label, this.icon, this.color, this.trend);
}

class _HealthData {
  final String name, detail;
  final bool ok;
  const _HealthData(this.name, this.ok, this.detail);
}

class _DeptData {
  final String name;
  final int pct;
  final Color color;
  const _DeptData(this.name, this.pct, this.color);
}

class _AlertData {
  final String title, body;
  final _AlertLevel level;
  const _AlertData(this.title, this.body, this.level);
}