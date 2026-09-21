// lib/main_entry_deps/splash.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zephyr/service/app_icon/app_icon_service.dart';
import 'package:zephyr/service/app_theme/app_theme_cache.dart';

/// 闪屏主题的兜底种子色。
///
/// 只有「首次启动、缓存里还没有 seedColor」时才会用到。用 GlobalSettingState
/// 的默认种子色，保证首次启动的闪屏色和主界面默认色一致。
const Color kFallbackSeedColor = Color(0xFFEF5350);

// ─────────────────────────────────────────────────────────────────────
// 动画参数
// ─────────────────────────────────────────────────────────────────────

/// 图标逻辑边长。
const double _kIconSize = 96;

/// 光环画布尺寸（涟漪最大扩散到这个直径）。
const double _kHaloDiameter = 280;

/// 同时存在的光环条数。
///
/// Telegram 用的是「两条错峰」的节奏；这里给 3 条，覆盖更密，
/// 但通过错峰相位让视觉上只有 1~2 条同时明显可见。
const int _kHaloCount = 3;

/// 入场动画总时长。
const Duration _kEnterDuration = Duration(milliseconds: 1200);

/// 涟漪循环时长（每条光环完整扩散一遍的时长）。
const Duration _kPulseDuration = Duration(milliseconds: 2600);

// ─────────────────────────────────────────────────────────────────────
// 启动闪屏
// ─────────────────────────────────────────────────────────────────────

/// 启动闪屏。
///
/// 视觉分三层（Stack 自下而上）：
///   1. **脉冲光环**：3 条错峰圆环从图标边缘持续向外扩散，无限循环；
///   2. **图标**：先淡入，再用 `easeOutBack` 从 0 弹到约 1.10 峰值，
///      最后平滑回落到 1.0（单段连续曲线，无中间停顿）；
///   3. **应用名**：延后于图标入场，从下往上滑入 + 淡入。
///
/// 公共 widget：[ZephyrApp] 业务初始化阶段和 [AppBootstrapPage] 都渲染它。
/// 图标来源 [AppIconService.instance.value.assetPath]（main 里已 await 加载）。
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with TickerProviderStateMixin {
  /// 入场控制器：只跑一次。
  late final AnimationController _enterCtrl = AnimationController(
    duration: _kEnterDuration,
    vsync: this,
  )..forward();

  /// 脉冲控制器：无限循环。
  late final AnimationController _pulseCtrl = AnimationController(
    duration: _kPulseDuration,
    vsync: this,
  )..repeat();

  // ─── 图标缩放：单段 easeOutBack ──────────────────────────────────
  //
  // 之前用 TweenSequence 三段式，问题在段间速度不连续：
  //   - 段 1 结尾 easeOutCubic 斜率 → 0（近 1.08 处几乎不动）
  //   - 段 2 开头 easeInOut  斜率 = 0（离开 1.08 处也几乎不动）
  //   - 段 2/3 交接处同样有斜率跳变
  //   → 视觉上就是"卡一下 → 抖一下 → 卡一下"，很突兀。
  //
  // easeOutBack 是一条连续 cubic-bezier，速度处处连续：
  //   - 前 60% 快速冲出，峰值约 1.10
  //   - 后 40% 平滑回落到 1.0
  //   - 全程无中间停顿
  //
  // 用 Interval(0.0, 0.75) 让缩放动画在入场前 75% 内走完，
  // 后 25% 保持静止，给应用名入场（50% 开始）留出重叠但不抢戏。
  late final Animation<double> _iconScale = Tween<double>(begin: 0.0, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
        ),
      );

  /// 图标透明度：0 → 1，前 35% 完成。
  late final Animation<double> _iconFade = CurvedAnimation(
    parent: _enterCtrl,
    curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
  );

  /// 图标轻微旋转：-0.06 turns（约 -21°）→ 0。
  ///
  /// 这个幅度很小，视觉上是"从斜一点的位置转正"，不是"转圈"。
  /// 配合缩放弹入，会产生"被抛进来"的感觉。
  late final Animation<double> _iconRotate =
      Tween<double>(begin: -0.06, end: 0.0).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
        ),
      );

  /// 应用名透明度：50% → 100% 淡入。
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _enterCtrl,
    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
  );

  /// 应用名上移：+12px → 0。
  late final Animation<double> _textSlide = Tween<double>(begin: 12, end: 0)
      .animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = AppIconService.instance.value.assetPath;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _kHaloDiameter,
              height: _kHaloDiameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ─── 第 1 层：脉冲光环 ─────────────────────────
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(_kHaloDiameter, _kHaloDiameter),
                        painter: _RipplePainter(
                          progress: _pulseCtrl.value,
                          color: primary,
                          ringCount: _kHaloCount,
                          baseDiameter: _kIconSize * 1.15,
                          maxDiameter: _kHaloDiameter,
                        ),
                      );
                    },
                  ),

                  // ─── 第 2 层：图标 ─────────────────────────────
                  FadeTransition(
                    opacity: _iconFade,
                    child: RotationTransition(
                      turns: _iconRotate,
                      child: ScaleTransition(
                        scale: _iconScale,
                        child: _IconTile(
                          assetPath: assetPath,
                          size: _kIconSize,
                          shadowColor: primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── 第 3 层：应用名 ──────────────────────────────
            AnimatedBuilder(
              animation: _textSlide,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: child,
                );
              },
              child: FadeTransition(
                opacity: _textFade,
                child: Text(
                  'Breeze',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 图标瓦片：圆角 + 阴影
// ─────────────────────────────────────────────────────────────────────

/// 图标显示容器。
///
/// 加圆角裁切 + 主题色柔光阴影，让图标"浮"起来一点。阴影用 primary
/// 而不是黑色，跟品牌色统一。
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.assetPath,
    required this.size,
    required this.shadowColor,
  });

  final String assetPath;
  final double size;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // 图标加载失败（比如首次安装尚未就绪）时兜底成一个中性占位，
          // 避免整棵树被 ErrorWidget 替换。
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: shadowColor.withValues(alpha: 0.15),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: shadowColor,
              size: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 脉冲光环绘制
// ─────────────────────────────────────────────────────────────────────

/// 错峰扩散的圆环 painter。
///
/// 每条环按 `i / ringCount` 的相位差出发，同一时刻画面上有 1~2 条
/// 明显可见、其余在淡入/淡出边缘 —— 这就是 Telegram 那种"持续呼吸"
/// 而不拥挤的感觉。
class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.progress,
    required this.color,
    required this.ringCount,
    required this.baseDiameter,
    required this.maxDiameter,
  });

  /// 循环进度 [0, 1)。
  final double progress;

  /// 环的颜色（一般用主题色）。
  final Color color;

  /// 同时存在的环数。
  final int ringCount;

  /// 起始直径（从图标边缘开始扩散）。
  final double baseDiameter;

  /// 终止直径（扩散到的最大圆）。
  final double maxDiameter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (var i = 0; i < ringCount; i++) {
      // 相位错峰：第 i 条环比第 0 条晚 i / ringCount 个周期出发。
      //
      // 取模保证进度永远在 [0, 1) 内，形成无限循环。
      final t = (progress + i / ringCount) % 1.0;

      // 尺寸：baseDiameter → maxDiameter，用 easeOut 让"扩散"先快后慢，
      // 符合视觉惯性（物体远离时看起来减速）。
      final eased = Curves.easeOutCubic.transform(t);
      final diameter = baseDiameter + (maxDiameter - baseDiameter) * eased;

      // 透明度：0 → 峰值 → 0
      //
      //   前 15% 淡入（避免环"突然出现"）；
      //   中间 60% 保持较高不透明度；
      //   后 25% 快速淡出（收尾干净）。
      final double opacity;
      if (t < 0.15) {
        opacity = t / 0.15;
      } else if (t < 0.75) {
        opacity = 1.0;
      } else {
        opacity = 1.0 - (t - 0.75) / 0.25;
      }

      // 环越往外越细：视觉上像"能量在扩散中变薄"。
      final strokeWidth = 2.0 - 1.0 * eased;

      paint
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: (opacity.clamp(0.0, 1.0)) * 0.45);

      canvas.drawCircle(center, diameter / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.ringCount != ringCount ||
        old.baseDiameter != baseDiameter ||
        old.maxDiameter != maxDiameter;
  }
}

// ─────────────────────────────────────────────────────────────────────
// 启动闪屏宿主（业务初始化阶段）
// ─────────────────────────────────────────────────────────────────────

/// `_bootstrap` 阶段的闪屏宿主。
///
/// 主题来源：[AppThemeCache]，与主界面用同一份 seedColor / themeMode，
/// 消除「闪屏色 → 主界面色」的跳变。
class StartupSplashApp extends StatelessWidget {
  const StartupSplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = AppThemeCache.seedColor ?? kFallbackSeedColor;
    // AppThemeCache.themeMode 的静态类型是 Enum?（内部存的是 ThemeMode），
    // 这里显式收窄到 ThemeMode，否则 MaterialApp.themeMode 参数不接受 Enum。
    final themeMode = (AppThemeCache.themeMode is ThemeMode)
        ? AppThemeCache.themeMode as ThemeMode
        : ThemeMode.system;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: ColorScheme.fromSeed(seedColor: seed).surface,
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).surface,
      ),
      home: const AppSplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 启动失败兜底页
// ─────────────────────────────────────────────────────────────────────

/// 初始化失败的兜底页。
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  '应用启动失败',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                if (kDebugMode && stackTrace != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '详细堆栈已打印到控制台。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
