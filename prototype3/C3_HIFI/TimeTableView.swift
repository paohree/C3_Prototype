//
//  TimeTableView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.

import SwiftUI
import EventKit

struct TimeTableSlot: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let hour: Int
    let title: String?
    let isOccupied: Bool
}

enum AlertType: Identifiable {
    case success(String)
    case failure(String)

    var id: String {
        switch self {
        case .success(let msg): return "success:\(msg)"
        case .failure(let msg): return "failure:\(msg)"
        }
    }

    var alert: Alert {
        switch self {
        case .success(let msg):
            return Alert(title: Text("캘린더에 반영되었습니다."), message: Text(msg), dismissButton: .default(Text("확인")))
        case .failure(let msg):
            return Alert(title: Text("슬롯 선택 불가"), message: Text(msg), dismissButton: .default(Text("확인")))
        }
    }
}

struct TimeTableView: View {
  
  @State private var alertTrigger: AlertType? = nil
  
  @State private var isModalActive = false
  
  @State private var eventStore = EKEventStore()
  
  @Environment(\.dismiss) private var dismiss
  
    let baseDate: Date
    let requiredDuration: TimeInterval
    let preferStartHour: Int
    let preferEndHour: Int
    let taskTitle: String

    @State private var slots: [TimeTableSlot] = []
    @State private var selectedSlot: TimeTableSlot? = nil
    @State private var showModal = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var confirmedTimeRange: (Date, Date)? = nil
    @State private var weekOffset: Int = 0

    private let calendar = Calendar.current
    private let cellWidth: CGFloat = 48
    private let store = EKEventStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                dayHeader

                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 1) {
                          ForEach(preferStartHour ..< preferEndHour, id: \.self) { hour in
                                Text("\(hour)시")
                                    .font(.caption2)
                                    .frame(width: 30, height: 44)
                            }
                        }

                        ScrollView(.horizontal) {
                            VStack(spacing: 1) {
                              ForEach(preferStartHour ..< preferEndHour, id: \.self ) { hour in
                                    HStack(spacing: 1) {
                                      ForEach(currentWeekDates, id: \.self ) { date in
                                            let slot = slotFor(date: date, hour: hour)
                                            Button(action: {
                                                handleSlotSelection(slot)
                                            }) {
                                                Rectangle()
                                                    .fill(slot.isOccupied ? Color.gray.opacity(0.6) : Color.green.opacity(0.4))
                                                    .frame(width: cellWidth, height: 44)
                                                    .overlay(
                                                        Text(slot.title ?? "")
                                                            .font(.caption2)
                                                            .foregroundColor(.white)
                                                            .lineLimit(2)
                                                            .minimumScaleFactor(0.5),
                                                        alignment: .topLeading
                                                    )
                                            }
                                            .disabled(slot.isOccupied)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("시간 선택")
          
          
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("나가기") {
//                        dismiss()
//                    }
//                }
//            }
          
            .sheet(isPresented: $showModal) {
                if let selectedSlot {
                    TimeSelectionModal(
                        slot: selectedSlot,
                        requiredDuration: requiredDuration
                    ) { start, end in
                        let isValid = validateSlotAvailability(start: start, duration: requiredDuration)
                        showModal = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if isValid {
                                confirmSchedule(start: start, end: end)
                                alertTrigger = .success("\(taskTitle)\n\(formatted(start)) - \(formatted(end))")
                            } else {
                                alertTrigger = .failure("작업 시간에 필요한 연속 시간이 부족해요. 다른 시간대를 선택해주세요.")
                            }
                        }
                    }
                }
            }
        }
      
        .onChange(of: showModal) { newValue in
            if newValue == false {
                print(" 모달 닫힘 → isModalActive = false")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let range = confirmedTimeRange {
                        alertMessage = "캘린더에 반영되었습니다.\n\n\(taskTitle)\n\(formatted(range.0)) - \(formatted(range.1))"
                        showAlert = true
                    } else if selectedSlot == nil {
                        alertMessage = "작업 시간에 필요한 연속 시간이 부족해요. 다른 시간을 선택해주세요."
                        showAlert = true
                    }
                }
            }
        }
        .alert(item: $alertTrigger) { $0.alert }

//      .alert(isPresented: $showAlert) {
//          //  confirmedTimeRange 존재 여부로 분기
//          if confirmedTimeRange != nil {
//              return Alert(
//                  title: Text("캘린더에 반영되었습니다."),
//                  message: Text(alertMessage),
//                  primaryButton: .default(Text("작업 항목으로 돌아가기"), action: {
//                      dismiss()
//                  }),
//                  secondaryButton: .default(Text("캘린더에서 보기"), action: {
//                      if let url = URL(string: "calshow://") {
//                          UIApplication.shared.open(url)
//                          dismiss()
//                      }
//                  })
//              )
//          } else {
//              return Alert(
//                  title: Text("슬롯 선택 불가"),
//                  message: Text(alertMessage),
//                  dismissButton: .default(Text("확인"))
//              )
//          }
//      }
      
      
        .onAppear {
            loadEventsFromCalendar()
        }
    }

    var header: some View {
        VStack(spacing: 4) {
            Text(taskTitle)
                .font(.headline)
            HStack {
                Button("<") { weekOffset -= 1; loadEventsFromCalendar() }
                Spacer()
                Text(weekRangeText)
                Spacer()
                Button(">") { weekOffset += 1; loadEventsFromCalendar() }
            }
            .font(.subheadline)
            Text("소요시간: \(Int(requiredDuration / 3600))시간 \(Int(requiredDuration.truncatingRemainder(dividingBy: 3600)) / 60)분")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }

    var dayHeader: some View {
        VStack(spacing: 2) {
            HStack(spacing: 1) {
                Spacer().frame(width: 30)
              ForEach(weekdaySymbols, id: \.self ) { day in
                    Text(day)
                        .font(.caption)
                        .frame(width: cellWidth)
                }
            }
            HStack(spacing: 1) {
                Spacer().frame(width: 30)
              ForEach(currentWeekDates, id: \.self ) { date in
                    Text("\(calendar.component(.day, from: date))일")
                        .font(.caption2)
                        .frame(width: cellWidth)
                }
            }
        }
    }

    var currentWeekDates: [Date] {
        let start = weekStart(for: weekOffset)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

  var weekdaySymbols: [String] {
      let symbols = calendar.shortWeekdaySymbols
      let weekdayShift = calendar.component(.weekday, from: currentWeekDates.first ?? Date()) - 1
      return Array(symbols[weekdayShift...] + symbols[..<weekdayShift])
  }

    var weekRangeText: String {
        let start = weekStart(for: weekOffset)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

  func confirmSchedule(start: Date, end: Date) {
      print("[confirmSchedule] 실행됨")

      // 이벤트 범위 넓게 잡기
      let searchStart = calendar.date(byAdding: .day, value: -7, to: start)!
      let searchEnd = calendar.date(byAdding: .day, value: 7, to: end)!
      let predicate = eventStore.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: nil)
      let events = eventStore.events(matching: predicate)

      print("찾은 이벤트 수: \(events.count)")

      // 기존 일정 삭제
      for event in events where event.title == taskTitle {
          do {
              try eventStore.remove(event, span: .thisEvent)
              print("삭제된 이벤트: \(event.title ?? "")")
          } catch {
              print("삭제 실패: \(error.localizedDescription)")
          }
      }

      // 새 일정 생성
      let newEvent = EKEvent(eventStore: eventStore)
      newEvent.title = taskTitle
      newEvent.startDate = start
      newEvent.endDate = end
      newEvent.notes = "소요시간: \(Int(requiredDuration / 60))분"
      newEvent.calendar = eventStore.defaultCalendarForNewEvents

      do {
          try eventStore.save(newEvent, span: .thisEvent)
          print("저장된 이벤트: \(taskTitle)")
          alertMessage = "캘린더에 반영되었습니다.\n\n\(taskTitle)\n\(formatted(start)) - \(formatted(end))"
          confirmedTimeRange = (start, end)
          showAlert = true
      } catch {
          print("저장 실패: \(error.localizedDescription)")
          alertMessage = "일정 등록에 실패했습니다. 다시 시도해주세요."
          confirmedTimeRange = nil
          showAlert = true
      }

      loadEventsFromCalendar()
  }
  
  func weekStart(for offset: Int) -> Date {
      let base = calendar.date(byAdding: .weekOfYear, value: offset, to: calendar.startOfDay(for: baseDate))!
      let weekday = calendar.component(.weekday, from: base)
      let diff = weekday - calendar.firstWeekday
      return calendar.date(byAdding: .day, value: -diff, to: base)!
  }

    func slotFor(date: Date, hour: Int) -> TimeTableSlot {
        slots.first(where: { calendar.isDate($0.date, inSameDayAs: date) && $0.hour == hour }) ??
        TimeTableSlot(date: date, hour: hour, title: nil, isOccupied: false)
    }

  func handleSlotSelection(_ slot: TimeTableSlot) {
      let start = calendar.date(bySettingHour: slot.hour, minute: 0, second: 0, of: slot.date)!
      //guard let end = calendar.date(byAdding: .second, value: Int(requiredDuration), to: start) else { return }

      let requiredHours = Int(ceil(requiredDuration / 3600))
      let possible = (0..<requiredHours).allSatisfy { offset in
          guard let checkDate = calendar.date(byAdding: .hour, value: offset, to: start) else { return false }
          let match = slots.contains {
              calendar.isDate($0.date, inSameDayAs: checkDate) &&
              $0.hour == calendar.component(.hour, from: checkDate) &&
              !$0.isOccupied
          }
          return match
      }

    if possible {
        selectedSlot = slot
        showModal = true
    } else {
        selectedSlot = nil
        showModal = false

//        // 모달이 닫힌 후 0.2초 기다리고 alert 띄움
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
//            if !showModal {
//                alertMessage = "작업 시간에 필요한 연속 시간이 부족해요. 다른 시간을 선택해주세요."
//                showAlert = true
//            } else {
//                print("모달 아직 떠 있음, 얼러트 생략됨")
//            }
//        }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          alertTrigger = .failure("작업 시간에 필요한 연속 시간이 부족해요. 다른 시간대를 선택해주세요.")
      }
    }
  }

  func validateSlotAvailability(start: Date, duration: TimeInterval) -> Bool {
      let requiredHours = Int(ceil(duration / 3600))
      return (0..<requiredHours).allSatisfy { offset in
          guard let checkDate = calendar.date(byAdding: .hour, value: offset, to: start) else { return false }
          return slots.contains {
              calendar.isDate($0.date, inSameDayAs: checkDate) &&
              $0.hour == calendar.component(.hour, from: checkDate) &&
              !$0.isOccupied
          }
      }
  }
  
    func updateEvent(to start: Date, end: Date) {
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: baseDate, end: end, calendars: calendars)
        let allEvents = store.events(matching: predicate)

        // 이전 이벤트 삭제 (title 기준으로 찾음)
        for event in allEvents where event.title == taskTitle {
            try? store.remove(event, span: .thisEvent, commit: true)
        }

        // 새 이벤트 생성
        let newEvent = EKEvent(eventStore: store)
        newEvent.title = taskTitle
        newEvent.startDate = start
        newEvent.endDate = end
        newEvent.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(newEvent, span: .thisEvent, commit: true)
            alertMessage = "캘린더에 반영되었습니다.\n\n\(taskTitle)\n\(formatted(start)) - \(formatted(end))"
            showAlert = true
            loadEventsFromCalendar()
        } catch {
            alertMessage = "일정 저장 중 오류가 발생했습니다. 다시 시도해주세요."
            showAlert = true
        }
    }

    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일(E) a h:mm"
        return formatter.string(from: date)
    }

    func loadEventsFromCalendar() {
        store.requestAccess(to: .event) { granted, _ in
            guard granted else { return }

            let start = weekStart(for: weekOffset)
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            let events = store.events(matching: predicate)

            DispatchQueue.main.async {
                var generated: [TimeTableSlot] = []

                for date in currentWeekDates {
                    for hour in preferStartHour..<preferEndHour {
                        let fullDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
                        generated.append(TimeTableSlot(date: fullDate, hour: hour, title: nil, isOccupied: false))
                    }
                }

              for event in events {
                  guard let start = event.startDate as Date?, let end = event.endDate as Date? else { continue }

                  var current = start
                  while current < end {
                      let hour = calendar.component(.hour, from: current)
                      let dayStart = calendar.startOfDay(for: current)

                      if hour >= preferStartHour && hour < preferEndHour {
                          if let fullHourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) {
                              if let index = generated.firstIndex(where: { $0.date == fullHourDate && $0.hour == hour }) {
                                  generated[index] = TimeTableSlot(
                                      date: fullHourDate,
                                      hour: hour,
                                      title: event.title,
                                      isOccupied: true
                                  )
                              }
                          }
                      }

                      guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
                      current = next
                  }
              }

                slots = generated
            }
        }
    }
}
