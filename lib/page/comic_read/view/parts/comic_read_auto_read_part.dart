part of '../comic_read.dart';

extension _ComicReadAutoReadPart on _ComicReadPageState {
  // 每次构建时同步自动阅读状态：开关、模式、间隔变化都会重配。
  void _syncAutoRead({
    required ReadSettingState readSetting,
    required int readMode,
  }) {
    _autoReadController.sync(
      readSetting: readSetting,
      readMode: readMode,
      canTick: () {
        final readerState = context.read<ReaderCubit>().state;
        return !readerState.isMenuVisible &&
            !readerState.isSliderRolling &&
            !readerState.isComicRolling;
      },
      onTick: _actionController.onAutoReadTick,
    );
  }

  // 仅暂停计时，不改动用户设置项本身。
  void _toggleAutoReadPaused() {
    _refreshState(() {});
    _autoReadController.togglePaused(
      readSetting: context.read<GlobalSettingCubit>().state.readSetting,
      readMode: context.read<GlobalSettingCubit>().state.readSetting.readMode,
      canTick: () {
        final readerState = context.read<ReaderCubit>().state;
        return !readerState.isMenuVisible &&
            !readerState.isSliderRolling &&
            !readerState.isComicRolling;
      },
      onTick: _actionController.onAutoReadTick,
    );
  }

  // 自动阅读悬浮控制按钮。
  Widget _autoReadControlWidget() {
    return BlocBuilder<GlobalSettingCubit, GlobalSettingState>(
      buildWhen: (previous, current) =>
          previous.readSetting.autoScroll != current.readSetting.autoScroll ||
          previous.readSetting.autoScrollHidePauseButton !=
              current.readSetting.autoScrollHidePauseButton ||
          previous.leftHandModeEnabled != current.leftHandModeEnabled,
      builder: (context, globalSettingState) {
        if (globalSettingState.readSetting.autoScroll == false ||
            globalSettingState.readSetting.autoScrollHidePauseButton) {
          return const Positioned.fill(
            child: IgnorePointer(child: SizedBox.shrink()),
          );
        }

        final leftHandMode = globalSettingState.leftHandModeEnabled;
        return BlocSelector<ReaderCubit, ReaderState, bool>(
          selector: (state) => state.isMenuVisible,
          builder: (context, isMenuVisible) {
            final bottomSafe = context.bottomSafeHeight;
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: leftHandMode ? 14 : null,
              right: leftHandMode ? null : 14,
              bottom: (isMenuVisible ? 122.0 : 14.0) + bottomSafe,
              child: Tooltip(
                // Miuix 迁移：FloatingActionButton.small → 40x40
                // MiuixFloatingActionButton + Tooltip（heroTag 无需保留）。
                message: _autoReadController.isPaused
                    ? t.reader.resumeAutoRead
                    : t.reader.pauseAutoRead,
                child: MiuixFloatingActionButton(
                  minWidth: 40,
                  minHeight: 40,
                  onPressed: _toggleAutoReadPaused,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      _autoReadController.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      key: ValueKey(_autoReadController.isPaused),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
