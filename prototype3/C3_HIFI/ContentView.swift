//
//  ContentView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

//
// ContentView -> SelectTaskView(TaskSlotListView) -> DetailInputView -> TimeTableView -> TimeSelectionModal
//             ㄴ> HistoryView
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
          TabView{
            SelectTaskView().tabItem{
              Label("일정 등록", systemImage: "list.bullet")
            }
            HistoryView().tabItem{
              Label("보관함", systemImage:"archivebox")
            }
          }
        }
        .padding()
    }
}

#Preview {
  ContentView()
}

