// lib/features/attendance/presentation/screens/pages/history.dart
//
// pubspec.yaml additions:
//   share_plus: ^10.0.0
//   path_provider: ^2.1.0
//   pdf: ^3.11.0
//   csv: ^6.0.0

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../../core/services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic>? _user;
  bool    _loading    = true;
  bool    _exporting  = false;
  String? _error;

  // Student data
  List<Map<String, dynamic>> _records   = [];
  List<Map<String, dynamic>> _unitStats = [];
  Map<String, dynamic>       _summary   = {};

  // Lecturer data
  List<Map<String, dynamic>> _lecturerUnitStats    = [];
  List<Map<String, dynamic>> _lecturerSessionStats = [];
  Map<String, dynamic>       _lecturerSummary      = {};

  // Filters
  String _filterStatus = 'All';
  String _searchQuery  = '';

  late TabController _tabCtrl;

  // ── Role helpers ──────────────────────────────────────────────────────────
  String get _role       => _user?['role'] as String? ?? 'student';
  bool   get _isStudent  => _role == 'student';
  bool   get _isLecturer => _role == 'lecturer';

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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    final user = await ApiService().getUser();
    if (!mounted) return;
    setState(() => _user = user);
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });

    if (_isStudent) {
      final r = await ApiService().get('/attendance/my-history');
      if (!mounted) return;
      if (r.success) {
        setState(() {
          _records   = List<Map<String,dynamic>>.from(r.data?['records']   ?? []);
          _unitStats = List<Map<String,dynamic>>.from(r.data?['unitStats'] ?? []);
          _summary   = r.data?['summary'] as Map<String,dynamic>? ?? {};
          _loading   = false;
        });
      } else {
        setState(() { _error = r.error; _loading = false; });
      }
    } else {
      // Lecturer / Admin
      final r = await ApiService().get('/attendance/lecturer-reports');
      if (!mounted) return;
      if (r.success) {
        setState(() {
          _lecturerUnitStats    = List<Map<String,dynamic>>.from(r.data?['unitStats']    ?? []);
          _lecturerSessionStats = List<Map<String,dynamic>>.from(r.data?['sessionStats'] ?? []);
          _lecturerSummary      = r.data?['summary'] as Map<String,dynamic>? ?? {};
          _loading              = false;
        });
      } else {
        setState(() { _error = r.error; _loading = false; });
      }
    }
  }

  // ── Filtered records ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    return _records.where((r) {
      final status = r['status'] as String? ?? '';
      final unit   = (r['unit'] as Map<String,dynamic>?);
      final name   = unit?['name'] as String? ?? '';
      final code   = unit?['code'] as String? ?? '';

      final matchStatus = _filterStatus == 'All' ||
          status.toLowerCase() == _filterStatus.toLowerCase();
      final matchSearch = _searchQuery.isEmpty ||
          name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          code.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT METHODS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _exportCSV() async {
    setState(() => _exporting = true);
    try {
      final lines = <String>[];
      if (_isStudent) {
        lines.add('"Unit","Code","Date","Time","Status","Biometric","Face"');
        for (final r in _records) {
          final unit   = r['unit'] as Map<String,dynamic>? ?? {};
          final marked = r['markedAt'] ?? r['createdAt'] ?? '';
          final dt     = marked.isNotEmpty ? DateTime.tryParse(marked) : null;
          final date   = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '—';
          final time   = dt != null
              ? '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
              : '—';
          lines.add('"${unit['name'] ?? '—'}","${unit['code'] ?? '—'}",'
              '"$date","$time","${r['status'] ?? '—'}",'
              '"${(r['biometricVerified'] == true) ? 'Yes' : 'No'}",'
              '"${(r['faceVerified'] == true) ? 'Yes' : 'No'}"');
        }
      } else {
        lines.add('"Unit","Code","Sessions","Present","Absent","Late","Avg %"');
        for (final u in _lecturerUnitStats) {
          lines.add('"${u['name'] ?? '—'}","${u['code'] ?? '—'}",'
              '"${u['students'] ?? 0}","${u['present'] ?? 0}",'
              '"${u['absent'] ?? 0}","${u['late'] ?? 0}","${u['percentage'] ?? 0}%"');
        }
      }

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(lines.join('\n'));

      await Share.shareXFiles([XFile(file.path)],
          subject: 'Attendance Export — CSV');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPDF() async {
    setState(() => _exporting = true);
    try {
      final pdf = pw.Document();

      if (_isStudent) {
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text('Attendance Report',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            // Summary row
            pw.Row(children: [
              _pdfBubble('Present', '${_summary['present'] ?? 0}', PdfColors.green800),
              pw.SizedBox(width: 12),
              _pdfBubble('Absent', '${_summary['absent'] ?? 0}', PdfColors.red700),
              pw.SizedBox(width: 12),
              _pdfBubble('Late', '${_summary['late'] ?? 0}', PdfColors.orange700),
              pw.SizedBox(width: 12),
              _pdfBubble('Overall', '${_summary['percentage'] ?? 0}%', PdfColors.indigo700),
            ]),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Unit', 'Code', 'Date', 'Status', 'Biometric', 'Face'],
              data: _records.map((r) {
                final unit   = r['unit'] as Map<String,dynamic>? ?? {};
                final marked = r['markedAt'] ?? r['createdAt'] ?? '';
                final dt     = marked.isNotEmpty ? DateTime.tryParse(marked.toString()) : null;
                final date   = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '—';
                return [
                  unit['name'] ?? '—',
                  unit['code'] ?? '—',
                  date,
                  '${r['status'] ?? '—'}',
                  (r['biometricVerified'] == true) ? '✓' : '✗',
                  (r['faceVerified']      == true) ? '✓' : '✗',
                ];
              }).toList(),
              headerStyle:    pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
          ],
        ));
      } else {
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text('Lecturer Attendance Report',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Unit', 'Code', 'Students', 'Present', 'Absent', 'Late', 'Avg %'],
              data: _lecturerUnitStats.map((u) => [
                u['name']       ?? '—',
                u['code']       ?? '—',
                '${u['students'] ?? 0}',
                '${u['present']  ?? 0}',
                '${u['absent']   ?? 0}',
                '${u['late']     ?? 0}',
                '${u['percentage'] ?? 0}%',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Recent Sessions',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Unit', 'Date', 'Scanned', 'Expected', 'Rate'],
              data: _lecturerSessionStats.map((s) {
                final dt   = DateTime.tryParse(s['date']?.toString() ?? '');
                final date = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '—';
                return [
                  s['unitCode'] ?? '—',
                  date,
                  '${s['scanned']  ?? 0}',
                  '${s['expected'] ?? 0}',
                  '${s['rate']     ?? 0}%',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
          ],
        ));
      }

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          subject: 'Attendance Report — PDF');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportJSON() async {
    setState(() => _exporting = true);
    try {
      final data   = _isStudent
          ? { 'summary': _summary, 'unitStats': _unitStats, 'records': _records }
          : { 'summary': _lecturerSummary, 'unitStats': _lecturerUnitStats,
              'sessions': _lecturerSessionStats };
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      final dir    = await getTemporaryDirectory();
      final file   = File('${dir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(pretty);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Attendance Data — JSON');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfBubble(String label, String value, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pw.BoxDecoration(
            color: color, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          pw.Text(value, style: pw.TextStyle(
              color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(label, style: const pw.TextStyle(
              color: PdfColors.white, fontSize: 9)),
        ]),
      );

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const Text('Export Report',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Choose a format to share or save',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          Row(children: [
            _ExportFormatBtn(
              label: 'CSV',
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF2E7D32),
              subtitle: 'Excel compatible',
              onTap: () { Navigator.pop(context); _exportCSV(); },
            ),
            const SizedBox(width: 12),
            _ExportFormatBtn(
              label: 'PDF',
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFE53935),
              subtitle: 'Print-ready',
              onTap: () { Navigator.pop(context); _exportPDF(); },
            ),
            const SizedBox(width: 12),
            _ExportFormatBtn(
              label: 'JSON',
              icon: Icons.data_object_rounded,
              color: const Color(0xFF283593),
              subtitle: 'Raw data',
              onTap: () { Navigator.pop(context); _exportJSON(); },
            ),
          ]),
        ]),
      ),
    );
  }

  void _showSnack(String msg, { bool isError = false }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFE53935) : _accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [_buildAppBar()],
                  body: _isStudent
                      ? _buildStudentBody()
                      : _buildLecturerBody(),
                ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final present    = _isStudent ? (_summary['present']    ?? 0) : (_lecturerSummary['present']    ?? 0);
    final absent     = _isStudent ? (_summary['absent']     ?? 0) : (_lecturerSummary['absent']     ?? 0);
    final late       = _isStudent ? (_summary['late']       ?? 0) : (_lecturerSummary['late']       ?? 0);
    final percentage = _isStudent ? (_summary['percentage'] ?? 0) : (_lecturerSummary['percentage'] ?? 0);

    return SliverAppBar(
      expandedHeight: _isStudent ? 220 : 180,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _accent,
      actions: [
        if (_exporting)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
          )
        else
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Export',
            onPressed: _showExportSheet,
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadData,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: _accent,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: _accent,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: _isStudent
                ? const [Tab(text: 'My Records'), Tab(text: 'By Subject')]
                : const [Tab(text: 'Unit Reports'), Tab(text: 'Sessions')],
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_accent, _accentMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 100, 56),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_isStudent
                      ? Icons.history_rounded
                      : Icons.assessment_rounded,
                      color: Colors.white.withOpacity(0.85), size: 20),
                  const SizedBox(width: 8),
                  Text(_isStudent ? 'Attendance History' : 'Attendance Reports',
                      style: const TextStyle(fontSize: 22,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
                const SizedBox(height: 16),
                // Summary bubbles
                Row(children: [
                  _SummaryBubble('$present', 'Present',
                      Colors.white, Colors.white.withOpacity(0.2)),
                  const SizedBox(width: 10),
                  _SummaryBubble('$absent',  'Absent',
                      const Color(0xFFFFCDD2), Colors.red.withOpacity(0.2)),
                  const SizedBox(width: 10),
                  _SummaryBubble('$late',    'Late',
                      const Color(0xFFFFE0B2), Colors.orange.withOpacity(0.2)),
                  const SizedBox(width: 10),
                  _SummaryBubble('$percentage%', 'Overall',
                      const Color(0xFFB3E5FC), Colors.lightBlue.withOpacity(0.2)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Student body ──────────────────────────────────────────────────────────
  Widget _buildStudentBody() => TabBarView(
    controller: _tabCtrl,
    children: [_buildRecordsTab(), _buildUnitStatsTab()],
  );

  Widget _buildRecordsTab() {
    return Column(children: [
      // Search + filter
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search unit…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, size: 18,
                    color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Present', 'Absent', 'Late'].map((s) {
                final isSelected = _filterStatus == s;
                final chipColor  = switch (s) {
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? chipColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? chipColor
                              : Colors.grey.shade200),
                    ),
                    child: Text(s, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade600)),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${_filtered.length} record${_filtered.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: _filtered.isEmpty
            ? _buildEmpty('No records match your filter')
            : RefreshIndicator(
                color: _accent,
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _RecordCard(
                      record: _filtered[i], accentColor: _accent),
                ),
              ),
      ),
    ]);
  }

  Widget _buildUnitStatsTab() {
    if (_unitStats.isEmpty) {
      return _buildEmpty('No unit data yet');
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _unitStats.length,
        itemBuilder: (_, i) => _UnitStatCard(
            stat: _unitStats[i], accentColor: _accent,
            accentLight: _accentLight),
      ),
    );
  }

  // ── Lecturer body ─────────────────────────────────────────────────────────
  Widget _buildLecturerBody() => TabBarView(
    controller: _tabCtrl,
    children: [_buildLecturerUnitTab(), _buildSessionsTab()],
  );

  Widget _buildLecturerUnitTab() {
    if (_lecturerUnitStats.isEmpty) {
      return _buildEmpty('No attendance data yet');
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lecturerUnitStats.length,
        itemBuilder: (_, i) => _UnitStatCard(
            stat: _lecturerUnitStats[i], accentColor: _accent,
            accentLight: _accentLight, showStudentCount: true),
      ),
    );
  }

  Widget _buildSessionsTab() {
    if (_lecturerSessionStats.isEmpty) {
      return _buildEmpty('No sessions held yet');
    }
    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lecturerSessionStats.length,
        itemBuilder: (_, i) => _SessionCard(
            session: _lecturerSessionStats[i], accentColor: _accent),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildEmpty(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(msg, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
          color: Colors.grey.shade400)),
    ]),
  );

  Widget _buildError() => GestureDetector(
    onTap: _loadData,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
      const SizedBox(height: 8),
      Text('Tap to retry',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ])),
  );

  Widget _buildBottomNav() => Container(
    decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0, -4))]),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    child: GNav(
      backgroundColor: Colors.white,
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
        GButton(icon: Icons.home_rounded,           text: 'Home'),
        GButton(icon: Icons.history_rounded,         text: 'History'),
        GButton(icon: Icons.calendar_today_rounded,  text: 'Timetable'),
        GButton(icon: Icons.settings_rounded,        text: 'Settings'),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RECORD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final Color accentColor;
  const _RecordCard({required this.record, required this.accentColor});

  String get _status => record['status'] as String? ?? 'present';
  Color  get _statusColor => switch (_status) {
    'present' => const Color(0xFF2E7D32),
    'late'    => const Color(0xFFF57C00),
    _         => const Color(0xFFE53935),
  };
  Color  get _statusBg => switch (_status) {
    'present' => const Color(0xFFE8F5E9),
    'late'    => const Color(0xFFFFF8E1),
    _         => const Color(0xFFFFEBEE),
  };
  IconData get _statusIcon => switch (_status) {
    'present' => Icons.check_circle_rounded,
    'late'    => Icons.watch_later_rounded,
    _         => Icons.cancel_rounded,
  };

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[dt.weekday-1]}, ${dt.day} ${months[dt.month-1]}';
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final unit    = record['unit']    as Map<String,dynamic>? ?? {};
    final session = record['session'] as Map<String,dynamic>? ?? {};
    final marked  = record['markedAt']?.toString() ?? record['createdAt']?.toString();
    final bio     = record['biometricVerified'] == true;
    final face    = record['faceVerified']      == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(color: _statusBg,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(_statusIcon, color: _statusColor, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(unit['name'] as String? ?? '—',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 3),
          Row(children: [
            Text(unit['code'] as String? ?? '—',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(width: 6),
            Container(width: 3, height: 3, decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.grey.shade400)),
            const SizedBox(width: 6),
            Text(_fmtDate(marked),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 4),
          // Verification badges
          Row(children: [
            _VerBadge('Bio', bio),
            const SizedBox(width: 4),
            _VerBadge('Face', face),
            if ((session['location'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(width: 4),
              Icon(Icons.location_on_outlined, size: 11,
                  color: Colors.grey.shade400),
              Text(session['location'] as String? ?? '',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min, children: [
          Text(_fmtTime(marked), style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusBg,
                borderRadius: BorderRadius.circular(8)),
            child: Text(_status[0].toUpperCase() + _status.substring(1),
                style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w800, color: _statusColor)),
          ),
        ]),
      ]),
    );
  }
}

class _VerBadge extends StatelessWidget {
  final String label; final bool passed;
  const _VerBadge(this.label, this.passed);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: passed
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(4)),
    child: Text('$label ${passed ? '✓' : '✗'}',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: passed
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE53935))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIT STAT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UnitStatCard extends StatelessWidget {
  final Map<String, dynamic> stat;
  final Color accentColor, accentLight;
  final bool showStudentCount;
  const _UnitStatCard({
    required this.stat,
    required this.accentColor,
    required this.accentLight,
    this.showStudentCount = false,
  });

  Color _colorFor(int pct) => pct >= 75
      ? const Color(0xFF2E7D32)
      : pct >= 60
          ? const Color(0xFFF57C00)
          : const Color(0xFFE53935);

  // Stable colour from code string
  Color _unitColor() {
    final colors = [
      const Color(0xFF2E7D32), const Color(0xFF283593),
      const Color(0xFF6A1B9A), const Color(0xFFF57C00),
      const Color(0xFFE53935), const Color(0xFF00695C),
    ];
    final code = stat['code'] as String? ?? '';
    return colors[code.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final pct      = (stat['percentage'] as num?)?.toInt() ?? 0;
    final color    = _unitColor();
    final pctColor = _colorFor(pct);
    final present  = stat['present']  ?? 0;
    final absent   = stat['absent']   ?? 0;
    final late     = stat['late']     ?? 0;
    final students = stat['students'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(
                (stat['code'] as String? ?? '').split(' ').last,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w900, color: color),
              ))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stat['name'] as String? ?? '—',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B))),
            Text(stat['code'] as String? ?? '—',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (showStudentCount)
              Text('$students student${students != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          Text('$pct%', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w900, color: pctColor)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100, minHeight: 7,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(pctColor),
          )),
        const SizedBox(height: 12),
        Row(children: [
          _MiniStat('$present', 'Present', const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          _MiniStat('$absent',  'Absent',  const Color(0xFFE53935)),
          const SizedBox(width: 8),
          _MiniStat('$late',    'Late',    const Color(0xFFF57C00)),
          const Spacer(),
          if (pct < 75)
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
  final String value, label; final Color color;
  const _MiniStat(this.value, this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION CARD  (lecturer sessions tab)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final Color accentColor;
  const _SessionCard({required this.session, required this.accentColor});

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '—';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month-1]} · '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scanned  = session['scanned']  as num? ?? 0;
    final expected = session['expected'] as num? ?? 0;
    final rate     = session['rate']     as num? ?? 0;
    final isActive = session['isActive'] as bool? ?? false;
    final rateColor = rate >= 75
        ? const Color(0xFF2E7D32)
        : rate >= 50
            ? const Color(0xFFF57C00)
            : const Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
            : Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.qr_code_rounded, color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(session['unitCode'] as String? ?? '—',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: accentColor)),
            const SizedBox(width: 8),
            if (isActive) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('LIVE', style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
            ),
          ]),
          const SizedBox(height: 2),
          Text(session['unitName'] as String? ?? '—',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(_fmtDate(session['date']?.toString()),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$scanned/$expected',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B))),
          Text('scanned',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: rateColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text('$rate%', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w800, color: rateColor)),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export format button
// ─────────────────────────────────────────────────────────────────────────────

class _ExportFormatBtn extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ExportFormatBtn({
    required this.label, required this.subtitle, required this.icon,
    required this.color, required this.onTap,
  });
  @override Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10,
              color: color.withOpacity(0.7)), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary bubble
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBubble extends StatelessWidget {
  final String value, label; final Color color, bg;
  const _SummaryBubble(this.value, this.label, this.color, this.bg);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.85))),
    ]),
  );
}