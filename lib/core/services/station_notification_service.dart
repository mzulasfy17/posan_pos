import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service untuk menangani Push Notifikasi & Audio Alert di Stasiun Barista dan Kitchen
class StationNotificationService {
  static final StationNotificationService _instance = StationNotificationService._internal();
  factory StationNotificationService() => _instance;
  StationNotificationService._internal();

  bool _isSoundEnabled = true;
  bool get isSoundEnabled => _isSoundEnabled;

  void toggleSound() {
    _isSoundEnabled = !_isSoundEnabled;
  }

  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  /// Mainkan bunyi lonceng / alert pesanan baru
  Future<void> playNewOrderAlertSound() async {
    if (!_isSoundEnabled) return;

    try {
      // Mainkan SystemSound alert
      await SystemSound.play(SystemSoundType.alert);
      // Mainkan nada kedua untuk efek double chime yang ramah di telinga
      await Future.delayed(const Duration(milliseconds: 180));
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Station alert sound error: $e');
    }
  }

  /// Tampilkan floating push notification banner di stasiun
  static void showOrderNotificationBanner({
    required BuildContext context,
    required String title,
    required String message,
    required String station, // 'barista' | 'kitchen'
    VoidCallback? onTap,
  }) {
    final isBarista = station.toLowerCase() == 'barista';
    final accentColor = isBarista ? const Color(0xFFBA6A34) : const Color(0xFFE65100);
    final bgColor = isBarista ? const Color(0xFF1E1712) : const Color(0xFF2B170B);
    final icon = isBarista ? Icons.coffee_rounded : Icons.restaurant_rounded;

    // Trigger audio
    StationNotificationService().playNewOrderAlertSound();

    // Show MaterialBanner / SnackBar as floating push notif
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFFFBBF24), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFE2D9CC),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onTap();
                },
                style: TextButton.styleFrom(
                  backgroundColor: accentColor.withValues(alpha: 0.25),
                  foregroundColor: const Color(0xFFFFE0B2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Lihat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.5),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
