import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Individual boxed OTP digit entry (one square field per digit), with
/// auto-advance to the next box on input and auto-back on backspace.
class OtpBoxInput extends StatefulWidget {
  const OtpBoxInput({
    super.key,
    this.length = 4,
    required this.onChanged,
    this.initialValue = '',
    this.autoFocus = false,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final bool autoFocus;

  @override
  State<OtpBoxInput> createState() => OtpBoxInputState();
}

class OtpBoxInputState extends State<OtpBoxInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (i) => TextEditingController(
        text: i < widget.initialValue.length ? widget.initialValue[i] : '',
      ),
    );
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Fills every box with [value] (used to auto-fill the demo code since
  /// there's no real SMS/email gateway behind this OTP flow).
  void fill(String value) {
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = i < value.length ? value[i] : '';
    }
    setState(() {});
    widget.onChanged(value);
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {});
    widget.onChanged('');
    if (_focusNodes.isNotEmpty) _focusNodes.first.requestFocus();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // Handles pasting a full code into one box.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      fill(digits.substring(0, digits.length.clamp(0, widget.length)));
      return;
    }
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 56,
          height: 56,
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  _controllers[i].text.isEmpty &&
                  i > 0) {
                _focusNodes[i - 1].requestFocus();
                _controllers[i - 1].clear();
                widget.onChanged(_value);
              }
            },
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              autofocus: widget.autoFocus && i == 0,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: widget.length, // allow paste-into-one-box to be caught by _onChanged
              style: AppText.display(size: 20, color: AppColors.blue900),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.blue600, width: 2),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => _onChanged(i, v),
            ),
          ),
        );
      }),
    );
  }
}
