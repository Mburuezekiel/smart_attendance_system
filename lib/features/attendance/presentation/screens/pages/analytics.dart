// lib/features/attendance/presentation/screens/pages/analytics.dart
// pubspec.yaml: fl_chart: ^0.69.0, intl: ^0.19.0

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../../core/services/api_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic>? _user;
  bool    _loading = true;
  String? _error;

  List<Map<String, dynamic>> _records              = [];
  List<Map<String, dynamic>> _unitStats            = [];
  Map<String, dynamic>       _summary              = {};
  List<Map<String, dynamic>> _lecturerUnitStats    = [];
  List<Map<String, dynamic>> _lecturerSessionStats = [];
  Map<String, dynamic>       _lecturerSummary      = {};

  late TabController _tabCtrl;

  String get _role       => _user?['role'] as String? ?? 'student';
  bool   get _isStudent  => _role == 'student';
  Color  get _accent     => _role == 'lecturer'
      ? const Color(0xFF283593) : const Color(0xFF2E7D32);
  Color  get _accentMid  => _role == 'lecturer'
      ? const Color(0xFF3949AB) : const Color(0xFF43A047);
  Color  get _accentLight => _role == 'lecturer'
      ? const Color(0xFFE8EAF6) : const Color(0xFFE8F5E9);
  String get _homePath   => _role == 'lecturer' ? '/lecturer-home' : '/home';

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _init();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    final user = await ApiService().getUser();
    if (!mounted) return;
    setState(() => _user = user);  // never recreate _tabCtrl here
    await _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    if (_user == null) {
      setState(() {
        _error = 'Session expired. Please log in again.';
        _loading = false;
      });
      return;
    }

    try {
      if (_isStudent) {
        final r = await ApiService().get('/attendance/my-history');
        if (!mounted) return;
        if (r.success) {
          setState(() {
            _records   = List<Map<String,dynamic>>.from(r.data?['records']   ?? []);
            _unitStats = List<Map<String,dynamic>>.from(r.data?['unitStats'] ?? []);
            _summary   = Map<String,dynamic>.from(r.data?['summary']  ?? {});
          });
        } else {
          setState(() => _error = r.error ?? 'Failed to load data');
        }
      } else {
        final r = await ApiService().get('/attendance/lecturer-reports');
        if (!mounted) return;
        if (r.success) {
          setState(() {
            _lecturerUnitStats    = List<Map<String,dynamic>>.from(
                r.data?['unitStats']    ?? []);
            _lecturerSessionStats = List<Map<String,dynamic>>.from(
                r.data?['sessionStats'] ?? []);
            _lecturerSummary      = Map<String,dynamic>.from(
                r.data?['summary']      ?? {});
          });
        } else {
          setState(() => _error = r.error ?? 'Failed to load data');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Unexpected error: $e');
    } finally {
      // Guarantees _loading = false no matter what path was taken
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _longestStreak {
    final dates = _records
        .where((r) => r['status'] == 'present')
        .map((r) {
          final dt = DateTime.tryParse(
              (r['markedAt'] ?? r['createdAt'])?.toString() ?? '');
          return dt?.copyWith(hour:0, minute:0, second:0, millisecond:0);
        })
        .whereType<DateTime>().toSet().toList()..sort();
    if (dates.isEmpty) return 0;
    int best = 1, cur = 1;
    for (int i = 1; i < dates.length; i++) {
      cur = dates[i].difference(dates[i-1]).inDays == 1 ? cur+1 : 1;
      if (cur > best) best = cur;
    }
    return best;
  }

  double get _bioRate {
    if (_records.isEmpty) return 0;
    return _records.where((r) =>
        r['biometricVerified'] == true && r['faceVerified'] == true)
        .length / _records.length * 100;
  }

  List<Map<String,dynamic>> get _atRisk => _lecturerUnitStats
      .where((u) => ((u['percentage'] as num?) ?? 0) < 75).toList();

  List<_SessionPoint> get _sessionTrend {
    final src = _lecturerSessionStats.isEmpty ? _mockSessions : _lecturerSessionStats;
    return src.take(12).toList().reversed.map((s) {
      final dt = DateTime.tryParse(s['date']?.toString() ?? '');
      return _SessionPoint(
        label: dt != null ? DateFormat('d MMM').format(dt) : '—',
        rate:  ((s['rate'] as num?) ?? 0).toDouble(),
      );
    }).toList();
  }

  List<Map<String,dynamic>> get _mockSessions => List.generate(8, (i) => {
    'date': DateTime.now().subtract(Duration(days: (7-i)*3)).toIso8601String(),
    'rate': [72, 85, 78, 90, 88, 67, 92, 80][i],
    'unitCode': 'UNIT${i+1}', 'unitName': 'Unit ${i+1}',
    'scanned': 24, 'expected': 30, 'isActive': false,
  });

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(child: CircularProgressIndicator(color: _accent)),
    );

    if (_error != null) return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_error!, style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(backgroundColor: _accent),
        ),
      ])),
    );

    final tabs = _isStudent
        ? const [Tab(text:'Overview'), Tab(text:'Trends'),
                 Tab(text:'Units'),    Tab(text:'Insights')]
        : const [Tab(text:'Overview'), Tab(text:'Sessions'),
                 Tab(text:'Units'),    Tab(text:'Insights')];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: _accent,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _loadData,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: ColoredBox(
                color: Colors.white,
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: _accent,
                  unselectedLabelColor: Colors.grey.shade400,
                  indicatorColor: _accent,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700),
                  tabs: tabs,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _appBarBg()),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: _isStudent
              ? [_studentOverview(), _studentTrends(),
                 _studentUnits(),   _studentInsights()]
              : [_lecturerOverview(), _lecturerSessions(),
                 _lecturerUnits(),   _lecturerInsights()],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _appBarBg() {
    final pct   = _isStudent ? (_summary['percentage']        ?? 0)
                             : (_lecturerSummary['percentage'] ?? 0);
    final total = _isStudent ? _records.length
                             : (_lecturerSummary['total']      ?? 0);
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
          colors: [_accent, _accentMid],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20,16,80,60),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.analytics_rounded,
                color: Colors.white.withOpacity(0.8), size: 18),
            const SizedBox(width: 8),
            Text(_isStudent ? 'My Analytics' : 'Class Analytics',
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          const SizedBox(height: 4),
          Text(_isStudent
              ? 'Deep-dive into your attendance patterns'
              : 'Class-wide performance & insights',
              style: TextStyle(fontSize: 11,
                  color: Colors.white.withOpacity(0.65))),
          const SizedBox(height: 14),
          Row(children: [
            _pill('Overall', '$pct%',  Icons.donut_large_rounded),
            const SizedBox(width: 8),
            _pill('Records', '$total', Icons.receipt_long_rounded),
            if (_isStudent) ...[
              const SizedBox(width: 8),
              _pill('Streak', '${_longestStreak}d',
                  Icons.local_fire_department_rounded),
            ],
          ]),
        ]),
      )),
    );
  }

  Widget _pill(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 13),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 9,
            color: Colors.white.withOpacity(0.7))),
      ]),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENT TABS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _studentOverview() {
    final p   = (_summary['present'] as num?)?.toInt() ?? 0;
    final a   = (_summary['absent']  as num?)?.toInt() ?? 0;
    final l   = (_summary['late']    as num?)?.toInt() ?? 0;
    final t   = p + a + l;
    final pct = (_summary['percentage'] as num?)?.toInt() ?? 0;

    return _list([
      _card('Overall Attendance', 'All units combined', Row(children: [
        SizedBox(width: 130, height: 130,
          child: t == 0
            ? _emptyBox('No records yet')
            : PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 36,
                sections: [
                  _pie(p.toDouble(), const Color(0xFF2E7D32), '$p'),
                  _pie(a.toDouble(), const Color(0xFFE53935), '$a'),
                  _pie(l.toDouble(), const Color(0xFFF57C00), '$l'),
                ])),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('$pct%', style: TextStyle(fontSize: 34,
              fontWeight: FontWeight.w900, color: _accent)),
          Text('Attendance rate', style: TextStyle(fontSize: 11,
              color: Colors.grey.shade500)),
          const SizedBox(height: 14),
          _legend(const Color(0xFF2E7D32), 'Present', p),
          const SizedBox(height: 5),
          _legend(const Color(0xFFE53935), 'Absent',  a),
          const SizedBox(height: 5),
          _legend(const Color(0xFFF57C00), 'Late',    l),
        ])),
      ])),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65,
        children: [
          _kpi(Icons.local_fire_department_rounded, const Color(0xFFF57C00),
              'Best Streak', '${_longestStreak}d', 'consecutive present'),
          _kpi(Icons.fingerprint_rounded, _accent,
              'Bio Rate', '${_bioRate.toStringAsFixed(0)}%', 'bio + face passed'),
          _kpi(Icons.school_rounded, const Color(0xFF6A1B9A),
              'Units', '${_unitStats.length}', 'enrolled this term'),
          _kpi(Icons.trending_up_rounded,
              pct >= 75 ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
              'Risk',
              pct >= 75 ? 'Low' : pct >= 60 ? 'Medium' : 'High',
              pct >= 75 ? 'Above threshold' : 'Below 75%'),
        ],
      ),
      if (t > 0) ...[
        const SizedBox(height: 12),
        _card('Status Breakdown', '$t total records', Column(children: [
          _barRow('Present', p, t, const Color(0xFF2E7D32)),
          const SizedBox(height: 8),
          _barRow('Late',    l, t, const Color(0xFFF57C00)),
          const SizedBox(height: 8),
          _barRow('Absent',  a, t, const Color(0xFFE53935)),
        ])),
      ],
      if (_unitStats.any((u) => ((u['percentage'] as num?) ?? 0) < 75)) ...[
        const SizedBox(height: 12),
        _atRiskBanner(_unitStats.where(
            (u) => ((u['percentage'] as num?) ?? 0) < 75).toList()),
      ],
    ]);
  }

  Widget _studentTrends() {
    final now   = DateTime.now();
    final weeks = List.generate(8, (i) {
      final start = now.subtract(Duration(days: (7-i)*7 + now.weekday - 1));
      return _WeekBucket(DateFormat('d MMM').format(start), start, 0, 0, 0);
    });
    for (final r in _records) {
      final dt = DateTime.tryParse(
          (r['markedAt'] ?? r['createdAt'])?.toString() ?? '');
      if (dt == null) continue;
      for (final b in weeks) {
        if (dt.isAfter(b.start) &&
            dt.isBefore(b.start.add(const Duration(days: 7)))) {
          final s = (r['status'] as String? ?? '').toLowerCase();
          if (s == 'present') b.present++;
          else if (s == 'late') b.late++;
          else b.absent++;
          break;
        }
      }
    }
    final days = List.generate(7, (i) =>
        _DayBucket(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][i], 0, 0));
    for (final r in _records) {
      final dt = DateTime.tryParse(
          (r['markedAt'] ?? r['createdAt'])?.toString() ?? '');
      if (dt == null) continue;
      days[dt.weekday-1].total++;
      if (r['status'] == 'present') days[dt.weekday-1].present++;
    }

    return _list([
      _card('Weekly Attendance', 'Last 8 weeks — present / late / absent',
        SizedBox(height: 200, child: BarChart(BarChartData(
          barGroups: weeks.asMap().entries.map((e) =>
            BarChartGroupData(x: e.key, barsSpace: 2, barRods: [
              _rod(e.value.present.toDouble(), const Color(0xFF2E7D32)),
              _rod(e.value.late.toDouble(),    const Color(0xFFF57C00)),
              _rod(e.value.absent.toDouble(),  const Color(0xFFE53935)),
            ])).toList(),
          titlesData: _barTitles(weeks.map((b) =>
              b.label.split(' ').last).toList()),
          gridData: _gridData(), borderData: FlBorderData(show: false),
        ))),
      ),
      const SizedBox(height: 12),
      _card('Attendance by Day', 'Best and worst days of the week',
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days.map((d) {
            final rate = d.total == 0 ? 0.0 : d.present / d.total;
            final h    = 70.0 * rate;
            final c    = rate >= 0.8 ? const Color(0xFF2E7D32)
                       : rate >= 0.6 ? const Color(0xFFF57C00)
                       : rate == 0   ? Colors.grey.shade200
                       : const Color(0xFFE53935);
            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${(rate*100).round()}%', style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w700, color: c)),
              const SizedBox(height: 3),
              Container(width: 26, height: max(4.0, h),
                  decoration: BoxDecoration(color: c,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 5),
              Text(d.day, style: TextStyle(fontSize: 10,
                  color: Colors.grey.shade500)),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _studentUnits() {
    if (_unitStats.isEmpty) return _fullEmpty('No unit data yet');
    final sorted = [..._unitStats]
      ..sort((a,b) => ((b['percentage'] as num?) ?? 0)
          .compareTo((a['percentage'] as num?) ?? 0));
    return _list([
      _card('Unit Comparison', 'Sorted by attendance %',
        Column(children: sorted.map((u) {
          final pct = ((u['percentage'] as num?) ?? 0).toInt();
          final c   = _pctColor(pct);
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(u['name'] as String? ?? '—',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('$pct%', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w900, color: c)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: pct/100, minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(c))),
            ]),
          );
        }).toList()),
      ),
      const SizedBox(height: 12),
      ...sorted.map((u) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _unitCard(u, false),
      )),
    ]);
  }

  Widget _studentInsights() {
    final pct     = (_summary['percentage'] as num?)?.toInt() ?? 0;
    final absent  = (_summary['absent']  as num?)?.toInt() ?? 0;
    final late    = (_summary['late']    as num?)?.toInt() ?? 0;
    final present = (_summary['present'] as num?)?.toInt() ?? 0;
    final streak  = _longestStreak;
    final total   = present + absent + late;
    final curPct  = total > 0 ? present / total * 100 : 0.0;

    final ins = <_Ins>[];
    if (pct >= 90) ins.add(_Ins(Icons.star_rounded, const Color(0xFF2E7D32),
        'Excellent attendance!', 'You\'re in the top tier at $pct%. Keep it up!'));
    else if (pct >= 75) ins.add(_Ins(Icons.thumb_up_rounded, const Color(0xFF2E7D32),
        'Good standing', 'At $pct% you\'re above the 75% threshold.'));
    else if (pct >= 60) ins.add(_Ins(Icons.warning_amber_rounded, const Color(0xFFF57C00),
        'Approaching risk zone',
        'Your $pct% is below the 75% requirement. Attend consistently.'));
    else ins.add(_Ins(Icons.error_outline_rounded, const Color(0xFFE53935),
        'High risk — action needed',
        'At $pct%, contact your academic advisor.'));
    if (late > 0) ins.add(_Ins(Icons.watch_later_rounded, const Color(0xFFF57C00),
        'Punctuality note',
        'You\'ve been late $late time${late!=1?'s':''}. Arriving on time matters.'));
    if (_bioRate < 80) ins.add(_Ins(Icons.fingerprint_rounded, _accent,
        'Biometric tip',
        'Only ${_bioRate.toStringAsFixed(0)}% passed bio+face. '
        'Ensure good lighting when scanning.'));
    if (streak >= 7) ins.add(_Ins(Icons.local_fire_department_rounded,
        const Color(0xFFF57C00), '$streak-day streak!',
        'Consistency is key to academic success.'));

    final ach = [
      _Ach(Icons.emoji_events_rounded, 'First Scan',    present>=1, const Color(0xFFF57C00)),
      _Ach(Icons.star_rounded,         '75% Club',      pct>=75,    const Color(0xFF2E7D32)),
      _Ach(Icons.workspace_premium_rounded,'90% Elite', pct>=90,    const Color(0xFF283593)),
      _Ach(Icons.local_fire_department_rounded,'7d Streak', streak>=7, const Color(0xFFF57C00)),
      _Ach(Icons.whatshot_rounded,     '30 Sessions',   present>=30,const Color(0xFF6A1B9A)),
      _Ach(Icons.fingerprint_rounded,  'Fully Verified',present>=5, const Color(0xFF00695C)),
    ];

    return _list([
      _card('Smart Insights', 'Based on your data',
        Column(children: ins.map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: i.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(i.icon, color: i.color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.title, style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(i.body, style: TextStyle(fontSize: 11, height: 1.4,
                  color: Colors.grey.shade600)),
            ])),
          ]),
        )).toList()),
      ),
      const SizedBox(height: 12),
      _card('Achievements', 'Milestones reached',
        Wrap(spacing: 8, runSpacing: 8,
          children: ach.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: a.earned ? a.color.withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: a.earned
                    ? a.color.withOpacity(0.3) : Colors.grey.shade200)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(a.icon, size: 14,
                  color: a.earned ? a.color : Colors.grey.shade400),
              const SizedBox(width: 5),
              Text(a.label, style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: a.earned ? a.color : Colors.grey.shade400)),
            ]),
          )).toList(),
        ),
      ),
      const SizedBox(height: 12),
      _card('Forecast', 'Sessions needed to reach 75%',
        curPct >= 75
          ? _greenBox('You\'ve already met the 75% threshold!')
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Need ${((0.75*total - present)/0.25).ceil()} more present sessions',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('to reach 75% (currently ${curPct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ]),
            ),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LECTURER TABS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _lecturerOverview() {
    final p   = (_lecturerSummary['present'] as num?)?.toInt() ?? 0;
    final a   = (_lecturerSummary['absent']  as num?)?.toInt() ?? 0;
    final l   = (_lecturerSummary['late']    as num?)?.toInt() ?? 0;
    final t   = p + a + l;
    final pct = (_lecturerSummary['percentage'] as num?)?.toInt() ?? 0;

    return _list([
      _card('Class Overview', 'All units combined', Row(children: [
        SizedBox(width: 130, height: 130,
          child: t == 0
            ? _emptyBox('No data')
            : PieChart(PieChartData(sectionsSpace: 3, centerSpaceRadius: 36,
                sections: [
                  _pie(p.toDouble(), const Color(0xFF2E7D32), '$p'),
                  _pie(a.toDouble(), const Color(0xFFE53935), '$a'),
                  _pie(l.toDouble(), const Color(0xFFF57C00), '$l'),
                ])),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('$pct%', style: TextStyle(fontSize: 34,
              fontWeight: FontWeight.w900, color: _accent)),
          Text('Average scan rate', style: TextStyle(fontSize: 11,
              color: Colors.grey.shade500)),
          const SizedBox(height: 14),
          _legend(const Color(0xFF2E7D32), 'Scanned', p),
          const SizedBox(height: 5),
          _legend(const Color(0xFFE53935), 'Absent',  a),
          const SizedBox(height: 5),
          _legend(const Color(0xFFF57C00), 'Late',    l),
        ])),
      ])),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65,
        children: [
          _kpi(Icons.class_rounded, _accent,
              'Units', '${_lecturerUnitStats.length}', 'active assignments'),
          _kpi(Icons.qr_code_scanner_rounded, const Color(0xFF6A1B9A),
              'Sessions', '${_lecturerSessionStats.length}', 'run this term'),
          _kpi(Icons.warning_amber_rounded, const Color(0xFFE53935),
              'At Risk', '${_atRisk.length}', 'below 75%'),
          _kpi(Icons.people_rounded, const Color(0xFF00695C), 'Students',
              '${_lecturerUnitStats.fold<int>(0, (s,u) =>
                  s + ((u['students'] as num?) ?? 0).toInt())}',
              'enrolled total'),
        ],
      ),
      if (_atRisk.isNotEmpty) ...[
        const SizedBox(height: 12),
        _card('At-Risk Units', 'Below 75% attendance',
          Column(children: _atRisk.map((u) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(width: 34, height: 34,
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE53935), size: 16)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(u['name'] as String? ?? '—', style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${u['code']??''} · ${u['students']??0} students',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ])),
              Text('${u['percentage']??0}%', style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w900, color: Color(0xFFE53935))),
            ]),
          )).toList()),
        ),
      ],
    ]);
  }

  Widget _lecturerSessions() {
    final trend    = _sessionTrend;
    final sessions = _lecturerSessionStats.isEmpty
        ? _mockSessions : _lecturerSessionStats;

    return _list([
      _card('Session Scan Rate', 'Percentage of students scanned per session',
        SizedBox(height: 190, child: LineChart(LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: trend.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.rate))
                  .toList(),
              isCurved: true, color: _accent, barWidth: 2.5,
              dotData: FlDotData(getDotPainter: (_,__,___,____) =>
                  FlDotCirclePainter(radius: 3, color: _accent, strokeWidth: 0)),
              belowBarData: BarAreaData(show: true,
                  color: _accent.withOpacity(0.07)),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v,_) => Text('${v.toInt()}%',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade400)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                interval: 2,
                getTitlesWidget: (v,_) {
                  final i = v.toInt();
                  if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top:4),
                    child: Text(trend[i].label, style: TextStyle(
                        fontSize: 8, color: Colors.grey.shade400)));
                })),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: _gridData(), borderData: FlBorderData(show: false),
          minY: 0, maxY: 100,
        ))),
      ),
      const SizedBox(height: 12),
      ...sessions.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _sessionCard(s),
      )),
    ]);
  }

  Widget _lecturerUnits() {
    if (_lecturerUnitStats.isEmpty) return _fullEmpty('No unit data yet');
    return _list([
      _card('Student Distribution', 'Students per unit',
        SizedBox(
          height: max(160.0, _lecturerUnitStats.length * 44.0),
          child: BarChart(BarChartData(
            barGroups: _lecturerUnitStats.asMap().entries.map((e) =>
              BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: ((e.value['students'] as num?)??0).toDouble(),
                  gradient: LinearGradient(colors: [_accentMid, _accent],
                      begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  width: 20, borderRadius: BorderRadius.circular(4)),
              ])).toList(),
            titlesData: _barTitles(_lecturerUnitStats
                .map((u) => u['code'] as String? ?? '').toList()),
            gridData: _gridData(), borderData: FlBorderData(show: false),
          )),
        ),
      ),
      const SizedBox(height: 12),
      ..._lecturerUnitStats.map((u) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _unitCard(u, true),
      )),
    ]);
  }

  Widget _lecturerInsights() {
    final pct       = (_lecturerSummary['percentage'] as num?)?.toInt() ?? 0;
    final sesCount  = _lecturerSessionStats.length;
    final atRiskCnt = _atRisk.length;

    final ins = <_Ins>[];
    if (pct >= 80) ins.add(_Ins(Icons.check_circle_rounded, const Color(0xFF2E7D32),
        'Strong engagement', 'Average scan rate of $pct% shows excellent attendance.'));
    else if (pct >= 60) ins.add(_Ins(Icons.info_outline_rounded, _accent,
        'Moderate attendance',
        'Average of $pct%. Consider checking on absent students.'));
    else ins.add(_Ins(Icons.warning_amber_rounded, const Color(0xFFE53935),
        'Low class attendance',
        'Average $pct% is concerning. Review session scheduling.'));
    if (atRiskCnt > 0) ins.add(_Ins(Icons.group_off_rounded, const Color(0xFFE53935),
        '$atRiskCnt unit${atRiskCnt!=1?'s':''} at risk',
        'Below 75% attendance. Consider targeted outreach.'));
    ins.add(_Ins(Icons.qr_code_scanner_rounded, const Color(0xFF6A1B9A),
        '$sesCount sessions recorded',
        'Your digital record is complete. Use History to export reports.'));

    final sorted = [..._lecturerSessionStats]
      ..sort((a,b) => ((b['rate'] as num?)??0)
          .compareTo((a['rate'] as num?)??0));
    final avgRate = _lecturerSessionStats.isEmpty ? 0.0
        : _lecturerSessionStats.fold<double>(0,
            (s,e) => s + ((e['rate'] as num?)??0).toDouble())
          / _lecturerSessionStats.length;

    return _list([
      _card('Teaching Insights', 'Data-driven recommendations',
        Column(children: ins.map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: i.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(i.icon, color: i.color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.title, style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(i.body, style: TextStyle(fontSize: 11, height: 1.4,
                  color: Colors.grey.shade600)),
            ])),
          ]),
        )).toList()),
      ),
      const SizedBox(height: 12),
      _card('Unit Ranking', 'By attendance %',
        Column(children: (_lecturerUnitStats.toList()
          ..sort((a,b) => ((b['percentage'] as num?)??0)
              .compareTo((a['percentage'] as num?)??0)))
          .take(5).toList().asMap().entries.map((e) {
            final u = e.value;
            final p = ((u['percentage'] as num?)??0).toInt();
            return Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 22, height: 22,
                    decoration: BoxDecoration(color: _accentLight,
                        shape: BoxShape.circle),
                    child: Center(child: Text('${e.key+1}',
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w900, color: _accent)))),
                const SizedBox(width: 8),
                Expanded(child: Text(u['name'] as String? ?? '—',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('$p%', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w900, color: _pctColor(p))),
              ]),
            );
          }).toList()),
      ),
      if (_lecturerSessionStats.isNotEmpty) ...[
        const SizedBox(height: 12),
        _card('Session Quality', 'Best / worst / average',
          Row(children: [
            Expanded(child: _qualityTile('Best',
                '${sorted.first['rate']??0}%',
                sorted.first['unitCode'] as String? ?? '—',
                const Color(0xFF2E7D32))),
            const SizedBox(width: 8),
            Expanded(child: _qualityTile('Worst',
                '${sorted.last['rate']??0}%',
                sorted.last['unitCode'] as String? ?? '—',
                const Color(0xFFE53935))),
            const SizedBox(width: 8),
            Expanded(child: _qualityTile('Average',
                '${avgRate.toStringAsFixed(0)}%',
                '$sesCount sessions', _accent)),
          ]),
        ),
      ],
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED MICRO-BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _list(List<Widget> ch) => RefreshIndicator(
    color: _accent, onRefresh: _loadData,
    child: ListView(padding: const EdgeInsets.all(16), children: ch),
  );

  Widget _card(String title, String sub, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0,3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14,
          fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
      Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Widget _kpi(IconData ic, Color c, String label, String value, String sub) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 8, offset: const Offset(0,2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, color: c, size: 18),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.w900, color: c)),
          Text(label, style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700)),
          Text(sub, style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _legend(Color c, String label, int count) => Row(children: [
    Container(width: 9, height: 9, decoration: BoxDecoration(
        color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    const Spacer(),
    Text('$count', style: TextStyle(fontSize: 12,
        fontWeight: FontWeight.w800, color: c)),
  ]);

  Widget _barRow(String label, int count, int total, Color c) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      SizedBox(width: 52, child: Text(label, style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600, color: Colors.grey.shade700))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 9,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(c)))),
      const SizedBox(width: 7),
      SizedBox(width: 32, child: Text('${(pct*100).round()}%',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c))),
    ]);
  }

  Widget _unitCard(Map<String, dynamic> u, bool showStudents) {
    final pct = ((u['percentage'] as num?)??0).toInt();
    final c   = _pctColor(pct);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(u['name'] as String? ?? '—', style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800)),
            Text('${u['code']??''}${showStudents
                ? ' · ${u['students']??0} students' : ''}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ])),
          Text('$pct%', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w900, color: c)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct/100, minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(c))),
        const SizedBox(height: 8),
        Row(children: [
          _mini('${u['present']??0}','P',const Color(0xFF2E7D32)),
          const SizedBox(width: 5),
          _mini('${u['absent']??0}', 'A',const Color(0xFFE53935)),
          const SizedBox(width: 5),
          _mini('${u['late']??0}',   'L',const Color(0xFFF57C00)),
        ]),
      ]),
    );
  }

  Widget _sessionCard(Map<String,dynamic> s) {
    final rate    = ((s['rate']     as num?)??0).toInt();
    final scanned = ((s['scanned']  as num?)??0).toInt();
    final exp     = ((s['expected'] as num?)??0).toInt();
    final active  = s['isActive'] as bool? ?? false;
    final dt      = DateTime.tryParse(s['date']?.toString() ?? '');
    final c       = _pctColor(rate);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? const Color(0xFF2E7D32) : Colors.grey.shade100,
              width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0,2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(children: [
              Text(s['unitCode'] as String? ?? '—', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w800, color: _accent)),
              if (active) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)))),
              ],
            ]),
            Text(s['unitName'] as String? ?? '—', style: TextStyle(
                fontSize: 11, color: Colors.grey.shade600)),
            if (dt != null) Text(DateFormat('EEE d MMM · HH:mm').format(dt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ])),
          Text('$rate%', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w900, color: c)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: exp > 0 ? scanned/exp : 0, minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(c))),
        const SizedBox(height: 5),
        Text('$scanned of $exp students scanned',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _qualityTile(String label, String value, String sub, Color c) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w900, color: c)),
          Text(sub, style: TextStyle(fontSize: 9, color: c.withOpacity(0.7)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _atRiskBanner(List<Map<String,dynamic>> units) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.warning_rounded, color: Color(0xFFE53935), size: 16),
        SizedBox(width: 6),
        Text('Units Below 75%', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w800, color: Color(0xFFE53935))),
      ]),
      const SizedBox(height: 10),
      ...units.map((u) => Padding(padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(u['name'] as String? ?? '—',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          Text('${u['percentage']??0}%', style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w900, color: Color(0xFFE53935))),
        ]),
      )),
    ]),
  );

  Widget _greenBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(
          fontSize: 12, color: Color(0xFF2E7D32)))),
    ]),
  );

  Widget _mini(String v, String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(0.09),
        borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(v, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c)),
      const SizedBox(width: 3),
      Text(l, style: TextStyle(fontSize: 9, color: c.withOpacity(0.8))),
    ]),
  );

  Widget _emptyBox(String msg) => Center(child: Text(msg,
      style: TextStyle(color: Colors.grey.shade400)));

  Widget _fullEmpty(String msg) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.analytics_outlined, size: 60, color: Colors.grey.shade300),
    const SizedBox(height: 14),
    Text(msg, style: TextStyle(fontSize: 14,
        fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
  ]));

  // fl_chart helpers
  PieChartSectionData _pie(double v, Color c, String title) =>
      PieChartSectionData(value: v, color: c, title: title,
          titleStyle: const TextStyle(fontSize: 10,
              fontWeight: FontWeight.w800, color: Colors.white),
          radius: 28);

  BarChartRodData _rod(double y, Color c) => BarChartRodData(
      toY: y, color: c, width: 9,
      borderRadius: BorderRadius.circular(3));

  FlTitlesData _barTitles(List<String> labels) => FlTitlesData(
    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
        reservedSize: 26, getTitlesWidget: (v,_) => Text(v.toInt().toString(),
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400)))),
    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
        getTitlesWidget: (v,_) {
          final i = v.toInt();
          if (i < 0 || i >= labels.length) return const SizedBox.shrink();
          return Padding(padding: const EdgeInsets.only(top:3),
              child: Text(labels[i], style: TextStyle(fontSize: 8,
                  color: Colors.grey.shade500)));
        })),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );

  FlGridData _gridData() => FlGridData(drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.grey.shade100, strokeWidth: 1));

  Color _pctColor(int pct) => pct >= 75
      ? const Color(0xFF2E7D32)
      : pct >= 60 ? const Color(0xFFF57C00) : const Color(0xFFE53935);

  Widget _bottomNav() => Container(
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0,-4))]),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    child: GNav(
      backgroundColor: Colors.white, color: Colors.grey.shade500,
      activeColor: Colors.white, tabBackgroundColor: _accent,
      gap: 8, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      selectedIndex: 1,
      onTabChange: (i) {
        if (i == 0) context.go(_homePath);
        if (i == 2) context.go('/timetable');
        if (i == 3) context.go('/settings');
      },
      tabs: const [
        GButton(icon: Icons.home_rounded,          text: 'Home'),
        GButton(icon: Icons.analytics_rounded,      text: 'Analytics'),
        GButton(icon: Icons.calendar_today_rounded, text: 'Timetable'),
        GButton(icon: Icons.settings_rounded,       text: 'Settings'),
      ],
    ),
  );
}

// ── Models ────────────────────────────────────────────────────────────────────
class _WeekBucket {
  final String label; final DateTime start;
  int present, absent, late;
  _WeekBucket(this.label, this.start, this.present, this.absent, this.late);
}
class _DayBucket {
  final String day; int total, present;
  _DayBucket(this.day, this.total, this.present);
}
class _SessionPoint {
  final String label; final double rate;
  _SessionPoint({required this.label, required this.rate});
}
class _Ins {
  final IconData icon; final Color color; final String title, body;
  _Ins(this.icon, this.color, this.title, this.body);
}
class _Ach {
  final IconData icon; final String label;
  final bool earned; final Color color;
  _Ach(this.icon, this.label, this.earned, this.color);
}