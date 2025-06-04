//
//  ScheduleDetailView.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI

struct ScheduleDetailView: View {
  let schedule: StoredSchedule
  
  var body: some View {
    Form {
      Section(header: Text("제목")) {
        Text(schedule.title)
      }
      
      Section(header: Text("소요 시간")) {
        Text("\(schedule.duration)시간")
      }
      
      Section(header: Text("마감 기한")) {
        Text(schedule.deadline.formatted(date: .abbreviated, time: .omitted))
      }
      
      if let contacted = schedule.contactedDate {
        Section(header: Text("연락 온 날")) {
          Text(contacted.formatted(date: .abbreviated, time: .omitted))
        }
      }
    }
    .navigationTitle("일정 정보")
  }
}

#Preview {
  let dummy = StoredSchedule(
    title: "회의 일정",
    duration: 2,
    deadline: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
    contactedDate: .now,
    searchStart: .now,
    calendarID: nil
  )
  
  return ScheduleDetailView(schedule: dummy)
}
