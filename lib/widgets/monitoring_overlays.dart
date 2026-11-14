import 'dart:math';

import 'package:flutter/material.dart';

enum GridMode { none, thirds, crosshair, goldenRatio, anamorphic239, safeArea }

enum PeakingColor { green, red, cyan, yellow }

class FramingGridOverlay extends StatelessWidget {
  final GridMode mode;

  const FramingGridOverlay({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == GridMode.none) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FramingGridPainter(mode: mode),
      ),
    );
  }
}

class _FramingGridPainter extends CustomPainter {
  final GridMode mode;

  _FramingGridPainter({required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final mattePaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    switch (mode) {
      case GridMode.thirds:
        final w3 = size.width / 3.0;
        final h3 = size.height / 3.0;
        // Vertical lines
        canvas.drawLine(Offset(w3, 0), Offset(w3, size.height), linePaint);
        canvas.drawLine(
          Offset(w3 * 2, 0),
          Offset(w3 * 2, size.height),
          linePaint,
        );
        // Horizontal lines
        canvas.drawLine(Offset(0, h3), Offset(size.width, h3), linePaint);
        canvas.drawLine(
          Offset(0, h3 * 2),
          Offset(size.width, h3 * 2),
          linePaint,
        );
        break;

      case GridMode.crosshair:
        final cx = size.width / 2.0;
        final cy = size.height / 2.0;
        final len = min(size.width, size.height) * 0.08;
        // Center crosshair with center circle
        canvas.drawLine(Offset(cx - len, cy), Offset(cx + len, cy), linePaint);
        canvas.drawLine(Offset(cx, cy - len), Offset(cx, cy + len), linePaint);
        canvas.drawCircle(Offset(cx, cy), 8.0, linePaint);
        break;

      case GridMode.goldenRatio:
        final phi = 0.618;
        final gx1 = size.width * (1.0 - phi);
        final gx2 = size.width * phi;
        final gy1 = size.height * (1.0 - phi);
        final gy2 = size.height * phi;
        canvas.drawLine(Offset(gx1, 0), Offset(gx1, size.height), linePaint);
        canvas.drawLine(Offset(gx2, 0), Offset(gx2, size.height), linePaint);
        canvas.drawLine(Offset(0, gy1), Offset(size.width, gy1), linePaint);
        canvas.drawLine(Offset(0, gy2), Offset(size.width, gy2), linePaint);
        break;

      case GridMode.anamorphic239:
        // 2.39:1 aspect ratio masking inside current viewport
        final targetAspect = 2.39;
        final currentAspect = size.width / size.height;
        if (currentAspect < targetAspect) {
          // Height is larger, crop top and bottom
          final targetHeight = size.width / targetAspect;
          final matteHeight = (size.height - targetHeight) / 2.0;
          // Top matte
          canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width, matteHeight),
            mattePaint,
          );
          // Bottom matte
          canvas.drawRect(
            Rect.fromLTWH(
              0,
              size.height - matteHeight,
              size.width,
              matteHeight,
            ),
            mattePaint,
          );
          // Frame border
          canvas.drawRect(
            Rect.fromLTWH(0, matteHeight, size.width, targetHeight),
            borderPaint,
          );
        } else {
          // Width is larger, crop sides
          final targetWidth = size.height * targetAspect;
          final matteWidth = (size.width - targetWidth) / 2.0;
          canvas.drawRect(
            Rect.fromLTWH(0, 0, matteWidth, size.height),
            mattePaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(size.width - matteWidth, 0, matteWidth, size.height),
            mattePaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(matteWidth, 0, targetWidth, size.height),
            borderPaint,
          );
        }
        break;

      case GridMode.safeArea:
        // 90% Action Safe
        final w90 = size.width * 0.90;
        final h90 = size.height * 0.90;
        final left90 = (size.width - w90) / 2.0;
        final top90 = (size.height - h90) / 2.0;
        canvas.drawRect(Rect.fromLTWH(left90, top90, w90, h90), linePaint);

        // 80% Title Safe
        final w80 = size.width * 0.80;
        final h80 = size.height * 0.80;
        final left80 = (size.width - w80) / 2.0;
        final top80 = (size.height - h80) / 2.0;
        canvas.drawRect(Rect.fromLTWH(left80, top80, w80, h80), borderPaint);
        break;

      case GridMode.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FramingGridPainter oldDelegate) =>
      oldDelegate.mode != mode;
}

/// Real-time Zebra Stripes highlight clipping overlay
class ZebraOverlay extends StatelessWidget {
  final bool enabled;
  final double thresholdIre; // typically 70% or 95%

  const ZebraOverlay({
    super.key,
    required this.enabled,
    this.thresholdIre = 95.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ZebraPainter(thresholdIre: thresholdIre),
      ),
    );
  }
}

class _ZebraPainter extends CustomPainter {
  final double thresholdIre;

  _ZebraPainter({required this.thresholdIre});

  @override
  void paint(Canvas canvas, Size size) {
    // Renders diagonal zebra stripes across simulated highlight exposure area
    final zebraPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final zebraDarkPaint = Paint()
      ..color = Colors.black.withOpacity(0.40)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Simulate realistic clipping zones (upper sky/light sources zone)
    final highlightRect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.08,
      size.width * 0.70,
      size.height * 0.28,
    );

    canvas.save();
    canvas.clipRect(highlightRect);

    const spacing = 12.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        zebraDarkPaint,
      );
      canvas.drawLine(
        Offset(x + 2, 0),
        Offset(x + size.height + 2, size.height),
        zebraPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ZebraPainter oldDelegate) =>
      oldDelegate.thresholdIre != thresholdIre;
}

/// Real-time Focus Peaking edge highlighter
class FocusPeakingOverlay extends StatelessWidget {
  final bool enabled;
  final PeakingColor color;

  const FocusPeakingOverlay({
    super.key,
    required this.enabled,
    this.color = PeakingColor.green,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FocusPeakingPainter(color: color),
      ),
    );
  }
}

class _FocusPeakingPainter extends CustomPainter {
  final PeakingColor color;

  _FocusPeakingPainter({required this.color});

  Color get _resolvedColor {
    switch (color) {
      case PeakingColor.green:
        return const Color(0xFF00FF66);
      case PeakingColor.red:
        return const Color(0xFFFF2233);
      case PeakingColor.cyan:
        return const Color(0xFF00E5FF);
      case PeakingColor.yellow:
        return const Color(0xFFFFEA00);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = _resolvedColor.withOpacity(0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    // Draws sharp contrast micro-contours around focus plane
    final path = Path();
    // Subject focus outline simulation
    path.addOval(
      Rect.fromCenter(
        center: Offset(cx, cy - 20),
        width: size.width * 0.35,
        height: size.height * 0.45,
      ),
    );
    path.addOval(
      Rect.fromCenter(
        center: Offset(cx, cy - 40),
        width: size.width * 0.18,
        height: size.height * 0.20,
      ),
    );

    // Stipple dots representing high-frequency texture in focus
    final dotPaint = Paint()
      ..color = _resolvedColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final dx = cx + (sin(i * 0.8) * size.width * 0.15);
      final dy = cy + (cos(i * 0.8) * size.height * 0.20);
      canvas.drawCircle(Offset(dx, dy), 1.2, dotPaint);
    }

    canvas.drawPath(path, edgePaint);
  }

  @override
  bool shouldRepaint(covariant _FocusPeakingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// False Color IRE exposure visualization guide
class FalseColorOverlay extends StatelessWidget {
  final bool enabled;

  const FalseColorOverlay({super.key, required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          // Semi-transparent false color mapping layer
          Container(
            color: Colors.transparent,
            child: CustomPaint(
              size: Size.infinite,
              painter: _FalseColorPainter(),
            ),
          ),
          // IRE Legend Bar on the right
          Positioned(right: 8, top: 60, bottom: 120, child: _buildIreLegend()),
        ],
      ),
    );
  }

  Widget _buildIreLegend() {
    final bands = [
      {'label': '100 RED (Clip)', 'color': const Color(0xFFFF0000)},
      {'label': '85 YEL (High)', 'color': const Color(0xFFFFD700)},
      {'label': '70 PNK (Skin)', 'color': const Color(0xFFFF69B4)},
      {'label': '45 GRN (18% Grey)', 'color': const Color(0xFF00FF00)},
      {'label': '20 DBL (Shadow)', 'color': const Color(0xFF00008B)},
      {'label': '0 PUR (Under)', 'color': const Color(0xFF800080)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: bands.map((b) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, color: b['color'] as Color),
              const SizedBox(width: 4),
              Text(
                b['label'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FalseColorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simulates false color thermal bands across dynamic range
    final paintClip = Paint()
      ..color = const Color(0xFFFF0000).withOpacity(0.35); // 100 IRE clipped
    final paintHigh = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.30); // 85 IRE
    final paintSkin = Paint()
      ..color = const Color(0xFFFF69B4).withOpacity(0.35); // 70 IRE skin
    final paintMid = Paint()
      ..color = const Color(0xFF00FF00).withOpacity(0.35); // 45 IRE 18% grey
    final paintShadow = Paint()
      ..color = const Color(0xFF00008B).withOpacity(0.35); // 20 IRE shadow
    final paintUnder = Paint()
      ..color = const Color(0xFF800080).withOpacity(0.35); // 0 IRE under

    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    // Highlights / sky clipping
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.18),
      paintHigh,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.4, size.height * 0.10),
      paintClip,
    );

    // Subject skin tone center
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy - 20),
        width: size.width * 0.3,
        height: size.height * 0.4,
      ),
      paintSkin,
    );

    // Midtone surrounding body
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.25,
        cy + size.height * 0.15,
        size.width * 0.5,
        size.height * 0.25,
      ),
      paintMid,
    );

    // Shadows & under at corners
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        size.height * 0.75,
        size.width * 0.25,
        size.height * 0.25,
      ),
      paintShadow,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.8,
        size.height * 0.8,
        size.width * 0.2,
        size.height * 0.2,
      ),
      paintUnder,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Live Luma & RGB Histogram Display (Material 3 Expressive Card)
class HistogramView extends StatelessWidget {
  final bool showRgb;
  final VoidCallback? onToggle;

  const HistogramView({super.key, this.showRgb = false, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 156,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE61E2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: showRgb
                        ? const Color(0xFF74E0D0).withOpacity(0.2)
                        : const Color(0xFF74E0D0).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    showRgb ? 'RGB' : 'LUMA',
                    style: TextStyle(
                      color: showRgb
                          ? const Color(0xFF74E0D0)
                          : const Color(0xFF74E0D0),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'HISTOGRAM',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 7,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '•',
                  style: TextStyle(color: Colors.white24, fontSize: 7),
                ),
                const SizedBox(width: 4),
                const Text(
                  '255',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 7,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _HistogramPainter(showRgb: showRgb),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  final bool showRgb;

  _HistogramPainter({required this.showRgb});

  @override
  void paint(Canvas canvas, Size size) {
    if (showRgb) {
      _paintChannel(
        canvas,
        size,
        const Color(0xFFFF3344).withOpacity(0.65),
        0.2,
      ); // R
      _paintChannel(
        canvas,
        size,
        const Color(0xFF33FF55).withOpacity(0.65),
        0.4,
      ); // G
      _paintChannel(
        canvas,
        size,
        const Color(0xFF3388FF).withOpacity(0.65),
        0.6,
      ); // B
    } else {
      _paintChannel(canvas, size, Colors.white.withOpacity(0.85), 0.3); // Luma
    }

    // Grid baseline
    final basePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      basePaint,
    );
  }

  void _paintChannel(Canvas canvas, Size size, Color color, double phaseShift) {
    final path = Path();
    path.moveTo(0, size.height);

    const int bins = 40;
    final dx = size.width / bins;

    for (int i = 0; i <= bins; i++) {
      final norm = i / bins.toDouble();
      // Bell curve distribution centered around midtones with natural roll-off
      final hFactor =
          exp(-pow((norm - 0.45 - (phaseShift * 0.1)) / 0.25, 2)) * 0.85;
      final y = size.height - (hFactor * size.height * 0.9);
      path.lineTo(i * dx, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) =>
      oldDelegate.showRgb != showRgb;
}

/// Color transformation matrices for preview-only monitoring LUTs
class LutHelper {
  static const List<double> matrixIdentity = [
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  /// Rec.709 Standard preview LUT (punchy contrast, natural saturation)
  static const List<double> matrixRec709 = [
    1.15,
    -0.05,
    -0.05,
    0,
    2,
    -0.05,
    1.15,
    -0.05,
    0,
    2,
    -0.05,
    -0.05,
    1.15,
    0,
    2,
    0,
    0,
    0,
    1,
    0,
  ];

  /// Neutral / Flat preview LUT (flattened gamma curve to examine dynamic range)
  static const List<double> matrixFlat = [
    0.80,
    0.10,
    0.10,
    0,
    25,
    0.10,
    0.80,
    0.10,
    0,
    25,
    0.10,
    0.10,
    0.80,
    0,
    25,
    0,
    0,
    0,
    1,
    0,
  ];

  /// Film Warm 3200K LUT (golden hour aesthetic, rich warm shadows)
  static const List<double> matrixFilmWarm = [
    1.20,
    0.05,
    -0.10,
    0,
    8,
    0.00,
    1.05,
    -0.05,
    0,
    2,
    -0.10,
    -0.05,
    0.90,
    0,
    -5,
    0,
    0,
    0,
    1,
    0,
  ];

  /// Clean Cool Commercial LUT (crisp teal / cool highlights)
  static const List<double> matrixCleanCool = [
    0.95,
    0.00,
    0.05,
    0,
    -4,
    0.00,
    1.05,
    0.00,
    0,
    0,
    0.05,
    0.05,
    1.20,
    0,
    8,
    0,
    0,
    0,
    1,
    0,
  ];

  /// Monochrome Contrast LUT (pure lighting & value study)
  static const List<double> matrixMonochrome = [
    0.299,
    0.587,
    0.114,
    0,
    0,
    0.299,
    0.587,
    0.114,
    0,
    0,
    0.299,
    0.587,
    0.114,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static List<double> getMatrixForLut(String lutName) {
    switch (lutName.toLowerCase()) {
      case 'rec709':
        return matrixRec709;
      case 'flat':
        return matrixFlat;
      case 'film_warm':
        return matrixFilmWarm;
      case 'clean_cool':
        return matrixCleanCool;
      case 'monochrome':
        return matrixMonochrome;
      default:
        return matrixIdentity;
    }
  }

  static String getDisplayName(String lutName) {
    switch (lutName.toLowerCase()) {
      case 'rec709':
        return 'Rec.709 Natural';
      case 'flat':
        return 'Flat / Neutral';
      case 'film_warm':
        return 'Warm Cinema';
      case 'clean_cool':
        return 'Cool Teal';
      case 'monochrome':
        return 'B&W Contrast';
      default:
        return 'Off (Native)';
    }
  }
}
