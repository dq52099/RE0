import 'package:flutter/material.dart';

const String _cnFontFamily = 'sans-serif';
const List<String> _cnFontFallback = [
  'PingFang SC',
  'Hiragino Sans GB',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'Microsoft YaHei',
  'WenQuanYi Micro Hei',
];
const String _cnHeadingFontFamily = 'sans-serif';
const List<String> _cnHeadingFallback = _cnFontFallback;

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
    required this.galleryTabLabel,
    required this.favoriteTabLabel,
    required this.generateTitle,
    required this.editTitle,
    required this.historyTitle,
    required this.galleryTitle,
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
  final String galleryTabLabel;
  final String favoriteTabLabel;
  final String generateTitle;
  final String editTitle;
  final String historyTitle;
  final String galleryTitle;
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
    String? generateTabLabel,
    String? editTabLabel,
    String? historyTabLabel,
    String? galleryTabLabel,
    String? favoriteTabLabel,
    String? generateTitle,
    String? editTitle,
    String? historyTitle,
    String? galleryTitle,
    String? promptLabel,
    String? editPromptLabel,
    String? generatePromptHint,
    String? editPromptHint,
    String? generateQuotaLabel,
    String? editQuotaLabel,
    String? generateButtonLabel,
    String? editButtonLabel,
    String? generateLoadingText,
    String? editLoadingText,
    String? generateErrorLabel,
    String? editErrorLabel,
    String? generateActionLabel,
    String? editActionLabel,
    String? emptyHistoryText,
    String? pickImageText,
    String? consoleTitle,
  }) {
    return AppBrand(
      style: style,
      appTitle: title,
      loginTitle: '登录 $title',
      generateTabLabel: generateTabLabel ?? '生图',
      editTabLabel: editTabLabel ?? '改图',
      historyTabLabel: historyTabLabel ?? '记忆回廊',
      galleryTabLabel: galleryTabLabel ?? '画廊',
      favoriteTabLabel: favoriteTabLabel ?? '收藏',
      generateTitle: generateTitle ?? '$title - 生图',
      editTitle: editTitle ?? '$title - 改图',
      historyTitle: historyTitle ?? '$title - 记忆回廊',
      galleryTitle: galleryTitle ?? '$title - 画廊',
      promptLabel: promptLabel ?? '提示词',
      editPromptLabel: editPromptLabel ?? '改图提示词',
      generatePromptHint: generatePromptHint ?? '描述你想要生成的画面...',
      editPromptHint: editPromptHint ?? '描述你想要如何修改这张图...',
      generateQuotaLabel: generateQuotaLabel ?? '生图额度',
      editQuotaLabel: editQuotaLabel ?? '改图额度',
      generateButtonLabel: generateButtonLabel ?? '开始生图',
      editButtonLabel: editButtonLabel ?? '开始改图',
      generateLoadingText: generateLoadingText ?? '图片生成中...',
      editLoadingText: editLoadingText ?? '图片修改中...',
      generateErrorLabel: generateErrorLabel ?? '生图失败',
      editErrorLabel: editErrorLabel ?? '改图失败',
      generateActionLabel: generateActionLabel ?? '生图',
      editActionLabel: editActionLabel ?? '改图',
      emptyHistoryText: emptyHistoryText ?? '暂无历史记录',
      pickImageText: pickImageText ?? '点击选择原图',
      consoleTitle: consoleTitle ?? title,
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
    galleryTabLabel: '希卡画廊',
    favoriteTabLabel: '珍藏符匣',
    generateTitle: '魔法终端 - 具现化',
    editTitle: '时间回溯 - 改图',
    historyTitle: '希卡图鉴 - 历史',
    galleryTitle: '希卡画廊 - 展示',
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
    appTitle: '从零开始',
    loginTitle: 'Re0:ゼロから始める異世界生図',
    generateTabLabel: '咏唱',
    editTabLabel: '死亡回归',
    historyTabLabel: '记忆回廊',
    galleryTabLabel: '圣域画廊',
    favoriteTabLabel: '契约珍藏',
    generateTitle: '魔法终端 - 咏唱',
    editTitle: '死亡回归 - 改图',
    historyTitle: '记忆回廊 - 历史',
    galleryTitle: '露格尼卡圣域 - 画廊',
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
    consoleTitle: '露格尼卡圣域',
    galleryAlbumName: '从零开始',
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
    generateTabLabel: '元素绘卷',
    editTabLabel: '炼金重塑',
    historyTabLabel: '冒险图鉴',
    galleryTabLabel: '旅人画廊',
    favoriteTabLabel: '珍藏绘卷',
    generateTitle: '提瓦特画架 - 元素绘卷',
    editTitle: '炼金工坊 - 改图',
    historyTitle: '冒险图鉴 - 历史',
    galleryTitle: '旅人画廊 - 展示',
    promptLabel: '元素灵感',
    editPromptLabel: '炼金指令',
    generatePromptHint: '写下风、岩、雷、草等元素交织的画面...',
    editPromptHint: '描述要如何重新调和这张图...',
    generateQuotaLabel: '原石能量',
    editQuotaLabel: '炼金素材',
    generateButtonLabel: '发动元素绘卷',
    editButtonLabel: '开始炼金重塑',
    generateLoadingText: '元素力正在汇聚...',
    editLoadingText: '炼金台正在重构画面...',
    generateActionLabel: '元素绘卷',
    editActionLabel: '炼金重塑',
    emptyHistoryText: '冒险图鉴尚未收录',
    pickImageText: '选择需要炼金的原图',
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
    generateTabLabel: '跃迁成像',
    editTabLabel: '星轨回溯',
    historyTabLabel: '列车档案',
    galleryTabLabel: '列车展厅',
    favoriteTabLabel: '跃迁收藏',
    generateTitle: '星穹列车 - 跃迁成像',
    editTitle: '模拟宇宙 - 星轨回溯',
    historyTitle: '列车档案 - 历史',
    galleryTitle: '星穹列车 - 展厅',
    promptLabel: '开拓坐标',
    editPromptLabel: '回溯指令',
    generatePromptHint: '描述一段跨越星海的开拓影像...',
    editPromptHint: '描述要如何改写这段星轨画面...',
    generateQuotaLabel: '开拓燃料',
    editQuotaLabel: '回溯燃料',
    generateButtonLabel: '启动跃迁',
    editButtonLabel: '启动星轨回溯',
    generateLoadingText: '列车正在跃迁...',
    editLoadingText: '星轨正在重排...',
    generateActionLabel: '跃迁成像',
    editActionLabel: '星轨回溯',
    emptyHistoryText: '列车档案暂无记录',
    pickImageText: '选择需要回溯的影像',
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
    generateTabLabel: '共鸣成像',
    editTabLabel: '声纹调律',
    historyTabLabel: '回声档案',
    galleryTabLabel: '共鸣画廊',
    favoriteTabLabel: '回声珍藏',
    generateTitle: '共鸣终端 - 成像',
    editTitle: '声纹调律 - 改图',
    historyTitle: '回声档案 - 历史',
    galleryTitle: '共鸣画廊 - 展示',
    promptLabel: '共鸣频谱',
    editPromptLabel: '调律指令',
    generatePromptHint: '描述潮声、频谱与废墟共鸣出的画面...',
    editPromptHint: '描述要如何重新调律这张图...',
    generateQuotaLabel: '共鸣能量',
    editQuotaLabel: '调律能量',
    generateButtonLabel: '释放共鸣',
    editButtonLabel: '开始声纹调律',
    generateLoadingText: '频谱正在校准...',
    editLoadingText: '回声正在重构...',
    generateActionLabel: '共鸣成像',
    editActionLabel: '声纹调律',
    emptyHistoryText: '回声档案暂无记录',
    pickImageText: '选择需要调律的原图',
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
    generateTabLabel: '委托影像',
    editTabLabel: '录像剪辑',
    historyTabLabel: '录像仓库',
    galleryTabLabel: '街区橱窗',
    favoriteTabLabel: '收藏录像',
    generateTitle: '新艾利都 - 委托影像',
    editTitle: '录像店 - 剪辑改图',
    historyTitle: '录像仓库 - 历史',
    galleryTitle: '新艾利都 - 橱窗',
    promptLabel: '委托说明',
    editPromptLabel: '剪辑脚本',
    generatePromptHint: '描述街区、空洞、霓虹和委托目标...',
    editPromptHint: '描述要如何重新剪辑这张图...',
    generateQuotaLabel: '电量',
    editQuotaLabel: '剪辑电量',
    generateButtonLabel: '开始委托',
    editButtonLabel: '开始剪辑',
    generateLoadingText: '录像带正在转动...',
    editLoadingText: '剪辑台正在处理...',
    generateActionLabel: '委托影像',
    editActionLabel: '录像剪辑',
    emptyHistoryText: '录像仓库还是空的',
    pickImageText: '选择需要剪辑的影像',
  );

  static final yanyun = _standard(
    style: BrandStyle.yanyun,
    title: '燕云十六声',
    backgroundAsset: 'assets/backgrounds/yanyun.png',
    primaryColor: const Color(0xFF7D4E2D),
    warningColor: const Color(0xFFB86F32),
    successColor: const Color(0xFF4E8F6A),
    panelColor: const Color(0xFFF4EFE7),
    backgroundOverlay: const Color(0xFFFFFBF4),
    backgroundOverlayOpacity: 0.72,
    theme: _yanyunTheme,
    generateTabLabel: '入画',
    editTabLabel: '墨痕回转',
    historyTabLabel: '江湖画卷',
    galleryTabLabel: '燕云画廊',
    favoriteTabLabel: '藏卷阁',
    generateTitle: '江湖画案 - 入画',
    editTitle: '墨痕回转 - 改图',
    historyTitle: '江湖画卷 - 历史',
    galleryTitle: '江湖画卷 - 画廊',
    promptLabel: '题画词',
    editPromptLabel: '改画批注',
    generatePromptHint: '写下山河、侠影、燕云与风骨...',
    editPromptHint: '描述要如何重写这幅画卷...',
    generateQuotaLabel: '笔墨',
    editQuotaLabel: '改画笔墨',
    generateButtonLabel: '挥毫入画',
    editButtonLabel: '重写墨痕',
    generateLoadingText: '笔墨正在铺开...',
    editLoadingText: '墨痕正在回转...',
    generateActionLabel: '入画',
    editActionLabel: '墨痕回转',
    emptyHistoryText: '江湖画卷尚无题记',
    pickImageText: '选择需要重写的画卷',
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

TextTheme _refinedTextTheme({
  required Brightness brightness,
  required Color bodyColor,
  required Color mutedColor,
  required Color headingColor,
}) {
  final isDark = brightness == Brightness.dark;
  return TextTheme(
    headlineSmall: TextStyle(
      fontFamily: _cnHeadingFontFamily,
      fontFamilyFallback: _cnHeadingFallback,
      fontSize: isDark ? 26 : 25,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: headingColor,
    ),
    titleLarge: TextStyle(
      fontFamily: _cnHeadingFontFamily,
      fontFamilyFallback: _cnHeadingFallback,
      fontSize: 22,
      height: 1.24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: headingColor,
    ),
    titleMedium: TextStyle(
      fontFamily: _cnHeadingFontFamily,
      fontFamilyFallback: _cnHeadingFallback,
      fontSize: 18,
      height: 1.28,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: headingColor,
    ),
    bodyLarge: TextStyle(
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      fontSize: 16,
      height: 1.56,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: bodyColor,
    ),
    bodyMedium: TextStyle(
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      fontSize: 14,
      height: 1.58,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: bodyColor,
    ),
    bodySmall: TextStyle(
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: mutedColor,
    ),
    labelLarge: TextStyle(
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: bodyColor,
    ),
  );
}

final ThemeData _botwTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: _cnFontFamily,
  fontFamilyFallback: _cnFontFallback,
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00D2FF),
    secondary: Color(0xFFFF9600),
    surface: Color(0xFF2A2A2A),
  ),
  textTheme: _refinedTextTheme(
    brightness: Brightness.dark,
    bodyColor: Colors.white70,
    mutedColor: Colors.white54,
    headingColor: const Color(0xFF7DEBFF),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF2A2A2A).withValues(alpha: 0.8),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: const BorderSide(color: Color(0xFF00D2FF), width: 0.5),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.58),
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
      color: const Color(0xFF00D2FF).withValues(alpha: 0.4),
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
    fontFamily: _cnFontFamily,
    fontFamilyFallback: _cnFontFallback,
    textTheme: _refinedTextTheme(
      brightness: Brightness.light,
      bodyColor: const Color(0xFF20242E),
      mutedColor: const Color(0xFF67707F),
      headingColor: const Color(0xFF1A2230),
    ),
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      color: surface.withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: primary.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: primary.withValues(alpha: 0.14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface.withValues(alpha: 0.96),
      hintStyle: TextStyle(
        fontFamily: _cnFontFamily,
        fontFamilyFallback: _cnFontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: primary.withValues(alpha: 0.55),
      ),
      labelStyle: TextStyle(
        fontFamily: _cnFontFamily,
        fontFamilyFallback: _cnFontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: primary.withValues(alpha: 0.82),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary.withValues(alpha: 0.36)),
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
        fontFamily: _cnFontFamily,
        fontFamilyFallback: _cnFontFallback,
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
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
    fontFamily: _cnFontFamily,
    fontFamilyFallback: _cnFontFallback,
    textTheme: _refinedTextTheme(
      brightness: Brightness.dark,
      bodyColor: const Color(0xFFF3F6FA),
      mutedColor: const Color(0xFF9CA8BC),
      headingColor: const Color(0xFFFFFFFF),
    ),
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    cardTheme: CardThemeData(
      color: surface.withValues(alpha: 0.9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: primary.withValues(alpha: 0.24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.64),
      hintStyle: TextStyle(
        fontFamily: _cnFontFamily,
        fontFamilyFallback: _cnFontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: Colors.white.withValues(alpha: 0.58),
      ),
      labelStyle: TextStyle(
        fontFamily: _cnFontFamily,
        fontFamilyFallback: _cnFontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.86),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary.withValues(alpha: 0.42)),
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
        fontFamily: _cnFontFamily,
        fontFamilyFallback: _cnFontFallback,
        color: primary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
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
  fontFamily: _cnFontFamily,
  fontFamilyFallback: _cnFontFallback,
  textTheme: _refinedTextTheme(
    brightness: Brightness.light,
    bodyColor: const Color(0xFF243244),
    mutedColor: const Color(0xFF6F7C8F),
    headingColor: const Color(0xFF1C2D46),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF4682B4),
    secondary: Color(0xFFE6E6FA),
    surface: Color(0xFFFDFDFD),
    error: Color(0xFFA23535),
  ),
  scaffoldBackgroundColor: const Color(0xFFFDFDFD),
  cardTheme: CardThemeData(
    color: Colors.white.withValues(alpha: 0.9),
    elevation: 8,
    shadowColor: const Color(0xFF4682B4).withValues(alpha: 0.2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: const Color(0xFFE6E6FA).withValues(alpha: 0.5),
        width: 1.5,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.96),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE6E6FA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide:
          BorderSide(color: const Color(0xFF4682B4).withValues(alpha: 0.34)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF4682B4), width: 2),
    ),
    hintStyle: TextStyle(
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      color: const Color(0xFF52657B).withValues(alpha: 0.78),
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    labelStyle: const TextStyle(
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      color: Color(0xFF2C3E50),
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
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
      fontFamily: _cnFontFamily,
      fontFamilyFallback: _cnFontFallback,
      color: Color(0xFF2C3E50),
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  ),
);
