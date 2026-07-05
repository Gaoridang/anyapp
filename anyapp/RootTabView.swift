//
//  RootTabView.swift
//  anyapp
//

import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("메모", systemImage: "note.text")
                }

            SpeakingPracticeView()
                .tabItem {
                    Label("연습", systemImage: "mic.and.signal.meter")
                }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Item.self, inMemory: true)
}