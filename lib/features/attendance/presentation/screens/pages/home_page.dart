import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/usecases/role.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _green900 = Color(0xFF1B5E20);
  static const _green700 = Color(0xFF2E7D32);
  static const _green500 = Color(0xFF4CAF50);
  static const _green100 = Color(0xFFE8F5E9);
  static const _ink      = Color(0xFF0D1B0E);
  static const _inkLight = Color(0xFF4A5568);
  static const _surface  = Color(0xFFF6FAF6);
  static const _white    = Colors.white;

  @override
  Widget build(BuildContext context) {
    final roleManager = RoleManager();

    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: roleManager.isStudent
          ? _ScanFAB(onPressed: () => context.push('/qr_scan'))
          : null,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _DashboardAppBar(roleManager: roleManager),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (roleManager.isStudent) ..._studentBody(context)
                else if (roleManager.isLecturer) ..._lecturerBody(context)
                else if (roleManager.isAdmin) ..._adminBody(context),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(context: context),
    );
  }

  List<Widget> _studentBody(BuildContext context) => [
    const SizedBox(height: 20),
    _AttendanceWarningCard(),
    const SizedBox(height: 20),
    _AttendanceRingCard(),
    const SizedBox(height: 20),
    _StatsRow(),
    const SizedBox(height: 28),
    _SectionLabel("Upcoming Lecture"),
    const SizedBox(height: 12),
    _UpcomingLectureCard(context: context),
    const SizedBox(height: 28),
    _SectionLabel("Recent Activity"),
    const SizedBox(height: 12),
    _RecentItem(context: context),
    const SizedBox(height: 12),
    _RecentItem(context: context),
  ];

  List<Widget> _lecturerBody(BuildContext context) => [
    const SizedBox(height: 28),
    _SectionLabel("Today's Classes"),
    const SizedBox(height: 16),
    _LecturerClassCard(context: context, index: 0),
    const SizedBox(height: 16),
    _LecturerClassCard(context: context, index: 1),
  ];

  List<Widget> _adminBody(BuildContext context) => [
    const SizedBox(height: 28),
    _SectionLabel("System Overview"),
    const SizedBox(height: 16),
    _AdminStatsGrid(),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR (SliverAppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardAppBar extends StatelessWidget {
  final RoleManager roleManager;
  const _DashboardAppBar({required this.roleManager});

  static const _green900 = Color(0xFF1B5E20);
  static const _green700 = Color(0xFF2E7D32);
  static const _green500 = Color(0xFF43A047);

  String get _name => roleManager.isLecturer
      ? "Dr. Smith"
      : roleManager.isAdmin
          ? "Admin User"
          : "Student Name";

  String get _subtext => roleManager.isLecturer
      ? "Lecturer ID: L-1234"
      : roleManager.isAdmin
          ? "System Administrator"
          : "Registration Number";

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _green700,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_green900, _green700, _green500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -20, left: 30,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.pinkAccent.shade100,
                        child: const Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Greeting
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _subtext,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bell icon
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Collapsed title
      title: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.pinkAccent.shade100,
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            _name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE WARNING
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceWarningCard extends StatelessWidget {
  static const bool isLowAttendance = true; // Hardcoded for demo

  @override
  Widget build(BuildContext context) {
    if (!isLowAttendance) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Low Attendance Alert",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Below 75% — please contact your lecturer.",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE RING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceRingCard extends StatelessWidget {
  static const _green700 = Color(0xFF2E7D32);
  static const _green100 = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _green700.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 90, height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80, height: 80,
                  child: CircularProgressIndicator(
                    value: 0.5,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.grey.shade100,
                    color: const Color(0xFFFF4081),
                  ),
                ),
                const Text(
                  "50%",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF4081),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overall Attendance",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D1B0E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "You've attended 20 out of 40 lectures this semester.",
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, height: 1.5),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Needs improvement",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: "Total", value: "48", bg: Colors.green.shade50, color: Colors.green.shade700, icon: Icons.event_note_rounded),
        const SizedBox(width: 12),
        _StatCard(label: "Attended", value: "20", bg: const Color(0xFFE3F2FD), color: const Color(0xFF1565C0), icon: Icons.check_circle_outline_rounded),
        const SizedBox(width: 12),
        _StatCard(label: "Missed", value: "4", bg: const Color(0xFFFFEBEE), color: const Color(0xFFC62828), icon: Icons.cancel_outlined),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color bg, color;
  final IconData icon;

  const _StatCard({
    required this.label, required this.value,
    required this.bg, required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPCOMING LECTURE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingLectureCard extends StatelessWidget {
  final BuildContext context;
  const _UpcomingLectureCard({required this.context});

  static const _green700 = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext ctx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green700.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time indicator column
          Column(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.schedule_rounded, color: _green700, size: 26),
              ),
              const SizedBox(height: 6),
              Container(width: 2, height: 40, color: Colors.grey.shade200),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Unit Code : Unit Name",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      "Lecture Duration",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "Lecturer Name",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "Upcoming",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _green700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _RecentItem extends StatelessWidget {
  final BuildContext context;
  const _RecentItem({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Unit Name",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Time Verified : Means of Verification",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LECTURER CLASS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _LecturerClassCard extends StatelessWidget {
  final BuildContext context;
  final int index;
  const _LecturerClassCard({required this.context, required this.index});

  static const _green700 = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 15, color: _green700),
                  const SizedBox(width: 5),
                  Text(
                    "09:00 AM – 11:00 AM",
                    style: const TextStyle(
                      color: _green700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Lab 3",
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Unit Code ${index + 300} : Computer Networks",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D1B0E),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/qr_scan'),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text(
                "Generate QR Code",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN STATS GRID
// ─────────────────────────────────────────────────────────────────────────────

class _AdminStatsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AdminStatTile(
          label: "Total Users",
          value: "1,240",
          icon: Icons.group_rounded,
          bg: Colors.blue.shade50,
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 14),
        _AdminStatTile(
          label: "Active Classes",
          value: "32",
          icon: Icons.class_rounded,
          bg: Colors.orange.shade50,
          color: Colors.orange.shade700,
        ),
      ],
    );
  }
}

class _AdminStatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color bg, color;

  const _AdminStatTile({
    required this.label, required this.value,
    required this.icon, required this.bg, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ScanFAB extends StatelessWidget {
  final VoidCallback onPressed;
  const _ScanFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: Colors.green.shade600,
      elevation: 4,
      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
      label: const Text(
        "Scan",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final BuildContext context;
  const _BottomNav({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      child: GNav(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        color: Colors.grey,
        activeColor: Colors.white,
        tabBackgroundColor: Colors.green.shade600,
        gap: 8,
        padding: const EdgeInsets.all(16),
        selectedIndex: 0,
        onTabChange: (index) {
          if (index == 1) context.go('/history');
          else if (index == 2) context.go('/timetable');
          else if (index == 3) context.go('/settings');
        },
        tabs: const [
          GButton(icon: Icons.home_rounded, text: 'Home'),
          GButton(icon: Icons.history_rounded, text: 'History'),
          GButton(icon: Icons.calendar_today_rounded, text: 'Calendar'),
          GButton(icon: Icons.settings_rounded, text: 'Settings'),
        ],
      ),
    );
  }
}