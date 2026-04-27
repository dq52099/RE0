import 'package:flutter/material.dart';

enum BrandStyle {
  botw,
  re0,
  genshin,
  starRail,
  wuthering,
  zzz,
  yanyun,
}

class AppBrand {
  const AppBrand({
    required this.style,
    required this.appTitle,
    required this.loginTitle,
    required this.generateTabLabel,
    required this.editTabLabel,
    required this.historyTabLabel,
    required this.generateTitle,
    required this.editTitle,
    required this.historyTitle,
    required this.promptLabel,
    required this.editPromptLabel,
    required this.generatePromptHint,
    required this.editPromptHint,
    required this.generateQuotaLabel,
    required this.editQuotaLabel,
    required this.generateButtonLabel,
    required this.editButtonLabel,
    required this.generateLoadingText,
    required this.editLoadingText,
    required this.generateErrorLabel,
    required this.editErrorLabel,
    required this.generateActionLabel,
    required this.editActionLabel,
    required this.emptyHistoryText,
    required this.pickImageText,
    required this.consoleTitle,
    required this.galleryAlbumName,
    required this.primaryColor,
    required this.warningColor,
    required this.successColor,
    required this.panelColor,
    required this.backgroundAsset,
    required this.backgroundOverlay,
    required this.backgroundOverlayOpacity,
    required this.historyImageRadius,
    required this.theme,
  });

  final BrandStyle style;
  final String appTitle;
  final String loginTitle;
  final String generateTabLabel;
  final String editTabLabel;
  final String historyTabLabel;
  final String generateTitle;
  final String editTitle;
  final String historyTitle;
  final String promptLabel;
  final String editPromptLabel;
  final String generatePromptHint;
  final String editPromptHint;
  final String generateQuotaLabel;
  final String editQuotaLabel;
  final String generateButtonLabel;
  final String editButtonLabel;
  final String generateLoadingText;
  final String editLoadingText;
  final String generateErrorLabel;
  final String editErrorLabel;
  final String generateActionLabel;
  final String editActionLabel;
  final String emptyHistoryText;
  final String pickImageText;
  final String consoleTitle;
  final String galleryAlbumName;
  final Color primaryColor;
  final Color warningColor;
  final Color successColor;
  final Color panelColor;
  final String backgroundAsset;
  final Color backgroundOverlay;
  final double backgroundOverlayOpacity;
  final BorderRadius historyImageRadius;
  final ThemeData theme;

  String get id => style.name;
}

class AppBrands {
  static AppBrand _standard({
    required BrandStyle style,
    required String title,
    required String backgroundAsset,
    required Color primaryColor,
    required Color warningColor,
    required Color successColor,
    required Color panelColor,
    required Color backgroundOverlay,
    required double backgroundOverlayOpacity,
    required ThemeData theme,
  }) {
    return AppBrand(
      style: style,
      appTitle: title,
      loginTitle: '登录 $title',
      generateTabLabel: '生图',
      editTabLabel: '改图',
      historyTabLabel: '记忆回廊',
      generateTitle: '$title - 生图',
      editTitle: '$title - 改图',
      historyTitle: '$title - 记忆回廊',
      promptLabel: '提示词',
      editPromptLabel: '改图提示词',
      generatePromptHint: '描述你想要生成的画面...',
      editPromptHint: '描述你想要如何修改这张图...',
      generateQuotaLabel: '生图额度',
      editQuotaLabel: '改图额度',
      generateButtonLabel: '开始生图',
      editButtonLabel: '开始改图',
      generateLoadingText: '图片生成中...',
      editLoadingText: '图片修改中...',
      generateErrorLabel: '生图失败',
      editErrorLabel: '改图失败',
      generateActionLabel: '生图',
      editActionLabel: '改图',
      emptyHistoryText: '暂无历史记录',
      pickImageText: '点击选择原图',
      consoleTitle: title,
      galleryAlbumName: title,
      primaryColor: primaryColor,
      warningColor: warningColor,
      successColor: successColor,
      panelColor: panelColor,
      backgroundAsset: backgroundAsset,
      backgroundOverlay: backgroundOverlay,
      backgroundOverlayOpacity: backgroundOverlayOpacity,
      historyImageRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      theme: theme,
    );
  }

  static final botw = AppBrand(
    style: BrandStyle.botw,
    appTitle: '希卡之石',
    loginTitle: '登录希卡之石',
    generateTabLabel: '具现化',
    editTabLabel: '时间回溯',
    historyTabLabel: '希卡图鉴',
    generateTitle: '魔法终端 - 具现化',
    editTitle: '时间回溯 - 改图',
    historyTitle: '希卡图鉴 - 历史',
    promptLabel: '编写符文 (Runes)',
    editPromptLabel: '修正符文 (Edit Prompt)',
    generatePromptHint: '描述你想要具现化的景象...',
    editPromptHint: '描述你想要如何改变这张图...',
    generateQuotaLabel: '生图电池',
    editQuotaLabel: '改图电池',
    generateButtonLabel: '开始具现化',
    editButtonLabel: '开始时间回溯',
    generateLoadingText: '正在与世界根源沟通...',
    editLoadingText: '时间回溯中...',
    generateErrorLabel: '具现化失败',
    editErrorLabel: '回归失败',
    generateActionLabel: '具现化',
    editActionLabel: '时间回溯',
    emptyHistoryText: '回廊空空如也',
    pickImageText: '点击选择需要回归的原图',
    consoleTitle: '控制台',
    galleryAlbumName: '希卡之石',
    primaryColor: const Color(0xFF00D2FF),
    warningColor: const Color(0xFFFF9600),
    successColor: const Color(0xFF00FF99),
    panelColor: const Color(0xFF121212),
    backgroundAsset: 'assets/backgrounds/botw.png',
    backgroundOverlay: const Color(0xFF061417),
    backgroundOverlayOpacity: 0.68,
    historyImageRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    theme: _botwTheme,
  );

  static final re0 = AppBrand(
    style: BrandStyle.re0,
    appTitle: 'RE0',
    loginTitle: '登录 RE0',
    generateTabLabel: '咏唱',
    editTabLabel: '死亡回归',
    historyTabLabel: '记忆回廊',
    generateTitle: '魔法终端 - 咏唱',
    editTitle: '死亡回归 - 改图',
    historyTitle: '记忆回廊 - 历史',
    promptLabel: '编写咒文 (Spells)',
    editPromptLabel: '修正咒文 (Edit Prompt)',
    generatePromptHint: '描述你想要咏唱出的景象...',
    editPromptHint: '描述你想要如何改变这张图...',
    generateQuotaLabel: '生图玛那',
    editQuotaLabel: '改图玛那',
    generateButtonLabel: '开始咏唱',
    editButtonLabel: '开始死亡回归',
    generateLoadingText: '正在与世界根源沟通...',
    editLoadingText: '时间回溯中...',
    generateErrorLabel: '咏唱失败',
    editErrorLabel: '回归失败',
    generateActionLabel: '咏唱',
    editActionLabel: '死亡回归',
    emptyHistoryText: '回廊空空如也',
    pickImageText: '点击选择需要回归的原图',
    consoleTitle: '圣域',
    galleryAlbumName: 'RE0',
    primaryColor: const Color(0xFF4682B4),
    warningColor: const Color(0xFFD4AF37),
    successColor: const Color(0xFF7FFFD4),
    panelColor: const Color(0xFFE6E6FA),
    backgroundAsset: 'assets/backgrounds/re0.png',
    backgroundOverlay: const Color(0xFFF8FBFF),
    backgroundOverlayOpacity: 0.72,
    historyImageRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    theme: _re0Theme,
  );

  static final genshin = _standard(
    style: BrandStyle.genshin,
    title: '原神',
    backgroundAsset: 'assets/backgrounds/genshin.png',
    primaryColor: const Color(0xFF2E8B57),
    warningColor: const Color(0xFFC5892F),
    successColor: const Color(0xFF4ECDC4),
    panelColor: const Color(0xFFF8F4E3),
    backgroundOverlay: const Color(0xFFFFFEF6),
    backgroundOverlayOpacity: 0.70,
    theme: _genshinTheme,
  );

  static final starRail = _standard(
    style: BrandStyle.starRail,
    title: '星穹铁道',
    backgroundAsset: 'assets/backgrounds/star_rail.png',
    primaryColor: const Color(0xFF5B7CFA),
    warningColor: const Color(0xFFD0A43A),
    successColor: const Color(0xFF5AD7FF),
    panelColor: const Color(0xFF14182A),
    backgroundOverlay: const Color(0xFF060A18),
    backgroundOverlayOpacity: 0.70,
    theme: _starRailTheme,
  );

  static final wuthering = _standard(
    style: BrandStyle.wuthering,
    title: '鸣潮',
    backgroundAsset: 'assets/backgrounds/wuthering.png',
    primaryColor: const Color(0xFF1B8C8F),
    warningColor: const Color(0xFFE6A73A),
    successColor: const Color(0xFF2ED3B7),
    panelColor: const Color(0xFFEAF3F2),
    backgroundOverlay: const Color(0xFFF7FCFB),
    backgroundOverlayOpacity: 0.68,
    theme: _wutheringTheme,
  );

  static final zzz = _standard(
    style: BrandStyle.zzz,
    title: '绝区零',
    backgroundAsset: 'assets/backgrounds/zzz.png',
    primaryColor: const Color(0xFFE6C229),
    warningColor: const Color(0xFFFF6B35),
    successColor: const Color(0xFF42E8B4),
    panelColor: const Color(0xFF171717),
    backgroundOverlay: const Color(0xFF090909),
    backgroundOverlayOpacity: 0.70,
    theme: _zzzTheme,
  );

  static final yanyun = _standard(
    style: BrandStyle.yanyun,
    title: '烟云十六声',
    backgroundAsset: 'assets/backgrounds/yanyun.png',
    primaryColor: const Color(0xFF7D4E2D),
    warningColor: const Color(0xFFB86F32),
    successColor: const Color(0xFF4E8F6A),
    panelColor: const Color(0xFFF4EFE7),
    backgroundOverlay: const Color(0xFFFFFBF4),
    backgroundOverlayOpacity: 0.72,
    theme: _yanyunTheme,
  );

  static List<AppBrand> get all => [
        re0,
        genshin,
        starRail,
        wuthering,
        zzz,
        yanyun,
        botw,
      ];

  static AppBrand byId(String? id) {
    return all.firstWhere(
      (brand) => brand.id == id,
      orElse: () => re0,
    );
  }
}

final ThemeData _botwTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00D2FF),
    secondary: Color(0xFFFF9600),
    surface: Color(0xFF2A2A2A),
  ),
  cardTheme: CardTheme(
    color: const Color(0xFF2A2A2A).withOpacity(0.8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: const BorderSide(color: Color(0xFF00D2FF), width: 0.5),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.black.withOpacity(0.4),
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF00D2FF)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white24),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF00D2FF), width: 2),
    ),
    hintStyle: TextStyle(
      color: const Color(0xFF00D2FF).withOpacity(0.4),
      fontSize: 14,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFF00D2FF),
      side: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: Color(0xFF00D2FF),
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
    bodyLarge: TextStyle(color: Colors.white70),
  ),
);

ThemeData _lightTheme({
  required Color primary,
  required Color secondary,
  required Color surface,
  required Color background,
  Color error = const Color(0xFFA23535),
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    cardTheme: CardTheme(
      color: surface.withOpacity(0.92),
      elevation: 2,
      shadowColor: primary.withOpacity(0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: primary.withOpacity(0.14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface.withOpacity(0.78),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary.withOpacity(0.24)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: primary,
      titleTextStyle: TextStyle(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

ThemeData _darkTheme({
  required Color primary,
  required Color secondary,
  required Color surface,
  required Color background,
  Color error = const Color(0xFFFF6B6B),
}) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    cardTheme: CardTheme(
      color: surface.withOpacity(0.9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: primary.withOpacity(0.24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withOpacity(0.32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: primary,
      titleTextStyle: TextStyle(
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

final ThemeData _genshinTheme = _lightTheme(
  primary: const Color(0xFF2E8B57),
  secondary: const Color(0xFFC5892F),
  surface: const Color(0xFFFFFFFF),
  background: const Color(0xFFF8F9F0),
);

final ThemeData _starRailTheme = _darkTheme(
  primary: const Color(0xFF7EA2FF),
  secondary: const Color(0xFFD0A43A),
  surface: const Color(0xFF161C30),
  background: const Color(0xFF080B16),
);

final ThemeData _wutheringTheme = _lightTheme(
  primary: const Color(0xFF1B8C8F),
  secondary: const Color(0xFFE6A73A),
  surface: const Color(0xFFFFFFFF),
  background: const Color(0xFFF0F7F6),
);

final ThemeData _zzzTheme = _darkTheme(
  primary: const Color(0xFFE6C229),
  secondary: const Color(0xFFFF6B35),
  surface: const Color(0xFF181818),
  background: const Color(0xFF0D0D0D),
);

final ThemeData _yanyunTheme = _lightTheme(
  primary: const Color(0xFF7D4E2D),
  secondary: const Color(0xFFB86F32),
  surface: const Color(0xFFFFFCF6),
  background: const Color(0xFFF5F0E8),
);

final ThemeData _re0Theme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF4682B4),
    secondary: Color(0xFFE6E6FA),
    surface: Color(0xFFFDFDFD),
    error: Color(0xFFA23535),
  ),
  scaffoldBackgroundColor: const Color(0xFFFDFDFD),
  cardTheme: CardTheme(
    color: Colors.white.withOpacity(0.9),
    elevation: 8,
    shadowColor: const Color(0xFF4682B4).withOpacity(0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: const Color(0xFFE6E6FA).withOpacity(0.5),
        width: 1.5,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFE6E6FA).withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE6E6FA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: const Color(0xFFE6E6FA).withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF4682B4), width: 2),
    ),
    labelStyle: const TextStyle(
      color: Color(0xFF2C3E50),
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF4682B4),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      elevation: 4,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: Color(0xFF2C3E50),
      fontSize: 22,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
  ),
);
