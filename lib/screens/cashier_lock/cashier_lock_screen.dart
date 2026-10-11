import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/cashier_session_model.dart';

class CashierLockScreen extends StatefulWidget {
  final CashierSessionModel session;

  const CashierLockScreen({
    super.key,
    required this.session,
  });

  static Future<void> show(
    BuildContext context, {
    required CashierSessionModel session,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            CashierLockScreen(session: session),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<CashierLockScreen> createState() => _CashierLockScreenState();
}

class _CashierLockScreenState extends State<CashierLockScreen> {
  String _pin = '';
  final String _correctPin = '1234'; // Default demo PIN
  String? _errorMessage;

  void _onKeyPress(String key) {
    if (_pin.length >= 4) return;
    setState(() {
      _errorMessage = null;
      _pin += key;
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _verifyPin() async {
    // Small delay for UI smoothness
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    // Accept 1234 or any 4 digit pin for demo convenience
    if (_pin == _correctPin || _pin.length == 4) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Layar kasir berhasil dibuka.'),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'PIN salah. Gunakan 1234.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = Responsive.isLandscape(context);

    return PopScope(
      canPop: false, // Prevent back button without PIN
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1713),
        body: SafeArea(
          child: isLandscape
              ? Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    child: MaxContentWidth(
                      maxWidth: 800,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left column: Profile & PIN Dots
                          Expanded(
                            flex: 5,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHeaderBadge(),
                                const SizedBox(height: 16),
                                _buildProfileSection(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),

                          // Right column: Numpad
                          Expanded(
                            flex: 5,
                            child: _buildNumpadSection(),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildHeaderBadge(),
                    ),

                    // Middle: Profile Avatar & PIN prompt
                    _buildProfileSection(),

                    // Bottom Numpad
                    Padding(
                      padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
                      child: _buildNumpadSection(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 13, color: Colors.white70),
                  SizedBox(width: 5),
                  Text(
                    'Layar Terkunci',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          widget.session.merchantName,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFBA6A34),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.person,
              size: 38,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.session.cashierName,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.session.shift,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 18),

        // PIN Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled
                    ? const Color(0xFFBA6A34)
                    : Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                  color: isFilled
                      ? const Color(0xFFBA6A34)
                      : Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 10),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFF6B6B),
              fontWeight: FontWeight.w600,
            ),
          )
        else
          const Text(
            'Masukkan 4-digit PIN kasir (Demo: 1234)',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white38,
            ),
          ),
      ],
    );
  }

  Widget _buildNumpadSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        _buildNumpadBottomRow(),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) => _buildNumpadBtn(k)).toList(),
    );
  }

  Widget _buildNumpadBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Empty spacer
        const SizedBox(width: 68, height: 60),
        const SizedBox(width: 16),

        // 0 key
        _buildNumpadBtn('0'),
        const SizedBox(width: 16),

        // Backspace key
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onBackspace,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 68,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.backspace_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadBtn(String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 68,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
