import ActivityKit
import WidgetKit
import SwiftUI

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
            .keylineTint(.accentColor)
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
