// lib/features/home/presentation/admin_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _teal     = Color(0xFF00695C);
  static const _tealMid  = Color(0xFF00796B);
  static const _tealLight= Color(0xFFE0F2F1);

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

  String get _firstName => (_user?['fullName'] as String? ?? 'Admin').split(' ').first;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _teal)));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _buildKpiGrid(),
              const SizedBox(height: 20),
              _buildSystemHealth(),
              const SizedBox(height: 20),
              _buildDepartmentBreakdown(),
              const SizedBox(height: 20),
              _buildManagementActions(),
              const SizedBox(height: 20),
              _buildRecentAlerts(),
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
    backgroundColor: _teal,
    automaticallyImplyLeading: false,
    actions: [
      IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
      IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white), onPressed: () {}),
      IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _logout),
    ],
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_teal, _tealMid, Color(0xFF26A69A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Good ${_greeting()}, 👋', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                  Text(_firstName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
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
  );

  Widget _buildKpiGrid() {
    final kpis = [
      _Kpi('1,247', 'Total Students',   Icons.school_rounded,      _teal,                   '+12 this week'),
      _Kpi('48',    'Lecturers',         Icons.person_pin_rounded,   const Color(0xFF283593),  '+2 this month'),
      _Kpi('78%',   'Overall Attendance',Icons.bar_chart_rounded,    const Color(0xFF2E7D32),  '↑ 3% vs last week'),
      _Kpi('6',     'Active Alerts',     Icons.warning_amber_rounded, const Color(0xFFE53935),  '2 critical'),
    ];
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic)),
      child: GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
        children: kpis.map((k) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(k.icon, color: k.color, size: 18),
              const Spacer(),
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
    );
  }

  Widget _buildSystemHealth() {
    final checks = [
      _HealthCheck('Database',        true,  'Connected · 12ms'),
      _HealthCheck('Auth Service',    true,  'Operational'),
      _HealthCheck('Biometric API',   true,  'Operational'),
      _HealthCheck('Backup Service',  false, 'Last backup: 2h ago'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'System Health', icon: Icons.monitor_heart_rounded, color: _teal),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(children: checks.asMap().entries.map((e) {
          final c = e.value;
          final isLast = e.key == checks.length - 1;
          return Column(children: [
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.ok ? const Color(0xFF2E7D32) : const Color(0xFFF57C00),
              )),
              const SizedBox(width: 12),
              Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text(c.detail, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(c.ok ? 'OK' : 'WARN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: c.ok ? const Color(0xFF2E7D32) : const Color(0xFFF57C00)))),
            ]),
            if (!isLast) Divider(height: 20, color: Colors.grey.shade100),
          ]);
        }).toList()),
      ),
    ]);
  }

  Widget _buildDepartmentBreakdown() {
    final depts = [
      _Dept('Computer Science',   92, const Color(0xFF2E7D32)),
      _Dept('Mathematics',         84, const Color(0xFF1565C0)),
      _Dept('Engineering',         78, _teal),
      _Dept('Business Admin',     71, const Color(0xFFF57C00)),
      _Dept('Social Sciences',    65, const Color(0xFF6A1B9A)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Dept. Attendance', icon: Icons.domain_rounded, color: _teal, action: 'Full Report'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(children: depts.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            SizedBox(width: 130, child: Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: d.pct / 100, minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(d.color),
              ),
            )),
            const SizedBox(width: 10),
            SizedBox(width: 36, child: Text('${d.pct}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: d.color))),
          ]),
        )).toList()),
      ),
    ]);
  }

  Widget _buildManagementActions() {
    final actions = [
      _Action('Manage\nUsers',     Icons.manage_accounts_rounded, _teal),
      _Action('Generate\nReport',  Icons.summarize_rounded,       const Color(0xFF283593)),
      _Action('Send\nBroadcast',   Icons.campaign_rounded,        const Color(0xFFF57C00)),
      _Action('System\nSettings',  Icons.settings_rounded,        const Color(0xFF6A1B9A)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Management', icon: Icons.admin_panel_settings_rounded, color: _teal),
      const SizedBox(height: 12),
      Row(children: actions.map((a) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: _QuickActionCard(action: a),
      ))).toList()),
    ]);
  }

  Widget _buildRecentAlerts() {
    final alerts = [
      _Alert('Low Attendance',   'CS-301: 3 students below 60%', _AlertLevel.critical),
      _Alert('Missed Session',   'Dr. Kamau — Networks (Mon)',    _AlertLevel.warning),
      _Alert('New Registration', '14 new student accounts today', _AlertLevel.info),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Recent Alerts', icon: Icons.notifications_active_rounded, color: _teal, action: 'View All'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(children: alerts.asMap().entries.map((e) {
          final a = e.value;
          final isLast = e.key == alerts.length - 1;
          final (color, bg, icon) = switch (a.level) {
            _AlertLevel.critical => (const Color(0xFFE53935), const Color(0xFFFFEBEE), Icons.error_rounded),
            _AlertLevel.warning  => (const Color(0xFFF57C00), const Color(0xFFFFF8E1), Icons.warning_rounded),
            _AlertLevel.info     => (_teal,                   _tealLight,              Icons.info_rounded),
          };
          return Column(children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(width: 36, height: 36,
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
    ]);
  }
}

enum _AlertLevel { critical, warning, info }

class _Kpi {
  final String value, label, trend; final IconData icon; final Color color;
  const _Kpi(this.value, this.label, this.icon, this.color, this.trend);
}
class _HealthCheck {
  final String name, detail; final bool ok;
  const _HealthCheck(this.name, this.ok, this.detail);
}
class _Dept {
  final String name; final int pct; final Color color;
  const _Dept(this.name, this.pct, this.color);
}
class _Action {
  final String label; final IconData icon; final Color color;
  const _Action(this.label, this.icon, this.color);
}
class _Alert {
  final String title, body; final _AlertLevel level;
  const _Alert(this.title, this.body, this.level);
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