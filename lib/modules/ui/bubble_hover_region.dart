import 'package:flutter/material.dart';

// Shared by Flutter hover tracking and the native click-through rectangles.
// Reserve the station pill space so showing it cannot move the hover boundary.
Rect bubbleInteractionRect({
  required bool isRight,
  required bool isBottom,
  required bool isDocked,
}) => Rect.fromLTWH(
  isRight ? 350 : (isDocked ? 0 : 16),
  isBottom ? 6 : 228,
  isDocked ? 90 : 74,
  98,
);

class BubbleHoverRegion extends StatelessWidget {
  const BubbleHoverRegion({super.key, required this.onChanged});

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MouseRegion(
    opaque: false,
    hitTestBehavior: HitTestBehavior.translucent,
    onEnter: (_) => onChanged(true),
    onExit: (_) => onChanged(false),
    child: const SizedBox.expand(),
  );
}
