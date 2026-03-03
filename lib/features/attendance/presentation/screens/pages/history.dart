// lib/features/attendance/presentation/screens/pages/history.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late TabController _tabCtrl;

  // ── Filters ─────────────────────────────────────────────────────────────────
  String _filterStatus = 'All';   // All / Present / Absent / Late
  final String _filterUnit   = 'All';   // All / per-unit
  String _searchQuery  = '';

  // ── Role helpers ─────────────────────────────────────────────────────────────
  String get _role       => _user?['role'] as String? ?? 'student';
  bool   get _isStudent  => _role == 'student';
  bool   get _isLecturer => _role == 'lecturer';
  bool   get _isAdmin    => _role == 'admin';

  Color get _accent => switch (_role) {
    'lecturer' => const Color(0xFF283593),
    'admin'    => const Color(0xFF00695C),
    _          => const Color(0xFF2E7D32),
  };
  Color get _accentMid => switch (_role) {
    'lecturer' => const Color(0xFF3949AB),
    'admin'    => const Color(0xFF00796B),
    _          => const Color(0xFF43A047),
  };
  Color get _accentLight => switch (_role) {
    'lecturer' => const Color(0xFFE8EAF6),
    'admin'    => const Color(0xFFE0F2F1),
    _          => const Color(0xFFE8F5E9),
  };
  String get _homePath => switch (_role) {
    'lecturer' => '/lecturer-home',
    'admin'    => '/admin-home',
    _          => '/home',
  };

  // ── Static mock data (swap for real API calls) ───────────────────────────────
  static final List<_AttendanceRecord> _studentRecords = [
    _AttendanceRecord('Software Engineering',   'SE 401', DateTime(2025,3,10,8,5),  _AttStatus.present, 'Fingerprint + Face ID'),
    _AttendanceRecord('Computer Networks',      'CS 301', DateTime(2025,3,10,10,3), _AttStatus.present, 'Fingerprint + Face ID'),
    _AttendanceRecord('Database Systems',       'CS 211', DateTime(2025,3,9,13,0),  _AttStatus.absent,  '—'),
    _AttendanceRecord('Operating Systems',      'CS 322', DateTime(2025,3,9,9,2),   _AttStatus.late,    'Fingerprint only'),
    _AttendanceRecord('Algorithms & DS',        'CS 311', DateTime(2025,3,8,14,4),  _AttStatus.present, 'Fingerprint + Face ID'),
    _AttendanceRecord('Mobile Development',     'CS 401', DateTime(2025,3,8,10,1),  _AttStatus.present, 'Fingerprint + Face ID'),
    _AttendanceRecord('Software Engineering',   'SE 401', DateTime(2025,3,7,8,0),   _AttStatus.present, 'Fingerprint + Face ID'),
    _AttendanceRecord('Computer Networks',      'CS 301', DateTime(2025,3,7,10,0),  _AttStatus.late,    'Face ID only'),
    _AttendanceRecord('Database Systems',       'CS 211', DateTime(2025,3,6,13,0),  _AttStatus.absent,  '—'),
    _AttendanceRecord('Operating Systems',      'CS 322', DateTime(2025,3,6,9,0),   _AttStatus.present, 'Fingerprint + Face ID'),
  ];

  static final List<_SubjectReport> _subjectReports = [
    _SubjectReport('Software Engineering',   'SE 401', 87, 52, 6,  2, const Color(0xFF2E7D32)),
    _SubjectReport('Computer Networks',      'CS 301', 74, 38, 10, 4, const Color(0xFF283593)),
    _SubjectReport('Database Systems',       'CS 211', 68, 34, 14, 2, const Color(0xFF6A1B9A)),
    _SubjectReport('Operating Systems',      'CS 322', 91, 48, 4,  0, const Color(0xFFF57C00)),
    _SubjectReport('Mobile Development',     'CS 401', 83, 44, 8,  2, const Color(0xFF2E7D32)),
    _SubjectReport('Algorithms & DS',        'CS 311', 78, 41, 10, 1, const Color(0xFFE53935)),
  ];

  int get _presentCount => _studentRecords.where((r) => r.status == _AttStatus.present).length;
  int get _absentCount  => _studentRecords.where((r) => r.status == _AttStatus.absent).length;
  int get _lateCount    => _studentRecords.where((r) => r.status == _AttStatus.late).length;
  double get _overallPct => (_presentCount / _studentRecords.length * 100);

  List<_AttendanceRecord> get _filtered {
    return _studentRecords.where((r) {
      final matchStatus = _filterStatus == 'All' || r.status.name == _filterStatus.toLowerCase();
      final matchUnit   = _filterUnit   == 'All' || r.unitName == _filterUnit;
      final matchSearch = _searchQuery.isEmpty ||
          r.unitName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.unitCode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchStatus && matchUnit && matchSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _isStudent ? 2 : 2, vsync: this);
    _loadUser();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadUser() async {
    final user = await ApiService().getUser();
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                _buildAppBar(isDark),
              ],
              body: _isStudent
                  ? _buildStudentBody(isDark)
                  : _buildReportsBody(isDark),
            ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: _isStudent ? 230 : 160,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _accent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: _accent,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: _accent,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: _isStudent
                ? const [Tab(text: 'My Attendance'), Tab(text: 'By Subject')]
                : const [Tab(text: 'Subject Reports'), Tab(text: 'Export')],
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent, _accentMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_isStudent ? Icons.history_rounded : Icons.assessment_rounded,
                        color: Colors.white.withOpacity(0.85), size: 20),
                    const SizedBox(width: 8),
                    Text(_isStudent ? 'Attendance History' : 'Reports',
                        style: const TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w800, color: Colors.white)),
                    const Spacer(),
                    if (_isStudent) _buildOverallBadge(),
                  ]),
                  if (_isStudent) ...[
                    const SizedBox(height: 16),
                    _buildStudentSummaryRow(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20)),
    child: Text('${_overallPct.toStringAsFixed(0)}% overall',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
  );

  Widget _buildStudentSummaryRow() => Row(children: [
    _SummaryBubble(value: '$_presentCount', label: 'Present',
        color: Colors.white, bg: Colors.white.withOpacity(0.2)),
    const SizedBox(width: 10),
    _SummaryBubble(value: '$_absentCount',  label: 'Absent',
        color: const Color(0xFFFFCDD2), bg: Colors.red.withOpacity(0.2)),
    const SizedBox(width: 10),
    _SummaryBubble(value: '$_lateCount',    label: 'Late',
        color: const Color(0xFFFFE0B2), bg: Colors.orange.withOpacity(0.2)),
  ]);

  // ── Student body ─────────────────────────────────────────────────────────────
  Widget _buildStudentBody(bool isDark) {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildStudentListTab(isDark),
        _buildBySubjectTab(isDark),
      ],
    );
  }

  Widget _buildStudentListTab(bool isDark) {
    return Column(children: [
      // Search + filter bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(children: [
          // Search
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1B1B1B)),
              decoration: InputDecoration(
                hintText: 'Search unit…',
                hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, size: 18,
                    color: isDark ? Colors.white38 : Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: ['All', 'Present', 'Absent', 'Late'].map((s) {
              final isSelected = _filterStatus == s;
              final chipColor = switch (s) {
                'Present' => const Color(0xFF2E7D32),
                'Absent'  => const Color(0xFFE53935),
                'Late'    => const Color(0xFFF57C00),
                _         => _accent,
              };
              return GestureDetector(
                onTap: () => setState(() => _filterStatus = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? chipColor : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected ? chipColor : (isDark ? Colors.white10 : Colors.grey.shade200)),
                  ),
                  child: Text(s, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey.shade600))),
                ),
              );
            }).toList()),
          ),
        ]),
      ),
      // Record count
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${_filtered.length} records',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      // List
      Expanded(
        child: _filtered.isEmpty
            ? _buildEmptyState(isDark, 'No records match your filter')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _RecordCard(record: _filtered[i], isDark: isDark),
              ),
      ),
    ]);
  }

  Widget _buildBySubjectTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjectReports.length,
      itemBuilder: (_, i) => _SubjectCard(
          report: _subjectReports[i], isDark: isDark, accentColor: _accent, accentLight: _accentLight),
    );
  }

  // ── Lecturer / Admin body ─────────────────────────────────────────────────────
  Widget _buildReportsBody(bool isDark) {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildSubjectReportsTab(isDark),
        _buildExportTab(isDark),
      ],
    );
  }

  Widget _buildSubjectReportsTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjectReports.length,
      itemBuilder: (_, i) {
        final r = _subjectReports[i];
        return _StaffReportCard(report: r, isDark: isDark,
            accentColor: _accent, accentLight: _accentLight);
      },
    );
  }

  Widget _buildExportTab(bool isDark) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final formats = [
      _ExportFormat('CSV',  Icons.table_chart_rounded,  'Spreadsheet · Excel compatible', const Color(0xFF2E7D32)),
      _ExportFormat('PDF',  Icons.picture_as_pdf_rounded,'Formatted report · Print-ready',  const Color(0xFFE53935)),
      _ExportFormat('XLSX', Icons.grid_on_rounded,       'Excel workbook · Charts included', const Color(0xFF1565C0)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Export all
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: _accentLight, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.download_rounded, color: _accent, size: 22)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isAdmin ? 'Export All Reports' : 'Export My Reports',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
                Text('Full semester data', style: TextStyle(fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500)),
              ]),
            ]),
            const SizedBox(height: 16),
            Row(children: formats.map((f) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _showExportSnack(f.label),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: f.color.withOpacity(isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: f.color.withOpacity(0.3)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.icon, color: f.color, size: 22),
                    const SizedBox(height: 4),
                    Text(f.label, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800, color: f.color)),
                  ]),
                ),
              ),
            ))).toList()),
          ]),
        ),
        const SizedBox(height: 24),

        // Per-subject export
        Text('BY SUBJECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1.2, color: isDark ? Colors.white38 : Colors.grey.shade500)),
        const SizedBox(height: 12),
        ..._subjectReports.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: r.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.description_rounded, color: r.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
              Text(r.code, style: TextStyle(fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500)),
            ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _IconExportBtn(icon: Icons.table_chart_rounded,  color: const Color(0xFF2E7D32), isDark: isDark,
                  onTap: () => _showExportSnack('CSV')),
              const SizedBox(width: 8),
              _IconExportBtn(icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFE53935), isDark: isDark,
                  onTap: () => _showExportSnack('PDF')),
            ]),
          ]),
        )),
      ]),
    );
  }

  void _showExportSnack(String format) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Exporting as $format…'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _accent,
    ));
  }

  Widget _buildEmptyState(bool isDark, String message) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white38 : Colors.grey.shade400)),
    ]),
  );

  // ── Bottom nav ───────────────────────────────────────────────────────────────
  Widget _buildBottomNav(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
          blurRadius: 20, offset: const Offset(0, -4))],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    child: GNav(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      color: Colors.grey.shade500,
      activeColor: Colors.white,
      tabBackgroundColor: _accent,
      gap: 8,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      selectedIndex: 1,
      onTabChange: (i) {
        if (i == 0) context.go(_homePath);
        if (i == 2) context.go('/timetable');
        if (i == 3) context.go('/settings');
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

// ─────────────────────────────────────────────────────────────────────────────
// RECORD CARD  (student attendance record)
// ─────────────────────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final _AttendanceRecord record;
  final bool isDark;
  const _RecordCard({required this.record, required this.isDark});

  Color get _statusColor => switch (record.status) {
    _AttStatus.present => const Color(0xFF2E7D32),
    _AttStatus.absent  => const Color(0xFFE53935),
    _AttStatus.late    => const Color(0xFFF57C00),
  };
  Color get _statusBg => switch (record.status) {
    _AttStatus.present => const Color(0xFFE8F5E9),
    _AttStatus.absent  => const Color(0xFFFFEBEE),
    _AttStatus.late    => const Color(0xFFFFF8E1),
  };
  String get _statusLabel => switch (record.status) {
    _AttStatus.present => 'Present',
    _AttStatus.absent  => 'Absent',
    _AttStatus.late    => 'Late',
  };
  IconData get _statusIcon => switch (record.status) {
    _AttStatus.present => Icons.check_circle_rounded,
    _AttStatus.absent  => Icons.cancel_rounded,
    _AttStatus.late    => Icons.watch_later_rounded,
  };

  String _formatDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday-1]}, ${d.day} ${months[d.month-1]}';
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        // Status icon
        Container(width: 42, height: 42,
          decoration: BoxDecoration(
              color: isDark ? _statusColor.withOpacity(0.2) : _statusBg,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(_statusIcon, color: _statusColor, size: 22)),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(record.unitName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
          const SizedBox(height: 3),
          Row(children: [
            Text(record.unitCode, style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
            const SizedBox(width: 8),
            Container(width: 3, height: 3, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white24 : Colors.grey.shade400)),
            const SizedBox(width: 8),
            Text(_formatDate(record.date), style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ]),
          if (record.status != _AttStatus.absent) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.fingerprint_rounded, size: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(record.verificationMethod, style: TextStyle(fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade400)),
            ]),
          ],
        ])),
        // Right: time + status badge
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(_formatTime(record.date), style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? _statusColor.withOpacity(0.2) : _statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusLabel, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor)),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT CARD  (student — by subject tab)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  final _SubjectReport report;
  final bool isDark;
  final Color accentColor;
  final Color accentLight;
  const _SubjectCard({required this.report, required this.isDark,
      required this.accentColor, required this.accentLight});

  Color get _pctColor => report.percentage >= 75
      ? const Color(0xFF2E7D32)
      : report.percentage >= 60
          ? const Color(0xFFF57C00)
          : const Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
                color: report.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(report.code.split(' ').last,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: report.color)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
            Text(report.code, style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ])),
          Text('${report.percentage}%', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900, color: _pctColor)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: report.percentage / 100, minHeight: 7,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(_pctColor),
          )),
        const SizedBox(height: 12),
        Row(children: [
          _MiniStat('${report.present}', 'Present', const Color(0xFF2E7D32), isDark),
          const SizedBox(width: 10),
          _MiniStat('${report.absent}',  'Absent',  const Color(0xFFE53935), isDark),
          const SizedBox(width: 10),
          _MiniStat('${report.late}',    'Late',    const Color(0xFFF57C00), isDark),
          const Spacer(),
          if (report.percentage < 75)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Below 75%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: Color(0xFFE53935))),
            ),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label; final Color color; final bool isDark;
  const _MiniStat(this.value, this.label, this.color, this.isDark);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAFF REPORT CARD  (lecturer / admin)
// ─────────────────────────────────────────────────────────────────────────────

class _StaffReportCard extends StatelessWidget {
  final _SubjectReport report;
  final bool isDark;
  final Color accentColor;
  final Color accentLight;
  const _StaffReportCard({required this.report, required this.isDark,
      required this.accentColor, required this.accentLight});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final pctColor = report.percentage >= 75
        ? const Color(0xFF2E7D32)
        : report.percentage >= 60
            ? const Color(0xFFF57C00)
            : const Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: report.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(report.code.split(' ').last,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: report.color)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1B1B1B))),
            Text(report.code, style: TextStyle(fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${report.percentage}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: pctColor)),
            Text('avg attendance', style: TextStyle(fontSize: 9,
                color: isDark ? Colors.white38 : Colors.grey.shade500)),
          ]),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: report.percentage / 100, minHeight: 7,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(pctColor),
          )),
        const SizedBox(height: 12),
        Row(children: [
          _MiniStat('${report.present}', 'Present', const Color(0xFF2E7D32), isDark),
          const SizedBox(width: 8),
          _MiniStat('${report.absent}',  'Absent',  const Color(0xFFE53935), isDark),
          const SizedBox(width: 8),
          _MiniStat('${report.late}',    'Late',    const Color(0xFFF57C00), isDark),
          const Spacer(),
          // View details button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: accentLight, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility_outlined, size: 13, color: accentColor),
                const SizedBox(width: 4),
                Text('Details', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: accentColor)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBubble extends StatelessWidget {
  final String value, label; final Color color, bg;
  const _SummaryBubble({required this.value, required this.label,
      required this.color, required this.bg});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
    ]),
  );
}

class _IconExportBtn extends StatelessWidget {
  final IconData icon; final Color color; final bool isDark; final VoidCallback onTap;
  const _IconExportBtn({required this.icon, required this.color,
      required this.isDark, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 16)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

enum _AttStatus { present, absent, late }

class _AttendanceRecord {
  final String unitName, unitCode, verificationMethod;
  final DateTime date;
  final _AttStatus status;
  const _AttendanceRecord(this.unitName, this.unitCode, this.date,
      this.status, this.verificationMethod);
}

class _SubjectReport {
  final String name, code;
  final int percentage, present, absent, late;
  final Color color;
  const _SubjectReport(this.name, this.code, this.percentage,
      this.present, this.absent, this.late, this.color);
}

class _ExportFormat {
  final String label, description; final IconData icon; final Color color;
  const _ExportFormat(this.label, this.icon, this.description, this.color);
}