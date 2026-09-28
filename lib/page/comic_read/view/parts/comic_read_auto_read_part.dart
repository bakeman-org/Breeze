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
            // 可拖拽 + 位置持久化的自动阅读控制按钮。
            // 菜单可见时抬高 108px，避免被底部菜单遮挡（不写入存储）。
            return Positioned.fill(
              child: DraggableFabGroup(
                pageKey: 'reader_auto_read',
                defaultAlignment: leftHandMode
                    ? Alignment.bottomLeft
                    : Alignment.bottomRight,
                margin: 14,
                extraShift: Offset(0, isMenuVisible ? -108.0 : 0.0),
                child: Tooltip(
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
              ),
            );
          },
        );
      },
    );
  }
}
