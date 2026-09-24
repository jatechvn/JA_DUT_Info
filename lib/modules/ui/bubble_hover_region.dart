import 'dart:math' as math;
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

/// Geometry data for positioning a label or badge along a wire curve.
class WireLabelGeometry {
  final Offset position;
  final double
  angle; // in radians, normalized between -pi/2 and pi/2 for readability
  final Offset normal;

  const WireLabelGeometry({
    required this.position,
    required this.angle,
    required this.normal,
  });
}

/// Computes the midpoint and tangent angle of the cubic Bézier lead-in wire
/// connecting the docked bubble to the first/target card terminal.
WireLabelGeometry computeLeadInWireStationGeometry({
  required Offset bubbleAnchor,
  required double wireX,
  required double cardY,
  required bool isBottom,
  double t = 0.48,
  double normalOffset = 15.0,
}) {
  final p0 = bubbleAnchor;
  final p1 = Offset(
    bubbleAnchor.dx + (wireX - bubbleAnchor.dx) * 0.45,
    bubbleAnchor.dy,
  );
  final p2 = Offset(wireX, isBottom ? cardY - 15.0 : cardY + 15.0);
  final p3 = Offset(wireX, cardY);

  final double u = 1.0 - t;
  final double tt = t * t;
  final double uu = u * u;
  final double uuu = uu * u;
  final double ttt = tt * t;

  final double bx =
      uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx;
  final double by =
      uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy;

  final double dx =
      3 * uu * (p1.dx - p0.dx) +
      6 * u * t * (p2.dx - p1.dx) +
      3 * tt * (p3.dx - p2.dx);
  final double dy =
      3 * uu * (p1.dy - p0.dy) +
      6 * u * t * (p2.dy - p1.dy) +
      3 * tt * (p3.dy - p2.dy);

  double angle = math.atan2(dy, dx);
  // Ensure readable orientation (not upside down, between -pi/2 and pi/2)
  if (angle > math.pi / 2) {
    angle -= math.pi;
  } else if (angle < -math.pi / 2) {
    angle += math.pi;
  }

  final double len = math.sqrt(dx * dx + dy * dy);
  Offset normal = len > 0.001
      ? Offset(-dy / len, dx / len)
      : const Offset(0, -1);

  // When isBottom: lead-in curves downwards, open space is ABOVE the wire (dy < 0)
  // When !isBottom: lead-in curves upwards, open space is BELOW the wire (dy > 0)
  if (isBottom) {
    if (normal.dy > 0) normal = -normal;
  } else {
    if (normal.dy < 0) normal = -normal;
  }

  final Offset pos = Offset(
    bx + normal.dx * normalOffset,
    by + normal.dy * normalOffset,
  );

  return WireLabelGeometry(position: pos, angle: angle, normal: normal);
}
