import 'package:flutter/material.dart';

import 'mule_tokens.dart';

/// Small, manufacturer-neutral yard-tractor mark from INTERFAZ_MULEAGENT_V1.
/// It deliberately has no trailer or wordmark.
class MuleTruckLogo extends StatelessWidget {
  const MuleTruckLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo MuleAgent, tractor de patio',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const _MuleTruckPainter()),
    ),
  );
}

class _MuleTruckPainter extends CustomPainter {
  const _MuleTruckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);

    final navy = Paint()..color = MulePalette.navy;
    final glass = Paint()..color = MulePalette.mutedBlue;
    final cream = Paint()..color = MulePalette.cream;
    final white = Paint()..color = Colors.white;
    final orange = Paint()..color = MulePalette.orange;

    // Rear chassis and coupling, visible behind the offset cab.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 35, 47, 9),
        const Radius.circular(3),
      ),
      navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 29, 22, 7),
        const Radius.circular(2),
      ),
      glass,
    );
    canvas.drawRect(const Rect.fromLTWH(9, 25, 6, 8), navy);
    canvas.drawRect(const Rect.fromLTWH(7, 23, 13, 3), navy);

    // Three-quarter cab: slanted front and visible side panel.
    final cab = Path()
      ..moveTo(36, 13)
      ..lineTo(47, 13)
      ..lineTo(55, 22)
      ..lineTo(57, 38)
      ..lineTo(33, 38)
      ..lineTo(30, 20)
      ..close();
    canvas.drawPath(cab, navy);
    final side = Path()
      ..moveTo(36, 15)
      ..lineTo(46, 15)
      ..lineTo(53, 23)
      ..lineTo(54, 34)
      ..lineTo(35, 34)
      ..lineTo(32, 20)
      ..close();
    canvas.drawPath(side, white);

    final window = Path()
      ..moveTo(37, 18)
      ..lineTo(45, 18)
      ..lineTo(50, 23)
      ..lineTo(50, 28)
      ..lineTo(37, 28)
      ..lineTo(35, 20)
      ..close();
    canvas.drawPath(window, glass);
    canvas.drawRect(const Rect.fromLTWH(37, 29, 14, 1.5), cream);

    final front = Path()
      ..moveTo(54, 24)
      ..lineTo(59, 27)
      ..lineTo(60, 39)
      ..lineTo(55, 38)
      ..close();
    canvas.drawPath(front, navy);
    canvas.drawRect(const Rect.fromLTWH(56, 32, 3, 3), cream);

    // Roof beacon.
    canvas.drawRect(const Rect.fromLTWH(42, 10, 5, 3), navy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 6, 5, 5),
        const Radius.circular(2),
      ),
      orange,
    );

    // Wheels and visible hubs.
    for (final center in [const Offset(20, 43), const Offset(48, 43)]) {
      canvas.drawCircle(center, 9, navy);
      canvas.drawCircle(center, 4, glass);
      canvas.drawCircle(center, 1.5, cream);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MuleTruckPainter oldDelegate) => false;
}
