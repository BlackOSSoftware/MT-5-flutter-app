import 'package:flutter/material.dart';

import '../mt_colors.dart';

class DotLeaderRow extends StatelessWidget {
  const DotLeaderRow({
    super.key,
    required this.label,
    required this.value,
    this.colon = true,
    this.fontSize = 15.5,
    this.verticalPadding = 3,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool colon;
  final double fontSize;
  final double verticalPadding;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: MtColors.text,
      fontSize: fontSize,
      height: 1.15,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            Text(
              colon ? '$label:' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: fontSize,
                child: const CustomPaint(painter: _DotPainter()),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              maxLines: 1,
              style: style.copyWith(
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD8D8D8);
    const gap = 8.0;
    const radius = 1.1;
    final y = size.height - radius - 1;
    for (var x = radius; x <= size.width - radius; x += gap) {
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
