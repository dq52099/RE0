import 'package:flutter/material.dart';

enum BrandStyle {
  botw,
  re0,
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
  final BorderRadius historyImageRadius;
  final ThemeData theme;

  String get id => style.name;
}

class AppBrands {
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
    historyImageRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    theme: _re0Theme,
  );

  static List<AppBrand> get all => [re0, botw];

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
