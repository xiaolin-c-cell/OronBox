import Foundation
import ActivityKit

/// POC 用的最小 ActivityAttributes。
/// 注：用 Xcode 16（iOS 18 SDK）编译时，ActivityKit 的 request/end 重载被标记为
/// iOS 16.2+，因此本地控制门槛设为 16.2；Widget 显示侧仍支持 16.1。
/// 后续正式接入可针对 16.1 使用旧的重载，或干脆把最低版本定为 16.2。
@available(iOS 16.2, *)
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
@available(iOS 16.2, *)
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
