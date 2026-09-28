import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/source/bika/models/bika_models.dart';
import 'package:zephyr/source/bika/view/widgets/bika_cover_image.dart';

class BikaComicCard extends StatelessWidget {
  const BikaComicCard({super.key, required this.comic});

  final ComicBase comic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.pushRoute(BikaDetailRoute(comicId: comic.uid)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BikaCoverImage(image: comic.thumb),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              comic.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.25),
            ),
            const SizedBox(height: 2),
            Text(
              comic.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BikaComicGrid extends StatelessWidget {
  const BikaComicGrid({
    super.key,
    required this.comics,
    this.padding = const EdgeInsets.all(12),
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  final List<ComicBase> comics;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 600
            ? 4
            : 3;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.52,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
          ),
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          controller: controller,
          itemCount: comics.length,
          itemBuilder: (context, index) => BikaComicCard(comic: comics[index]),
        );
      },
    );
  }
}

class BikaListEmptyView extends StatelessWidget {
  const BikaListEmptyView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message ?? t.bika.empty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
