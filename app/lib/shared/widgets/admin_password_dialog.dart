import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// Asks for the admin password before a sensitive action (e.g. zero treasury).
Future<String?> showAdminPasswordDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = context.l10n;
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.adminPasswordRequired,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.fieldRequired;
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, controller.text);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, controller.text);
            }
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(title),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}
