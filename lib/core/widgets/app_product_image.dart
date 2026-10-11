import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/posan_api_service.dart';

class AppProductImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double iconSize;

  const AppProductImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final rawUrl = imageUrl?.trim() ?? '';

    Widget placeholder() {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5EFE6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.coffee_rounded,
                color: const Color(0xFFBA6A34),
                size: iconSize,
              ),
              const SizedBox(height: 2),
              const Text(
                'POSAN',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFFBA6A34),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (rawUrl.isEmpty) {
      return placeholder();
    }

    // 1. Check if Base64 Data URL or raw base64 string
    if (rawUrl.startsWith('data:image') || rawUrl.contains('base64,')) {
      try {
        final cleanBase64 = rawUrl.contains('base64,') ? rawUrl.split('base64,').last : rawUrl;
        final Uint8List bytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => placeholder(),
        );
      } catch (_) {
        return placeholder();
      }
    }

    // 2. Format Relative or Full Network URL
    String effectiveUrl = rawUrl;
    if (rawUrl.startsWith('/')) {
      final baseUrl = PosanApiService().baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      effectiveUrl = '$baseUrl$rawUrl';
    }

    if (effectiveUrl.startsWith('http://') || effectiveUrl.startsWith('https://')) {
      return Image.network(
        effectiveUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF5EFE6),
            child: Center(
              child: SizedBox(
                width: iconSize * 0.6,
                height: iconSize * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFFBA6A34),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local asset if network fails
          return Image.asset(
            'assets/images/caramel_macchiato.jpg',
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (c, e, s) => placeholder(),
          );
        },
      );
    }

    // 3. Local Flutter Assets
    String assetPath = effectiveUrl;
    if (!assetPath.startsWith('assets/')) {
      assetPath = 'assets/images/$assetPath';
    }

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return placeholder();
      },
    );
  }
}
