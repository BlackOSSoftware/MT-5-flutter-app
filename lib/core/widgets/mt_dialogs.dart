import 'package:flutter/material.dart';

import '../mt_colors.dart';

const _blue = Color(0xFF168BE1);

/// MT5 style dialog: white rounded card, bada title, gray message,
/// right me blue text buttons.
Future<T?> showMtDialog<T>(
  BuildContext context, {
  String? title,
  required Widget body,
  List<(String, T?)> actions = const [],
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: MtColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, title == null ? 18 : 26, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: MtColors.text,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Padding(padding: const EdgeInsets.only(right: 12), child: body),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final (label, value) in actions) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, value),
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

TextStyle mtDialogMessageStyle() =>
    TextStyle(fontSize: 15, height: 1.35, color: MtColors.icon);

/// "No / Yes" confirm (Delete account, Clear saved password...).
Future<bool> showMtConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String no = 'No',
  String yes = 'Yes',
}) async {
  final ok = await showMtDialog<bool>(
    context,
    title: title,
    body: Text(message, style: mtDialogMessageStyle()),
    actions: [(no, false), (yes, true)],
  );
  return ok == true;
}

/// Sirf OK wala info dialog (Properties).
Future<void> showMtInfo(
  BuildContext context, {
  required String title,
  required String message,
}) => showMtDialog<void>(
  context,
  title: title,
  body: Text(message, style: mtDialogMessageStyle()),
  actions: const [('OK', null)],
);

/// Bina title ke options list wala rounded dialog (Change password types).
Future<T?> showMtChoiceDialog<T>(
  BuildContext context,
  List<(String, T)> options,
) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: MtColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value) in options)
              InkWell(
                onTap: () => Navigator.pop(ctx, value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 16, color: MtColors.text),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Neeche se khulne wala MT5 action sheet: gray title, phir options.
Future<T?> showMtActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<(String, T)> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: MtColors.white,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    shape: const RoundedRectangleBorder(),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, color: Color(0xFF8A8A8A)),
            ),
          ),
          for (final (label, value) in options)
            InkWell(
              onTap: () => Navigator.pop(ctx, value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: MtColors.text),
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}
