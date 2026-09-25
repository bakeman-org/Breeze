import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/platform/desktop/native_window.dart';

/// Material 3 风格的自定义标题栏（仅桌面平台使用）
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    if (Platform.isWindows && NativeWindow.isReady) {
      _isMaximized = NativeWindow.isMaximized;
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  void _minimize() {
    if (Platform.isWindows) {
      NativeWindow.minimize();
    } else {
      windowManager.minimize();
    }
  }

  void _toggleMaximize() {
    if (Platform.isWindows) {
      NativeWindow.toggleMaximize();
    } else if (_isMaximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  void _handleClose() {
    if (Platform.isWindows) {
      NativeWindow.close();
    } else {
      windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMacOS = Platform.isMacOS; // 检测是否为 macOS

    return Container(
      height: 40,
      color: colorScheme.surface,
      child: Row(
        children: [
          if (isMacOS) const SizedBox(width: 80),
          _RouterBackButton(colorScheme: colorScheme),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: Row(
                children: [
                  // 仅在非 macOS 平台（如 Windows）显示图标和标题
                  if (!isMacOS) ...[
                    const SizedBox(width: 12),
                    Image.asset(
                      'asset/image/app_icon.ico',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Breeze',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  // 如果是 macOS，可以让标题居中（可选）
                  if (isMacOS) const Spacer(),
                  if (isMacOS)
                    Text(
                      'Breeze',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 13, // macOS 标题通常更小更精致
                      ),
                    ),
                  if (isMacOS) const Spacer(),
                ],
              ),
            ),
          ),

          // 2. 右侧按钮区域（仅在非 macOS 平台显示）
          // macOS 的控制按钮在左边，所以右边的自定义按钮应该隐藏
          if (!isMacOS) ...[
            _TitleBarButton(
              icon: Icons.minimize_rounded,
              onPressed: _minimize,
              hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
              iconColor: colorScheme.onSurfaceVariant,
            ),
            _TitleBarButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              onPressed: _toggleMaximize,
              hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
              iconColor: colorScheme.onSurfaceVariant,
            ),
            _TitleBarButton(
              icon: Icons.close_rounded,
              onPressed: _handleClose,
              hoverColor: Colors.red,
              hoverIconColor: Colors.white,
              iconColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _RouterBackButton extends StatelessWidget {
  const _RouterBackButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appRouter,
      builder: (context, _) {
        final canPop = appRouter.canPop();
        return _TitleBarButton(
          icon: Icons.arrow_back,
          onPressed: canPop ? () => appRouter.maybePop() : null,
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
          iconColor: canPop
              ? colorScheme.onSurfaceVariant
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        );
      },
    );
  }
}

/// 标题栏上的单个按钮
class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color hoverColor;
  final Color iconColor;
  final Color? hoverIconColor;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    required this.iconColor,
    this.hoverIconColor,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) {
        if (enabled) setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 40,
          color: _isHovered && enabled
              ? widget.hoverColor
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 18,
            color: _isHovered && enabled
                ? (widget.hoverIconColor ?? widget.iconColor)
                : widget.iconColor,
          ),
        ),
      ),
    );
  }
}
