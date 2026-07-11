import 'package:flutter/material.dart';

Future<void> showReportDialog({
  required BuildContext context,
  required String title,
  required Future<void> Function(String reason, String details) onSubmit,
  String successMessage = 'تم إرسال البلاغ بنجاح',
}) async {
  final reasons = <String>[
    'محتوى غير مناسب',
    'معلومات مضللة',
    'احتيال أو سبام',
    'انتحال شخصية',
    'أخرى',
  ];
  String selectedReason = reasons.first;
  final detailsController = TextEditingController();
  bool isSubmitting = false;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title, textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedReason,
              items: reasons
                  .map((reason) => DropdownMenuItem<String>(
                        value: reason,
                        child: Text(reason),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => selectedReason = value);
              },
              decoration: const InputDecoration(
                labelText: 'السبب',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'تفاصيل إضافية',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setDialogState(() => isSubmitting = true);
                    try {
                      await onSubmit(
                        selectedReason,
                        detailsController.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(successMessage)),
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل إرسال البلاغ: $e')),
                      );
                    }
                  },
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('إرسال'),
          ),
        ],
      ),
    ),
  );
}
