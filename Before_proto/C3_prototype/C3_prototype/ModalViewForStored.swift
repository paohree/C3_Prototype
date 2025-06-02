//
//  ModalViewForStored.swift
//  C3_prototype
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI
import EventKit
import SwiftData

struct ModalViewForStored: View {
    var schedule: StoredSchedule
    @Binding var showModal: Bool

    @Environment(\.modelContext) private var modelContext

    let store = EKEventStore()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("보류된 일정")) {
                    Text("제목: \(schedule.title)")
                    Text("소요 시간: \(schedule.duration)시간")

                    if let deadline = schedule.deadline {
                        Text("기한: \(deadline.formatted(date: .numeric, time: .omitted))")
                    }
                    if let contacted = schedule.contactedDate {
                        Text("연락: \(contacted.formatted(date: .numeric, time: .omitted))")
                    }
                    if let source = schedule.source {
                        Text("출처: \(source)")
                    }
                    
                    HStack{
                        Spacer()
                        Button("캘린더에 등록") {
                            addToCalendar(schedule)
                            modelContext.delete(schedule)
                            showModal = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.vertical)
                        Spacer()
                    }
                }
            }
            .navigationTitle("보관된 일정")
        }
    }

    private func addToCalendar(_ schedule: StoredSchedule) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in
                if granted {
                    insertEvent(for: schedule)
                } else {
                    print("캘린더 접근 권한 거부: \(error?.localizedDescription ?? "")")
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                if granted {
                    insertEvent(for: schedule)
                } else {
                    print("캘린더 접근 권한 거부: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }

    private func insertEvent(for schedule: StoredSchedule) {
        let startDate = Date() // 그냥 지금 시간
        guard let endDate = Calendar.current.date(byAdding: .hour, value: schedule.duration, to: startDate) else {
            print("종료 시간 계산 실패")
            return
        }

        let event = EKEvent(eventStore: store)
        event.title = schedule.title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = store.defaultCalendarForNewEvents

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var notes = ""
        if let contacted = schedule.contactedDate {
            notes += "연락온날:\(formatter.string(from: contacted))\n"
        }
        if let deadline = schedule.deadline {
            notes += "기한:\(formatter.string(from: deadline))"
        }
        event.notes = notes

        do {
            try store.save(event, span: .thisEvent)
            print("캘린더에 이벤트 등록 완료")
        } catch {
            print("캘린더 저장 실패: \(error.localizedDescription)")
        }
    }
}
