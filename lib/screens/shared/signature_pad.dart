import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../theme/app_theme.dart';
import '../../utils/localization.dart';

class SignaturePadModal extends StatefulWidget {
  final String title;
  final Function(String dataUrl) onSave;
  final VoidCallback onCancel;
  final bool isDark;

  const SignaturePadModal({
    super.key,
    required this.title,
    required this.onSave,
    required this.onCancel,
    required this.isDark,
  });

  @override
  State<SignaturePadModal> createState() => _SignaturePadModalState();
}

class _SignaturePadModalState extends State<SignaturePadModal> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 4,
      penColor: Colors.white,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please draw a signature first!')),
      );
      return;
    }

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes != null) {
        final base64Str = base64Encode(bytes);
        final dataUrl = "data:image/png;base64,$base64Str";
        widget.onSave(dataUrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Error saving signature')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(25),
        decoration: AppTheme.glassDecoration(
          context: context,
          isDark: widget.isDark,
          borderRadius: 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            
            // Signature drawing area
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _controller.clear(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.clear, size: 18),
                        const SizedBox(width: 8),
                        Text(Localization.get('done') == 'Done' ? 'Clear' : 'মুছুন'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 18),
                        const SizedBox(width: 8),
                        Text(Localization.get('done') == 'Done' ? 'Save' : 'সংরক্ষণ'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: widget.onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white60,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white12),
                ),
              ),
              child: Text(Localization.get('cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
