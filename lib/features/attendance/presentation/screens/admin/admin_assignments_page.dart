// lib/features/assignments/presentation/admin_assignments_page.dart

import 'package:flutter/material.dart';
import '../../../../../../../core/services/api_service.dart';

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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([
      ApiService().get('/assignments'),
      ApiService().get('/units'),
      ApiService().get('/users', queryParams: {'role': 'lecturer', 'limit': '100'}),
      ApiService().get('/users', queryParams: {'role': 'student',  'limit': '200'}),
    ]);
    if (!mounted) return;
    final ok = results.every((r) => r.success);
    if (ok) {
      setState(() {
        _assignments = List<Map<String,dynamic>>.from(results[0].data?['assignments'] ?? []);
        _units       = List<Map<String,dynamic>>.from(results[1].data?['units']       ?? []);
        _lecturers   = List<Map<String,dynamic>>.from(results[2].data?['users']       ?? []);
        _students    = List<Map<String,dynamic>>.from(results[3].data?['users']       ?? []);
        _loading     = false;
      });
    } else {
      setState(() { _error = 'Failed to load data. Tap to retry.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _teal,
        title: const Text('Assignments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded),     text: 'All'),
            Tab(icon: Icon(Icons.add_box_rounded),      text: 'New'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAll,
          ),
        ],
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
                  ]),
                ))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _AssignmentList(
                      assignments: _assignments,
                      onRefresh: _loadAll,
                      allStudents: _students,
                      allLecturers: _lecturers,
                    ),
                    _CreateAssignmentForm(
                      units: _units,
                      lecturers: _lecturers,
                      students: _students,
                      onCreated: () { _loadAll(); _tabCtrl.animateTo(0); },
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
  final List<Map<String, dynamic>> allLecturers;
  final VoidCallback onRefresh;
  static const _teal = Color(0xFF00695C);

  const _AssignmentList({
    required this.assignments, required this.onRefresh,
    required this.allStudents, required this.allLecturers,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No assignments yet', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        const SizedBox(height: 8),
        Text('Use the New tab to create one', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
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
    final students  = (assignment['students'] as List?)?.cast<Map<String,dynamic>>() ?? [];
    final isActive  = assignment['isActive'] as bool? ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: _teal.withOpacity(0.3)) : null,
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            if (!isActive) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
              child: Text('INACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Lecturer
            Row(children: [
              Icon(Icons.person_pin_rounded, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(lecturer['fullName'] as String? ?? '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(assignment['room'] as String? ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 10),
            // Students
            Row(children: [
              Icon(Icons.people_rounded, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('${students.length} students enrolled',
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
            // Student avatars
            if (students.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: Stack(
                  children: List.generate(students.take(5).length, (i) {
                    final name = students[i]['fullName'] as String? ?? '?';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return Positioned(
                      left: i * 20.0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: _teal.withOpacity(0.15),
                        child: Text(initial, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _teal)),
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
  const _ManageStudentsSheet({required this.assignment, required this.allStudents, required this.onSaved});
  @override State<_ManageStudentsSheet> createState() => _ManageStudentsSheetState();
}

class _ManageStudentsSheetState extends State<_ManageStudentsSheet> {
  static const _teal = Color(0xFF00695C);
  late Set<String> _enrolled;
  bool _saving = false;
  String _search = '';
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = (widget.assignment['students'] as List?)
        ?.map((s) => (s as Map<String,dynamic>)['_id'] as String? ?? '')
        .toSet() ?? {};
    _enrolled = existing;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
        ?.map((s) => (s as Map<String,dynamic>)['_id'] as String? ?? '')
        .toSet() ?? {};

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
        const SnackBar(content: Text('Students updated successfully'), backgroundColor: _teal),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to update'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4, decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              const Text('Manage Students', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('${_enrolled.length} selected',
                    style: const TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
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
          // List
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
                value: isIn,
                activeColor: _teal,
                onChanged: (v) => setState(() {
                  if (v == true) _enrolled.add(id);
                  else _enrolled.remove(id);
                }),
                title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(reg, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                secondary: CircleAvatar(
                  radius: 18, backgroundColor: _teal.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _teal)),
                ),
                dense: true,
              );
            },
          )),
          // Save button
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
// CREATE ASSIGNMENT FORM
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
  String? _unitId, _lecturerId;
  final Set<String> _selectedStudents = {};
  final _roomCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  String _studentSearch = '';
  final _studentSearchCtrl = TextEditingController();

  @override
  void dispose() { _roomCtrl.dispose(); _studentSearchCtrl.dispose(); super.dispose(); }

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
      setState(() => _error = 'Please select a unit and a lecturer.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final result = await ApiService().post('/assignments', {
      'unitId':     _unitId,
      'lecturerId': _lecturerId,
      'studentIds': _selectedStudents.toList(),
      'room':       _roomCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment created!'), backgroundColor: _teal),
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Unit dropdown
        _FormLabel('Unit'),
        DropdownButtonFormField<String>(
          value: _unitId,
          hint: const Text('Select unit…', style: TextStyle(fontSize: 13)),
          decoration: _dropDecor(),
          items: widget.units.map((u) => DropdownMenuItem(
            value: u['_id'] as String?,
            child: Text('${u['code']} — ${u['name']}',
                style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (v) => setState(() => _unitId = v),
        ),
        const SizedBox(height: 16),

        // Lecturer dropdown
        _FormLabel('Lecturer'),
        DropdownButtonFormField<String>(
          value: _lecturerId,
          hint: const Text('Select lecturer…', style: TextStyle(fontSize: 13)),
          decoration: _dropDecor(),
          items: widget.lecturers.map((l) => DropdownMenuItem(
            value: l['_id'] as String?,
            child: Text(l['fullName'] as String? ?? '—', style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (v) => setState(() => _lecturerId = v),
        ),
        const SizedBox(height: 16),

        // Room
        _FormLabel('Room (optional)'),
        TextField(
          controller: _roomCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. LH-3',
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
        ),
        const SizedBox(height: 20),

        // Students
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
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _filteredStudents.isEmpty
              ? const Center(child: Text('No students found', style: TextStyle(color: Colors.grey)))
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
                      dense: true,
                      value: isIn,
                      activeColor: _teal,
                      onChanged: (v) => setState(() {
                        if (v == true) _selectedStudents.add(id);
                        else _selectedStudents.remove(id);
                      }),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(reg, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    );
                  },
                ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFE53935))),
          ),
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
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
  );
}