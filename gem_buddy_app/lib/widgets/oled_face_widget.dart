import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

class OledFaceWidget extends StatefulWidget {
  final int faceMode; // Matches ESP32 FaceMode enum
  final String deviceName;
  final String userName;
  final int batteryPercent;
  final int bpm;
  final String activeAlarmName;

  const OledFaceWidget({
    super.key,
    required this.faceMode,
    this.deviceName = 'GEM',
    this.userName = 'Friend',
    this.batteryPercent = 100,
    this.bpm = 0,
    this.activeAlarmName = 'Alarm',
  });

  @override
  State<OledFaceWidget> createState() => _OledFaceWidgetState();
}

class _OledFaceWidgetState extends State<OledFaceWidget> with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;

  final math.Random _random = math.Random();
  Timer? _frameTimer;

  int _sequenceIndex = 0;
  _EyeFrameId _currentFrame = _EyeFrameId.front;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startFrameTimer();
  }

  @override
  void didUpdateWidget(covariant OledFaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.faceMode != widget.faceMode) {
      _sequenceIndex = 0;
      _currentFrame = _sequenceFor(widget.faceMode).first;
    }
  }

  void _startFrameTimer() {
    _frameTimer = Timer.periodic(const Duration(milliseconds: 420), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final sequence = _sequenceFor(widget.faceMode);
      final int nextIndex = (_sequenceIndex + 1) % sequence.length;
      final _EyeFrameId nextFrame = sequence[nextIndex];

      setState(() {
        _sequenceIndex = nextIndex;
        _currentFrame = nextFrame;
      });

      if (_random.nextDouble() > 0.82 && widget.faceMode != 8) {
        // Give the face occasional blink-like motion in the open-eye states.
        setState(() {
          _currentFrame = _blinkVariantFor(widget.faceMode, _currentFrame);
        });
      }
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<_EyeFrameId> _sequenceFor(int faceMode) {
    switch (faceMode) {
      case 2: // FACE_NIGHT
        return const [
          _EyeFrameId.sleep,
          _EyeFrameId.blinkUpper,
          _EyeFrameId.night,
          _EyeFrameId.upperLids,
          _EyeFrameId.sleep,
        ];
      case 5: // FACE_PET
        return const [
          _EyeFrameId.front,
          _EyeFrameId.middle,
          _EyeFrameId.wide,
          _EyeFrameId.blinkUpper,
          _EyeFrameId.front,
        ];
      case 7: // FACE_HEART
        return const [
          _EyeFrameId.front,
          _EyeFrameId.middle,
          _EyeFrameId.wide,
          _EyeFrameId.front,
        ];
      case 8: // FACE_ALARM
        return const [
          _EyeFrameId.glare,
          _EyeFrameId.mad,
          _EyeFrameId.distressed,
          _EyeFrameId.cry,
          _EyeFrameId.crossed,
        ];
      case 1: // FACE_EVENING
        return const [
          _EyeFrameId.down,
          _EyeFrameId.tired,
          _EyeFrameId.lowerLids,
          _EyeFrameId.upperLids,
          _EyeFrameId.night,
        ];
      case 4: // FACE_MENU
        return const [
          _EyeFrameId.glasses,
          _EyeFrameId.front,
          _EyeFrameId.middle,
          _EyeFrameId.glasses,
        ];
      case 6: // FACE_TIME
        return const [
          _EyeFrameId.front,
          _EyeFrameId.blank,
          _EyeFrameId.front,
        ];
      case 9: // FACE_INFO
        return const [
          _EyeFrameId.blank,
          _EyeFrameId.front,
          _EyeFrameId.blank,
        ];
      default:
        return const [
          _EyeFrameId.front,
          _EyeFrameId.middle,
          _EyeFrameId.narrow,
          _EyeFrameId.wide,
          _EyeFrameId.crossed,
          _EyeFrameId.right,
          _EyeFrameId.rightDown,
          _EyeFrameId.rightUp,
          _EyeFrameId.left,
          _EyeFrameId.leftDown,
          _EyeFrameId.leftUp,
          _EyeFrameId.confused1,
          _EyeFrameId.confused2,
          _EyeFrameId.glasses,
        ];
    }
  }

  _EyeFrameId _blinkVariantFor(int faceMode, _EyeFrameId frame) {
    if (faceMode == 2) return _EyeFrameId.sleep;
    if (faceMode == 8) return frame;
    switch (frame) {
      case _EyeFrameId.front:
      case _EyeFrameId.middle:
      case _EyeFrameId.narrow:
      case _EyeFrameId.wide:
      case _EyeFrameId.crossed:
      case _EyeFrameId.right:
      case _EyeFrameId.rightDown:
      case _EyeFrameId.rightUp:
      case _EyeFrameId.left:
      case _EyeFrameId.leftDown:
      case _EyeFrameId.leftUp:
      case _EyeFrameId.confused1:
      case _EyeFrameId.confused2:
        return _EyeFrameId.blinkUpper;
      default:
        return frame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _currentFrame;

    return AspectRatio(
      aspectRatio: 2.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff020205),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: GemColors.accentBlue.withValues(alpha: 0.3),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: GemColors.accentBlue.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_floatController, _pulseController]),
          builder: (context, child) {
            return CustomPaint(
              painter: _OledPainter(
                faceMode: widget.faceMode,
                deviceName: widget.deviceName,
                userName: widget.userName,
                batteryPercent: widget.batteryPercent,
                bpm: widget.bpm,
                activeAlarmName: widget.activeAlarmName,
                frame: frame,
                floatProgress: _floatController.value,
                pulseProgress: _pulseController.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _EyeFrameId {
  front,
  middle,
  narrow,
  wide,
  crossed,
  down,
  up,
  right,
  rightDown,
  rightUp,
  left,
  leftDown,
  leftUp,
  confused1,
  confused2,
  cry,
  distressed,
  glare,
  mad,
  glasses,
  sleep,
  blinkUpper,
  tired,
  night,
  upperLids,
  lowerLids,
  blank,
}

class _EyeFrameSpec {
  final _EyeSpec left;
  final _EyeSpec right;
  final bool glasses;
  final bool tear;
  final bool angryBrows;
  final bool useSleepArc;
  final String label;

  const _EyeFrameSpec({
    required this.left,
    required this.right,
    this.glasses = false,
    this.tear = false,
    this.angryBrows = false,
    this.useSleepArc = false,
    this.label = '',
  });
}

class _EyeSpec {
  final double width;
  final double height;
  final Offset offset;
  final Offset pupilOffset;
  final double pupilRadius;
  final double topCover;
  final double bottomCover;
  final double tiltDeg;
  final bool blank;

  const _EyeSpec({
    required this.width,
    required this.height,
    this.offset = Offset.zero,
    this.pupilOffset = Offset.zero,
    this.pupilRadius = 1.8,
    this.topCover = 0.0,
    this.bottomCover = 0.0,
    this.tiltDeg = 0.0,
    this.blank = false,
  });
}

class _OledPainter extends CustomPainter {
  final int faceMode;
  final String deviceName;
  final String userName;
  final int batteryPercent;
  final int bpm;
  final String activeAlarmName;
  final _EyeFrameId frame;
  final double floatProgress;
  final double pulseProgress;

  _OledPainter({
    required this.faceMode,
    required this.deviceName,
    required this.userName,
    required this.batteryPercent,
    required this.bpm,
    required this.activeAlarmName,
    required this.frame,
    required this.floatProgress,
    required this.pulseProgress,
  });

  static const Map<_EyeFrameId, _EyeFrameSpec> _frames = {
    _EyeFrameId.front: _EyeFrameSpec(
      label: '01 EYES_FRONT',
      left: _EyeSpec(width: 16, height: 22, pupilRadius: 2.0),
      right: _EyeSpec(width: 16, height: 22, pupilRadius: 2.0),
    ),
    _EyeFrameId.middle: _EyeFrameSpec(
      label: '02 EYES_MIDDLE',
      left: _EyeSpec(width: 16, height: 22, pupilRadius: 2.0, pupilOffset: Offset(-0.4, 0)),
      right: _EyeSpec(width: 16, height: 22, pupilRadius: 2.0, pupilOffset: Offset(0.4, 0)),
    ),
    _EyeFrameId.narrow: _EyeFrameSpec(
      label: '03 EYES_NARROW',
      left: _EyeSpec(width: 13, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-0.7, 0)),
      right: _EyeSpec(width: 13, height: 22, pupilRadius: 1.9, pupilOffset: Offset(0.7, 0)),
    ),
    _EyeFrameId.wide: _EyeFrameSpec(
      label: '04 EYES_WIDE',
      left: _EyeSpec(width: 18, height: 24, pupilRadius: 2.0, pupilOffset: Offset(0, -0.4)),
      right: _EyeSpec(width: 18, height: 24, pupilRadius: 2.0, pupilOffset: Offset(0, -0.4)),
    ),
    _EyeFrameId.crossed: _EyeFrameSpec(
      label: '05 EYES_CROSSED',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(1.8, 0)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-1.8, 0)),
    ),
    _EyeFrameId.down: _EyeFrameSpec(
      label: '06 EYES_DOWN',
      left: _EyeSpec(width: 14, height: 22, pupilRadius: 1.9, pupilOffset: Offset(0, 3.0)),
      right: _EyeSpec(width: 14, height: 22, pupilRadius: 1.9, pupilOffset: Offset(0, 3.0)),
    ),
    _EyeFrameId.up: _EyeFrameSpec(
      label: '07 EYES_UP',
      left: _EyeSpec(width: 14, height: 22, pupilRadius: 1.9, pupilOffset: Offset(0, -3.0)),
      right: _EyeSpec(width: 14, height: 22, pupilRadius: 1.9, pupilOffset: Offset(0, -3.0)),
    ),
    _EyeFrameId.right: _EyeFrameSpec(
      label: '08 EYES_RIGHT',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(2.8, 0)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(2.8, 0)),
    ),
    _EyeFrameId.rightDown: _EyeFrameSpec(
      label: '09 EYES_RIGHT_DOWN',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(2.6, 2.8)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(2.6, 2.8)),
    ),
    _EyeFrameId.rightUp: _EyeFrameSpec(
      label: '10 EYES_RIGHT_UP',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(2.6, -2.8)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(2.6, -2.8)),
    ),
    _EyeFrameId.left: _EyeFrameSpec(
      label: '11 EYES_LEFT',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-2.8, 0)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-2.8, 0)),
    ),
    _EyeFrameId.leftDown: _EyeFrameSpec(
      label: '12 EYES_LEFT_DOWN',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-2.6, 2.8)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-2.6, 2.8)),
    ),
    _EyeFrameId.leftUp: _EyeFrameSpec(
      label: '13 EYES_LEFT_UP',
      left: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-2.6, -2.8)),
      right: _EyeSpec(width: 15, height: 22, pupilRadius: 1.9, pupilOffset: Offset(-2.6, -2.8)),
    ),
    _EyeFrameId.confused1: _EyeFrameSpec(
      label: '14 CONFUSSED_1',
      left: _EyeSpec(width: 14, height: 22, pupilRadius: 1.8, pupilOffset: Offset(-1.3, 1.4)),
      right: _EyeSpec(width: 14, height: 22, pupilRadius: 1.8, pupilOffset: Offset(1.3, -1.4)),
    ),
    _EyeFrameId.confused2: _EyeFrameSpec(
      label: '15 CONFUSSED_2',
      left: _EyeSpec(width: 14, height: 22, pupilRadius: 1.8, pupilOffset: Offset(-1.4, -1.4)),
      right: _EyeSpec(width: 14, height: 22, pupilRadius: 1.8, pupilOffset: Offset(1.4, 1.4)),
    ),
    _EyeFrameId.cry: _EyeFrameSpec(
      label: '16 EYES_CRY',
      left: _EyeSpec(width: 15, height: 20, pupilRadius: 1.5, pupilOffset: Offset(0, 2.2)),
      right: _EyeSpec(width: 15, height: 20, pupilRadius: 1.5, pupilOffset: Offset(0, 2.2)),
      tear: true,
    ),
    _EyeFrameId.distressed: _EyeFrameSpec(
      label: '17 EYES_DISTRESSED',
      left: _EyeSpec(width: 16, height: 20, pupilRadius: 1.6, pupilOffset: Offset(-0.8, 1.2), tiltDeg: -8),
      right: _EyeSpec(width: 16, height: 20, pupilRadius: 1.6, pupilOffset: Offset(0.8, 1.2), tiltDeg: 8),
    ),
    _EyeFrameId.glare: _EyeFrameSpec(
      label: '18 EYES_GLARE',
      left: _EyeSpec(width: 16, height: 14, pupilRadius: 1.6, topCover: 0.42, bottomCover: 0.18),
      right: _EyeSpec(width: 16, height: 14, pupilRadius: 1.6, topCover: 0.42, bottomCover: 0.18),
    ),
    _EyeFrameId.mad: _EyeFrameSpec(
      label: '19 EYES_MAD',
      left: _EyeSpec(width: 16, height: 18, pupilRadius: 1.7, tiltDeg: -14, topCover: 0.22),
      right: _EyeSpec(width: 16, height: 18, pupilRadius: 1.7, tiltDeg: 14, topCover: 0.22),
      angryBrows: true,
    ),
    _EyeFrameId.glasses: _EyeFrameSpec(
      label: '20 EYES_GLASSES',
      left: _EyeSpec(width: 18, height: 11, pupilRadius: 1.4, topCover: 0.08, bottomCover: 0.08),
      right: _EyeSpec(width: 18, height: 11, pupilRadius: 1.4, topCover: 0.08, bottomCover: 0.08),
      glasses: true,
    ),
    _EyeFrameId.sleep: _EyeFrameSpec(
      label: '21 EYES_SLEEP',
      left: _EyeSpec(width: 16, height: 10, blank: true, topCover: 1.0),
      right: _EyeSpec(width: 16, height: 10, blank: true, topCover: 1.0),
      useSleepArc: true,
    ),
    _EyeFrameId.blinkUpper: _EyeFrameSpec(
      label: '22 BLINK_UPPER',
      left: _EyeSpec(width: 16, height: 18, pupilRadius: 1.8, topCover: 0.72),
      right: _EyeSpec(width: 16, height: 18, pupilRadius: 1.8, topCover: 0.72),
    ),
    _EyeFrameId.tired: _EyeFrameSpec(
      label: '23 EYES_TIRED',
      left: _EyeSpec(width: 15, height: 14, pupilRadius: 1.5, topCover: 0.56, bottomCover: 0.18),
      right: _EyeSpec(width: 15, height: 14, pupilRadius: 1.5, topCover: 0.56, bottomCover: 0.18),
    ),
    _EyeFrameId.night: _EyeFrameSpec(
      label: '24 EYES_NIGHT',
      left: _EyeSpec(width: 15, height: 13, pupilRadius: 1.4, topCover: 0.62, bottomCover: 0.08),
      right: _EyeSpec(width: 15, height: 13, pupilRadius: 1.4, topCover: 0.62, bottomCover: 0.08),
    ),
    _EyeFrameId.upperLids: _EyeFrameSpec(
      label: '25 UPPER_LIDS',
      left: _EyeSpec(width: 16, height: 18, pupilRadius: 1.8, topCover: 0.34),
      right: _EyeSpec(width: 16, height: 18, pupilRadius: 1.8, topCover: 0.34),
    ),
    _EyeFrameId.lowerLids: _EyeFrameSpec(
      label: '26 LOWER_LIDS',
      left: _EyeSpec(width: 16, height: 18, pupilRadius: 1.6, bottomCover: 0.42),
      right: _EyeSpec(width: 16, height: 18, pupilRadius: 1.6, bottomCover: 0.42),
    ),
    _EyeFrameId.blank: _EyeFrameSpec(
      label: '27 EYES_BLANK',
      left: _EyeSpec(width: 16, height: 22, blank: true),
      right: _EyeSpec(width: 16, height: 22, blank: true),
    ),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final Paint eyeWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint eyeBlack = Paint()
      ..color = const Color(0xff020205)
      ..style = PaintingStyle.fill;

    final Paint accent = Paint()
      ..color = GemColors.accentBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, eyeBlack);

    canvas.drawLine(
      const Offset(4, 15),
      Offset(size.width - 4, 15),
      accent..strokeWidth = 0.45,
    );

    _drawText(canvas, userName.toUpperCase(), const Offset(8, 4), size: 7);
    _drawText(canvas, deviceName.toUpperCase(), Offset(size.width - 48, 4), size: 7);

    final double batX = size.width - 18;
    const double batY = 4;
    const double batW = 10;
    const double batH = 6;
    canvas.drawRect(Rect.fromLTWH(batX, batY, batW, batH), accent..strokeWidth = 0.5);
    canvas.drawRect(Rect.fromLTWH(batX + batW, batY + 1.5, 1, 3), eyeWhite);

    final double fillW = (batteryPercent / 100.0) * (batW - 2);
    if (fillW > 0) {
      canvas.drawRect(Rect.fromLTWH(batX + 1, batY + 1, fillW, batH - 2), eyeWhite);
    }

    final _EyeFrameSpec spec = _frames[frame] ?? _frames[_EyeFrameId.front]!;
    final double centerY = 28.0;
    final double leftX = size.width * 0.28;
    final double rightX = size.width * 0.72;
    final double eyeYJitter = _frameYOffsetForFaceMode();
    final double eyeScale = _eyeScaleForFaceMode();
    final double pairShift = _pairShiftForFaceMode();

    if (spec.glasses) {
      _drawGlasses(canvas, Offset(size.width / 2, centerY + eyeYJitter), eyeWhite, eyeBlack);
    }

    if (spec.useSleepArc) {
      _drawSleepArc(canvas, Offset(leftX, centerY + eyeYJitter), eyeScale, eyeWhite, eyeBlack, left: true);
      _drawSleepArc(canvas, Offset(rightX, centerY + eyeYJitter), eyeScale, eyeWhite, eyeBlack, left: false);
    } else {
      _drawEye(canvas, Offset(leftX + pairShift, centerY + eyeYJitter), spec.left, eyeScale, eyeWhite, eyeBlack);
      _drawEye(canvas, Offset(rightX + pairShift, centerY + eyeYJitter), spec.right, eyeScale, eyeWhite, eyeBlack);
    }

    if (spec.angryBrows || faceMode == 8) {
      _drawBrows(canvas, Offset(leftX, centerY + eyeYJitter), Offset(rightX, centerY + eyeYJitter), eyeScale, eyeWhite);
    }

    if (spec.tear) {
      _drawTears(canvas, Offset(leftX + pairShift, centerY + eyeYJitter), eyeScale, eyeWhite);
      _drawTears(canvas, Offset(rightX + pairShift, centerY + eyeYJitter), eyeScale, eyeWhite, mirrored: true);
    }

    final double mouthY = 48.0;
    final bool smile = faceMode != 8 && faceMode != 2;
    final bool tiny = faceMode == 5 || faceMode == 2;
    _drawMouth(canvas, size.width * 0.50, mouthY, smile, tiny, eyeWhite, accent);

    if (faceMode == 5) {
      _drawFloatingHearts(canvas, size, floatProgress);
      _drawText(canvas, 'I like your company', Offset(size.width * 0.2, size.height * 0.85), size: 7);
    } else if (faceMode == 2) {
      _drawSleepingZzz(canvas, size, floatProgress);
      _drawText(canvas, 'Night sleep mode', Offset(size.width * 0.22, size.height * 0.85), size: 7);
    } else if (faceMode == 7) {
      _drawText(canvas, 'BPM', Offset(size.width * 0.76, size.height * 0.35), size: 8);
      _drawText(canvas, '$bpm', Offset(size.width * 0.76, size.height * 0.55), size: 14, bold: true);
      _drawPulseScanner(canvas, size, pulseProgress);
    } else if (faceMode == 8) {
      _drawAlarmBells(canvas, size, pulseProgress);
      _drawText(canvas, activeAlarmName, Offset(size.width * 0.2, size.height * 0.85), size: 7, center: true);
    } else if (faceMode == 1) {
      _drawText(canvas, 'Evening relax mode', Offset(size.width * 0.22, size.height * 0.85), size: 7);
    } else {
      _drawText(canvas, 'Day mode', Offset(size.width * 0.36, size.height * 0.85), size: 7);
    }
  }

  double _frameYOffsetForFaceMode() {
    switch (faceMode) {
      case 1:
        return 1.6;
      case 2:
        return 3.0;
      case 7:
        return -0.6;
      case 8:
        return -1.0;
      default:
        return 0.0;
    }
  }

  double _eyeScaleForFaceMode() {
    switch (faceMode) {
      case 1:
        return 0.95;
      case 2:
        return 0.88;
      case 7:
        return 1.03;
      case 8:
        return 1.0;
      default:
        return 1.0;
    }
  }

  double _pairShiftForFaceMode() {
    switch (faceMode) {
      case 8:
        return -1.0;
      default:
        return 0.0;
    }
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    _EyeSpec spec,
    double scale,
    Paint eyeWhite,
    Paint eyeBlack,
  ) {
    canvas.save();
    canvas.translate(center.dx + spec.offset.dx * scale, center.dy + spec.offset.dy * scale);
    canvas.rotate(spec.tiltDeg * math.pi / 180.0);

    final Rect eyeRect = Rect.fromCenter(
      center: Offset.zero,
      width: spec.width * scale,
      height: spec.height * scale,
    );

    canvas.drawOval(eyeRect, eyeWhite);

    if (spec.topCover > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          eyeRect.left - 1,
          eyeRect.top - 1,
          eyeRect.width + 2,
          eyeRect.height * spec.topCover + 1,
        ),
        eyeBlack,
      );
    }

    if (spec.bottomCover > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          eyeRect.left - 1,
          eyeRect.bottom - eyeRect.height * spec.bottomCover,
          eyeRect.width + 2,
          eyeRect.height * spec.bottomCover + 1,
        ),
        eyeBlack,
      );
    }

    if (!spec.blank) {
      final Offset pupilCenter = Offset(spec.pupilOffset.dx * scale, spec.pupilOffset.dy * scale);
      canvas.drawCircle(pupilCenter, spec.pupilRadius * scale, eyeBlack);
      canvas.drawCircle(
        pupilCenter + Offset(-0.8 * scale, -0.8 * scale),
        0.8 * scale,
        eyeWhite,
      );
    }

    canvas.restore();
  }

  void _drawSleepArc(
    Canvas canvas,
    Offset center,
    double scale,
    Paint eyeWhite,
    Paint eyeBlack, {
    required bool left,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final Rect arcRect = Rect.fromCenter(
      center: Offset.zero,
      width: 18 * scale,
      height: 12 * scale,
    );

    final Paint arcPaint = Paint()
      ..color = eyeWhite.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round;

    final double start = left ? math.pi * 0.02 : math.pi * 0.98;
    final double sweep = left ? math.pi * 0.92 : -math.pi * 0.92;
    canvas.drawArc(arcRect, start, sweep, false, arcPaint);

    canvas.restore();
  }

  void _drawGlasses(Canvas canvas, Offset center, Paint eyeWhite, Paint eyeBlack) {
    final Paint framePaint = Paint()
      ..color = eyeWhite.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx - 17, center.dy), width: 18, height: 12),
        const Radius.circular(2),
      ),
      framePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx + 17, center.dy), width: 18, height: 12),
        const Radius.circular(2),
      ),
      framePaint,
    );
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      framePaint,
    );

    canvas.drawCircle(Offset(center.dx - 17, center.dy), 5.0, eyeBlack);
    canvas.drawCircle(Offset(center.dx + 17, center.dy), 5.0, eyeBlack);
  }

  void _drawBrows(Canvas canvas, Offset leftCenter, Offset rightCenter, double scale, Paint eyeWhite) {
    final Paint brow = Paint()
      ..color = eyeWhite.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(leftCenter.dx - 10 * scale, leftCenter.dy - 14 * scale),
      Offset(leftCenter.dx + 2 * scale, leftCenter.dy - 18 * scale),
      brow,
    );
    canvas.drawLine(
      Offset(rightCenter.dx - 2 * scale, rightCenter.dy - 18 * scale),
      Offset(rightCenter.dx + 10 * scale, rightCenter.dy - 14 * scale),
      brow,
    );
  }

  void _drawTears(Canvas canvas, Offset eyeCenter, double scale, Paint eyeWhite, {bool mirrored = false}) {
    final Paint tearPaint = Paint()
      ..color = eyeWhite.color
      ..style = PaintingStyle.fill;

    final double x = mirrored ? eyeCenter.dx + 7 * scale : eyeCenter.dx - 7 * scale;
    final double y = eyeCenter.dy + 10 * scale;
    final Path tear = Path()
      ..moveTo(x, y)
      ..quadraticBezierTo(x + (mirrored ? 2 : -2) * scale, y + 2.0 * scale, x, y + 5.0 * scale)
      ..quadraticBezierTo(x - (mirrored ? 2 : -2) * scale, y + 2.0 * scale, x, y);
    canvas.drawPath(tear, tearPaint);
  }

  void _drawMouth(Canvas canvas, double cx, double cy, bool smile, bool tiny, Paint fill, Paint glow) {
    final Path path = Path();
    final double w = tiny ? 10.0 : 16.0;
    final double h = tiny ? 4.0 : 7.0;

    if (smile) {
      path.moveTo(cx - w / 2, cy);
      path.quadraticBezierTo(cx, cy + h, cx + w / 2, cy);
    } else {
      path.moveTo(cx - w / 2, cy + h);
      path.quadraticBezierTo(cx, cy, cx + w / 2, cy + h);
    }

    canvas.drawPath(path, glow..style = PaintingStyle.stroke..strokeWidth = 1.8);
  }

  void _drawFloatingHearts(Canvas canvas, Size size, double progress) {
    final double yOffset = progress * size.height;
    _drawHeartIcon(canvas, Offset(16, size.height - 20 - (yOffset % 40)), 6);
    _drawHeartIcon(canvas, Offset(size.width - 24, size.height - 10 - ((yOffset + 20) % 40)), 6);
  }

  void _drawHeartIcon(Canvas canvas, Offset offset, double size) {
    final Paint paint = Paint()..color = GemColors.statusAlert..style = PaintingStyle.fill;
    final Path path = Path();

    path.moveTo(offset.dx, offset.dy + size / 4);
    path.cubicTo(
      offset.dx - size / 2,
      offset.dy - size / 2,
      offset.dx - size,
      offset.dy + size / 3,
      offset.dx,
      offset.dy + size,
    );
    path.cubicTo(
      offset.dx + size,
      offset.dy + size / 3,
      offset.dx + size / 2,
      offset.dy - size / 2,
      offset.dx,
      offset.dy + size / 4,
    );
    canvas.drawPath(path, paint);
  }

  void _drawSleepingZzz(Canvas canvas, Size size, double progress) {
    final double t = progress;
    final double x = size.width - 35 - 15 * math.sin(t * 2 * math.pi);
    final double y = size.height - 18 - 30 * t;

    _drawZText(canvas, 'Z', Offset(x, y), 8);
    _drawZText(canvas, 'z', Offset(x + 8, y + 6), 6);
    _drawZText(canvas, 'z', Offset(x + 14, y + 10), 4);
  }

  void _drawZText(Canvas canvas, String text, Offset offset, double fontSize) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: GemColors.accentBlue.withValues(alpha: 0.8),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  void _drawAlarmBells(Canvas canvas, Size size, double pulse) {
    final double bellSize = 12 + pulse * 4;
    final Paint alertPaint = Paint()
      ..color = GemColors.statusAlert
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(18, size.height * 0.45), bellSize / 2, alertPaint);
    canvas.drawCircle(Offset(size.width - 18, size.height * 0.45), bellSize / 2, alertPaint);
  }

  void _drawPulseScanner(Canvas canvas, Size size, double pulse) {
    final Paint pulsePaint = Paint()
      ..color = GemColors.accentBlue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.45),
      12 + pulse * 14,
      pulsePaint,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double size = 9,
    bool bold = false,
    bool center = false,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: GemColors.accentBlue,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    Offset paintOffset = offset;
    if (center) {
      paintOffset = Offset(offset.dx - textPainter.width / 2, offset.dy);
    }
    textPainter.paint(canvas, paintOffset);
  }

  @override
  bool shouldRepaint(covariant _OledPainter oldDelegate) {
    return oldDelegate.faceMode != faceMode ||
        oldDelegate.batteryPercent != batteryPercent ||
        oldDelegate.bpm != bpm ||
        oldDelegate.deviceName != deviceName ||
        oldDelegate.userName != userName ||
        oldDelegate.frame != frame ||
        oldDelegate.floatProgress != floatProgress ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
