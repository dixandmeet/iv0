import 'package:flutter/material.dart';

/// Icônes SVG inline trait pour Aule.
class AuleIcons {
  AuleIcons._();

  static Widget search({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _SearchPainter(color: color),
      );

  static Widget star({double size = 22, Color color = Colors.white}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _StarPainter(color: color),
      );

  static Widget accessibility({double size = 14, Color? color}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _AccessPainter(color: color),
      );

  static Widget walk({double size = 13, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _WalkPainter(color: color),
      );

  static Widget pin({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _PinPainter(color: color),
      );

  static Widget bus({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _BusPainter(color: color),
      );

  static Widget network({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _NetworkPainter(color: color),
      );

  static Widget alert({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _AlertPainter(color: color),
      );

  static Widget assistant({double size = 22, Color color = Colors.white}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _AssistantPainter(color: color),
      );

  static Widget chevron({double size = 18, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _ChevronPainter(color: color),
      );

  static Widget home({double size = 19, Color? color, bool filled = false}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _HomePainter(color: color, filled: filled),
      );

  static Widget work({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _WorkPainter(color: color),
      );

  static Widget map({double size = 24, Color? color, bool active = false}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _MapNavPainter(color: color, active: active),
      );

  static Widget profile({double size = 24, Color? color, bool active = false}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _ProfileNavPainter(color: color, active: active),
      );

  static Widget accueil({double size = 24, Color? color, bool active = false}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _AccueilNavPainter(color: color, active: active),
      );

  static Widget layers({double size = 22, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _LayersPainter(color: color),
      );

  static Widget locate({double size = 22, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _LocatePainter(color: color),
      );

  static Widget favoriteOutline({double size = 19, Color? color}) =>
      CustomPaint(
        size: Size(size, size),
        painter: _FavOutlinePainter(color: color),
      );

  static Widget lineFollow({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _LineFollowPainter(color: color),
      );

  static Widget bell({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _BellPainter(color: color),
      );

  static Widget gear({double size = 19, Color? color}) => CustomPaint(
        size: Size(size, size),
        painter: _GearPainter(color: color),
      );
}

abstract class _StrokePainter extends CustomPainter {
  _StrokePainter({Color? color}) : c = color ?? const Color(0xFF0B1220);
  final Color c;

  void stroke(Canvas canvas, Path path, {double width = 2}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

class _SearchPainter extends _StrokePainter {
  _SearchPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(Offset(11 * s, 11 * s), 7 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2 * s);
    stroke(canvas, Path()..moveTo(20 * s, 20 * s)..lineTo(16.5 * s, 16.5 * s),
        width: 2 * s);
  }

  @override
  bool shouldRepaint(covariant _SearchPainter old) => old.c != c;
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(12 * s, 3.5 * s)
      ..lineTo(14.5 * s, 8.8 * s)
      ..lineTo(20.3 * s, 9.5 * s)
      ..lineTo(16 * s, 13.5 * s)
      ..lineTo(17.1 * s, 19.3 * s)
      ..lineTo(12 * s, 16.5 * s)
      ..lineTo(6.9 * s, 19.3 * s)
      ..lineTo(8 * s, 13.5 * s)
      ..lineTo(3.7 * s, 9.5 * s)
      ..lineTo(9.5 * s, 8.8 * s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

class _AccessPainter extends _StrokePainter {
  _AccessPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(
        Offset(12 * s, 4 * s), 2 * s, Paint()..color = c);
    stroke(canvas, Path()
      ..moveTo(7 * s, 8 * s)
      ..lineTo(17 * s, 8 * s)
      ..moveTo(12 * s, 8 * s)
      ..lineTo(12 * s, 13 * s)
      ..moveTo(12 * s, 13 * s)
      ..lineTo(15.5 * s, 19 * s)
      ..moveTo(12 * s, 13 * s)
      ..lineTo(8.5 * s, 19 * s), width: 1.8 * s);
  }

  @override
  bool shouldRepaint(covariant _AccessPainter old) => old.c != c;
}

class _WalkPainter extends _StrokePainter {
  _WalkPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(
        Offset(13 * s, 4 * s), 2 * s, Paint()..color = c);
    stroke(canvas, Path()
      ..moveTo(13 * s, 8 * s)
      ..lineTo(11 * s, 12 * s)
      ..lineTo(8 * s, 14 * s)
      ..moveTo(13 * s, 8 * s)
      ..lineTo(15 * s, 12 * s)
      ..lineTo(17 * s, 13 * s)
      ..moveTo(11 * s, 12 * s)
      ..lineTo(10 * s, 20 * s)
      ..moveTo(15 * s, 12 * s)
      ..lineTo(12 * s, 20 * s), width: 1.7 * s);
  }

  @override
  bool shouldRepaint(covariant _WalkPainter old) => old.c != c;
}

class _PinPainter extends _StrokePainter {
  _PinPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(12 * s, 2.5 * s)
      ..cubicTo(5.5 * s, 2.5 * s, 2 * s, 8.8 * s, 2 * s, 8.8 * s)
      ..cubicTo(2 * s, 8.8 * s, 12 * s, 21.5 * s, 12 * s, 21.5 * s)
      ..cubicTo(12 * s, 21.5 * s, 22 * s, 8.8 * s, 22 * s, 8.8 * s)
      ..cubicTo(22 * s, 8.8 * s, 18.5 * s, 2.5 * s, 12 * s, 2.5 * s)
      ..close(), width: 2 * s);
    canvas.drawCircle(
        Offset(12 * s, 9 * s), 2.4 * s, Paint()..color = c);
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.c != c;
}

class _BusPainter extends _StrokePainter {
  _BusPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(6 * s, 4 * s)
      ..lineTo(18 * s, 4 * s)
      ..lineTo(18 * s, 15 * s)
      ..lineTo(16 * s, 17 * s)
      ..lineTo(8 * s, 17 * s)
      ..lineTo(6 * s, 15 * s)
      ..close()
      ..moveTo(6 * s, 11 * s)
      ..lineTo(18 * s, 11 * s), width: 1.8 * s);
  }

  @override
  bool shouldRepaint(covariant _BusPainter old) => old.c != c;
}

class _NetworkPainter extends _StrokePainter {
  _NetworkPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(4 * s, 13 * s)
      ..cubicTo(8 * s, 9 * s, 16 * s, 9 * s, 20 * s, 13 * s), width: 1.8 * s);
    stroke(canvas, Path()
      ..moveTo(7 * s, 16 * s)
      ..cubicTo(9.5 * s, 14 * s, 14.5 * s, 14 * s, 17 * s, 16 * s), width: 1.8 * s);
    canvas.drawCircle(
        Offset(12 * s, 19 * s), 1.6 * s, Paint()..color = c);
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter old) => old.c != c;
}

class _AlertPainter extends _StrokePainter {
  _AlertPainter({super.color}) : warnColor = color ?? const Color(0xFFB45309);
  final Color warnColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final warn = warnColor;
    stroke(canvas, Path()
      ..moveTo(12 * s, 4 * s)
      ..lineTo(2.5 * s, 20 * s)
      ..lineTo(21.5 * s, 20 * s)
      ..close(), width: 1.9 * s);
    stroke(canvas, Path()..moveTo(12 * s, 10 * s)..lineTo(12 * s, 14 * s),
        width: 2 * s);
    canvas.drawCircle(
        Offset(12 * s, 17 * s), 1.1 * s, Paint()..color = warn);
  }

  @override
  bool shouldRepaint(covariant _AlertPainter old) =>
      old.c != c || old.warnColor != warnColor;
}

class _AssistantPainter extends _StrokePainter {
  _AssistantPainter({required Color color}) : super(color: color);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(12 * s, 3 * s)
      ..lineTo(12 * s, 6 * s)
      ..moveTo(12 * s, 18 * s)
      ..lineTo(12 * s, 21 * s)
      ..moveTo(3 * s, 12 * s)
      ..lineTo(6 * s, 12 * s)
      ..moveTo(18 * s, 12 * s)
      ..lineTo(21 * s, 12 * s), width: 2 * s);
    canvas.drawCircle(Offset(12 * s, 12 * s), 4 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2 * s);
  }

  @override
  bool shouldRepaint(covariant _AssistantPainter old) => old.c != c;
}

class _ChevronPainter extends _StrokePainter {
  _ChevronPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(9 * s, 6 * s)
      ..lineTo(15 * s, 12 * s)
      ..lineTo(9 * s, 18 * s), width: 2 * s);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter old) => old.c != c;
}

class _HomePainter extends _StrokePainter {
  _HomePainter({super.color, this.filled = false});
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(4 * s, 11 * s)
      ..lineTo(12 * s, 4 * s)
      ..lineTo(20 * s, 11 * s)
      ..moveTo(6 * s, 10 * s)
      ..lineTo(6 * s, 19 * s)
      ..lineTo(18 * s, 19 * s)
      ..lineTo(18 * s, 10 * s);
    if (filled) {
      canvas.drawPath(path, Paint()..color = c);
    } else {
      stroke(canvas, path, width: 1.9 * s);
    }
  }

  @override
  bool shouldRepaint(covariant _HomePainter old) =>
      old.c != c || old.filled != filled;
}

class _WorkPainter extends _StrokePainter {
  _WorkPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(4 * s, 8 * s, 16 * s, 11 * s), Radius.circular(2 * s)))
      ..moveTo(9 * s, 8 * s)
      ..lineTo(9 * s, 6 * s)
      ..cubicTo(9 * s, 4 * s, 11 * s, 4 * s, 12 * s, 4 * s)
      ..cubicTo(13 * s, 4 * s, 15 * s, 4 * s, 15 * s, 6 * s)
      ..lineTo(15 * s, 8 * s), width: 1.9 * s);
  }

  @override
  bool shouldRepaint(covariant _WorkPainter old) => old.c != c;
}

class _AccueilNavPainter extends _StrokePainter {
  _AccueilNavPainter({super.color, this.active = false});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final sw = active ? 2.1 * s : 1.8 * s;
    stroke(canvas, Path()
      ..moveTo(4 * s, 11.5 * s)
      ..lineTo(12 * s, 4 * s)
      ..lineTo(20 * s, 11.5 * s), width: sw);
    final house = Path()
      ..moveTo(6 * s, 10.5 * s)
      ..lineTo(6 * s, 19 * s)
      ..lineTo(18 * s, 19 * s)
      ..lineTo(18 * s, 10.5 * s)
      ..close();
    if (active) {
      canvas.drawPath(
          house,
          Paint()
            ..color = c.withValues(alpha: 0.12)
            ..style = PaintingStyle.fill);
    }
    stroke(canvas, house, width: sw);
  }

  @override
  bool shouldRepaint(covariant _AccueilNavPainter old) =>
      old.c != c || old.active != active;
}

class _MapNavPainter extends _StrokePainter {
  _MapNavPainter({super.color, this.active = false});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final sw = active ? 2.1 * s : 1.8 * s;
    final path = Path()
      ..moveTo(9 * s, 4 * s)
      ..lineTo(3.5 * s, 6.5 * s)
      ..lineTo(3.5 * s, 19.5 * s)
      ..lineTo(9 * s, 17 * s)
      ..lineTo(15 * s, 19.5 * s)
      ..lineTo(20.5 * s, 17 * s)
      ..lineTo(20.5 * s, 4 * s)
      ..lineTo(15 * s, 6.5 * s)
      ..close();
    if (active) {
      canvas.drawPath(
          path,
          Paint()
            ..color = c.withValues(alpha: 0.12)
            ..style = PaintingStyle.fill);
    }
    stroke(canvas, path, width: sw);
    stroke(canvas, Path()
      ..moveTo(9 * s, 6.5 * s)
      ..lineTo(9 * s, 17 * s)
      ..moveTo(15 * s, 4 * s)
      ..lineTo(15 * s, 17 * s), width: sw);
  }

  @override
  bool shouldRepaint(covariant _MapNavPainter old) =>
      old.c != c || old.active != active;
}

class _ProfileNavPainter extends _StrokePainter {
  _ProfileNavPainter({super.color, this.active = false});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final sw = active ? 2.1 * s : 1.8 * s;
    canvas.drawCircle(Offset(12 * s, 8 * s), 3.4 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = sw);
    stroke(canvas, Path()
      ..moveTo(5 * s, 20 * s)
      ..cubicTo(5 * s, 16.4 * s, 8.1 * s, 14.5 * s, 12 * s, 14.5 * s)
      ..cubicTo(15.9 * s, 14.5 * s, 19 * s, 16.4 * s, 19 * s, 20 * s), width: sw);
  }

  @override
  bool shouldRepaint(covariant _ProfileNavPainter old) =>
      old.c != c || old.active != active;
}

class _LayersPainter extends _StrokePainter {
  _LayersPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(12 * s, 2 * s)
      ..lineTo(2 * s, 7 * s)
      ..lineTo(12 * s, 12 * s)
      ..lineTo(22 * s, 7 * s)
      ..close(), width: 1.8 * s);
    stroke(canvas, Path()
      ..moveTo(2 * s, 12 * s)
      ..lineTo(12 * s, 17 * s)
      ..lineTo(22 * s, 12 * s), width: 1.8 * s);
    stroke(canvas, Path()
      ..moveTo(2 * s, 17 * s)
      ..lineTo(12 * s, 22 * s)
      ..lineTo(22 * s, 17 * s), width: 1.8 * s);
  }

  @override
  bool shouldRepaint(covariant _LayersPainter old) => old.c != c;
}

class _LocatePainter extends _StrokePainter {
  _LocatePainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(Offset(12 * s, 12 * s), 3 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2 * s);
    stroke(canvas, Path()
      ..moveTo(12 * s, 2 * s)
      ..lineTo(12 * s, 6 * s)
      ..moveTo(12 * s, 18 * s)
      ..lineTo(12 * s, 22 * s)
      ..moveTo(2 * s, 12 * s)
      ..lineTo(6 * s, 12 * s)
      ..moveTo(18 * s, 12 * s)
      ..lineTo(22 * s, 12 * s), width: 2 * s);
  }

  @override
  bool shouldRepaint(covariant _LocatePainter old) => old.c != c;
}

class _FavOutlinePainter extends _StrokePainter {
  _FavOutlinePainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(12 * s, 4 * s)
      ..lineTo(14.3 * s, 8.8 * s)
      ..lineTo(19.5 * s, 9.6 * s)
      ..lineTo(15.6 * s, 13.2 * s)
      ..lineTo(16.6 * s, 18.4 * s)
      ..lineTo(12 * s, 15.6 * s)
      ..lineTo(7.4 * s, 18.4 * s)
      ..lineTo(8.4 * s, 13.2 * s)
      ..lineTo(4.5 * s, 9.6 * s)
      ..lineTo(9.7 * s, 8.8 * s)
      ..close(), width: 1.8 * s);
  }

  @override
  bool shouldRepaint(covariant _FavOutlinePainter old) => old.c != c;
}

class _LineFollowPainter extends _StrokePainter {
  _LineFollowPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(Offset(6 * s, 6 * s), 2.4 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.8 * s);
    canvas.drawCircle(Offset(18 * s, 18 * s), 2.4 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.8 * s);
    stroke(canvas, Path()
      ..moveTo(6 * s, 8.5 * s)
      ..lineTo(6 * s, 11.5 * s)
      ..cubicTo(6 * s, 15.5 * s, 10 * s, 15.5 * s, 10 * s, 15.5 * s)
      ..lineTo(14 * s, 15.5 * s)
      ..cubicTo(18 * s, 15.5 * s, 18 * s, 19.5 * s, 18 * s, 19.5 * s), width: 1.8 * s);
  }

  @override
  bool shouldRepaint(covariant _LineFollowPainter old) => old.c != c;
}

class _BellPainter extends _StrokePainter {
  _BellPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    stroke(canvas, Path()
      ..moveTo(6 * s, 9 * s)
      ..cubicTo(6 * s, 5 * s, 18 * s, 5 * s, 18 * s, 9 * s)
      ..cubicTo(18 * s, 14 * s, 20 * s, 15 * s, 20 * s, 15 * s)
      ..lineTo(4 * s, 15 * s)
      ..cubicTo(4 * s, 15 * s, 6 * s, 14 * s, 6 * s, 9 * s), width: 1.8 * s);
    stroke(canvas, Path()
      ..moveTo(10 * s, 19 * s)
      ..cubicTo(10 * s, 20.1 * s, 14 * s, 20.1 * s, 14 * s, 19 * s), width: 1.8 * s);
  }

  @override
  bool shouldRepaint(covariant _BellPainter old) => old.c != c;
}

class _GearPainter extends _StrokePainter {
  _GearPainter({super.color});
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawCircle(Offset(12 * s, 12 * s), 3 * s,
        Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.8 * s);
    stroke(canvas, Path()
      ..moveTo(12 * s, 3 * s)
      ..lineTo(12 * s, 5.5 * s)
      ..moveTo(12 * s, 18.5 * s)
      ..lineTo(12 * s, 21 * s)
      ..moveTo(3 * s, 12 * s)
      ..lineTo(5.5 * s, 12 * s)
      ..moveTo(18.5 * s, 12 * s)
      ..lineTo(21 * s, 12 * s), width: 1.7 * s);
  }

  @override
  bool shouldRepaint(covariant _GearPainter old) => old.c != c;
}
