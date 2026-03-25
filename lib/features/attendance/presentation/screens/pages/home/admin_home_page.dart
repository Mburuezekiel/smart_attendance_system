// lib/features/home/presentation/admin_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';
// The assignments page lives one level up in features/assignments/presentation/
import '../../admin/admin_assignments_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});
  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboardStats;
  bool _loading = true;
  int  _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _teal    = Color(0xFF00695C);
  static const _tealMid = Color(0xFF00796B);

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadData();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

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
        fadeCtrl: _fadeCtrl, slideCtrl: _slideCtrl,
        getFirstName: () => _firstName, getStats: () => _dashboardStats,
      ),
      const _ManageUsersPage(),
      // Tab 2 — Admin assigns lecturers → units → students
      const AdminAssignmentsPage(),
    ];
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await ApiService().clearSession();
    if (mounted) context.go('/login');
  }

  String get _firstName =>
      (_user?['fullName'] as String? ?? 'Admin').split(' ').first;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator(color: _teal)));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _AdminBottomNav(
        selectedIndex: _selectedIndex,
        onTabChange: (i) {
          // Tabs 0, 1, 2 are embedded pages
          // Tabs 3, 4 navigate via GoRouter
          if (i == 3) { context.go('/notifications'); return; }
          if (i == 4) { context.go('/settings');      return; }
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV  — 5 tabs, tab 2 is now Assignments
// ─────────────────────────────────────────────────────────────────────────────

class _AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  static const _teal = Color(0xFF00695C);
  const _AdminBottomNav({required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, -4))]),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: Colors.white, color: Colors.grey.shade500,
        activeColor: Colors.white, tabBackgroundColor: _teal,
        gap: 8, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: selectedIndex, onTabChange: onTabChange,
        tabs: const [
          GButton(icon: Icons.dashboard_rounded,        text: 'Dashboard'),
          GButton(icon: Icons.manage_accounts_rounded,  text: 'Users'),
          GButton(icon: Icons.assignment_rounded,       text: 'Assign'),   // ← NEW
          GButton(icon: Icons.notifications_active_rounded, text: 'Alerts'),
          GButton(icon: Icons.settings_rounded,         text: 'Settings'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN HOME BODY
// ─────────────────────────────────────────────────────────────────────────────

class _AdminHomeBody extends StatelessWidget {
  final AnimationController fadeCtrl;
  final AnimationController slideCtrl;
  final String Function() getFirstName;
  final Map<String, dynamic>? Function() getStats;

  static const _teal      = Color(0xFF00695C);
  static const _tealMid   = Color(0xFF00796B);
  static const _tealLight = Color(0xFFE0F2F1);

  const _AdminHomeBody({required this.fadeCtrl, required this.slideCtrl,
    required this.getFirstName, required this.getStats});

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
      _Kpi('$totalStudents',  'Total Students',    Icons.school_rounded,        _teal,                   studentDelta),
      _Kpi('$totalLecturers', 'Lecturers',          Icons.person_pin_rounded,    const Color(0xFF283593),  lecturerDelta),
      _Kpi('$overallAtt%',    'Overall Attendance', Icons.bar_chart_rounded,     const Color(0xFF2E7D32),  attendanceDelta),
      _Kpi('$activeAlerts',   'Active Alerts',      Icons.warning_amber_rounded, const Color(0xFFE53935),  alertDetail),
    ];
    final healthChecks = [
      _HealthCheck('Database',       true,  'Connected · 12ms'),
      _HealthCheck('Auth Service',   true,  'Operational'),
      _HealthCheck('Biometric API',  true,  'Operational'),
      _HealthCheck('Backup Service', false, 'Last backup: 2h ago'),
    ];
    final rawDepts   = s?['deptAttendance'] as List?;
    final deptColors = [
      const Color(0xFF2E7D32), const Color(0xFF1565C0), _teal,
      const Color(0xFFF57C00), const Color(0xFF6A1B9A),
    ];
    final depts = rawDepts != null
        ? rawDepts.asMap().entries.map((e) => _Dept(
              e.value['name'] as String, (e.value['pct'] as num).toInt(),
              deptColors[e.key % deptColors.length])).toList()
        : [
            _Dept('Computer Science', 92, const Color(0xFF2E7D32)),
            _Dept('Mathematics',       84, const Color(0xFF1565C0)),
            _Dept('Engineering',       78, _teal),
            _Dept('Business Admin',   71, const Color(0xFFF57C00)),
            _Dept('Social Sciences',  65, const Color(0xFF6A1B9A)),
          ];
    final alerts = [
      _Alert('Low Attendance',   'CS-301: 3 students below 60%', _AlertLevel.critical),
      _Alert('Missed Session',   'Dr. Kamau — Networks (Mon)',    _AlertLevel.warning),
      _Alert('New Registration', '14 new student accounts today', _AlertLevel.info),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 220, pinned: true,
          backgroundColor: _teal, automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () {}),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_teal, _tealMid, Color(0xFF26A69A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: fadeCtrl, curve: Curves.easeOut),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 56, height: 56,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Good ${_greeting()}, 👋',
                              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                          Text(firstName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text('System Administrator',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('ADMIN', style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _HeaderStat('$totalStudents',  'Students'),
                          Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
                          _HeaderStat('$totalLecturers', 'Lecturers'),
                          Container(width: 1, height: 28, color: Colors.white.withOpacity(0.3)),
                          _HeaderStat('$overallAtt%',    'Attendance'),
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
          sliver: SliverList(delegate: SliverChildListDelegate([
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(CurvedAnimation(parent: slideCtrl, curve: Curves.easeOutCubic)),
              child: GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
                children: kpis.map((k) => _KpiCard(kpi: k)).toList(),
              ),
            ),
            const SizedBox(height: 24),

            _AdminSectionHeader(title: 'System Health', icon: Icons.monitor_heart_rounded, color: _teal),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16), decoration: _cardDecor(),
              child: Column(children: healthChecks.asMap().entries.map((e) {
                final c = e.value; final isLast = e.key == healthChecks.length - 1;
                return Column(children: [
                  Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle,
                        color: c.ok ? const Color(0xFF2E7D32) : const Color(0xFFF57C00))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    Text(c.detail, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: c.ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(c.ok ? 'OK' : 'WARN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: c.ok ? const Color(0xFF2E7D32) : const Color(0xFFF57C00))),
                    ),
                  ]),
                  if (!isLast) Divider(height: 20, color: Colors.grey.shade100),
                ]);
              }).toList()),
            ),
            const SizedBox(height: 24),

            _AdminSectionHeader(title: 'Dept. Attendance', icon: Icons.domain_rounded, color: _teal, action: 'Full Report'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16), decoration: _cardDecor(),
              child: Column(children: depts.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  SizedBox(width: 130, child: Text(d.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: d.pct / 100, minHeight: 9,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(d.color)))),
                  const SizedBox(width: 10),
                  SizedBox(width: 36, child: Text('${d.pct}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: d.color))),
                ]),
              )).toList()),
            ),
            const SizedBox(height: 24),

            _AdminSectionHeader(title: 'Recent Alerts', icon: Icons.notifications_active_rounded, color: _teal, action: 'View All'),
            const SizedBox(height: 12),
            Container(
              decoration: _cardDecor(),
              child: Column(children: alerts.asMap().entries.map((e) {
                final a = e.value; final isLast = e.key == alerts.length - 1;
                final (color, bg, icon) = switch (a.level) {
                  _AlertLevel.critical => (const Color(0xFFE53935), const Color(0xFFFFEBEE), Icons.error_rounded),
                  _AlertLevel.warning  => (const Color(0xFFF57C00), const Color(0xFFFFF8E1), Icons.warning_rounded),
                  _AlertLevel.info     => (_teal, _tealLight, Icons.info_rounded),
                };
                return Column(children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(width: 38, height: 38,
                        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 18)),
                    title: Text(a.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(a.body, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  ),
                  if (!isLast) Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                ]);
              }).toList()),
            ),
            const SizedBox(height: 32),
          ])),
        ),
      ],
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))]);
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE USERS PAGE  (tab 1)
// ─────────────────────────────────────────────────────────────────────────────

class _ManageUsersPage extends StatefulWidget {
  const _ManageUsersPage();
  @override State<_ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<_ManageUsersPage> {
  static const _teal = Color(0xFF00695C);
  List<Map<String, dynamic>> _users = [];
  bool _loading = true; String _roleFilter = 'all'; String _search = '';
  int _page = 1; int _totalPages = 1; int _total = 0; bool _loadingMore = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _fetchUsers(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetchUsers({ int page = 1, bool append = false }) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() { _loading = true; _error = null; });
    }
    final result = await ApiService().get('/users', queryParams: {
      'page': '$page', 'limit': '20',
      if (_roleFilter != 'all') 'role': _roleFilter,
      if (_search.isNotEmpty)   'search': _search,
    });
    if (!mounted) return;
    if (result.success) {
      final incoming = List<Map<String, dynamic>>.from(result.data?['users'] ?? []);
      setState(() {
        _users = append ? [..._users, ...incoming] : incoming;
        _page = result.data?['pagination']?['page'] ?? 1;
        _totalPages = result.data?['pagination']?['pages'] ?? 1;
        _total = result.data?['pagination']?['total'] ?? 0;
        _loading = false; _loadingMore = false;
      });
    } else {
      setState(() { _error = result.error; _loading = false; _loadingMore = false; });
    }
  }

  void _onSearch(String val) { setState(() => _search = val); _fetchUsers(); }
  void _onRoleFilter(String role) {
    setState(() { _roleFilter = role; _search = ''; _searchCtrl.clear(); });
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _teal, automaticallyImplyLeading: false,
        title: const Text('Manage Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('$_total total',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ))),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(children: [
            TextField(
              controller: _searchCtrl, onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search name, email or reg. no…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear_rounded, size: 18, color: Colors.grey.shade400),
                        onPressed: () { _searchCtrl.clear(); _onSearch(''); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true, fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _RoleChip(label: 'All',       value: 'all',      current: _roleFilter, onTap: _onRoleFilter),
              const SizedBox(width: 8),
              _RoleChip(label: 'Students',  value: 'student',  current: _roleFilter, onTap: _onRoleFilter),
              const SizedBox(width: 8),
              _RoleChip(label: 'Lecturers', value: 'lecturer', current: _roleFilter, onTap: _onRoleFilter),
            ]),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _teal))
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _fetchUsers)
                  : _users.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline_rounded, size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No users found', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        ]))
                      : RefreshIndicator(
                          color: _teal,
                          onRefresh: () => _fetchUsers(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _users.length + (_page < _totalPages ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              if (i == _users.length) {
                                return _loadingMore
                                    ? const Center(child: Padding(padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(color: _teal, strokeWidth: 2)))
                                    : Center(child: TextButton(
                                        onPressed: () => _fetchUsers(page: _page + 1, append: true),
                                        child: const Text('Load more',
                                            style: TextStyle(color: _teal, fontWeight: FontWeight.w600))));
                              }
                              return _UserTile(user: _users[i]);
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String value, label;
  const _HeaderStat(this.value, this.label);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
    Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.75))),
  ]);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(kpi.icon, color: kpi.color, size: 18), const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: kpi.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(kpi.trend, style: TextStyle(fontSize: 9, color: kpi.color, fontWeight: FontWeight.w600))),
      ]),
      const Spacer(),
      Text(kpi.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kpi.color)),
      Text(kpi.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]),
  );
}

class _RoleChip extends StatelessWidget {
  final String label, value, current; final ValueChanged<String> onTap;
  static const _teal = Color(0xFF00695C);
  const _RoleChip({required this.label, required this.value, required this.current, required this.onTap});
  @override Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: active ? _teal : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserTile({required this.user});
  static const _teal = Color(0xFF00695C);
  Color get _roleColor => switch (user['role'] as String? ?? 'student') {
    'admin' => const Color(0xFF6A1B9A), 'lecturer' => const Color(0xFF283593), _ => _teal,
  };
  IconData get _roleIcon => switch (user['role'] as String? ?? 'student') {
    'admin' => Icons.shield_rounded, 'lecturer' => Icons.person_pin_rounded, _ => Icons.school_rounded,
  };
  @override Widget build(BuildContext context) {
    final name      = user['fullName'] as String? ?? '—';
    final email     = user['email']    as String? ?? '—';
    final regNo     = user['registrationNumber'] as String? ?? '—';
    final roleLabel = (user['role'] as String? ?? 'student').toUpperCase();
    final initials  = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(radius: 22, backgroundColor: _roleColor.withOpacity(0.12),
            child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _roleColor))),
        title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(email, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          Text(regNo,  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_roleIcon, size: 11, color: _roleColor), const SizedBox(width: 4),
            Text(roleLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _roleColor)),
          ]),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 16),
      TextButton.icon(onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00695C))),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

enum _AlertLevel { critical, warning, info }
class _Kpi { final String value, label, trend; final IconData icon; final Color color;
  const _Kpi(this.value, this.label, this.icon, this.color, this.trend); }
class _HealthCheck { final String name, detail; final bool ok;
  const _HealthCheck(this.name, this.ok, this.detail); }
class _Dept { final String name; final int pct; final Color color;
  const _Dept(this.name, this.pct, this.color); }
class _Alert { final String title, body; final _AlertLevel level;
  const _Alert(this.title, this.body, this.level); }

class _AdminSectionHeader extends StatelessWidget {
  final String title; final IconData icon; final Color color; final String? action;
  const _AdminSectionHeader({required this.title, required this.icon, required this.color, this.action});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color), const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
    const Spacer(),
    if (action != null) Text(action!, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  ]);
}