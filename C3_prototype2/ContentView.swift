//
//  ContentView.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    TabView {
      ScheduleInputView()
        .tabItem {
          Label("일정 등록", systemImage: "calendar.badge.plus")
        }
      
      ArchiveView()
        .tabItem {
          Label("보관함", systemImage: "archivebox")
        }
    }
  }
}

#Preview {
  ContentView()
}
