import ActivityKit
import WidgetKit
import SwiftUI

/// Widget target 独立编译的 attributes 定义。
/// 与主 app 的 LiveActivityBridge.swift 中同名结构体保持一致即可——
/// 两个 target 各自编译自己的副本，字段名/类型一致就能正确解码 content-state。
@available(iOS 16.1, *)
struct OronBoxLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var detail: String
        var progress: Double
    }
    var deviceName: String
}

/// POC 灵动岛 Widget：锁屏卡片 + 灵动岛三态（expanded / compact / minimal）。
/// 只依赖系统框架（ActivityKit/WidgetKit/SwiftUI），不需要任何第三方 pod。
@available(iOS 16.1, *)
struct OronBoxWidget: Widget {
    let kind: String = "OronBoxWidget"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OronBoxLiveActivityAttributes.self) { context in
            // MARK: 锁屏卡片
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.accentColor)
                    Text(context.state.title)
                        .font(.headline)
                    Spacer()
                    Text(context.attributes.deviceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ProgressView(value: context.state.progress)
                Text(context.state.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform.path.ecg").foregroundColor(.accentColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%").fontWeight(.semibold)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.detail).font(.caption)
                        ProgressView(value: context.state.progress)
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform.path.ecg").foregroundColor(.accentColor)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%").font(.caption2)
            } minimal: {
                Image(systemName: "waveform.path.ecg").foregroundColor(.accentColor)
            }
            .widgetURL(URL(string: "oronbox://liveactivity"))
        }
    }
}

@available(iOS 16.1, *)
@main
struct OronBoxWidgetBundle: WidgetBundle {
    var body: some Widget {
        OronBoxWidget()
    }
}
