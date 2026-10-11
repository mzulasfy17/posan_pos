import 'package:flutter/material.dart';

enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}

/// Helper utilitas untuk mendeteksi ukuran layar dan orientasi perangkat.
class Responsive {
  static const double mobileMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static Orientation orientation(BuildContext context) =>
      MediaQuery.orientationOf(context);

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMaxWidth;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileMaxWidth && w < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMaxWidth;

  /// Mode lebar (Wide) untuk layout kasir split-pane (tablet atau landscape HP besar)
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 720;

  static DeviceScreenType getDeviceType(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= tabletMaxWidth) return DeviceScreenType.desktop;
    if (w >= mobileMaxWidth) return DeviceScreenType.tablet;
    return DeviceScreenType.mobile;
  }

  /// Menghitung jumlah kolom grid secara otomatis berdasarkan lebar layar
  static int getAdaptiveGridColumns(
    BuildContext context, {
    double itemMinWidth = 160,
    int minColumns = 2,
    int maxColumns = 6,
    double availableWidthOffset = 0,
  }) {
    final width = screenWidth(context) - availableWidthOffset;
    final calculated = (width / itemMinWidth).floor();
    return calculated.clamp(minColumns, maxColumns);
  }
}

/// Widget untuk membatasi lebar maksimum konten pada layar tablet / desktop agar tidak melar berlebihan
class MaxContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  const MaxContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.alignment = Alignment.topCenter,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Widget builder adaptif untuk menampilkan layout yang berbeda sesuai tipe perangkat & orientasi
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) mobile;
  final Widget Function(BuildContext context, BoxConstraints constraints)? tablet;
  final Widget Function(BuildContext context, BoxConstraints constraints)? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Responsive.tabletMaxWidth && desktop != null) {
          return desktop!(context, constraints);
        }
        if (constraints.maxWidth >= Responsive.mobileMaxWidth && tablet != null) {
          return tablet!(context, constraints);
        }
        return mobile(context, constraints);
      },
    );
  }
}
