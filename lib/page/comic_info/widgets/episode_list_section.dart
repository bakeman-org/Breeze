import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_info/comic_info.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/context/context_extensions.dart';

/// 章节列表：根据宽度自适应 1 列 / 2 列 / 3 列。
class EpisodeListSection extends StatelessWidget {
  const EpisodeListSection({
    super.key,
    required this.episodes,
    required this.allInfo,
    required this.epsLength,
    required this.type,
    required this.comicId,
    required this.from,
    required this.isReversed,
  });

  final List<dynamic> episodes;
  final dynamic allInfo;
  final int epsLength;
  final ComicEntryType type;
  final String comicId;
  final String from;
  final bool isReversed;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          t.comicInfo.noChapters,
          style: context.theme.textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (var i = 0; i < episodes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EpButtonWidget(
                    doc: episodes[i] as Ep,
                    allInfo: allInfo,
                    epsLength: epsLength,
                    type: type,
                    comicId: comicId,
                    from: from,
                    index: i,
                    isReversed: isReversed,
                  ),
                ),
            ],
          );
        }

        final isDesktop = constraints.maxWidth >= 960;
        if (isDesktop) {
          return Center(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < episodes.length; i++)
                  SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EpButtonWidget(
                        doc: episodes[i] as Ep,
                        allInfo: allInfo,
                        epsLength: epsLength,
                        type: type,
                        comicId: comicId,
                        from: from,
                        index: i,
                        isReversed: isReversed,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final isWide = constraints.maxWidth >= 720;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: EpButtonWidget.fixedHeight,
          ),
          itemBuilder: (context, index) {
            final e = episodes[index] as Ep;
            return EpButtonWidget(
              doc: e,
              allInfo: allInfo,
              epsLength: epsLength,
              type: type,
              comicId: comicId,
              from: from,
              index: index,
              isReversed: isReversed,
            );
          },
        );
      },
    );
  }
}
