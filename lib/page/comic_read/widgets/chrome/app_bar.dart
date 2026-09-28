import 'dart:async';
import 'dart:ui';

import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/service/translation/translation_service.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comments/widgets/title.dart';
import 'package:zephyr/util/context/context_extensions.dart';

class ComicReadAppBar extends StatelessWidget {
  final String title;
  final ValueChanged<int> changePageIndex;
  final bool isDesktopFullscreen;
  final VoidCallback? onToggleFullscreen;

  const ComicReadAppBar({
    super.key,
    required this.title,
    required this.changePageIndex,
    this.isDesktopFullscreen = false,
    this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final isMenuVisible = context.select(
      (ReaderCubit cubit) => cubit.state.isMenuVisible,
    );
    final enableTranslation = context.select(
      (GlobalSettingCubit cubit) => cubit.state.enableTranslation,
    );
    final colorScheme = context.theme.colorScheme;
    const appBarRadius = 14.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !isMenuVisible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          offset: isMenuVisible ? Offset.zero : const Offset(0, -1),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(appBarRadius),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: AppBar(
                title: ScrollableTitle(text: title),
                titleSpacing: 6,
                actions: [
                  // Miuix 迁移：IconButton → MiuixIconButton（仍处于 AppBar
                  // 提供的 Material 祖先内，模糊/圆角容器保持原样）。
                  if (TranslationController.isSupported && enableTranslation)
                    _translationAction(),
                  if (onToggleFullscreen != null)
                    Tooltip(
                      message: isDesktopFullscreen
                          ? t.reader.exitFullscreen
                          : t.reader.enterFullscreen,
                      child: MiuixIconButton(
                        onPressed: onToggleFullscreen,
                        child: Icon(
                          isDesktopFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                        ),
                      ),
                    ),
                ],
                backgroundColor: colorScheme.surface.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                elevation: isMenuVisible ? 4.0 : 0.0,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(appBarRadius),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _translationAction() {
    final controller = TranslationController.instance;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.loadingKey,
      builder: (context, loadingKey, _) {
        final translating =
            loadingKey != null &&
            loadingKey == controller.currentImagePath.value;
        return Tooltip(
          message: t.translation.translate,
          child: MiuixIconButton(
            onPressed: () => unawaited(controller.toggleCurrentPage()),
            child: translating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.translate),
          ),
        );
      },
    );
  }
}
