// lib/features/attendance/presentation/screens/pages/timetable_import_page.dart
//
// Full import flow:
//   1. Optional filters  (unit codes / year / course)
//   2. Pick PDF or DOCX  via file_picker
//   3. POST to /api/timetable/import  → preview list
//   4. Lecturer reviews, toggles slots on/off, edits fields inline
//   5. POST to /api/timetable/import/confirm  → done

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../../core/services/api_service.dart';

// ─── Colours (same palette as main timetable page) ────────────────────────────
const _kIndigo    = Color(0xFF283593);
const _kIndigoMid = Color(0xFF3949AB);
const _kGreen     = Color(0xFF2E7D32);
const _kAmber     = Color(0xFFF57C00);
const _kRed       = Color(0xFFE53935);

const _kDays = [
  'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'
];

// ─── Data model for a preview slot ───────────────────────────────────────────

class _PreviewSlot {
  int    previewId;
  String unitCode, unitName, day, startTime, endTime, room, notes;
  String? assignmentId, unitId, warning;
  bool   matched, dayValid, selected;

  _PreviewSlot({
    required this.previewId,
    required this.unitCode,
    required this.unitName,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.notes,
    this.assignmentId,
    this.unitId,
    this.warning,
    required this.matched,
    required this.dayValid,
    this.selected = true,
  });

  factory _PreviewSlot.fromJson(Map<String, dynamic> j) => _PreviewSlot(
    previewId:    j['_previewId']   as int,
    unitCode:     j['unitCode']     as String? ?? '',
    unitName:     j['unitName']     as String? ?? '',
    day:          j['day']          as String? ?? '',
    startTime:    j['startTime']    as String? ?? '',
    endTime:      j['endTime']      as String? ?? '',
    room:         j['room']         as String? ?? '',
    notes:        j['notes']        as String? ?? '',
    assignmentId: j['assignmentId'] as String?,
    unitId:       j['unitId']       as String?,
    warning:      j['warning']      as String?,
    matched:      j['matched']      as bool? ?? false,
    dayValid:     j['dayValid']     as bool? ?? true,
    selected:     (j['matched'] as bool? ?? false) &&
                  (j['dayValid'] as bool? ?? true),
  );

  Map<String, dynamic> toConfirmJson() => {
    'assignmentId': assignmentId,
    'unitId':       unitId,
    'day':          day,
    'startTime':    startTime,
    'endTime':      endTime,
    'room':         room,
    'notes':        notes,
  };
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class TimetableImportPage extends StatefulWidget {
  const TimetableImportPage({super.key});
  @override State<TimetableImportPage> createState() => _TimetableImportState();
}

class _TimetableImportState extends State<TimetableImportPage> {
  // Step management
  int _step = 0;   // 0 = filters+pick  1 = preview  2 = done

  // Step 0
  final _unitCodesCtrl = TextEditingController();
  final _yearCtrl      = TextEditingController();
  final _courseCtrl    = TextEditingController();
  PlatformFile? _pickedFile;

  // Step 1
  List<_PreviewSlot> _preview = [];
  int _totalParsed = 0, _totalMatched = 0;

  // Loading / error
  bool    _busy  = false;
  String? _error;

  @override
  void dispose() {
    _unitCodesCtrl.dispose();
    _yearCtrl.dispose();
    _courseCtrl.dispose();
    super.dispose();
  }

  // ── File picker ──────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFile = result.files.first);
  }

  // ── Upload → preview ─────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (_pickedFile == null) {
      setState(() => _error = 'Please select a file first.');
      return;
    }
    setState(() { _busy = true; _error = null; });

    // Build query string
    final params = <String, String>{};
    if (_unitCodesCtrl.text.trim().isNotEmpty)
      params['unitCodes'] = _unitCodesCtrl.text.trim();
    if (_yearCtrl.text.trim().isNotEmpty)
      params['year'] = _yearCtrl.text.trim();
    if (_courseCtrl.text.trim().isNotEmpty)
      params['course'] = _courseCtrl.text.trim();

    final r = await ApiService().uploadFile(
      '/timetable/import',
      fileBytes:   _pickedFile!.bytes!,
      fileName:    _pickedFile!.name,
      queryParams: params,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!r.success) {
      setState(() => _error = r.error ?? 'Upload failed.');
      return;
    }

    final list = r.data?['preview'] as List<dynamic>? ?? [];
    _preview      = list.map((e) =>
        _PreviewSlot.fromJson(e as Map<String, dynamic>)).toList();
    _totalParsed  = r.data?['totalParsed']  as int? ?? list.length;
    _totalMatched = r.data?['totalMatched'] as int? ?? 0;
    setState(() => _step = 1);
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    final toSend = _preview
        .where((s) => s.selected && s.matched && s.dayValid)
        .map((s) => s.toConfirmJson())
        .toList();

    if (toSend.isEmpty) {
      setState(() => _error = 'No valid slots selected.');
      return;
    }

    setState(() { _busy = true; _error = null; });
    final r = await ApiService().post('/timetable/import/confirm', {'slots': toSend});
    if (!mounted) return;
    setState(() { _busy = false; if (r.success) _step = 2; else _error = r.error; });

    if (r.success) {
      final created = r.data?['created'] as int? ?? 0;
      final skipped = r.data?['skipped'] as int? ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ $created slot${created != 1 ? 's' : ''} created'
              '${skipped > 0 ? ', $skipped skipped' : ''}'),
          backgroundColor: _kGreen,
        ));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6F8),
    appBar: AppBar(
      backgroundColor: _kIndigo,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('Import Timetable',
          style: TextStyle(fontWeight: FontWeight.w800)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => _step > 0 && _step < 2
            ? setState(() { _step--; _error = null; })
            : Navigator.pop(context),
      ),
    ),
    body: Column(children: [
      _StepBar(current: _step),
      if (_error != null)
        _ErrorBanner(_error!, onDismiss: () => setState(() => _error = null)),
      Expanded(child: _busy
          ? const Center(child: CircularProgressIndicator(color: _kIndigo))
          : _step == 0 ? _buildStep0()
          : _step == 1 ? _buildStep1()
          : _buildStep2()),
    ]),
    bottomNavigationBar: _busy || _step == 2 ? null : _buildFooter(),
  );

  // ── Step 0: Filters + file pick ───────────────────────────────────────────

  Widget _buildStep0() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionCard(
        icon: Icons.filter_list_rounded,
        title: 'Filters (optional)',
        subtitle: 'Narrow down which classes to extract',
        child: Column(children: [
          _LabeledField(
            label: 'Unit Codes',
            hint: 'e.g. CS301, CS302, CS401',
            controller: _unitCodesCtrl,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _LabeledField(
                label: 'Year / Level',
                hint: 'e.g. 3',
                controller: _yearCtrl)),
            const SizedBox(width: 12),
            Expanded(child: _LabeledField(
                label: 'Course / Programme',
                hint: 'e.g. BSc CS',
                controller: _courseCtrl)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        icon: Icons.upload_file_rounded,
        title: 'Upload Timetable File',
        subtitle: 'PDF or Word document (.pdf / .doc / .docx)',
        child: _FilePicker(
            file: _pickedFile,
            onPick: _pickFile,
            onClear: () => setState(() => _pickedFile = null)),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Claude AI will scan the document, find class entries matching '
            'your filters, and generate a preview for you to review.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
          )),
        ]),
      ),
    ]),
  );

  // ── Step 1: Preview list ──────────────────────────────────────────────────

  Widget _buildStep1() {
    final selCount = _preview.where((s) => s.selected).length;
    return Column(children: [
      _PreviewSummaryBar(
          parsed: _totalParsed,
          matched: _totalMatched,
          selected: selCount,
          onSelectAll:   () => setState(() {
            for (final s in _preview) if (s.matched && s.dayValid) s.selected = true;
          }),
          onDeselectAll: () => setState(() {
            for (final s in _preview) s.selected = false;
          }),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _preview.length,
        itemBuilder: (_, i) => _PreviewCard(
          slot:     _preview[i],
          onToggle: (v) => setState(() => _preview[i].selected = v),
          onEdit:   (updated) => setState(() => _preview[i] = updated),
        ),
      )),
    ]);
  }

  // ── Step 2: Done ──────────────────────────────────────────────────────────

  Widget _buildStep2() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_rounded,
            color: _kGreen, size: 64),
      ),
      const SizedBox(height: 20),
      const Text('Import Complete!', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
      const SizedBox(height: 8),
      Text('Your timetable slots have been added.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _kIndigo,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        label: const Text('Back to Timetable',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  ));

  // ── Bottom footer ─────────────────────────────────────────────────────────

  Widget _buildFooter() => Container(
    decoration: BoxDecoration(color: Colors.white, boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(.07),
          blurRadius: 12, offset: const Offset(0, -3)),
    ]),
    padding: EdgeInsets.fromLTRB(
        20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
    child: _step == 0
        ? _GradBtn(
            label: 'Analyse File',
            icon:  Icons.auto_awesome_rounded,
            onTap: _pickedFile == null ? null : _upload,
          )
        : Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kIndigo),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: () => setState(() { _step = 0; _error = null; }),
              child: const Text('← Re-upload',
                  style: TextStyle(color: _kIndigo,
                      fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _GradBtn(
                label: 'Confirm Import',
                icon:  Icons.check_rounded,
                onTap: _confirm)),
          ]),
  );
}

// ─── Supporting widgets ────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) {
    const steps = ['Upload', 'Review', 'Done'];
    return Container(
      color: _kIndigo,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) return Expanded(child: Container(
            height: 1.5, color: Colors.white.withOpacity(.3)));
        final idx  = i ~/ 2;
        final done = idx < current;
        final now  = idx == current;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Colors.white
                  : now  ? Colors.white
                  : Colors.white.withOpacity(.2),
              border: Border.all(
                  color: Colors.white,
                  width: now ? 2 : 0),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.circle,
              size: done ? 16 : 8,
              color: done ? _kIndigo : now ? _kIndigo : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(steps[idx], style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: done || now ? Colors.white
                  : Colors.white.withOpacity(.55))),
        ]);
      })),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget child;
  const _SectionCard({required this.icon, required this.title,
      required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: _kIndigo.withOpacity(.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _kIndigo, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800)),
          Text(subtitle, style: TextStyle(
              fontSize: 11, color: Colors.grey.shade500)),
        ])),
      ]),
      const Divider(height: 20),
      child,
    ]),
  );
}

class _LabeledField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  const _LabeledField({required this.label, required this.hint,
      required this.controller});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 5),
    TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true, fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kIndigo, width: 2)),
      ),
    ),
  ]);
}

class _FilePicker extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback  onPick, onClear;
  const _FilePicker({required this.file, required this.onPick,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
              color: _kIndigo.withOpacity(.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _kIndigo.withOpacity(.3),
                  style: BorderStyle.solid,
                  width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(Icons.cloud_upload_rounded, size: 32,
                color: _kIndigo.withOpacity(.6)),
            const SizedBox(height: 8),
            Text('Tap to browse',
                style: TextStyle(fontSize: 13, color: _kIndigo.withOpacity(.8),
                    fontWeight: FontWeight.w600)),
            Text('PDF, DOC, DOCX',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ),
      );
    }
    final kb = ((file!.size) / 1024).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: _kGreen.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGreen.withOpacity(.3))),
      child: Row(children: [
        Icon(_fileIcon(file!.extension), color: _kGreen, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(file!.name, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          Text('$kb KB', style: TextStyle(
              fontSize: 11, color: Colors.grey.shade500)),
        ])),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: _kRed),
          onPressed: onClear,
        ),
      ]),
    );
  }

  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx': return Icons.description_rounded;
      default:     return Icons.insert_drive_file_rounded;
    }
  }
}

class _PreviewSummaryBar extends StatelessWidget {
  final int parsed, matched, selected;
  final VoidCallback onSelectAll, onDeselectAll;
  const _PreviewSummaryBar({required this.parsed, required this.matched,
      required this.selected, required this.onSelectAll,
      required this.onDeselectAll});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(.04),
          blurRadius: 6, offset: const Offset(0, 3)),
    ]),
    child: Column(children: [
      Row(children: [
        _StatPill('$parsed parsed', _kIndigo),
        const SizedBox(width: 8),
        _StatPill('$matched matched', _kGreen),
        const SizedBox(width: 8),
        _StatPill('$selected selected', _kAmber),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Text('Select:',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onSelectAll,
          child: const Text('All valid',
              style: TextStyle(fontSize: 11, color: _kIndigo,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onDeselectAll,
          child: const Text('None',
              style: TextStyle(fontSize: 11, color: _kRed,
                  fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        Text('Tap a card to edit',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
    ]),
  );
}

class _StatPill extends StatelessWidget {
  final String label; final Color color;
  const _StatPill(this.label, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

// ─── Preview card ──────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final _PreviewSlot slot;
  final void Function(bool)           onToggle;
  final void Function(_PreviewSlot)   onEdit;
  const _PreviewCard({required this.slot, required this.onToggle,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final canSelect = slot.matched && slot.dayValid;
    final borderCol = !canSelect           ? Colors.red.shade200
        : slot.selected ? _kGreen.withOpacity(.4)
        : Colors.grey.shade200;

    return GestureDetector(
      onTap: canSelect ? () => _openEdit(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 10, offset: const Offset(0, 3))]),
        child: Row(children: [
          // Left toggle
          GestureDetector(
            onTap: canSelect ? () => onToggle(!slot.selected) : null,
            child: Container(
              width: 48, height: 80,
              decoration: BoxDecoration(
                  color: !canSelect          ? const Color(0xFFFFEBEE)
                      : slot.selected ? _kGreen.withOpacity(.1)
                      : const Color(0xFFF7F7F7),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12))),
              child: Icon(
                !canSelect          ? Icons.warning_amber_rounded
                    : slot.selected ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: !canSelect ? _kRed
                    : slot.selected ? _kGreen
                    : Colors.grey.shade400,
                size: 22,
              ),
            ),
          ),
          // Body
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(slot.unitCode, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Expanded(child: Text(slot.unitName,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                _Chip(slot.day, Icons.calendar_today_rounded),
                const SizedBox(width: 6),
                _Chip('${slot.startTime} – ${slot.endTime}',
                    Icons.access_time_rounded),
                if (slot.room.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Chip(slot.room, Icons.location_on_outlined),
                ],
              ]),
              if (slot.warning != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 12, color: _kRed),
                  const SizedBox(width: 4),
                  Expanded(child: Text(slot.warning!,
                      style: const TextStyle(
                          fontSize: 10, color: _kRed))),
                ]),
              ],
            ]),
          )),
          // Edit arrow
          if (canSelect)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.edit_rounded,
                  size: 14, color: Colors.grey.shade400),
            ),
        ]),
      ),
    );
  }

  void _openEdit(BuildContext ctx) => showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditPreviewSheet(
        slot: slot, onSave: onEdit),
  );
}

class _Chip extends StatelessWidget {
  final String text; final IconData icon;
  const _Chip(this.text, this.icon);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: _kIndigo.withOpacity(.06),
        borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: _kIndigo),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(
          fontSize: 10, color: _kIndigo, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── Inline edit sheet ────────────────────────────────────────────────────────

class _EditPreviewSheet extends StatefulWidget {
  final _PreviewSlot slot;
  final void Function(_PreviewSlot) onSave;
  const _EditPreviewSheet({required this.slot, required this.onSave});
  @override State<_EditPreviewSheet> createState() =>
      _EditPreviewSheetState();
}

class _EditPreviewSheetState extends State<_EditPreviewSheet> {
  late String _day, _start, _end;
  late TextEditingController _roomCtrl, _notesCtrl;

  @override
  void initState() {
    super.initState();
    _day      = widget.slot.day;
    _start    = widget.slot.startTime;
    _end      = widget.slot.endTime;
    _roomCtrl  = TextEditingController(text: widget.slot.room);
    _notesCtrl = TextEditingController(text: widget.slot.notes);
  }

  @override void dispose() {
    _roomCtrl.dispose(); _notesCtrl.dispose(); super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final parts = (isStart ? _start : _end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour:   int.parse(parts[0]),
          minute: int.parse(parts[1])),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _kIndigo)),
          child: child!),
    );
    if (picked == null) return;
    final f = '${picked.hour.toString().padLeft(2,'0')}'
              ':${picked.minute.toString().padLeft(2,'0')}';
    setState(() => isStart ? _start = f : _end = f);
  }

  void _save() {
    final updated = _PreviewSlot(
      previewId:    widget.slot.previewId,
      unitCode:     widget.slot.unitCode,
      unitName:     widget.slot.unitName,
      day:          _day,
      startTime:    _start,
      endTime:      _end,
      room:         _roomCtrl.text.trim(),
      notes:        _notesCtrl.text.trim(),
      assignmentId: widget.slot.assignmentId,
      unitId:       widget.slot.unitId,
      warning:      widget.slot.warning,
      matched:      widget.slot.matched,
      dayValid:     _kDays.contains(_day),
      selected:     widget.slot.selected,
    );
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .75, maxChildSize: .95, minChildSize: .4,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
          child: Row(children: [
            Expanded(child: Text(
                'Edit  ${widget.slot.unitCode}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800))),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            const SizedBox(width: 6),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kIndigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _save,
                child: const Text('Save',
                    style: TextStyle(color: Colors.white))),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _FLabel('Day'),
            DropdownButtonFormField<String>(
              value:    _kDays.contains(_day) ? _day : null,
              hint:     const Text('Select day'),
              decoration: _inputDec(),
              items: _kDays.map((d) =>
                  DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _day = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _FLabel('Start'),
                _TimeBtn(_start, () => _pickTime(true)),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _FLabel('End'),
                _TimeBtn(_end, () => _pickTime(false)),
              ])),
            ]),
            const SizedBox(height: 12),
            const _FLabel('Room (optional)'),
            TextField(controller: _roomCtrl,
                decoration: _inputDec(hint: 'e.g. LH-3')),
            const SizedBox(height: 12),
            const _FLabel('Notes (optional)'),
            TextField(controller: _notesCtrl, maxLines: 2,
                decoration: _inputDec(hint: 'Any extra info…')),
          ]),
        )),
      ]),
    ),
  );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true, fillColor: const Color(0xFFF7F7F7),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kIndigo, width: 2)),
  );
}

// ─── Tiny helpers ─────────────────────────────────────────────────────────────

class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

class _TimeBtn extends StatelessWidget {
  final String time; final VoidCallback onTap;
  const _TimeBtn(this.time, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.access_time_rounded, size: 15, color: _kIndigo),
        const SizedBox(width: 6),
        Text(time, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: _kIndigo)),
      ]),
    ),
  );
}

class _GradBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback? onTap;
  const _GradBtn({required this.label, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        gradient: onTap != null
            ? const LinearGradient(colors: [_kIndigo, _kIndigoMid])
            : null,
        color: onTap == null ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onTap != null ? [BoxShadow(
            color: _kIndigo.withOpacity(.25),
            blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String msg; final VoidCallback onDismiss;
  const _ErrorBanner(this.msg, {required this.onDismiss});
  @override Widget build(BuildContext context) => Container(
    color: const Color(0xFFFFEBEE),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: _kRed, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
          style: const TextStyle(fontSize: 12, color: _kRed))),
      IconButton(
        icon: const Icon(Icons.close_rounded, size: 16, color: _kRed),
        onPressed: onDismiss,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]),
  );
}