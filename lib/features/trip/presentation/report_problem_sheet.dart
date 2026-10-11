import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../application/trip_providers.dart';
import '../domain/trip_models.dart';

/// "Report a problem" / "Lost an item". MOCK: saved on this device only (no backend endpoint).
Future<bool?> showReportProblemSheet(
  BuildContext context, {
  required int rideId,
  String initialCategory = 'Other',
}) {
  return showNordicBottomSheet<bool>(
    context: context,
    title: 'Report a problem',
    builder: (_) =>
        ReportProblemForm(rideId: rideId, initialCategory: initialCategory),
  );
}

class ReportProblemForm extends ConsumerStatefulWidget {
  const ReportProblemForm({
    super.key,
    required this.rideId,
    this.initialCategory = 'Other',
  });

  final int rideId;
  final String initialCategory;

  @override
  ConsumerState<ReportProblemForm> createState() => _ReportProblemFormState();
}

class _ReportProblemFormState extends ConsumerState<ReportProblemForm> {
  late String _category = widget.initialCategory;
  final _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _details.text.trim().length < 3) return;
    setState(() => _busy = true);
    await ref
        .read(problemReportRepositoryProvider)
        .submit(
          ProblemReport(
            rideId: widget.rideId,
            category: _category,
            details: _details.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kProblemCategories)
                NordicChip(
                  key: Key('cat_$c'),
                  label: c,
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          NordicTextField(
            key: const Key('report_details'),
            label: 'What happened?',
            controller: _details,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          NordicButton(
            key: const Key('report_submit'),
            label: 'Submit report',
            isLoading: _busy,
            onPressed: _details.text.trim().length < 3 ? null : _submit,
          ),
        ],
      ),
    );
  }
}
