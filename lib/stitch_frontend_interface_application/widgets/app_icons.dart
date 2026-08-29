import 'package:flutter/material.dart';

/// Set icon custom bergaya line-icon minimalis dengan aksen bentuk terisi,
/// dirancang khusus untuk tampilan startup modern (bukan Material default).
enum AppIconType {
  home,
  folder,
  tasks,
  person,
  plus,
  fingerprint,
  leave,
  groups,
  chart,
  code,
  campaign,
  calendar,
  check,
  alert,
  bell,
  chevronDown,
  info,
}

class AppIcon extends StatelessWidget {
  final AppIconType type;
  final double size;
  final Color color;
  final double strokeWidth;

  const AppIcon(
    this.type, {
    super.key,
    this.size = 24,
    required this.color,
    this.strokeWidth = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AppIconPainter(
        type: type,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  final AppIconType type;
  final Color color;
  final double strokeWidth;

  _AppIconPainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case AppIconType.home:
        _paintHome(canvas, stroke, fill);
        break;
      case AppIconType.folder:
        _paintFolder(canvas, stroke, fill);
        break;
      case AppIconType.tasks:
        _paintTasks(canvas, stroke, fill);
        break;
      case AppIconType.person:
        _paintPerson(canvas, stroke);
        break;
      case AppIconType.plus:
        _paintPlus(canvas);
        break;
      case AppIconType.fingerprint:
        _paintFingerprint(canvas, stroke);
        break;
      case AppIconType.leave:
        _paintLeave(canvas, stroke);
        break;
      case AppIconType.groups:
        _paintGroups(canvas, stroke);
        break;
      case AppIconType.chart:
        _paintChart(canvas, fill);
        break;
      case AppIconType.code:
        _paintCode(canvas, stroke);
        break;
      case AppIconType.campaign:
        _paintCampaign(canvas, fill, stroke);
        break;
      case AppIconType.calendar:
        _paintCalendar(canvas, stroke, fill);
        break;
      case AppIconType.check:
        _paintCheck(canvas);
        break;
      case AppIconType.alert:
        _paintAlert(canvas, fill);
        break;
      case AppIconType.bell:
        _paintBell(canvas, stroke, fill);
        break;
      case AppIconType.chevronDown:
        _paintChevronDown(canvas, stroke);
        break;
      case AppIconType.info:
        _paintInfo(canvas, stroke, fill);
        break;
    }

    canvas.restore();
  }

  void _paintHome(Canvas canvas, Paint stroke, Paint fill) {
    final roof = Path()
      ..moveTo(4, 12)
      ..lineTo(12, 4.5)
      ..lineTo(20, 12);
    canvas.drawPath(roof, stroke);
    canvas.drawLine(const Offset(5.5, 12), const Offset(5.5, 19.5), stroke);
    canvas.drawLine(const Offset(18.5, 12), const Offset(18.5, 19.5), stroke);
    canvas.drawLine(const Offset(5.5, 19.5), const Offset(18.5, 19.5), stroke);
    final door = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10.3, 14.3, 3.4, 5.2),
      const Radius.circular(1.4),
    );
    canvas.drawRRect(door, fill);
  }

  void _paintFolder(Canvas canvas, Paint stroke, Paint fill) {
    final tab = Path()
      ..moveTo(2.8, 8.6)
      ..lineTo(2.8, 6.6)
      ..lineTo(9, 6.6)
      ..lineTo(10.6, 8.6);
    canvas.drawPath(tab, stroke);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.8, 8.6, 18.4, 9.4),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawCircle(const Offset(17, 13.3), 1.05, fill);
  }

  void _paintTasks(Canvas canvas, Paint stroke, Paint fill) {
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 3.6, 16, 16.8),
      const Radius.circular(3),
    );
    canvas.drawRRect(card, stroke);
    for (var i = 0; i < 3; i++) {
      final y = 8.2 + i * 4.2;
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(6.6, y - 1.4, 2.8, 2.8),
        const Radius.circular(0.9),
      );
      canvas.drawRRect(box, i == 0 ? fill : stroke);
      canvas.drawLine(Offset(11.4, y), Offset(16.6 - i * 1.2, y), stroke);
    }
  }

  void _paintPerson(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(12, 8.2), 3.1, stroke);
    final shoulders = Path()
      ..moveTo(6, 19.4)
      ..cubicTo(6, 14.6, 8.7, 12.6, 12, 12.6)
      ..cubicTo(15.3, 12.6, 18, 14.6, 18, 19.4);
    canvas.drawPath(shoulders, stroke);
  }

  void _paintPlus(Canvas canvas) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(12, 6.2), const Offset(12, 17.8), p);
    canvas.drawLine(const Offset(6.2, 12), const Offset(17.8, 12), p);
  }

  void _paintFingerprint(Canvas canvas, Paint stroke) {
    for (var i = 0; i < 3; i++) {
      final r = 4.0 + i * 2.6;
      final rect = Rect.fromCircle(center: const Offset(12, 12.5), radius: r);
      canvas.drawArc(rect, 3.6, 4.6, false, stroke);
    }
    canvas.drawLine(const Offset(12, 16.8), const Offset(12, 19.2), stroke);
  }

  void _paintLeave(Canvas canvas, Paint stroke) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.5, 5, 17, 15),
      const Radius.circular(2.6),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawLine(const Offset(8, 3.2), const Offset(8, 6.6), stroke);
    canvas.drawLine(const Offset(16, 3.2), const Offset(16, 6.6), stroke);
    canvas.drawLine(const Offset(3.5, 9.4), const Offset(20.5, 9.4), stroke);
    final mark = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(9.8, 13.4), const Offset(14.2, 17.4), mark);
    canvas.drawLine(const Offset(14.2, 13.4), const Offset(9.8, 17.4), mark);
  }

  void _paintGroups(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(9.2, 9), 2.5, stroke);
    canvas.drawCircle(const Offset(15.2, 9.6), 2.1, stroke);
    final back = Path()
      ..moveTo(12.6, 19)
      ..cubicTo(12.6, 15.6, 14.3, 13.9, 16.5, 13.9)
      ..cubicTo(18.4, 13.9, 19.8, 15.6, 19.8, 19);
    canvas.drawPath(back, stroke);
    final front = Path()
      ..moveTo(4.2, 19.4)
      ..cubicTo(4.2, 15.3, 6.5, 13.2, 9.2, 13.2)
      ..cubicTo(11.9, 13.2, 14.2, 15.3, 14.2, 19.4);
    canvas.drawPath(front, stroke);
  }

  void _paintChart(Canvas canvas, Paint fill) {
    final bars = [
      const Rect.fromLTWH(5.6, 13, 3.2, 6.2),
      const Rect.fromLTWH(10.4, 9, 3.2, 10.2),
      const Rect.fromLTWH(15.2, 5, 3.2, 14.2),
    ];
    const opacities = [0.5, 0.75, 1.0];
    for (var i = 0; i < bars.length; i++) {
      final p = Paint()
        ..color = fill.color.withValues(alpha: opacities[i])
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          bars[i],
          topLeft: const Radius.circular(1.4),
          topRight: const Radius.circular(1.4),
        ),
        p,
      );
    }
  }

  void _paintCode(Canvas canvas, Paint stroke) {
    final left = Path()
      ..moveTo(9.2, 6.6)
      ..lineTo(4, 12)
      ..lineTo(9.2, 17.4);
    canvas.drawPath(left, stroke);
    final right = Path()
      ..moveTo(14.8, 6.6)
      ..lineTo(20, 12)
      ..lineTo(14.8, 17.4);
    canvas.drawPath(right, stroke);
  }

  void _paintCampaign(Canvas canvas, Paint fill, Paint stroke) {
    final body = Path()
      ..moveTo(4.5, 9.6)
      ..lineTo(4.5, 14.4)
      ..lineTo(8.6, 14.4)
      ..lineTo(15, 18.2)
      ..lineTo(15, 5.8)
      ..lineTo(8.6, 9.6)
      ..close();
    canvas.drawPath(body, fill);
    final handle = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 14.4, 2.2, 3.2),
      const Radius.circular(1),
    );
    canvas.drawRRect(handle, fill);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(15.5, 12), radius: 3.6),
      -0.7,
      1.4,
      false,
      stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(15.5, 12), radius: 5.6),
      -0.55,
      1.1,
      false,
      stroke,
    );
  }

  void _paintCalendar(Canvas canvas, Paint stroke, Paint fill) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.5, 5, 17, 15),
      const Radius.circular(2.6),
    );
    canvas.drawRRect(body, stroke);
    canvas.drawLine(const Offset(8, 3.2), const Offset(8, 6.6), stroke);
    canvas.drawLine(const Offset(16, 3.2), const Offset(16, 6.6), stroke);
    canvas.drawLine(const Offset(3.5, 9.4), const Offset(20.5, 9.4), stroke);
    canvas.drawCircle(const Offset(12, 14.4), 1.3, fill);
  }

  void _paintCheck(Canvas canvas) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(5, 12.6)
      ..lineTo(9.8, 17.4)
      ..lineTo(19, 7.2);
    canvas.drawPath(path, p);
  }

  void _paintAlert(Canvas canvas, Paint fill) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(12, 6.4), const Offset(12, 13.6), p);
    canvas.drawCircle(const Offset(12, 17), 1.35, fill);
  }

  void _paintBell(Canvas canvas, Paint stroke, Paint fill) {
    final body = Path()
      ..moveTo(6.6, 15.2)
      ..lineTo(6.6, 10.6)
      ..cubicTo(6.6, 6.9, 9, 4.6, 12, 4.6)
      ..cubicTo(15, 4.6, 17.4, 6.9, 17.4, 10.6)
      ..lineTo(17.4, 15.2);
    canvas.drawPath(body, stroke);
    canvas.drawLine(const Offset(5, 15.2), const Offset(19, 15.2), stroke);
    canvas.drawCircle(const Offset(12, 18.2), 1.3, fill);
    canvas.drawCircle(const Offset(18, 6.4), 1.7, fill);
  }

  void _paintChevronDown(Canvas canvas, Paint stroke) {
    final path = Path()
      ..moveTo(7, 10)
      ..lineTo(12, 15)
      ..lineTo(17, 10);
    canvas.drawPath(path, stroke);
  }

  void _paintInfo(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(12, 12), 9, stroke);
    canvas.drawCircle(const Offset(12, 7.6), 1.05, fill);
    canvas.drawLine(const Offset(12, 10.8), const Offset(12, 16.4), stroke);
  }

  @override
  bool shouldRepaint(covariant _AppIconPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
