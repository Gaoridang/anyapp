//
//  TopSegmentNavigator.swift
//  anyapp
//

import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case menu = 0
    case memo = 1
    case shadowing = 2
    case speakingPractice = 3

    var id: Int { rawValue }

    /// Main feature pages shown in the horizontal pager (menu is the leading page).
    static var contentTabs: [RootTab] {
        [.memo, .shadowing, .speakingPractice]
    }

    var title: String {
        switch self {
        case .menu:
            "메뉴"
        case .memo:
            "메모"
        case .shadowing:
            "쉐도잉"
        case .speakingPractice:
            "연습"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .menu:
            "menuTab"
        case .memo:
            "memoTab"
        case .shadowing:
            "shadowingTab"
        case .speakingPractice:
            "speakingPracticeTab"
        }
    }

    var menuIcon: String {
        switch self {
        case .menu:
            "line.3.horizontal"
        case .memo:
            "note.text"
        case .shadowing:
            "text.bubble"
        case .speakingPractice:
            "mic.and.signal.meter"
        }
    }
}