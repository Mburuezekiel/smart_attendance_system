// lib/features/attendance/presentation/screens/pages/lecturer_timetable_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../../../core/services/api_service.dart';

class LecturerTimetablePage extends StatefulWidget {
  const LecturerTimetablePage({super.key});
  @override
  State<LecturerTimetablePage> createState() => _LecturerTimetablePageState();
}

class _LecturerTimetablePageState extends State<LecturerTimetablePage>
    with SingleTickerProviderStateMixin {
  static const _indigo    = Color(0xFF283593);
  static const _indigoMid = Color(0xFF3949AB);

  List<Map<String, dynamic>> _timetable   = [];
  List<Map<String, dynamic>> _assignments = [];
  bool    _loading = true;
  String? _error;
  int     _selectedDayIndex = _todayIndex();
  bool    _showForm = false;

  late AnimationController _fadeCtrl;

  static const _days     = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  static const _dayShort = ['Mon','Tue','Wed','Thu','Fri','Sat'];

  static int _todayIndex() {
    final w = DateTime.now().weekday;
    return (w <= 5) ? w - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _loadAll();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    final r0 = await ApiService().get('/timetable');
    final r1 = await ApiService().get('/assignments');
    if (!mounted) return;
    if (r0.success && r1.success) {
      setState(() {
        _timetable   = List<Map<String,dynamic>>.from(r0.data?['timetable']   ?? []);
        _assignments = List<Map<String,dynamic>>.from(r1.data?['assignments'] ?? []);
        _loading     = false;
      });
    } else {
      setState(() {
        _error   = r0.error ?? r1.error ?? 'Failed to load data.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _dayEntries {
    final day = _days[_selectedDayIndex];
    return _timetable.where((e) => e['day'] == day).toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
  }

  bool _isNow(Map<String, dynamic> e) {
    final now   = TimeOfDay.now();
    final start = _parseTime(e['startTime'] as String? ?? '00:00');
    final end   = _parseTime(e['endTime']   as String? ?? '00:00');
    final nowM  = now.hour * 60 + now.minute;
    return nowM >= start && nowM < end;
  }

  int _parseTime(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  void _openCreateForm() => setState(() => _showForm = true);
  void _closeForm()      => setState(() => _showForm = false);

  void _onEntryDeleted(String id) {
    setState(() => _timetable.removeWhere((e) => e['_id'] == id));
  }

  void _onEntryCreated(Map<String, dynamic> entry) {
    setState(() {
      _timetable.add(entry);
      _showForm = false;
    });
  }

  void _onEntryUpdated(Map<String, dynamic> updated) {
    setState(() {
      final idx = _timetable.indexWhere((e) => e['_id'] == updated['_id']);
      if (idx != -1) _timetable[idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: !_showForm && !_loading
          ? FloatingActionButton.extended(
              backgroundColor: _indigo,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Slot',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: _openCreateForm,
            )
          : null,
      body: Column(children: [
        _buildHeader(),
        if (!_showForm) _buildDaySelector(),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _indigo))
            : _error != null
                ? _buildError()
                : _showForm
                    ? _CreateSlotForm(
                        assignments: _assignments,
                        selectedDay: _days[_selectedDayIndex],
                        onCreated: _onEntryCreated,
                        onCancel: _closeForm,
                      )
                    : FadeTransition(
                        opacity: CurvedAnimation(
                            parent: _fadeCtrl, curve: Curves.easeOut),
                        child: _buildDayView(),
                      )),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final total = _timetable.length;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _indigoMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.calendar_month_rounded,
                    color: Colors.white.withOpacity(0.8), size: 18),
                const SizedBox(width: 8),
                const Text('My Timetable',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
              const SizedBox(height: 4),
              Text('$total slot${total != 1 ? 's' : ''} scheduled',
                  style: TextStyle(fontSize: 12,
                      color: Colors.white.withOpacity(0.75))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('${_dayEntries.length}',
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                Text('today', style: TextStyle(fontSize: 10,
                    color: Colors.white.withOpacity(0.8))),
              ]),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadAll,
            ),
          ]),
        ),
      ),
    );
  }

  // ── Day selector ─────────────────────────────────────────────────────────────
  Widget _buildDaySelector() {
    final today = _todayIndex();
    return Container(
      color: _indigo,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: List.generate(_days.length, (i) {
        final isSelected = _selectedDayIndex == i;
        final isToday    = i == today;
        final count = _timetable.where((e) => e['day'] == _days[i]).length;
        return Expanded(child: GestureDetector(
          onTap: () {
            setState(() => _selectedDayIndex = i);
            _fadeCtrl..reset()..forward();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < _days.length - 1 ? 6 : 0),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_dayShort[i], style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isSelected ? _indigo : Colors.white)),
              if (isToday) ...[
                const SizedBox(height: 2),
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: isSelected ? _indigo : Colors.white)),
              ],
              if (count > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _indigo.withOpacity(0.15)
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$count', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: isSelected ? _indigo : Colors.white)),
                ),
              ],
            ]),
          ),
        ));
      })),
    );
  }

  // ── Day view ─────────────────────────────────────────────────────────────────
  Widget _buildDayView() {
    final entries = _dayEntries;
    if (entries.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_note_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No classes on ${_days[_selectedDayIndex]}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: Colors.grey.shade400)),
        const SizedBox(height: 6),
        Text('Tap + New Slot to add one',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ]));
    }
    return RefreshIndicator(
      color: _indigo,
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: entries.length,
        itemBuilder: (_, i) => _LecturerClassCard(
          entry:       entries[i],
          isNow:       _isNow(entries[i]),
          onDeleted:   () => _onEntryDeleted(entries[i]['_id'] as String),
          onUpdated:   _onEntryUpdated,
          assignments: _assignments,
        ),
      ),
    );
  }

  Widget _buildError() => GestureDetector(
    onTap: _loadAll,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(_error!, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const SizedBox(height: 8),
      Text('Tap to retry',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ])),
  );

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, -4))]),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: GNav(
        backgroundColor: Colors.white,
        color: Colors.grey.shade500,
        activeColor: Colors.white,
        tabBackgroundColor: _indigo,
        gap: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        selectedIndex: 2,
        onTabChange: (i) {
          if (i == 0) context.go('/lecturer-home');
          if (i == 1) context.go('/history');
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Lecturer class card with edit / delete
// ─────────────────────────────────────────────────────────────────────────────

class _LecturerClassCard extends StatelessWidget {
  final Map<String, dynamic>   entry;
  final bool                   isNow;
  final VoidCallback           onDeleted;
  final void Function(Map<String, dynamic>) onUpdated;
  final List<Map<String, dynamic>> assignments;
  static const _indigo = Color(0xFF283593);

  const _LecturerClassCard({
    required this.entry,
    required this.isNow,
    required this.onDeleted,
    required this.onUpdated,
    required this.assignments,
  });

  Color _unitColor() {
    final colors = [
      const Color(0xFF283593), const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A), const Color(0xFFF57C00),
      const Color(0xFFE53935), const Color(0xFF00695C),
    ];
    final code = (entry['unit']?['code'] as String? ?? '');
    return colors[code.hashCode.abs() % colors.length];
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete slot?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will remove the timetable entry for students too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFE53935)))),
        ],
      ),
    );
    if (confirm != true) return;

    final r = await ApiService().delete('/timetable/${entry['_id']}');
    if (context.mounted) {
      if (r.success) {
        onDeleted();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Slot deleted'), backgroundColor: _indigo));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r.error ?? 'Failed to delete'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _edit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSlotSheet(
        entry: entry,
        assignments: assignments,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit  = entry['unit']  as Map<String, dynamic>? ?? {};
    final color = _unitColor();
    final start = entry['startTime'] as String? ?? '';
    final end   = entry['endTime']   as String? ?? '';
    final room  = entry['room']      as String? ?? '';
    final notes = entry['notes']     as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isNow
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(
            color: isNow
                ? color.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 5, decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18)))),
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(start, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
              Container(margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 1, height: 12, color: Colors.grey.shade300),
              Text(end, style: TextStyle(fontSize: 11,
                  color: Colors.grey.shade500)),
            ]),
          ),
          Container(width: 1, color: Colors.grey.shade100),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  unit['name'] as String? ?? '—',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B)),
                )),
                if (isNow) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(8)),
                  child: const Text('NOW', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 1)),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(unit['code'] as String? ?? '—',
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w800, color: color)),
              ),
              const SizedBox(height: 8),
              if (room.isNotEmpty) Row(children: [
                Icon(Icons.location_on_outlined, size: 13,
                    color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(room, style: TextStyle(fontSize: 12,
                    color: Colors.grey.shade600)),
              ]),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 12, color: Color(0xFFF57C00)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(notes,
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF795548)))),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              // Action row
              Row(children: [
                _ActionChip(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: _indigo,
                  onTap: () => _edit(context),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFE53935),
                  onTap: () => _delete(context),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Create slot form
// ─────────────────────────────────────────────────────────────────────────────

class _CreateSlotForm extends StatefulWidget {
  final List<Map<String, dynamic>> assignments;
  final String selectedDay;
  final void Function(Map<String, dynamic>) onCreated;
  final VoidCallback onCancel;
  const _CreateSlotForm({
    required this.assignments, required this.selectedDay,
    required this.onCreated, required this.onCancel,
  });
  @override State<_CreateSlotForm> createState() => _CreateSlotFormState();
}

class _CreateSlotFormState extends State<_CreateSlotForm> {
  static const _indigo = Color(0xFF283593);
  static const _days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

  String? _assignmentId;
  String  _day       = 'Monday';
  String  _startTime = '08:00';
  String  _endTime   = '10:00';
  final   _roomCtrl  = TextEditingController();
  final   _notesCtrl = TextEditingController();
  bool    _saving    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _day = widget.selectedDay;
  }

  @override
  void dispose() {
    _roomCtrl.dispose(); _notesCtrl.dispose(); super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = _parseTimeOfDay(isStart ? _startTime : _endTime);
    final picked  = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _indigo)),
        child: child!,
      ),
    );
    if (picked == null) return;
    final formatted = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
    setState(() { if (isStart) _startTime = formatted; else _endTime = formatted; });
  }

  TimeOfDay _parseTimeOfDay(String t) {
    final p = t.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Future<void> _submit() async {
    if (_assignmentId == null) {
      setState(() => _error = 'Please select a unit.'); return;
    }
    setState(() { _saving = true; _error = null; });

    final r = await ApiService().post('/timetable', {
      'assignmentId': _assignmentId,
      'day':          _day,
      'startTime':    _startTime,
      'endTime':      _endTime,
      'room':         _roomCtrl.text.trim(),
      'notes':        _notesCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (r.success) {
      widget.onCreated(r.data?['entry'] as Map<String,dynamic>? ?? {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Timetable slot created!'),
          backgroundColor: _indigo));
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _indigo.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _indigo.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.add_box_rounded, color: _indigo, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('Create Timetable Slot',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: _indigo))),
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.grey),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Unit picker
        const _Label('Unit'),
        DropdownButtonFormField<String>(
          value: _assignmentId,
          hint: const Text('Select unit…', style: TextStyle(fontSize: 13)),
          decoration: _dropDecor(),
          isExpanded: true,
          items: widget.assignments.map((a) {
            final unit = a['unit'] as Map<String,dynamic>? ?? {};
            return DropdownMenuItem(
              value: a['_id'] as String?,
              child: Text('${unit['code']} — ${unit['name']}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) => setState(() => _assignmentId = v),
        ),
        const SizedBox(height: 16),

        // Day picker
        const _Label('Day'),
        DropdownButtonFormField<String>(
          value: _day,
          decoration: _dropDecor(),
          items: _days.map((d) => DropdownMenuItem(
              value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _day = v!),
        ),
        const SizedBox(height: 16),

        // Time row
        Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Start Time'),
            _TimePicker(time: _startTime, onTap: () => _pickTime(true)),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('End Time'),
            _TimePicker(time: _endTime, onTap: () => _pickTime(false)),
          ])),
        ]),
        const SizedBox(height: 16),

        // Room
        const _Label('Room (optional)'),
        TextField(
          controller: _roomCtrl,
          decoration: _inputDec('e.g. LH-3 or Lab C-2'),
        ),
        const SizedBox(height: 16),

        // Notes
        const _Label('Notes (optional)'),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: _inputDec('Any notes visible to students…'),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_error!,
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFFE53935))),
          ),
        ],
        const SizedBox(height: 24),

        GestureDetector(
          onTap: _saving ? null : _submit,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_indigo, Color(0xFF3949AB)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: _indigo.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: _saving
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : const Text('Create Slot',
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700))),
          ),
        ),
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
        borderSide: const BorderSide(color: _indigo, width: 2)),
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
        borderSide: const BorderSide(color: _indigo, width: 2)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit slot bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditSlotSheet extends StatefulWidget {
  final Map<String, dynamic> entry;
  final List<Map<String, dynamic>> assignments;
  final void Function(Map<String, dynamic>) onUpdated;
  const _EditSlotSheet({
    required this.entry, required this.assignments, required this.onUpdated});
  @override State<_EditSlotSheet> createState() => _EditSlotSheetState();
}

class _EditSlotSheetState extends State<_EditSlotSheet> {
  static const _indigo = Color(0xFF283593);
  static const _days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

  late String _day;
  late String _startTime;
  late String _endTime;
  late TextEditingController _roomCtrl;
  late TextEditingController _notesCtrl;
  bool    _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _day       = widget.entry['day']       as String? ?? 'Monday';
    _startTime = widget.entry['startTime'] as String? ?? '08:00';
    _endTime   = widget.entry['endTime']   as String? ?? '10:00';
    _roomCtrl  = TextEditingController(text: widget.entry['room']  as String? ?? '');
    _notesCtrl = TextEditingController(text: widget.entry['notes'] as String? ?? '');
  }

  @override
  void dispose() { _roomCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime(bool isStart) async {
    final p = (isStart ? _startTime : _endTime).split(':');
    final initial = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    final picked  = await showTimePicker(
      context: context, initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _indigo)),
        child: child!,
      ),
    );
    if (picked == null) return;
    final f = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
    setState(() { if (isStart) _startTime = f; else _endTime = f; });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final r = await ApiService().patch('/timetable/${widget.entry['_id']}', {
      'day':       _day,
      'startTime': _startTime,
      'endTime':   _endTime,
      'room':      _roomCtrl.text.trim(),
      'notes':     _notesCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.success) {
      widget.onUpdated(r.data?['entry'] as Map<String,dynamic>? ?? {});
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Slot updated!'), backgroundColor: _indigo));
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.80, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              const Text('Edit Slot',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _Label('Day'),
              DropdownButtonFormField<String>(
                value: _day,
                decoration: _dropDecor(),
                items: _days.map((d) => DropdownMenuItem(
                    value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _day = v!),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _Label('Start'),
                  _TimePicker(time: _startTime, onTap: () => _pickTime(true)),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _Label('End'),
                  _TimePicker(time: _endTime, onTap: () => _pickTime(false)),
                ])),
              ]),
              const SizedBox(height: 16),
              const _Label('Room'),
              TextField(controller: _roomCtrl,
                  decoration: _inputDec('e.g. LH-3')),
              const SizedBox(height: 16),
              const _Label('Notes'),
              TextField(controller: _notesCtrl, maxLines: 2,
                  decoration: _inputDec('Any notes…')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: const TextStyle(
                      fontSize: 12, color: Color(0xFFE53935))),
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_indigo, Color(0xFF3949AB)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: _saving
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : const Text('Save Changes',
                          style: TextStyle(color: Colors.white, fontSize: 15,
                              fontWeight: FontWeight.w700))),
                ),
              ),
            ]),
          )),
        ]),
      ),
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
        borderSide: const BorderSide(color: _indigo, width: 2)),
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
        borderSide: const BorderSide(color: _indigo, width: 2)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: Color(0xFF1B1B1B))),
  );
}

class _TimePicker extends StatelessWidget {
  final String time;
  final VoidCallback onTap;
  static const _indigo = Color(0xFF283593);
  const _TimePicker({required this.time, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.access_time_rounded, size: 18, color: _indigo),
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.w800, color: _indigo)),
      ]),
    ),
  );
}