import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Otwiera boczny panel STAFF w oknie overlay (tylko Android).
Future<void> openStaffSidebarOverlay() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final granted = await FlutterOverlayWindow.isPermissionGranted();
  if (!granted) {
    await FlutterOverlayWindow.requestPermission();
    final ok = await FlutterOverlayWindow.isPermissionGranted();
    if (!ok) return;
  }
  await FlutterOverlayWindow.showOverlay(
    height: WindowSize.fullCover,
    width: 320,
    alignment: OverlayAlignment.centerRight,
    enableDrag: true,
    overlayTitle: 'SELLEKTYWNI — panel',
    overlayContent: 'Panel pracownika',
  );
}

Future<void> closeStaffSidebarOverlay() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final active = await FlutterOverlayWindow.isActive();
  if (active) await FlutterOverlayWindow.closeOverlay();
}
