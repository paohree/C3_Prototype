//
//  C3_prototypeApp.swift
//  C3_prototype
//
//  Created by YONGWON SEO on 5/31/25.
//

import SwiftUI
import SwiftData

@main
struct MyScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: StoredSchedule.self)
        }
    }
}
