//
//  TimeTableView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.

import SwiftUI
import EventKit

/// 시간표에 표시할 개별 슬롯 단위 (1시간 단위)
struct TimeTableSlot: Identifiable, Hashable {
  let id = UUID()
  let date: Date              // 슬롯의 날짜
  let hour: Int               // 슬롯의 시간 (0~23)
  let title: String?          // 해당 시간대에 있는 이벤트 제목
  let isOccupied: Bool        // 일정 존재 여부
}

/// Alert의 성공/실패 유형을 enum으로 구분
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
  
  // Alert 노출 트리거 (성공 or 실패 케이스를 enum으로)
  @State private var alertTrigger: AlertType? = nil
  
  // 모달 창 표시 여부
  @State private var isModalActive = false
  
  // 이벤트 저장용 EventKit 객체
  @State private var eventStore = EKEventStore()
  
  // 뷰 닫기용 환경 변수
  @Environment(\.dismiss) private var dismiss
  
  // 외부에서 전달되는 파라미터들
  let baseDate: Date                     // 기준 날짜 (보통 시작 날짜)
  let requiredDuration: TimeInterval    // 필요한 작업 시간 (초 단위)
  let preferStartHour: Int              // 선호 시작 시간 (0~23)
  let preferEndHour: Int                // 선호 종료 시간 (0~23)
  let taskTitle: String                 // 작업 제목
  
  // 내부 상태
  @State private var slots: [TimeTableSlot] = []          // 전체 시간 슬롯 배열
  @State private var selectedSlot: TimeTableSlot? = nil   // 선택된 슬롯
  @State private var showModal = false                    // 모달 표시 여부
  @State private var showAlert = false                    // 얼럿 표시 여부 (deprecated)
  @State private var alertMessage = ""                    // 얼럿 메시지 (deprecated)
  @State private var confirmedTimeRange: (Date, Date)? = nil // 확정된 시간
  @State private var weekOffset: Int = 0                  // 주차 오프셋 (0은 이번주, -1은 지난주 등)
  
  private let calendar = Calendar.current
  private let cellWidth: CGFloat = 48
  private let store = EKEventStore() // 캘린더 이벤트 저장용
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        header     // 상단 제목 및 주 이동 영역
        dayHeader  // 요일 및 날짜 라벨
        
        // 시간 슬롯 그리드
        ScrollView(.vertical) {
          HStack(alignment: .top, spacing: 0) {
            // 세로 시간축 (시 단위)
            VStack(spacing: 1) {
              ForEach(preferStartHour ..< preferEndHour, id: \.self) { hour in
                Text("\(hour)시")
                  .font(.caption2)
                  .frame(width: 30, height: 44)
              }
            }
            
            // 가로 날짜축 (1주 단위)
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
      
      // 슬롯 선택 시 모달 창 표시
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
    // 모달 닫힘 후 Alert 표시
    .onChange(of: showModal) { newValue in
      if newValue == false {
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
    // Alert 표시
    .alert(item: $alertTrigger) { $0.alert }
    .onAppear {
      loadEventsFromCalendar()
    }
  }
  
  /// 상단 작업명, 주차 이동, 소요시간 표시
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
  
  /// 요일/날짜 헤더 표시
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
  
  /// 현재 주간 날짜 배열 반환
  var currentWeekDates: [Date] {
    let start = weekStart(for: weekOffset)
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }
  
  /// 요일 심볼 (월, 화, ...) 반환
  var weekdaySymbols: [String] {
    let symbols = calendar.shortWeekdaySymbols
    let weekdayShift = calendar.component(.weekday, from: currentWeekDates.first ?? Date()) - 1
    return Array(symbols[weekdayShift...] + symbols[..<weekdayShift])
  }
  
  /// 주간 범위 텍스트 반환
  var weekRangeText: String {
    let start = weekStart(for: weekOffset)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    let end = calendar.date(byAdding: .day, value: 6, to: start)!
    return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
  }
  
  /// 기준 주차의 시작일 계산
  func weekStart(for offset: Int) -> Date {
    let base = calendar.date(byAdding: .weekOfYear, value: offset, to: calendar.startOfDay(for: baseDate))!
    let weekday = calendar.component(.weekday, from: base)
    let diff = weekday - calendar.firstWeekday
    return calendar.date(byAdding: .day, value: -diff, to: base)!
  }
  
  /// 특정 날짜+시간에 해당하는 슬롯 찾기
  func slotFor(date: Date, hour: Int) -> TimeTableSlot {
    slots.first(where: { calendar.isDate($0.date, inSameDayAs: date) && $0.hour == hour }) ??
    TimeTableSlot(date: date, hour: hour, title: nil, isOccupied: false)
  }
  
  /// 슬롯 선택 시 호출되는 로직 (모달 표시 여부 판단)
  func handleSlotSelection(_ slot: TimeTableSlot) {
    let start = calendar.date(bySettingHour: slot.hour, minute: 0, second: 0, of: slot.date)!
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
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        alertTrigger = .failure("작업 시간에 필요한 연속 시간이 부족해요. 다른 시간대를 선택해주세요.")
      }
    }
  }
  
  /// 특정 시작시간 기준으로 duration 시간만큼 가능한지 확인
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
  
  /// 일정 확정 및 캘린더 반영
  func confirmSchedule(start: Date, end: Date) {
    let searchStart = calendar.date(byAdding: .day, value: -7, to: start)!
    let searchEnd = calendar.date(byAdding: .day, value: 7, to: end)!
    let predicate = eventStore.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: nil)
    let events = eventStore.events(matching: predicate)
    
    // 기존 작업 삭제
    for event in events where event.title == taskTitle {
      try? eventStore.remove(event, span: .thisEvent)
    }
    
    // 새로운 작업 추가
    let newEvent = EKEvent(eventStore: eventStore)
    newEvent.title = taskTitle
    newEvent.startDate = start
    newEvent.endDate = end
    newEvent.notes = "소요시간: \(Int(requiredDuration / 60))분"
    newEvent.calendar = eventStore.defaultCalendarForNewEvents
    
    do {
      try eventStore.save(newEvent, span: .thisEvent)
      confirmedTimeRange = (start, end)
      showAlert = true
    } catch {
      confirmedTimeRange = nil
      showAlert = true
    }
    
    loadEventsFromCalendar()
  }
  
  /// 날짜 포맷 문자열 반환
  func formatted(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일(E) a h:mm"
    return formatter.string(from: date)
  }
  
  /// 현재 주차 기준 캘린더에서 이벤트 로드
  func loadEventsFromCalendar() {
    store.requestAccess(to: .event) { granted, _ in
      guard granted else { return }
      
      let start = weekStart(for: weekOffset)
      let end = calendar.date(byAdding: .day, value: 7, to: start)!
      let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
      let events = store.events(matching: predicate)
      
      DispatchQueue.main.async {
        var generated: [TimeTableSlot] = []
        
        // 초기화: 빈 슬롯 생성
        for date in currentWeekDates {
          for hour in preferStartHour..<preferEndHour {
            let fullDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
            generated.append(TimeTableSlot(date: fullDate, hour: hour, title: nil, isOccupied: false))
          }
        }
        
        // 실제 이벤트 반영
        for event in events {
          guard let start = event.startDate, let end = event.endDate else { continue }
          
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
