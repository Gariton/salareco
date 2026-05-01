import Foundation
import LocalAuthentication
import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case records
    case templates
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            PayrollLocalization.text("ダッシュボード")
        case .records:
            PayrollLocalization.text("記録")
        case .templates:
            PayrollLocalization.text("テンプレート")
        case .settings:
            PayrollLocalization.text("設定")
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "chart.line.uptrend.xyaxis"
        case .records:
            "list.bullet.clipboard"
        case .templates:
            "square.stack.3d.up"
        case .settings:
            "slider.horizontal.3"
    }
}
}

@MainActor
@Observable
final class PayrollAppState {
    var selectedTab: AppTab = .dashboard
    var selectedSourceID: UUID?
    var isPresentingOnboarding = false
    var launchExperienceReplayRequest: LaunchExperienceReplayRequest?

    func requestInitialLaunchExperienceReplay() {
        launchExperienceReplayRequest = LaunchExperienceReplayRequest(resetsOnboarding: true)
    }
}

struct LaunchExperienceReplayRequest: Equatable {
    let id = UUID()
    let resetsOnboarding: Bool
}

struct AppLockOptions {
    static let requiresAuthenticationAtLaunchKey = "app.requiresAuthenticationAtLaunch"
    static var localizedReason: String {
        PayrollLocalization.text("給与データを保護するために認証してください。")
    }
}

struct AppAuthenticationAvailability {
    let isAvailable: Bool
    let summary: String
    let unavailableReason: String?
}

enum AppAuthenticationManager {
    static func availability() -> AppAuthenticationAvailability {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return AppAuthenticationAvailability(
                isAvailable: false,
                summary: PayrollLocalization.text("認証を利用できません"),
                unavailableReason: unavailableReason(from: error)
            )
        }

        let summary: String
        switch context.biometryType {
        case .faceID:
            summary = PayrollLocalization.text("Face ID またはパスコード")
        case .touchID:
            summary = PayrollLocalization.text("Touch ID またはパスコード")
        default:
            summary = PayrollLocalization.text("パスコード")
        }

        return AppAuthenticationAvailability(
            isAvailable: true,
            summary: summary,
            unavailableReason: nil
        )
    }

    static func authenticate(
        localizedReason: String = AppLockOptions.localizedReason
    ) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = PayrollLocalization.text("パスコードを使用")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? LAError(.biometryNotAvailable)
        }

        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: localizedReason) {
                success,
                evaluationError in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: evaluationError ?? LAError(.authenticationFailed)
                    )
                }
            }
        }
    }

    static func errorMessage(for error: Error) -> String? {
        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: nsError.code) else {
            return nsError.localizedDescription
        }

        switch code {
        case .appCancel, .systemCancel, .userCancel:
            return nil
        case .authenticationFailed:
            return PayrollLocalization.text("認証に失敗しました。もう一度お試しください。")
        case .biometryLockout:
            return PayrollLocalization.text("生体認証が一時的に無効です。パスコードで解除してください。")
        case .biometryNotAvailable:
            return PayrollLocalization.text("この端末では生体認証を利用できません。")
        case .biometryNotEnrolled:
            return PayrollLocalization.text("生体認証が設定されていません。")
        case .passcodeNotSet:
            return PayrollLocalization.text("この端末にパスコードが設定されていません。")
        default:
            return nsError.localizedDescription
        }
    }

    private static func unavailableReason(from error: NSError?) -> String {
        guard let error,
              error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return PayrollLocalization.text("この端末では生体認証またはパスコード認証を利用できません。")
        }

        switch code {
        case .biometryNotAvailable:
            return PayrollLocalization.text("この端末では生体認証を利用できません。")
        case .biometryNotEnrolled:
            return PayrollLocalization.text("生体認証が設定されていません。")
        case .passcodeNotSet:
            return PayrollLocalization.text("この端末にパスコードが設定されていません。")
        default:
            return error.localizedDescription
        }
    }
}
