//
//  TopSegmentNavigator.swift
//  anyapp
//

import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case memo = 0
    case shadowing = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .memo:
            "메모"
        case .shadowing:
            "쉐도잉"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .memo:
            "memoTab"
        case .shadowing:
            "shadowingTab"
        }
    }

    var menuIcon: String {
        switch self {
        case .memo:
            "note.text"
        case .shadowing:
            "text.bubble"
        }
    }
}
