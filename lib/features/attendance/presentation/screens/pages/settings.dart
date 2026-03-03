// lib/features/attendance/presentation/screens/pages/settings.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/theme/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late AnimationController _fadeCtrl;

  // ── Role-derived accent colour ──────────────────────────────────────────────
  Color get _accent => switch (_role) {
    'lecturer' => const Color(0xFF283593),
    'admin'    => const Color(0xFF00695C),
    _          => const Color(0xFF2E7D32),
  };
  Color get _accentLight => switch (_role) {
    'lecturer' => const Color(0xFFE8EAF6),
    'admin'    => const Color(0xFFE0F2F1),
    _          => const Color(0xFFE8F5E9),
  };
  String get _role    => _user?['role'] as String? ?? 'student';
  String get _name    => _user?['fullName'] as String? ?? '—';
  String get _email   => _user?['email']    as String? ?? '—';
  String get _regNo   => _user?['registrationNumber'] as String? ?? '—';
  String get _roleLabel => switch (_role) {
    'lecturer' => 'LECTURER',
    'admin'    => 'ADMIN',
    _          => 'STUDENT',
  };
  String get _homePath => switch (_role) {
    'lecturer' => '/lecturer-home',
    'admin'    => '/admin-home',
    _          => '/home',
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _loadUser();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(isDark),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeTransition(
                        opacity: CurvedAnimation(
                            parent: _fadeCtrl, curve: Curves.easeOut),
                        child: Column(children: [
                          const SizedBox(height: 20),
                          _buildProfileCard(isDark),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Preferences', isDark),
                          const SizedBox(height: 10),
                          _buildThemeTile(isDark),
                          const SizedBox(height: 6),
                          _buildNavTile(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            subtitle: 'Manage alerts & reminders',
                            isDark: isDark,
                            onTap: () => context.go('/notifications'),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionLabel('Account', isDark),
                          const SizedBox(height: 10),
                          _buildNavTile(
                            icon: Icons.lock_outline_rounded,
                            label: 'Security',
                            subtitle: 'Password & biometrics',
                            isDark: isDark,
                            onTap: () => context.go('/security'),
                          ),
                          const SizedBox(height: 6),
                          _buildNavTile(
                            icon: Icons.help_outline_rounded,
                            label: 'Help & Support',
                            subtitle: 'FAQs and contact',
                            isDark: isDark,
                            onTap: () => context.go('/help_support'),
                          ),
                          const SizedBox(height: 32),
                          _buildLogoutButton(isDark),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'EduTrack MUT v1.0.0',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade400),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ── App bar with gradient header ────────────────────────────────────────────
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _accent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent, Color.lerp(_accent, Colors.black, 0.15)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            Positioned(
              top: -20, right: -20,
              child: Container(width: 100, height: 100,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05))),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Icon(Icons.settings_rounded, color: Colors.white.withOpacity(0.9), size: 22),
                  const SizedBox(width: 10),
                  const Text('Settings',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 0.3)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_roleLabel,
                        style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Profile card ────────────────────────────────────────────────────────────
  Widget _buildProfileCard(bool isDark) {
    final initials = _name.trim().split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _accent.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(children: [
        // Avatar with accent ring
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 2.5)),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: _accentLight,
            child: Text(initials,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: _accent)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
          const SizedBox(height: 2),
          Text(_email,
              style: TextStyle(fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade500)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _accentLight, borderRadius: BorderRadius.circular(8)),
            child: Text(_regNo,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _accent)),
          ),
        ])),
        // Edit button
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _accentLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.edit_outlined, color: _accent, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Section label ───────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? Colors.white38 : Colors.grey.shade500)),
    );
  }

  // ── Theme tile (special — has the toggle inline) ────────────────────────────
  Widget _buildThemeTile(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: _accentLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: _accent, size: 20,
          ),
        ),
        title: Text('Dark Mode',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
        subtitle: Text(isDark ? 'Currently dark' : 'Currently light',
            style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
        trailing: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.instance.themeMode,
          builder: (_, mode, __) {
            final on = mode == ThemeMode.dark;
            return GestureDetector(
              onTap: () => ThemeController.instance.setThemeMode(
                  on ? ThemeMode.light : ThemeMode.dark),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 50, height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: on ? _accent : Colors.grey.shade300,
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Navigation tile ─────────────────────────────────────────────────────────
  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: _accentLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _accent, size: 20),
          ),
          title: Text(label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
          subtitle: Text(subtitle,
              style: TextStyle(fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500)),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14,
              color: isDark ? Colors.white38 : Colors.grey.shade400),
        ),
      ),
    );
  }

  // ── Logout button ───────────────────────────────────────────────────────────
  Widget _buildLogoutButton(bool isDark) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _accent)),
            ),
            TextButton(
              onPressed: () { Navigator.pop(context); _logout(); },
              child: const Text('Log Out',
                  style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C1A1A) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFE53935).withOpacity(0.3), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 20),
          SizedBox(width: 10),
          Text('Log Out',
              style: TextStyle(color: Color(0xFFE53935),
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ── Bottom nav ──────────────────────────────────────────────────────────────
  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        color: Colors.grey.shade500,
        activeColor: Colors.white,
        tabBackgroundColor: _accent,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: 3,
        onTabChange: (i) {
          if (i == 0) context.go(_homePath);
          if (i == 1) context.go('/history');
          if (i == 2) context.go('/timetable');
          // i == 3 is already Settings — no-op
        },
        tabs: const [
          GButton(icon: Icons.home_rounded,          text: 'Home'),
          GButton(icon: Icons.history_rounded,        text: 'History'),
          GButton(icon: Icons.calendar_today_rounded, text: 'Calendar'),
          GButton(icon: Icons.settings_rounded,       text: 'Settings'),
        ],
      ),
    );
  }
}