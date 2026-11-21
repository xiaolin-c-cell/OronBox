import Foundation
import ActivityKit

/// POC 用的最小 ActivityAttributes。被主 app 与 Widget extension 两个 target 共享编译。
/// 后续正式接入时可替换为真实的队列进度 attributes。
@available(iOS 16.1, *)
struct OronBoxLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var detail: String
        var progress: Double
    }
    // 静态属性：创建时确定，生命周期内不变
    var deviceName: String
}

/// 主 app 侧的活动控制封装。POC 阶段仅本地启动/结束，不走 APNs。
@available(iOS 16.1, *)
enum OronBoxLiveActivityBridge {
    static func areActivitiesEnabled() -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(title: String, detail: String, progress: Double) -> String? {
        guard areActivitiesEnabled() else { return nil }
        let attributes = OronBoxLiveActivityAttributes(deviceName: "POC Device")
        let state = OronBoxLiveActivityAttributes.ContentState(
            title: title,
            detail: detail,
            progress: progress
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil  // 本地启动，不需要 APNs / 推送证书
            )
            return activity.id
        } catch {
            NSLog("[OronBoxLA] start failed: \(error.localizedDescription)")
            return nil
        }
    }

    static func update(id: String, title: String, detail: String, progress: Double) {
        let state = OronBoxLiveActivityAttributes.ContentState(
            title: title,
            detail: detail,
            progress: progress
        )
        Task {
            for activity in Activity<OronBoxLiveActivityAttributes>.activities where activity.id == id {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
    }

    static func end(id: String? = nil) {
        Task {
            for activity in Activity<OronBoxLiveActivityAttributes>.activities {
                if id == nil || activity.id == id {
                    await activity.end(.init(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
                }
            }
        }
    }
}
