// lib/page/changelog/widgets/release_card.dart
import 'package:intl/intl.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/update/json/github_release_json.dart';

class ReleaseCard extends StatelessWidget {
  final GithubReleaseJson release;
  final Function(String) onLinkTap;

  const ReleaseCard({
    super.key,
    required this.release,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateStr = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(release.publishedAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shadowColor: Colors.transparent,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            release.tagName,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (release.prerelease)
                          const TagChip(text: 'Pre', color: Colors.orange),
                        if (release.draft) ...[
                          const SizedBox(width: 4),
                          const TagChip(text: 'Draft', color: Colors.grey),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.changelog.publishedAt(date: dateStr),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: t.changelog.viewInBrowser,
                child: IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onLinkTap(release.htmlUrl),
                ),
              ),
            ],
          ),
          children: [
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            MarkdownWidget(
              data: release.body,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              config: MarkdownConfig(
                configs: [
                  PConfig(
                    textStyle: textTheme.bodyMedium!.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  LinkConfig(
                    style: TextStyle(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    onTap: (url) => onLinkTap(url),
                  ),
                  CodeConfig(
                    style: TextStyle(
                      backgroundColor: colorScheme.surface,
                      fontFamily: 'monospace',
                    ),
                  ),
                  PreConfig(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (release.assets.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.changelog.attachments,
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: release.assets.map((asset) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.download_rounded,
                            size: 14,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          label: Text(asset.name),
                          backgroundColor: colorScheme.secondaryContainer,
                          labelStyle: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontSize: 12,
                          ),
                          side: BorderSide.none,
                          onPressed: () => onLinkTap(asset.browserDownloadUrl),
                          tooltip:
                              '${(asset.size / 1024 / 1024).toStringAsFixed(2)} MB',
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Release tag 上的小标签（Pre / Draft）。
class TagChip extends StatelessWidget {
  final String text;
  final Color color;

  const TagChip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
