import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Shows a modal bottom sheet with the Nordic chrome (drag handle, optional title).
Future<T?> showNordicBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(NordicRadii.card),
      ),
    ),
    builder: (ctx) => NordicSheetScaffold(title: title, child: builder(ctx)),
  );
}

/// Chrome used inside bottom sheets; also usable inline for persistent map sheets.
class NordicSheetScaffold extends StatelessWidget {
  const NordicSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NordicSpacing.md,
            NordicSpacing.sm,
            NordicSpacing.md,
            NordicSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: NordicSpacing.md),
                    decoration: BoxDecoration(
                      color: NordicColors.border,
                      borderRadius: NordicRadii.pillRadius,
                    ),
                  ),
                ),
              if (title != null) ...[
                Text(title!, style: NordicText.headlineSm),
                const SizedBox(height: NordicSpacing.md),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
