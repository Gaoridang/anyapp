//
//  STTMode.swift
//  anyapp
//

import Foundation

enum STTProvider: Equatable {
    case grok
    case onDevice
}

enum STTMode: String, CaseIterable, Identifiable {
    case automatic
    case grok
    case onDevice

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            "자동"
        case .grok:
            "Grok (클라우드)"
        case .onDevice:
            "기기 (온디바이스)"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            "API 키가 있으면 Grok, 없으면 기기 음성 인식을 사용합니다."
        case .grok:
            "xAI Grok API로 변환합니다. API 키가 필요합니다."
        case .onDevice:
            "인터넷 없이 iPhone에서 직접 변환합니다. 한국어 받아쓰기 언어팩이 필요합니다."
        }
    }
}

enum STTModeStore {
    private static let userDefaultsKey = "sttMode"

    static var mode: STTMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let mode = STTMode(rawValue: rawValue) else {
                return .automatic
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
}
