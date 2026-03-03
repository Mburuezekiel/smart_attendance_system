// lib/features/home/presentation/student_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
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
  int _selectedIndex = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;

  static const _green      = Color(0xFF2E7D32);
  static const _greenLight = Color(0xFFE8F5E9);
  static const _greenMid   = Color(0xFF43A047);

  // Only Home(0) and Scan(1) live inside this page.
  // Tabs 2-4 navigate via GoRouter to existing routes.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadUser();
    _pages = [
      _HomeBody(
        fadeCtrl: _fadeCtrl, slideCtrl: _slideCtrl,
        getFirstName: () => _firstName, getRegNumber: () => _regNumber,
      ),
      const _ScanAttendancePage(),   // QR → fingerprint → face flow
    ];
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
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _StudentBottomNav(
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
// STUDENT BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────

class _StudentBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  static const _green = Color(0xFF2E7D32);

  const _StudentBottomNav({required this.selectedIndex, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
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
          GButton(icon: Icons.home_rounded,           text: 'Home'),
          // "Scan" tab — this is the core student action: QR → fingerprint → face
          GButton(icon: Icons.qr_code_scanner_rounded, text: 'Scan'),
          GButton(icon: Icons.history_rounded,         text: 'History'),
          GButton(icon: Icons.calendar_today_rounded,  text: 'Timetable'),
          GButton(icon: Icons.settings_rounded,        text: 'Settings'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME BODY (extracted so IndexedStack works cleanly)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final AnimationController fadeCtrl;
  final AnimationController slideCtrl;
  final String Function() getFirstName;
  final String Function() getRegNumber;

  static const _green    = Color(0xFF2E7D32);
  static const _greenMid = Color(0xFF43A047);

  const _HomeBody({
    required this.fadeCtrl, required this.slideCtrl,
    required this.getFirstName, required this.getRegNumber,
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
    final regNumber = getRegNumber();

    final classes = [
      _ClassItem('Mathematics 201',    '08:00 – 10:00', 'Room LH-3', Icons.calculate_rounded,  const Color(0xFF1565C0), true),
      _ClassItem('Computer Networks',  '10:00 – 12:00', 'Lab C-2',   Icons.lan_rounded,          const Color(0xFF6A1B9A), false),
      _ClassItem('Software Engineering','14:00 – 16:00','Room LH-7', Icons.code_rounded,          _green,                false),
    ];
    final quickActions = [
      _Action('Scan\nQR Code',   Icons.qr_code_scanner_rounded, _green),
      _Action('My\nSchedule',    Icons.calendar_month_rounded,   const Color(0xFF1565C0)),
      _Action('View\nGrades',    Icons.grade_rounded,            const Color(0xFF6A1B9A)),
      _Action('Leave\nRequest',  Icons.event_busy_rounded,       const Color(0xFFF57C00)),
    ];
    final activities = [
      _Activity('Attendance marked', 'Software Eng. — Lab session', '2h ago',    Icons.check_circle_rounded, _green),
      _Activity('Absent recorded',   'Database Systems',            'Yesterday',  Icons.cancel_rounded,       const Color(0xFFE53935)),
      _Activity('Schedule updated',  'Mathematics 201 rescheduled', '2 days ago', Icons.update_rounded,       const Color(0xFFF57C00)),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App bar ─────────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: _green,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {},
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_green, _greenMid, Color(0xFF66BB6A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: fadeCtrl, curve: Curves.easeOut),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Good ${_greeting()}, 👋',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                        Text(firstName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(regNumber,
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('STUDENT', style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
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
            // ── Attendance overview ────────────────────────────────────────
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                  .animate(CurvedAnimation(parent: slideCtrl, curve: Curves.easeOutCubic)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.bar_chart_rounded, color: _green, size: 20),
                    const SizedBox(width: 8),
                    const Text('Attendance Overview',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
                    const Spacer(),
                    Text('This Semester', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    _AttendanceStat(value: '87%', label: 'Overall', color: _green),
                    _vDivider(),
                    _AttendanceStat(value: '42',  label: 'Present', color: const Color(0xFF1565C0)),
                    _vDivider(),
                    _AttendanceStat(value: '6',   label: 'Absent',  color: const Color(0xFFE53935)),
                    _vDivider(),
                    _AttendanceStat(value: '3',   label: 'Late',    color: const Color(0xFFF57C00)),
                  ]),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 0.87, minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(_green),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('87% attendance · Minimum required: 75%',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ── Today's classes ────────────────────────────────────────────
            _SectionHeader(title: "Today's Classes", icon: Icons.today_rounded, action: 'View All'),
            const SizedBox(height: 12),
            ...classes.map((c) => _ClassCard(item: c)),
            const SizedBox(height: 20),

            // ── Quick actions ──────────────────────────────────────────────
            _SectionHeader(title: 'Quick Actions', icon: Icons.bolt_rounded),
            const SizedBox(height: 12),
            Row(children: quickActions.map((a) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _QuickActionCard(action: a),
            ))).toList()),
            const SizedBox(height: 20),

            // ── Recent activity ────────────────────────────────────────────
            _SectionHeader(title: 'Recent Activity', icon: Icons.history_rounded, action: 'See All'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(children: activities.asMap().entries.map((e) {
                final isLast = e.key == activities.length - 1;
                return Column(children: [
                  _ActivityTile(activity: e.value),
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

  Widget _vDivider() => Container(
      height: 40, width: 1, color: Colors.grey.shade100, margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAN ATTENDANCE PAGE  (QR → Fingerprint → Face ID)
// ─────────────────────────────────────────────────────────────────────────────

class _ScanAttendancePage extends StatefulWidget {
  const _ScanAttendancePage();
  @override State<_ScanAttendancePage> createState() => _ScanAttendancePageState();
}

class _ScanAttendancePageState extends State<_ScanAttendancePage> {
  // 0=idle  1=qr_success  2=fingerprint  3=face  4=done
  int    _step        = 0;
  bool   _fpScanning  = false;
  bool   _faceScanning= false;
  String? _className;

  static const _green      = Color(0xFF2E7D32);
  static const _greenLight = Color(0xFFE8F5E9);

  void _reset() => setState(() { _step = 0; _fpScanning = false; _faceScanning = false; _className = null; });

  void _simulateQrScan() {
    setState(() { _className = 'Software Engineering — LH-7'; _step = 1; });
  }

  Future<void> _doFingerprint() async {
    setState(() { _fpScanning = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() { _fpScanning = false; _step = 3; });
  }

  Future<void> _doFace() async {
    setState(() { _faceScanning = true; });
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) setState(() { _faceScanning = false; _step = 4; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _green,
        automaticallyImplyLeading: false,
        title: const Text('Mark Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          if (_step > 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _reset,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildStepContent(),
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _QrStep(onScan: _simulateQrScan),
      1 => _QrSuccessStep(className: _className ?? '', onContinue: () => setState(() => _step = 2)),
      2 => _FingerprintStep(scanning: _fpScanning, onScan: _doFingerprint),
      3 => _FaceStep(scanning: _faceScanning, onScan: _doFace),
      4 => _AttendanceDoneStep(className: _className ?? '', onReset: _reset),
      _ => const SizedBox.shrink(),
    };
  }
}

class _QrStep extends StatelessWidget {
  final VoidCallback onScan;
  static const _green = Color(0xFF2E7D32);
  const _QrStep({required this.onScan});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Step indicator
      _ScanStepIndicator(current: 0),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(children: [
          Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green, width: 3),
              color: const Color(0xFFE8F5E9),
            ),
            child: const Icon(Icons.qr_code_2_rounded, size: 90, color: _green),
          ),
          const SizedBox(height: 20),
          const Text('Scan QR Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          Text('Point your camera at the QR code\ndisplayed by your lecturer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 24),
          // In a real implementation this launches a QR scanner
          _GreenButton(label: 'Open Camera Scanner', icon: Icons.camera_alt_rounded, onTap: onScan),
        ]),
      ),
    ],
  );
}

class _QrSuccessStep extends StatelessWidget {
  final String className;
  final VoidCallback onContinue;
  static const _green = Color(0xFF2E7D32);
  const _QrSuccessStep({required this.className, required this.onContinue});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ScanStepIndicator(current: 0),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(children: [
          Container(width: 80, height: 80,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
            child: const Icon(Icons.check_circle_rounded, color: _green, size: 46)),
          const SizedBox(height: 16),
          const Text('QR Verified!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _green)),
          const SizedBox(height: 8),
          Text(className, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
          const SizedBox(height: 4),
          Text('Now verify your identity to complete attendance',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          _GreenButton(label: 'Continue to Fingerprint', icon: Icons.fingerprint_rounded, onTap: onContinue),
        ]),
      ),
    ],
  );
}

class _FingerprintStep extends StatelessWidget {
  final bool scanning;
  final VoidCallback onScan;
  static const _green = Color(0xFF2E7D32);
  const _FingerprintStep({required this.scanning, required this.onScan});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ScanStepIndicator(current: 1),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scanning ? _green.withOpacity(0.15) : const Color(0xFFE8F5E9),
              border: Border.all(color: scanning ? _green : Colors.grey.shade200, width: 2.5),
            ),
            child: Icon(Icons.fingerprint_rounded, size: 64,
                color: scanning ? _green : Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(scanning ? 'Scanning…' : 'Step 2: Fingerprint',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: scanning ? _green : const Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          Text(scanning ? 'Place your finger firmly on the sensor…'
              : 'Place your finger on the phone sensor\nto verify your identity',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 24),
          if (!scanning) _GreenButton(label: 'Scan Fingerprint', icon: Icons.fingerprint_rounded, onTap: onScan),
          if (scanning) const SizedBox(height: 52,
              child: Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2.5))),
        ]),
      ),
    ],
  );
}

class _FaceStep extends StatelessWidget {
  final bool scanning;
  final VoidCallback onScan;
  static const _green = Color(0xFF2E7D32);
  const _FaceStep({required this.scanning, required this.onScan});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ScanStepIndicator(current: 2),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120, height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: scanning ? _green.withOpacity(0.1) : const Color(0xFFE8F5E9),
              border: Border.all(color: scanning ? _green : Colors.grey.shade200, width: 2.5),
            ),
            child: Icon(Icons.face_retouching_natural, size: 64,
                color: scanning ? _green : Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(scanning ? 'Capturing…' : 'Step 3: Face ID',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: scanning ? _green : const Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          Text(scanning ? 'Hold still, look straight at the camera…'
              : 'Final step — look at the front camera\nto complete attendance',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          if (!scanning) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.light_mode_outlined, color: Color(0xFFF57C00), size: 14),
                const SizedBox(width: 6),
                Text('Good lighting improves accuracy',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          if (!scanning) _GreenButton(label: 'Open Camera', icon: Icons.camera_alt_rounded, onTap: onScan),
          if (scanning) const SizedBox(height: 52,
              child: Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2.5))),
        ]),
      ),
    ],
  );
}

class _AttendanceDoneStep extends StatelessWidget {
  final String className;
  final VoidCallback onReset;
  static const _green = Color(0xFF2E7D32);
  const _AttendanceDoneStep({required this.className, required this.onReset});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.09), blurRadius: 24, offset: const Offset(0, 8))]),
        child: Column(children: [
          Container(width: 96, height: 96,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
            child: const Icon(Icons.verified_rounded, color: _green, size: 52)),
          const SizedBox(height: 20),
          const Text('Attendance Marked!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _green)),
          const SizedBox(height: 8),
          Text(className, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
          const SizedBox(height: 4),
          Text(
            '${TimeOfDay.now().format(context)} · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _DoneRow(Icons.qr_code_scanner_rounded, 'QR Code', 'Verified'),
              const Divider(height: 16, color: Color(0xFFEEEEEE)),
              _DoneRow(Icons.fingerprint_rounded,     'Fingerprint', 'Matched'),
              const Divider(height: 16, color: Color(0xFFEEEEEE)),
              _DoneRow(Icons.face_retouching_natural, 'Face ID',    'Matched'),
            ]),
          ),
          const SizedBox(height: 24),
          _GreenButton(label: 'Scan Another Class', icon: Icons.qr_code_scanner_rounded, onTap: onReset),
        ]),
      ),
    ],
  );
}

class _DoneRow extends StatelessWidget {
  final IconData icon; final String label, value;
  static const _green = Color(0xFF2E7D32);
  const _DoneRow(this.icon, this.label, this.value);
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: _green),
    const SizedBox(width: 10),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
      child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _green))),
  ]);
}

class _ScanStepIndicator extends StatelessWidget {
  final int current; // 0=QR, 1=fingerprint, 2=face
  static const _green = Color(0xFF2E7D32);
  const _ScanStepIndicator({required this.current});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final icons   = [Icons.qr_code_scanner_rounded, Icons.fingerprint_rounded, Icons.face_retouching_natural];
      final labels  = ['QR Code', 'Fingerprint', 'Face ID'];
      final isDone  = i < current;
      final isActive= i == current;
      return Row(children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? _green : isActive ? _green.withOpacity(0.15) : Colors.grey.shade100,
              border: Border.all(color: isActive ? _green : Colors.transparent, width: 2),
            ),
            child: Icon(icons[i], size: 22,
                color: isDone ? Colors.white : isActive ? _green : Colors.grey.shade400),
          ),
          const SizedBox(height: 4),
          Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: isActive ? _green : Colors.grey.shade400)),
        ]),
        if (i < 2) Container(width: 32, height: 2, margin: const EdgeInsets.only(bottom: 20),
          color: i < current ? _green : Colors.grey.shade200),
      ]);
    }),
  );
}

class _GreenButton extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  static const _green = Color(0xFF2E7D32);
  const _GreenButton({required this.label, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_green, Color(0xFF43A047)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// History, Timetable, and Settings navigate to existing routes via GoRouter.
// See _StudentHomePageState.build() → onTabChange for i == 2/3/4.

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ClassItem {
  final String name, time, room; final IconData icon; final Color color; final bool isNext;
  const _ClassItem(this.name, this.time, this.room, this.icon, this.color, this.isNext);
}
class _Action { final String label; final IconData icon; final Color color;
  const _Action(this.label, this.icon, this.color); }
class _Activity { final String title, subtitle, time; final IconData icon; final Color color;
  const _Activity(this.title, this.subtitle, this.time, this.icon, this.color); }

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
  static const _green = Color(0xFF2E7D32);
  const _SectionHeader({required this.title, required this.icon, this.action});
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: _green), const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
    const Spacer(),
    if (action != null) Text(action!, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
  ]);
}

class _ClassCard extends StatelessWidget {
  final _ClassItem item;
  static const _green = Color(0xFF2E7D32);
  const _ClassCard({required this.item});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: item.isNext ? Border.all(color: _green, width: 1.5) : null,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
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
        child: const Text('NEXT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _green))),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))]),
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