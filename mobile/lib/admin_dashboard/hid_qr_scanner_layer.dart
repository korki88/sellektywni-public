import 'package:flutter/material.dart';

/// Niewidoczne pole tekstowe nasłuchujące skanera HID (klawiatura).
/// Umieść jako ostatni element w [Stack], aby działało w WWW, w aplikacji
/// i w oknie overlay — skaner musi „widzieć” fokus.
class HidQrScannerLayer extends StatelessWidget {
  const HidQrScannerLayer({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.onSubmitted,
  });

  final FocusNode focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0.01,
        child: TextField(
          focusNode: focusNode,
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          enableInteractiveSelection: false,
          decoration: const InputDecoration(border: InputBorder.none),
          onSubmitted: (value) {
            controller.clear();
            final t = value.trim();
            if (t.isNotEmpty) onSubmitted(t);
          },
        ),
      ),
    );
  }
}
