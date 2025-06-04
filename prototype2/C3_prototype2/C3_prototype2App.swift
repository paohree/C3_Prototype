//
//  C3_prototype2App.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI
import SwiftData

@main
struct C3_prototype2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: StoredSchedule.self) // SwiftData 초기화
    }
}
