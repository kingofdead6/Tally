import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The balance, printed like a banknote: deep green paper with guilloche
/// security lines drawn in code.
class BanknoteCard extends StatelessWidget {
  final double balance;
  final double monthIn;
  final double monthOut;
  final String monthLabel;

  const BanknoteCard({
    super.key,
    required this.balance,
    required this.monthIn,
    required this.monthOut,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    const onNote = Color(0xFFEAF5EF);
    return Semantics(
      label: 'Total balance ${Money.format(balance)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Palette.cedar, Palette.cedarDeep],
            ),
          ),
          child: CustomPaint(
            painter: _GuillochePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total balance',
                        style: TextStyle(color: fade(onNote, 0.78), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: fade(Palette.gold, 0.7)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'DZD',
                          style: AppText.money(12, color: Palette.gold, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(balance),
                      style: AppText.money(38, color: Colors.white, weight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(height: 1, color: fade(onNote, 0.16)),
                  const SizedBox(height: 14),
                  Text(monthLabel, style: TextStyle(color: fade(onNote, 0.7), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _Flow(label: 'Money in', value: monthIn, income: true)),
                      Container(width: 1, height: 34, color: fade(onNote, 0.16)),
                      const SizedBox(width: 16),
                      Expanded(child: _Flow(label: 'Money out', value: monthOut, income: false)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Flow extends StatelessWidget {
  final String label;
  final double value;
  final bool income;
  const _Flow({required this.label, required this.value, required this.income});

  @override
  Widget build(BuildContext context) {
    final accent = income ? const Color(0xFF7FE3B5) : const Color(0xFFFFA3B1);
    return Row(
      children: [
        Icon(income ? Icons.south_west_rounded : Icons.north_east_rounded, size: 18, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: fade(Colors.white, 0.7), fontSize: 12)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Money.format(value), style: AppText.money(16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banknote-style security print: a rosette of epitrochoid curves on the
/// right, and fine wave bands along the bottom edge.
class _GuillochePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rosette = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = fade(Colors.white, 0.10);

    final center = Offset(size.width * 0.86, size.height * 0.34);
    final base = size.height * 0.42;
    for (var ring = 0; ring < 5; ring++) {
      final big = base - ring * 9;
      final small = big / 5.2;
      final d = small * 1.6;
      final path = Path();
      for (var i = 0; i <= 720; i++) {
        final t = i / 720 * 2 * math.pi;
        final x = (big + small) * math.cos(t) - d * math.cos((big + small) / small * t);
        final y = (big + small) * math.sin(t) - d * math.sin((big + small) / small * t);
        final p = center + Offset(x * 0.62, y * 0.62);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, rosette);
    }

    final waves = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = fade(Palette.gold, 0.16);
    for (var k = 0; k < 7; k++) {
      final path = Path();
      final y0 = size.height - 10 - k * 4.0;
      for (double x = 0; x <= size.width; x += 3) {
        final y = y0 + math.sin(x / 14 + k * 0.7) * 3;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, waves);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
