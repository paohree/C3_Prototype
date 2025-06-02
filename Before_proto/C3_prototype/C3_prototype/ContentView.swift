//
//  ContentView.swift
//  C3_prototype
//
//  Created by YONGWON SEO on 5/31/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            DateView()
                .tabItem {
                    Label("일정 등록", systemImage: "calendar.badge.plus")
                }

            BoxView()
                .tabItem {
                    Label("보관함", systemImage: "archivebox")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: StoredSchedule.self)
}
