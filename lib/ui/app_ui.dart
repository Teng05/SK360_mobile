import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SK 360's visual language: red and white first, with soft blue, yellow,
/// green, orange and gray reserved for meaningful states.
abstract final class AppColors {
  // Brand.
  static const primaryRed = Color(0xFFDC2626);
  static const actionRed = Color(0xFFC0202C);
  static const softPink = Color(0xFFFDEFEF);
  static const borderPink = Color(0xFFF6D5D7);

  // Neutrals. The page background is white; cards separate with a hairline
  // border and a very soft shadow.
  static const darkGray = Color(0xFF1B2130);
  static const lightGrayBg = Color(0xFFFFFFFF);
  static const white = Colors.white;
  static const lightText = Color(0xFF5F6878);
  static const buttonGray = lightText;
  static const surface = Colors.white;
  static const subtle = Color(0xFFF8F9FB);
  static const field = Color(0xFFF3F4F7);
  static const border = Color(0xFFE8EAEE);

  // Semantic accents, kept muted so screens stay easy on the eyes.
  static const success = Color(0xFF16803C);
  static const successSurface = Color(0xFFEAF7EE);
  static const warning = Color(0xFFC25410);
  static const warningSurface = Color(0xFFFFF2E7);
  static const info = Color(0xFF2E62D1);
  static const infoSurface = Color(0xFFEEF3FD);
  static const highlight = Color(0xFFA36A00);
  static const highlightSurface = Color(0xFFFFF7DC);
  static const muted = Color(0xFF7A8290);
  static const mutedSurface = Color(0xFFF1F2F5);
  static const error = Color(0xFFB3261E);
  static const gold = Color(0xFFD4A020);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const page = 16.0;
  static const section = 24.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const radius = 18.0;
  static const controlRadius = 14.0;
}

/// White cards with a hairline border and a soft, low shadow.
abstract final class AppDecorations {
  static const softShadow = [
    BoxShadow(
      color: Color(0x101B2130),
      blurRadius: 18,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
    BoxShadow(color: Color(0x081B2130), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static BoxDecoration surface({
    Color color = AppColors.surface,
    double radius = AppSpace.radius,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border),
    boxShadow: softShadow,
  );

  /// A quiet inset surface for rows and tiles inside a card.
  static BoxDecoration inset({double radius = AppSpace.controlRadius}) =>
      BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
      );
}

/// Text on a soft tint reads better when it is slightly deeper than the tint.
Color _ink(Color color) => Color.lerp(color, AppColors.darkGray, .12)!;

abstract final class AppTheme {
  static const fontFamily = 'Manrope';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryRed,
      primary: AppColors.primaryRed,
      onPrimary: Colors.white,
      secondary: AppColors.actionRed,
      secondaryContainer: AppColors.softPink,
      onSecondaryContainer: AppColors.actionRed,
      tertiary: AppColors.info,
      surface: AppColors.surface,
      onSurface: AppColors.darkGray,
      onSurfaceVariant: AppColors.lightText,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      borderSide: const BorderSide(color: AppColors.border),
    );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: .1,
    );
    final textTheme = base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -.9,
            color: AppColors.darkGray,
          ),
          headlineMedium: const TextStyle(
            fontSize: 26,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
            color: AppColors.darkGray,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
            color: AppColors.darkGray,
          ),
          titleLarge: const TextStyle(
            fontSize: 19,
            height: 1.25,
            fontWeight: FontWeight.w800,
            letterSpacing: -.35,
            color: AppColors.darkGray,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
            color: AppColors.darkGray,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.1,
            color: AppColors.darkGray,
          ),
          bodyLarge: const TextStyle(
            fontSize: 15.5,
            height: 1.5,
            color: AppColors.darkGray,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.darkGray,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.lightText,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
            color: AppColors.lightText,
          ),
        )
        .apply(fontFamily: fontFamily);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightGrayBg,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        shape: Border(bottom: BorderSide(color: AppColors.border)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
          color: AppColors.darkGray,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: AppColors.lightText, fontSize: 14.5),
        labelStyle: const TextStyle(color: AppColors.lightText),
        floatingLabelStyle: const TextStyle(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.lightText,
        suffixIconColor: AppColors.lightText,
        border: border,
        enabledBorder: border,
        disabledBorder: border.copyWith(
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: .6)),
        ),
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
        ),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.field,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(48, 48),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.field,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: controlShape,
          foregroundColor: AppColors.darkGray,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.actionRed,
          shape: controlShape,
          textStyle: buttonText.copyWith(fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 24,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
          color: AppColors.darkGray,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: const Color(0x331B2130),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGray,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkGray,
        shape: controlShape,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: buttonText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryRed,
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.field;
          return states.contains(WidgetState.selected)
              ? AppColors.primaryRed
              : AppColors.surface;
        }),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryRed
                : AppColors.border,
          ),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.darkGray,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 46)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.softPink),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(buttonText),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primaryRed
                : AppColors.softPink,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.darkGray,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.actionRed,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryRed,
        linearTrackColor: AppColors.softPink,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.lightText,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGray,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: AppColors.lightText,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AppColors.muted, width: 1.5),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final BoxFit fit;
  const AppLogo({
    super.key,
    this.width = 40,
    this.height = 40,
    this.fit = BoxFit.contain,
  });
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/sk logo.png',
    width: width,
    height: height,
    fit: fit,
    semanticLabel: 'SK 360 logo',
  );
}

/// The logo inside a soft white tile, used wherever the brand mark appears.
class AppLogoTile extends StatelessWidget {
  final double size;
  const AppLogoTile({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .1),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(size * .3),
      border: Border.all(color: AppColors.border),
      boxShadow: AppDecorations.softShadow,
    ),
    child: const AppLogo(),
  );
}

class AppHeader extends StatelessWidget {
  final String appName;
  final String subtitle;
  const AppHeader({
    super.key,
    this.appName = 'SK 360°',
    this.subtitle = 'Youth governance · Lipa City',
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        const AppLogoTile(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appName, style: Theme.of(context).textTheme.titleLarge),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Scrollable authentication layout, including keyboard and safe-area support.
/// A red brand hero with soft line-work carries the heading, and the form card
/// floats over its curved lower edge.
class AppAuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final String? step;
  final bool showBack;
  const AppAuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.step,
    this.showBack = true,
  });

  /// How far the form card rises into the hero.
  static const _overlap = 56.0;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
    child: Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(right: -130, bottom: -110, child: _AuthGlow(340)),
          const Positioned(left: -150, bottom: 150, child: _AuthGlow(260)),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthHero(
                    title: title,
                    subtitle: subtitle,
                    step: step,
                    showBack: showBack && Navigator.canPop(context),
                    bottomPadding: 32 + _overlap,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -_overlap),
                    child: _AuthColumn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x247F1D1D),
                                  blurRadius: 36,
                                  spreadRadius: -8,
                                  offset: Offset(0, 18),
                                ),
                                BoxShadow(
                                  color: Color(0x0A101828),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: AutofillGroup(child: child),
                          ),
                          const SizedBox(height: 24),
                          const Text.rich(
                            TextSpan(
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.verified_user_outlined,
                                      size: 15,
                                      color: AppColors.lightText,
                                    ),
                                  ),
                                ),
                                TextSpan(text: 'SK 360° · City of Lipa'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.lightText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Centers auth content at a readable width on tablets and desktops.
class _AuthColumn extends StatelessWidget {
  final Widget child;
  const _AuthColumn({required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      ),
    ),
  );
}

class _AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? step;
  final bool showBack;
  final double bottomPadding;
  const _AuthHero({
    required this.title,
    required this.subtitle,
    required this.step,
    required this.showBack,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onRed = Colors.white;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE53A3A),
              AppColors.primaryRed,
              Color(0xFFB01B25),
            ],
            stops: [0, .45, 1],
          ),
        ),
        child: CustomPaint(
          painter: const _AuthHeroPainter(),
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 16,
              bottom: bottomPadding,
            ),
            child: _AuthColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBack) ...[
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: onRed.withValues(alpha: .16),
                            foregroundColor: onRed,
                            fixedSize: const Size(44, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: onRed.withValues(alpha: .22),
                              ),
                            ),
                          ),
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const AppLogoTile(size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SK 360°',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: onRed,
                              ),
                            ),
                            Text(
                              'Youth governance · Lipa City',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onRed.withValues(alpha: .8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (step != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: onRed.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: onRed.withValues(alpha: .24)),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: onRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            TextSpan(text: step!.toUpperCase()),
                          ],
                        ),
                        style: const TextStyle(
                          color: onRed,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: onRed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: onRed.withValues(alpha: .86),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft light and line-work that give the red hero depth without noise:
/// concentric rings from the top-right corner and a dot grid that fades out
/// from the lower left.
class _AuthHeroPainter extends CustomPainter {
  const _AuthHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final light = Offset(size.width * .9, 0);
    final lightRadius = size.longestSide * .75;
    canvas.drawCircle(
      light,
      lightRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: light, radius: lightRadius)),
    );

    final shade = Offset(0, size.height);
    final shadeRadius = size.longestSide * .6;
    canvas.drawCircle(
      shade,
      shadeRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7F1D1D).withValues(alpha: .28),
            const Color(0xFF7F1D1D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: shade, radius: shadeRadius)),
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final ringCenter = Offset(size.width - 8, 36);
    for (var i = 0; i < 5; i++) {
      ring.color = Colors.white.withValues(alpha: .14 - i * .02);
      canvas.drawCircle(ringCenter, 60.0 + i * 48, ring);
    }

    const gap = 18.0;
    final reach = size.shortestSide * .9;
    final dot = Paint();
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width * .6; x += gap) {
        final fade = 1 - (Offset(x, y) - shade).distance / reach;
        if (fade <= 0) continue;
        dot.color = Colors.white.withValues(alpha: .2 * fade);
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_AuthHeroPainter oldDelegate) => false;
}

/// A faint red glow that keeps the white lower half from feeling empty.
class _AuthGlow extends StatelessWidget {
  final double size;
  const _AuthGlow(this.size);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primaryRed.withValues(alpha: .09),
            AppColors.primaryRed.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class AppInputField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool isPassword;
  final bool hasIcon;
  final IconData? iconData;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final bool enabled;
  final TextCapitalization textCapitalization;
  const AppInputField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.isPassword = false,
    this.hasIcon = false,
    this.iconData,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.maxLength,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });
  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField> {
  late bool _obscureText = widget.isPassword;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        onSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        maxLength: widget.maxLength,
        autocorrect: !widget.isPassword,
        enableSuggestions: !widget.isPassword,
        inputFormatters:
            widget.maxLength == 6 && widget.keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          hintText: widget.hintText,
          counterText: '',
          prefixIcon: widget.hasIcon ? Icon(widget.iconData, size: 20) : null,
          suffixIcon: widget.isPassword
              ? IconButton(
                  tooltip: _obscureText ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    ],
  );
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double width;
  final double height;
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 52,
  });
  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? AppColors.muted : AppColors.primaryRed,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          )
        : Text(label, textAlign: TextAlign.center);
    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: isPrimary
            ? FilledButton(
                onPressed: isLoading ? null : onPressed,
                child: content,
              )
            : OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                child: content,
              ),
      ),
    );
  }
}

class AppCheckboxAgreement extends StatelessWidget {
  final bool isChecked;
  final ValueChanged<bool> onChanged;
  final String text;
  const AppCheckboxAgreement({
    super.key,
    required this.isChecked,
    required this.onChanged,
    required this.text,
  });
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: isChecked,
    onChanged: (value) => onChanged(value ?? false),
    title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: AppDecorations.surface(color: color),
    child: child,
  );
}

/// A card with a thin colored strip on its leading edge. The accent carries
/// the record's state (red active, orange attention, gray inactive, …).
class AppAccentCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double accentWidth;

  const AppAccentCard({
    super.key,
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 16, 16),
    this.onTap,
    this.color = AppColors.surface,
    this.accentWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpace.radius);
    return DecoratedBox(
      decoration: AppDecorations.surface(color: color),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Padding(padding: padding, child: child),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: accentWidth,
                  child: ColoredBox(color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const LinearProgressIndicator(
    minHeight: 3,
    semanticsLabel: 'Refreshing records',
  );
}

class AppSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;
  const AppSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppColors.primaryRed),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          // Badges and links wrap rather than crowd out the title.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .5),
            child: action,
          ),
        ],
      ],
    ),
  );
}

/// Small uppercase caption for grouping a block, e.g. "SUBMISSION METRICS".
class AppOverline extends StatelessWidget {
  final String label;
  final Widget? action;
  const AppOverline(this.label, {super.key, this.action});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.lightText,
          ),
        ),
      ),
      ?action,
    ],
  );
}

/// A small tinted pill that introduces a page or block.
class AppEyebrow extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const AppEyebrow({
    super.key,
    required this.label,
    this.color = AppColors.primaryRed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: color.withValues(alpha: .12)),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: icon == null
                  ? Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    )
                  : Icon(icon, size: 14, color: color),
            ),
          ),
          TextSpan(text: label.toUpperCase()),
        ],
      ),
      style: TextStyle(
        color: _ink(color),
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );
}

/// Eyebrow, large title and supporting copy at the top of a page.
class AppPageIntro extends StatelessWidget {
  final String? eyebrow;
  final IconData? eyebrowIcon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  const AppPageIntro({
    super.key,
    required this.title,
    this.eyebrow,
    this.eyebrowIcon,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium,
    );
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            AppEyebrow(label: eyebrow!, icon: eyebrowIcon),
            const SizedBox(height: 12),
          ],
          if (action == null)
            heading
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 12), action!],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    action!,
                  ],
                );
              },
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.lightText,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;
  final IconData? icon;
  const AppStatusBadge({
    super.key,
    required this.label,
    this.color = AppColors.lightText,
    this.dot = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          if (dot || icon != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: icon != null
                    ? Icon(icon, size: 13, color: color)
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
          TextSpan(text: label),
        ],
      ),
      style: TextStyle(
        color: _ink(color),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String actionLabel;
  final Color color;
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel = 'Try again',
    this.color = AppColors.primaryRed,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .1)),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (onAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ],
    ),
  );
}

/// A compact metric card: label and icon on top, a large value, and a short
/// caption. [color] tints the icon and, when [dot] is set, a status dot.
class AppStatistic extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final String? caption;
  final Color? captionColor;
  final bool dot;
  const AppStatistic({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.primaryRed,
    this.caption,
    this.captionColor,
    this.dot = false,
  });
  static const _padding = EdgeInsets.fromLTRB(14, 14, 14, 16);

  @override
  Widget build(BuildContext context) {
    // Inside AppMetricGrid the cell width is known up front, which keeps the
    // card compatible with the grid's equal-height (intrinsic) rows.
    final cellWidth = context
        .dependOnInheritedWidgetOfExactType<_MetricCellWidth>()
        ?.width;
    return AppSurface(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cellWidth != null)
            _header(context, cellWidth - _padding.horizontal - 2)
          else
            LayoutBuilder(
              builder: (context, constraints) =>
                  _header(context, constraints.maxWidth),
            ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: captionColor ?? AppColors.lightText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, double maxWidth) {
    final labelText = Text.rich(
      TextSpan(
        children: [
          if (dot)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          TextSpan(text: label),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12.5,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.lightText,
      ),
    );
    if (icon == null) return labelText;
    final tile = AppIconTile(icon: icon!, color: color, size: 17);
    if (maxWidth < 110 || MediaQuery.textScalerOf(context).scale(14) > 19) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [tile, const SizedBox(height: 10), labelText],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: labelText,
          ),
        ),
        const SizedBox(width: 8),
        tile,
      ],
    );
  }
}

class _MetricCellWidth extends InheritedWidget {
  final double width;
  const _MetricCellWidth({required this.width, required super.child});

  @override
  bool updateShouldNotify(_MetricCellWidth oldWidget) =>
      width != oldWidget.width;
}

/// Lays out metric cards two (or more) per row, collapsing on narrow screens.
class AppMetricGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;
  const AppMetricGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final perRow = columns > 2 && constraints.maxWidth < 330
          ? 2
          : columns.clamp(1, children.length);
      final width =
          (constraints.maxWidth - spacing * (perRow - 1)) / perRow - .01;
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += perRow) {
        final slice = children.skip(i).take(perRow).toList();
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < slice.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Builder(
                    builder: (context) {
                      final cell = slice.length == 1 && perRow > 1
                          ? constraints.maxWidth
                          : width;
                      return SizedBox(
                        width: cell,
                        child: _MetricCellWidth(width: cell, child: slice[j]),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      }
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            rows[i],
          ],
        ],
      );
    },
  );
}

/// A consistent icon treatment for metrics, shortcuts, and record headers.
class AppIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool circle;
  const AppIconTile({
    super.key,
    required this.icon,
    this.color = AppColors.primaryRed,
    this.size = 22,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(size * .45),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(size * .6),
    ),
    child: Icon(icon, color: color, size: size),
  );
}

/// An image thumbnail, or a soft illustrated placeholder when there is none.
class AppThumbnail extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String? imageUrl;
  final bool dimmed;
  const AppThumbnail({
    super.key,
    required this.icon,
    this.color = AppColors.primaryRed,
    this.size = 64,
    this.imageUrl,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .26);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .16), color.withValues(alpha: .05)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -size * .16,
            top: -size * .16,
            child: Container(
              width: size * .56,
              height: size * .56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: size * .1,
            bottom: size * .1,
            child: Container(
              width: size * .14,
              height: size * .14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Icon(icon, size: size * .42, color: color),
          ),
        ],
      ),
    );
    final child = imageUrl?.isNotEmpty == true
        ? Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          )
        : placeholder;
    return Opacity(
      opacity: dimmed ? .6 : 1,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: color.withValues(alpha: .12)),
        ),
        child: child,
      ),
    );
  }
}

/// Month and day stacked in a tinted block, used for events and meetings.
class AppDateBlock extends StatelessWidget {
  final DateTime? date;
  final Color color;
  final double width;
  const AppDateBlock({
    super.key,
    required this.date,
    this.color = AppColors.primaryRed,
    this.width = 54,
  });

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .1)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          date == null ? '---' : _months[date!.month - 1],
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
            color: _ink(color),
          ),
        ),
        Text(
          date == null ? '--' : '${date!.day}'.padLeft(2, '0'),
          style: TextStyle(
            fontSize: 21,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: _ink(color),
          ),
        ),
      ],
    ),
  );
}

/// An inline icon + label used for record metadata (dates, counts, owners).
class AppMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? textColor;
  const AppMeta({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(icon, size: 15, color: color ?? AppColors.lightText),
          ),
        ),
        TextSpan(text: label),
      ],
    ),
    style: TextStyle(
      fontSize: 12.5,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: textColor ?? AppColors.lightText,
    ),
  );
}

/// One search field style for every list in the app.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCleared;
  final Widget? trailing;
  final Color fillColor;
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onCleared,
    this.trailing,
    this.fillColor = AppColors.field,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          suffixIcon: value.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                    onCleared?.call();
                  },
                )
              : trailing,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: AppColors.primaryRed,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling pill filters: red when active, white otherwise.
class AppFilterPills extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<int?>? counts;
  final EdgeInsetsGeometry padding;
  const AppFilterPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
            child: ChoiceChip(
              label: Text(
                counts?[i] == null ? labels[i] : '${labels[i]} (${counts![i]})',
              ),
              selected: i == selectedIndex,
              showCheckmark: false,
              onSelected: (_) => onSelected(i),
            ),
          ),
      ],
    ),
  );
}

/// The prominent, full-width create action used on management pages.
class AppActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: .28),
                blurRadius: 18,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      icon: Icon(icon, size: 22),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// Compact buttons for actions at the foot of a record card.
abstract final class AppCardButtonStyle {
  static ButtonStyle primary({Color color = AppColors.primaryRed}) =>
      FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      );

  static ButtonStyle secondary({Color color = AppColors.darkGray}) =>
      OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: AppColors.subtle,
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      );
}

/// Form rows stack when labels or text scaling need more room.
class AppAdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  const AppAdaptiveRow({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(14) > 19) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children)
              if (child is Expanded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child.child,
                )
              else if (child is! SizedBox)
                child,
          ],
        );
      }
      return Row(children: children);
    },
  );
}

/// The rounded, lightly filled icon button used in page headers.
class AppHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const AppHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    style: IconButton.styleFrom(
      backgroundColor: AppColors.field,
      foregroundColor: AppColors.darkGray,
      fixedSize: const Size(44, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 22),
  );
}

/// Keeps form controllers alive until the dialog's exit transition completes.
/// The future returned by showDialog completes earlier, when the route pops.
class AppDialogForm extends StatefulWidget {
  final Widget Function(BuildContext, List<TextEditingController>) builder;
  final int controllerCount;

  const AppDialogForm({
    super.key,
    required this.builder,
    this.controllerCount = 2,
  });

  @override
  State<AppDialogForm> createState() => _AppDialogFormState();
}

class _AppDialogFormState extends State<AppDialogForm> {
  late final _controllers = List.generate(
    widget.controllerCount,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}
