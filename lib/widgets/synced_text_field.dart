import 'package:flutter/material.dart';

/// A [TextField]/[TextFormField]-like widget whose text is driven by
/// external app state (so it survives `notifyListeners()` rebuilds
/// triggered by *other* fields) while still typing naturally — the
/// local [TextEditingController] is only overwritten from [value] when
/// the field does not have focus (e.g. when "Generate AI Summary"
/// overwrites the SOAP text from outside).
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.minLines,
    this.maxLines = 1,
    this.style,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int? minLines;
  final int maxLines;
  final TextStyle? style;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: widget.style,
      decoration: InputDecoration(hintText: widget.hintText),
      onChanged: widget.onChanged,
    );
  }
}
