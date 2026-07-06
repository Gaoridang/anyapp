//
//  RootTabView.swift
//  anyapp
//

import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        RootContainerView()
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Item.self, inMemory: true)
}