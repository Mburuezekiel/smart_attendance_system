// lib/features/assignments/presentation/admin_assignments_page.dart

import 'package:flutter/material.dart';
import '../../../../../core//services//api_service.dart';

class AdminAssignmentsPage extends StatefulWidget {
  const AdminAssignmentsPage({super.key});
  @override
  State<AdminAssignmentsPage> createState() => _AdminAssignmentsPageState();
}

class _AdminAssignmentsPageState extends State<AdminAssignmentsPage>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF00695C);

  late TabController _tabCtrl;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _units       = [];
  List<Map<String, dynamic>> _lecturers   = [];
  List<Map<String, dynamic>> _students    = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });

    // Sequential calls — avoids Future.wait generic cast issues
    final r0 = await ApiService().get('/assignments');
    final r1 = await ApiService().get('/units');
    final r2 = await ApiService().get('/users', queryParams: {'role': 'lecturer', 'limit': '100'});
    final r3 = await ApiService().get('/users', queryParams: {'role': 'student',  'limit': '500'});

    if (!mounted) return;

    if (r0.success && r1.success && r2.success && r3.success) {
      setState(() {
        _assignments = List<Map<String,dynamic>>.from(r0.data?['assignments'] ?? []);
        _units       = List<Map<String,dynamic>>.from(r1.data?['units']       ?? []);
        _lecturers   = List<Map<String,dynamic>>.from(r2.data?['users']       ?? []);
        _students    = List<Map<String,dynamic>>.from(r3.data?['users']       ?? []);
        _loading     = false;
      });
    } else {
      setState(() {
        _error   = r0.error ?? r1.error ?? r2.error ?? r3.error ?? 'Failed to load data.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _teal,
        automaticallyImplyLeading: false,
        title: const Text('Assignments',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded),   text: 'All'),
            Tab(icon: Icon(Icons.add_box_rounded),    text: 'New'),
            Tab(icon: Icon(Icons.menu_book_rounded),  text: 'Units'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _error != null
              ? Center(child: GestureDetector(
                  onTap: _loadAll,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('Tap to retry', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  ]),
                ))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _AssignmentList(
                      assignments: _assignments,
                      allStudents: _students,
                      onRefresh: _loadAll,
                    ),
                    _CreateAssignmentForm(
                      units: _units,
                      lecturers: _lecturers,
                      students: _students,
                      onCreated: () { _loadAll(); _tabCtrl.animateTo(0); },
                    ),
                    _UnitsTab(
                      units: _units,
                      onRefresh: _loadAll,
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASSIGNMENT LIST
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentList extends StatelessWidget {
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> allStudents;
  final VoidCallback onRefresh;
  static const _teal = Color(0xFF00695C);

  const _AssignmentList({
    required this.assignments, required this.allStudents, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No assignments yet', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Switch to the New tab to create one',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
      ]));
    }
    return RefreshIndicator(
      color: _teal,
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: assignments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _AssignmentCard(
          assignment: assignments[i],
          allStudents: allStudents,
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASSIGNMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final List<Map<String, dynamic>> allStudents;
  final VoidCallback onRefresh;
  static const _teal = Color(0xFF00695C);

  const _AssignmentCard({
    required this.assignment, required this.allStudents, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final unit      = assignment['unit']     as Map<String, dynamic>? ?? {};
    final lecturer  = assignment['lecturer'] as Map<String, dynamic>? ?? {};
    final students  = (assignment['students'] as List?)
        ?.whereType<Map<String,dynamic>>().toList() ?? [];
    final isActive  = assignment['isActive']    as bool?   ?? true;
    final semester  = assignment['semester']     as int?;
    final acadYear  = assignment['academicYear'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: _teal.withOpacity(0.25)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(6)),
              child: Text(unit['code'] as String? ?? '—',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(unit['name'] as String? ?? '—',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
            if (!isActive) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
              child: Text('INACTIVE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.person_pin_rounded, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(child: Text(lecturer['fullName'] as String? ?? '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 6),
            if (acadYear != null || semester != null)
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  [if (acadYear != null) acadYear, if (semester != null) 'Sem $semester'].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.people_rounded, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('${students.length} student${students.length != 1 ? 's' : ''} enrolled',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showManageStudents(context),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Manage'),
                style: TextButton.styleFrom(
                  foregroundColor: _teal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
            if (students.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: Stack(
                  children: List.generate(students.take(6).length, (i) {
                    final name    = students[i]['fullName'] as String? ?? '?';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return Positioned(
                      left: i * 20.0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: _teal.withOpacity(0.15),
                        child: Text(initial,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _teal)),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showManageStudents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageStudentsSheet(
        assignment: assignment,
        allStudents: allStudents,
        onSaved: onRefresh,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE STUDENTS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ManageStudentsSheet extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final List<Map<String, dynamic>> allStudents;
  final VoidCallback onSaved;
  const _ManageStudentsSheet({
    required this.assignment, required this.allStudents, required this.onSaved});
  @override State<_ManageStudentsSheet> createState() => _ManageStudentsSheetState();
}

class _ManageStudentsSheetState extends State<_ManageStudentsSheet> {
  static const _teal = Color(0xFF00695C);
  late Set<String> _enrolled;
  bool _saving = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _enrolled = (widget.assignment['students'] as List?)
        ?.whereType<Map<String,dynamic>>()
        .map((s) => s['_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet() ?? {};
  }

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Map<String,dynamic>> get _filtered {
    if (_search.isEmpty) return widget.allStudents;
    final q = _search.toLowerCase();
    return widget.allStudents.where((s) =>
      (s['fullName'] as String? ?? '').toLowerCase().contains(q) ||
      (s['registrationNumber'] as String? ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final currentIds = (widget.assignment['students'] as List?)
        ?.whereType<Map<String,dynamic>>()
        .map((s) => s['_id'] as String? ?? '').toSet() ?? {};

    final add    = _enrolled.difference(currentIds).toList();
    final remove = currentIds.difference(_enrolled).toList();

    final result = await ApiService().patch(
      '/assignments/${widget.assignment['_id']}/students',
      { if (add.isNotEmpty) 'add': add, if (remove.isNotEmpty) 'remove': remove },
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Students updated'), backgroundColor: _teal));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              const Text('Manage Students',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('${_enrolled.length} selected',
                    style: const TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search students…',
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true, fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) {
              final s    = _filtered[i];
              final id   = s['_id'] as String? ?? '';
              final name = s['fullName'] as String? ?? '—';
              final reg  = s['registrationNumber'] as String? ?? '—';
              final isIn = _enrolled.contains(id);
              return CheckboxListTile(
                value: isIn, activeColor: _teal,
                onChanged: (v) => setState(() { if (v == true) {
                  _enrolled.add(id);
                } else {
                  _enrolled.remove(id);
                } }),
                title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(reg, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                secondary: CircleAvatar(radius: 18, backgroundColor: _teal.withOpacity(0.1),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _teal))),
                dense: true,
              );
            },
          )),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_teal, Color(0xFF00796B)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE ASSIGNMENT FORM  — includes academicYear + semester (required by backend)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateAssignmentForm extends StatefulWidget {
  final List<Map<String,dynamic>> units, lecturers, students;
  final VoidCallback onCreated;
  const _CreateAssignmentForm({
    required this.units, required this.lecturers,
    required this.students, required this.onCreated});
  @override State<_CreateAssignmentForm> createState() => _CreateAssignmentFormState();
}

class _CreateAssignmentFormState extends State<_CreateAssignmentForm> {
  static const _teal = Color(0xFF00695C);

  String? _unitId;
  String? _lecturerId;
  int     _semester = 1;
  final   _yearCtrl = TextEditingController(text: '2025/2026');
  final   Set<String> _selectedStudents = {};
  bool    _saving = false;
  String? _error;
  String  _studentSearch = '';
  final   _studentSearchCtrl = TextEditingController();

  @override
  void dispose() { _yearCtrl.dispose(); _studentSearchCtrl.dispose(); super.dispose(); }

  List<Map<String,dynamic>> get _filteredStudents {
    if (_studentSearch.isEmpty) return widget.students;
    final q = _studentSearch.toLowerCase();
    return widget.students.where((s) =>
      (s['fullName'] as String? ?? '').toLowerCase().contains(q) ||
      (s['registrationNumber'] as String? ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _submit() async {
    if (_unitId == null || _lecturerId == null) {
      setState(() => _error = 'Please select a unit and a lecturer.'); return;
    }
    if (_yearCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the academic year.'); return;
    }
    setState(() { _saving = true; _error = null; });

    final result = await ApiService().post('/assignments', {
      'unitId':       _unitId,
      'lecturerId':   _lecturerId,
      'academicYear': _yearCtrl.text.trim(),
      'semester':     _semester,
      'studentIds':   _selectedStudents.toList(),
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      setState(() {
        _unitId = null; _lecturerId = null; _semester = 1;
        _yearCtrl.text = '2025/2026';
        _selectedStudents.clear(); _studentSearch = ''; _studentSearchCtrl.clear();
      });
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment created!'), backgroundColor: _teal));
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        const _FormLabel('Unit'),
        DropdownButtonFormField<String>(
          initialValue: _unitId,
          hint: const Text('Select unit…', style: TextStyle(fontSize: 13)),
          decoration: _dropDecor(), isExpanded: true,
          items: widget.units.map((u) => DropdownMenuItem(
            value: u['_id'] as String?,
            child: Text('${u['code']} — ${u['name']}',
                style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _unitId = v),
        ),
        const SizedBox(height: 16),

        const _FormLabel('Lecturer'),
        DropdownButtonFormField<String>(
          initialValue: _lecturerId,
          hint: const Text('Select lecturer…', style: TextStyle(fontSize: 13)),
          decoration: _dropDecor(), isExpanded: true,
          items: widget.lecturers.map((l) => DropdownMenuItem(
            value: l['_id'] as String?,
            child: Text(l['fullName'] as String? ?? '—',
                style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _lecturerId = v),
        ),
        const SizedBox(height: 16),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FormLabel('Academic Year'),
            TextField(controller: _yearCtrl, decoration: _inputDec('e.g. 2025/2026')),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FormLabel('Semester'),
            Row(children: [1, 2].map((s) => Padding(
              padding: EdgeInsets.only(right: s == 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _semester = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 68, height: 50,
                  decoration: BoxDecoration(
                    color: _semester == s ? _teal : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _semester == s ? _teal : Colors.grey.shade200),
                  ),
                  child: Center(child: Text('Sem $s', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _semester == s ? Colors.white : Colors.grey.shade600))),
                ),
              ),
            )).toList()),
          ]),
        ]),
        const SizedBox(height: 20),

        Row(children: [
          const Text('Enroll Students', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('${_selectedStudents.length} selected',
                style: const TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('You can also add/remove students later using the Manage button.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(height: 10),
        TextField(
          controller: _studentSearchCtrl,
          onChanged: (v) => setState(() => _studentSearch = v),
          decoration: InputDecoration(
            hintText: 'Search students…',
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 280,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)),
          child: _filteredStudents.isEmpty
              ? Center(child: Text('No students found',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _filteredStudents.length,
                  itemBuilder: (ctx, i) {
                    final s    = _filteredStudents[i];
                    final id   = s['_id'] as String? ?? '';
                    final name = s['fullName'] as String? ?? '—';
                    final reg  = s['registrationNumber'] as String? ?? '—';
                    final isIn = _selectedStudents.contains(id);
                    return CheckboxListTile(
                      dense: true, value: isIn, activeColor: _teal,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectedStudents.add(id);
                        } else {
                          _selectedStudents.remove(id);
                        }
                      }),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(reg, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    );
                  },
                ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFE53935)))),
        ],
        const SizedBox(height: 20),

        GestureDetector(
          onTap: _saving ? null : _submit,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, Color(0xFF00796B)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: _saving
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('Create Assignment',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  InputDecoration _dropDecor() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true, fillColor: const Color(0xFFF7F7F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 2)),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    filled: true, fillColor: const Color(0xFFF7F7F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 2)),
  );
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// UNITS TAB  — list existing units + create new ones
// ─────────────────────────────────────────────────────────────────────────────

class _UnitsTab extends StatefulWidget {
  final List<Map<String, dynamic>> units;
  final VoidCallback onRefresh;
  const _UnitsTab({required this.units, required this.onRefresh});
  @override State<_UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends State<_UnitsTab> {
  static const _teal = Color(0xFF00695C);
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _teal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(_showForm ? 'Cancel' : 'New Unit',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => setState(() => _showForm = !_showForm),
      ),
      body: _showForm
          ? _CreateUnitForm(onCreated: () {
              setState(() => _showForm = false);
              widget.onRefresh();
            })
          : _UnitList(units: widget.units, onRefresh: widget.onRefresh),
    );
  }
}

// ── Unit list ─────────────────────────────────────────────────────────────────

class _UnitList extends StatelessWidget {
  final List<Map<String, dynamic>> units;
  final VoidCallback onRefresh;
  static const _teal = Color(0xFF00695C);

  const _UnitList({required this.units, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No units yet', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Tap + New Unit to create one',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
      ]));
    }
    return RefreshIndicator(
      color: _teal,
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: units.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final u = units[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _teal.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_book_rounded, color: _teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] as String? ?? '—',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${u['code']} · ${u['department']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _teal.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: Text('Yr ${u['year']} · Sem ${u['semester']}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _teal)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ── Create unit form ─────────────────────────────────────────────────────────

class _CreateUnitForm extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateUnitForm({required this.onCreated});
  @override State<_CreateUnitForm> createState() => _CreateUnitFormState();
}

class _CreateUnitFormState extends State<_CreateUnitForm> {
  static const _teal = Color(0xFF00695C);

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  int   _year     = 1;
  int   _semester = 1;
  bool  _saving   = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose(); _nameCtrl.dispose(); _deptCtrl.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final dept = _deptCtrl.text.trim();

    if (code.isEmpty || name.isEmpty || dept.isEmpty) {
      setState(() => _error = 'Code, name and department are all required.'); return;
    }
    setState(() { _saving = true; _error = null; });

    final result = await ApiService().post('/units', {
      'code': code, 'name': name, 'department': dept,
      'year': _year, 'semester': _semester,
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit created!'), backgroundColor: _teal));
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _teal.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.menu_book_rounded, color: _teal, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('Create New Unit',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _teal))),
          ]),
        ),
        const SizedBox(height: 20),

        const _FormLabel('Unit Code'),
        _Field(hint: 'e.g. CS301', ctrl: _codeCtrl, caps: true),
        const SizedBox(height: 14),

        const _FormLabel('Unit Name'),
        _Field(hint: 'e.g. Computer Networks', ctrl: _nameCtrl),
        const SizedBox(height: 14),

        const _FormLabel('Department'),
        _Field(hint: 'e.g. Computer Science', ctrl: _deptCtrl),
        const SizedBox(height: 14),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Year picker
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FormLabel('Year'),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: _dropDecor(),
              items: List.generate(6, (i) => DropdownMenuItem(
                  value: i + 1, child: Text('Year ${i + 1}'))),
              onChanged: (v) => setState(() => _year = v!),
            ),
          ])),
          const SizedBox(width: 12),
          // Semester toggle
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FormLabel('Semester'),
            Row(children: [1, 2].map((s) => Padding(
              padding: EdgeInsets.only(right: s == 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _semester = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 68, height: 50,
                  decoration: BoxDecoration(
                    color: _semester == s ? _teal : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _semester == s ? _teal : Colors.grey.shade200),
                  ),
                  child: Center(child: Text('Sem $s', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _semester == s ? Colors.white : Colors.grey.shade600))),
                ),
              ),
            )).toList()),
          ]),
        ]),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFE53935)))),
        ],
        const SizedBox(height: 24),

        GestureDetector(
          onTap: _saving ? null : _submit,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, Color(0xFF00796B)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _teal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: _saving
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('Create Unit',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
          ),
        ),
      ]),
    );
  }

  InputDecoration _dropDecor() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true, fillColor: const Color(0xFFF7F7F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 2)),
  );
}

class _Field extends StatelessWidget {
  final String hint;
  final TextEditingController ctrl;
  final bool caps;
  static const _teal = Color(0xFF00695C);
  const _Field({required this.hint, required this.ctrl, this.caps = false});
  @override Widget build(BuildContext context) => TextField(
    controller: ctrl,
    textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.words,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true, fillColor: const Color(0xFFF7F7F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _teal, width: 2)),
    ),
  );
}