//
//  BreezeWidget.swift
//  Breeze 桌面小部件（iOS WidgetKit 骨架）
//
//  ⚠️ 本文件只是代码骨架，需在 Xcode 中手动接入才能生效：
//
//  1. Xcode 打开 ios/Runner.xcworkspace → File → New → Target… →
//     Widget Extension，命名 BreezeWidget（勾选 Include Configuration Intent 可不选）。
//  2. 用本文件内容替换生成的 BreezeWidget.swift，Info.plist 参考本目录 Info.plist。
//  3. Runner 与 BreezeWidget 两个 target 都开启同一 App Group
//     （Signing & Capabilities → + Capability → App Groups），
//     group 名需与下方 `appGroupId` 常量一致（如 group.com.zephyr.breeze）。
//  4. Flutter 侧 HomeWidget.setAppGroupId(appGroupId) 需在小部件数据写入前调用
//     （HomeWidgetService.updateWidgetData 已按需接入）。
//

import WidgetKit
import SwiftUI

private let appGroupId = "group.com.zephyr.breeze"
private let recentComicsKey = "recent_comics"

struct RecentComic: Identifiable {
    let id: Int
    let title: String
    let comicId: String
    let source: String

    var deepLink: URL? {
        URL(string: "breeze://comic/\(comicId)?from=\(source)&type=download")
    }
}

private func loadRecentComics() -> [RecentComic] {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let raw = defaults.string(forKey: recentComicsKey),
          let data = raw.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }

    return array.enumerated().compactMap { index, item in
        guard let comicId = item["comicId"] as? String, !comicId.isEmpty else { return nil }
        return RecentComic(
            id: index,
            title: item["title"] as? String ?? "",
            comicId: comicId,
            source: item["source"] as? String ?? ""
        )
    }
}

struct RecentComicsEntry: TimelineEntry {
    let date: Date
    let comics: [RecentComic]
}

struct RecentComicsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentComicsEntry {
        .init(date: .now, comics: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentComicsEntry) -> Void) {
        completion(.init(date: .now, comics: loadRecentComics()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentComicsEntry>) -> Void) {
        completion(.init(entries: [.init(date: .now, comics: loadRecentComics())], policy: .never))
    }
}

struct RecentComicsWidgetView: View {
    let entry: RecentComicsEntry

    var body: some View {
        if entry.comics.isEmpty {
            Text("暂无最近下载")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.comics.prefix(4)) { comic in
                    if let url = comic.deepLink {
                        Link(destination: url) {
                            Text(comic.title)
                                .font(.footnote)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .padding(4)
        }
    }
}

struct BreezeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreezeRecentWidget", provider: RecentComicsProvider()) { entry in
            RecentComicsWidgetView(entry: entry)
        }
        .configurationDisplayName("最近下载")
        .description("显示 Breeze 最近下载的漫画，点击进入详情。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BreezeWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreezeWidget()
    }
}
