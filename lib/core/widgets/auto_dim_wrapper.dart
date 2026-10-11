import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auto_dim_service.dart';

/// Wrapper global untuk mendeteksi interaksi sentuhan & menampilkan layar redup otomatis saat idle
class AutoDimWrapper extends StatefulWidget {
  final Widget child;

  const AutoDimWrapper({super.key, required this.child});

  @override
  State<AutoDimWrapper> createState() => _AutoDimWrapperState();
}

class _AutoDimWrapperState extends State<AutoDimWrapper> {
  final AutoDimService _autoDimService = AutoDimService();
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _autoDimService.init();
    _autoDimService.addListener(_onDimStateChanged);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_autoDimService.isDimmed && mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _onDimStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _autoDimService.removeListener(_onDimStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDimmed = _autoDimService.isDimmed;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _autoDimService.onUserInteraction(),
      onPointerMove: (_) => _autoDimService.onUserInteraction(),
      onPointerUp: (_) => _autoDimService.onUserInteraction(),
      child: Stack(
        children: [
          widget.child,

          // Smooth OLED / Dim Overlay
          if (isDimmed)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _autoDimService.wakeUp(),
                child: AnimatedOpacity(
                  opacity: isDimmed ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.92),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),

                          // POSAN Mini Logo & Status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'POSAN POS • Mode Siaga',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Big Digital Clock
                          Text(
                            DateFormat('HH:mm').format(_now),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              decoration: TextDecoration.none,
                              fontFamily: 'Roboto',
                            ),
                          ),

                          // Date
                          Text(
                            () {
                              try {
                                return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_now);
                              } catch (_) {
                                return DateFormat('EEEE, dd MMM yyyy').format(_now);
                              }
                            }(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),

                          const Spacer(),

                          // Wake Prompt with Pulsing Touch Icon
                          Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.touch_app_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Sentuh layar untuk melanjutkan transaksi',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
