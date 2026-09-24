import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_dut_info/modules/ui/bubble_hover_region.dart';

void main() {
  for (final right in [false, true]) {
    for (final bottom in [false, true]) {
      testWidgets('Stable dock hover right=$right bottom=$bottom', (
        tester,
      ) async {
        final rect = bubbleInteractionRect(
          isRight: right,
          isBottom: bottom,
          isDocked: true,
        );
        final changes = <bool>[];
        var expanded = false;
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      left: expanded ? (right ? 354 : 20) : (right ? 427 : -53),
                      top: bottom ? 10 : 256,
                      width: 66,
                      height: 66,
                      child: GestureDetector(
                        onTap: () => taps++,
                        child: const ColoredBox(color: Colors.blue),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: rect,
                      child: BubbleHoverRegion(
                        onChanged: (value) {
                          changes.add(value);
                          setState(() => expanded = value);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(200, 200));
        await mouse.moveTo(Offset(right ? 435 : 5, bottom ? 40 : 280));
        await tester.pumpAndSettle();
        expect(changes, [true]);
        // Moving through the slide corridor must not collapse the bubble.
        final center = Offset(right ? 387 : 53, bottom ? 43 : 289);
        await mouse.moveTo(center);
        await tester.pumpAndSettle();
        expect(changes, [true]);
        await tester.tapAt(center);
        expect(taps, 1, reason: 'Hover overlay must preserve bubble buttons');
        await mouse.moveTo(const Offset(200, 200));
        await tester.pumpAndSettle();
        expect(changes, [true, false]);
        await mouse.removePointer();
      });
    }
  }

  test(
    'computeLeadInWireStationGeometry produces upright angle and offset in 4 corners',
    () {
      for (final right in [false, true]) {
        for (final bottom in [false, true]) {
          final bubbleAnchor = Offset(
            right ? 427.0 : 13.0,
            bottom ? 43.0 : 289.0,
          );
          final wireX = right ? 387.0 : 53.0;
          final cardY = bottom ? 130.0 : 220.0;

          final geom = computeLeadInWireStationGeometry(
            bubbleAnchor: bubbleAnchor,
            wireX: wireX,
            cardY: cardY,
            isBottom: bottom,
          );

          // Verify angle is readable (-pi/2 <= angle <= pi/2)
          expect(geom.angle, greaterThanOrEqualTo(-3.14159265 / 2));
          expect(geom.angle, lessThanOrEqualTo(3.14159265 / 2));

          // Verify position is within window bounds and not NaN
          expect(geom.position.dx.isFinite, isTrue);
          expect(geom.position.dy.isFinite, isTrue);

          // When bottom, open space is above wire (normal.dy < 0)
          // When !bottom, open space is below wire (normal.dy > 0)
          if (bottom) {
            expect(geom.normal.dy, lessThanOrEqualTo(0.0));
          } else {
            expect(geom.normal.dy, greaterThanOrEqualTo(0.0));
          }
        }
      }
    },
  );
}
