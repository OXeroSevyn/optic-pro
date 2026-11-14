import 'package:flutter/material.dart';

class AudioMeterWidget extends StatelessWidget {
  final double rmsDb;
  final double peakDb;
  final bool isClipping;
  final String micName;
  final bool isExternalMic;

  const AudioMeterWidget({
    super.key,
    required this.rmsDb,
    required this.peakDb,
    required this.isClipping,
    this.micName = 'Built-in Mic',
    this.isExternalMic = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert -60 dB to 0 dB to 0.0 - 1.0 fraction
    final rmsFraction = ((rmsDb + 60.0) / 60.0).clamp(0.0, 1.0);
    final peakFraction = ((peakDb + 60.0) / 60.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6181A20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClipping
              ? const Color(0xFFFF453A)
              : Colors.white.withOpacity(0.12),
          width: isClipping ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExternalMic ? Icons.mic_external_on_rounded : Icons.mic_rounded,
            size: 14,
            color: isClipping
                ? const Color(0xFFFF453A)
                : (isExternalMic ? const Color(0xFF74E0D0) : Colors.white70),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isExternalMic
                  ? const Color(0xFF74E0D0).withOpacity(0.2)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isExternalMic ? 'EXT' : 'INT',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: isExternalMic ? const Color(0xFF74E0D0) : Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Decibel meter bar
          SizedBox(
            width: 80,
            height: 8,
            child: Stack(
              children: [
                // Background bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // RMS Level fill
                FractionallySizedBox(
                  widthFactor: rmsFraction,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF34C759), // Material Green
                          Color(0xFFFFD60A), // Material Yellow (-12dB)
                          Color(0xFFFF453A), // Material Red (0dB)
                        ],
                        stops: [0.65, 0.88, 1.0],
                      ),
                    ),
                  ),
                ),
                // Peak marker line
                if (peakFraction > 0.05)
                  Align(
                    alignment: Alignment(peakFraction * 2 - 1, 0),
                    child: Container(
                      width: 2,
                      height: 8,
                      decoration: BoxDecoration(
                        color: peakDb >= -1.0
                            ? const Color(0xFFFF453A)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Numerical dB display
          SizedBox(
            width: 32,
            child: Text(
              '${peakDb.toStringAsFixed(0)}dB',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: isClipping
                    ? const Color(0xFFFF453A)
                    : (peakDb >= -6.0
                          ? const Color(0xFFFFD60A)
                          : Colors.white70),
              ),
            ),
          ),
          if (isClipping) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF453A).withOpacity(0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Text(
                'CLIP',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
