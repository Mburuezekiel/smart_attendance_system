// lib/features/home/presentation/admin_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../../core/services/api_service.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});
  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  int  _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _teal      = Color(0xFF00695C);
  static const _tealMid   = Color(0xFF00796B);
  static const _tealLight = Color(0xFFE0F2F1);

  // Only Dashboard(0) and Users(1) live inside this page.
  // Tabs 2-4 navigate via GoRouter to existing routes.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadUser();
    _pages = [
      _AdminHomeBody(fadeCtrl: _fadeCtrl, slideCtrl: _slideCtrl, getFirstName: () => _firstName),
      const _ManageUsersPage(),
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

  String get _firstName => (_user?['fullName'] as String? ?? 'Admin').split(' ').first;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _teal)));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _AdminBottomNav(
        selectedIndex: _selectedIndex,
        onTabChange: (i) {
          if (i == 2) { context.go('/history');   return; }  // System Reports → reuse history route
          if (i == 3) { context.go('/notifications'); return; } // Alerts → notifications route
          if (i == 4) { context.go('/settings');  return; }
          setState(() => _selectedIndex = i);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  static const _teal = Color(0xFF00695C);

  const _AdminBottomNav({required this.selectedIndex, required this.onTabChange});

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
        tabBackgroundColor: _teal,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: selectedIndex,
        onTabChange: onTabChange,
        tabs: const [
          GButton(icon: Icons.dashboard_rounded,          text: 'Dashboard'),
          GButton(icon: Icons.manage_accounts_rounded,    text: 'Users'),
          GButton(icon: Icons.summarize_rounded,          text: 'Reports'),
          GButton(icon: Icons.notifications_active_rounded, text: 'Alerts'),
          GButton(icon: Icons.settings_rounded,           text: 'Settings'),
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

  static const _teal     = Color(0xFF00695C);
  static const _tealMid  = Color(0xFF00796B);
  static const _tealLight= Color(0xFFE0F2F1);

  const _AdminHomeBody({required this.fadeCtrl, required this.slideCtrl, required this.getFirstName});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = getFirstName();
    final kpis = [
      _Kpi('1,247', 'Total Students',    Icons.school_rounded,        _teal,                    '+12 this week'),
      _Kpi('48',    'Lecturers',          Icons.person_pin_rounded,    const Color(0xFF283593),   '+2 this month'),
      _Kpi('78%',   'Overall Attendance', Icons.bar_chart_rounded,     const Color(0xFF2E7D32),   '↑ 3% vs last week'),
      _Kpi('6',     'Active Alerts',      Icons.warning_amber_rounded, const Color(0xFFE53935),   '2 critical'),
    ];
    final healthChecks = [
      _HealthCheck('Database',       true,  'Connected · 12ms'),
      _HealthCheck('Auth Service',   true,  'Operational'),
      _HealthCheck('Biometric API',  true,  'Operational'),
      _HealthCheck('Backup Service', false, 'Last backup: 2h ago'),
    ];
    final depts = [
      _Dept('Computer Science', 92, const Color(0xFF2E7D32)),
      _Dept('Mathematics',       84, const Color(0xFF1565C0)),
      _Dept('Engineering',       78, _teal),
      _Dept('Business Admin',   71, const Color(0xFFF57C00)),
      _Dept('Social Sciences',  65, const Color(0xFF6A1B9A)),
    ];
    final alerts = [
      _Alert('Low Attendance',   'CS-301: 3 students below 60%',  _AlertLevel.critical),
      _Alert('Missed Session',   'Dr. Kamau — Networks (Mon)',     _AlertLevel.warning),
      _Alert('New Registration', '14 new student accounts today',  _AlertLevel.info),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 200, pinned: true, backgroundColor: _teal, automaticallyImplyLeading: false,
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
                    child: Row(children: [
                      Container(width: 56, height: 56,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Good ${_greeting()}, 👋', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                        Text(firstName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('System Administrator', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
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
            // KPI grid
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(CurvedAnimation(parent: slideCtrl, curve: Curves.easeOutCubic)),
              child: GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
                children: kpis.map((k) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(k.icon, color: k.color, size: 18), const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: k.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(k.trend, style: TextStyle(fontSize: 9, color: k.color, fontWeight: FontWeight.w600))),
                    ]),
                    const Spacer(),
                    Text(k.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: k.color)),
                    Text(k.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // System health
            _AdminSectionHeader(title: 'System Health', icon: Icons.monitor_heart_rounded, color: _teal),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))]),
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
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(c.ok ? 'OK' : 'WARN',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                              color: c.ok ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)))),
                  ]),
                  if (!isLast) Divider(height: 20, color: Colors.grey.shade100),
                ]);
              }).toList()),
            ),
            const SizedBox(height: 20),

            // Dept breakdown
            _AdminSectionHeader(title: 'Dept. Attendance', icon: Icons.domain_rounded, color: _teal, action: 'Full Report'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Column(children: depts.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  SizedBox(width: 130, child: Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: d.pct / 100, minHeight: 8,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(d.color)))),
                  const SizedBox(width: 10),
                  SizedBox(width: 36, child: Text('${d.pct}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: d.color))),
                ]),
              )).toList()),
            ),
            const SizedBox(height: 20),

            // Recent alerts
            _AdminSectionHeader(title: 'Recent Alerts', icon: Icons.notifications_active_rounded, color: _teal, action: 'View All'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Column(children: alerts.asMap().entries.map((e) {
                final a = e.value; final isLast = e.key == alerts.length - 1;
                final (color, bg, icon) = switch (a.level) {
                  _AlertLevel.critical => (const Color(0xFFE53935), const Color(0xFFFFEBEE), Icons.error_rounded),
                  _AlertLevel.warning  => (const Color(0xFFF57C00), const Color(0xFFFFF8E1), Icons.warning_rounded),
                  _AlertLevel.info     => (_teal,                   _tealLight,              Icons.info_rounded),
                };
                return Column(children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACEHOLDER PAGES
// ─────────────────────────────────────────────────────────────────────────────

class _ManageUsersPage extends StatelessWidget {
  const _ManageUsersPage();
  static const _teal = Color(0xFF00695C);
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: _teal, automaticallyImplyLeading: false,
        title: const Text('Manage Users', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
    body: const Center(child: Text('User management coming soon', style: TextStyle(color: Colors.grey))),
  );
}

// Reports → /history, Alerts → /notifications, Settings → /settings via GoRouter.
// See _AdminHomePageState.build() → onTabChange for i == 2/3/4.

// ─────────────────────────────────────────────────────────────────────────────
// Data classes + helpers
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