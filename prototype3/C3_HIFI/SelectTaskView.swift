//
//  SelectTaskView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI
import EventKit

// 하나의 시간 단위 작업을 나타내는 구조체
// 일정 데이터에서 hour 단위로 쪼개 저장된다
struct TimeSlot: Hashable, Identifiable {
  let id = UUID()
  let day: Date               // 해당 작업의 날짜 (startDate의 자정 기준)
  let hour: Int               // 해당 작업의 시간 (0~23)
  let title: String           // 작업 제목 (이벤트 제목)
  let startDate: Date         // 실제 시작 시간 (정확한 시각)
  let endDate: Date           // 실제 종료 시간
}

// 연속된 TimeSlot들을 하나로 합친 구조체
// UI에서 하나의 작업처럼 보이도록 하기 위해 사용
struct MergedSlot: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let startHour: Int          // 병합된 작업의 시작 시간
  let endHour: Int            // 병합된 작업의 종료 시간 + 1
  let startDate: Date         // 시작 Date (시각 포함)
  let endDate: Date           // 종료 Date
}

struct SelectTaskView: View {
  // 현재 선택된 날짜의 TimeSlot 목록 (시간 단위로 쪼갬)
  @State private var occupiedSlots: [TimeSlot] = []
  
  // 사용자가 선택한 날짜
  @State private var selectedDate = Date()
  
  // 사용자가 선택한 MergedSlot의 인덱스
  @State private var selectedSlotIndex: Int? = nil
  
  // 다음 뷰로 이동 여부
  @State private var navigate = false
  
  // 이벤트 접근을 위한 EventKit 객체
  private let store = EKEventStore()
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // 상단 고정 영역
        VStack(spacing: 16) {
          headerSection
          datePickerSection
        }
        .padding(.horizontal)
        .background(Color.black)
        
        
        // 중간 스크롤 가능한 리스트
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            let mergedSlots = mergeTimeSlots(occupiedSlots)
            
            if !mergedSlots.isEmpty {
              Text("\(formattedDate(selectedDate))에 등록된 작업 목록")
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
              
              TaskSlotListView(mergedSlots: mergedSlots, selectedIndex: $selectedSlotIndex)
            } else {
              Text("해당 날짜에 등록된 작업이 없습니다.")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
            }
          }
          .padding()
        }
        
        
        // 하단 고정 버튼
        VStack {
          NavigationLink(destination: destinationView(mergeTimeSlots(occupiedSlots)), isActive: $navigate) {
            Text("작업 세부 정보 등록하기")
              .frame(maxWidth: .infinity)
              .padding()
              .background(selectedSlotIndex == nil ? Color.gray.opacity(0.5) : Color.green)
              .foregroundColor(.black)
              .cornerRadius(10)
          }
          .disabled(selectedSlotIndex == nil)
          .padding(.horizontal)
          .padding(.bottom, 16)
        }
        .background(Color.black)
      }
      .navigationTitle("작업 선택")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear(perform: initialize)
      .preferredColorScheme(.dark)
      .background(Color.black)
      .foregroundColor(.white)
    }
  }
  
  // 상단 안내 텍스트
  var headerSection: some View {
    HStack {
      Text("기존 작업이 등록된 날짜를 선택해주세요.")
      Spacer()
    }
  }
  
  // 날짜 선택 뷰
  var datePickerSection: some View {
    DatePicker("", selection: $selectedDate, displayedComponents: [.date])
      .onChange(of: selectedDate) { _, _ in fetchEvents() }
      .labelsHidden()
      .padding(.horizontal, 8)
  }
  
  // 선택된 인덱스의 작업 정보를 다음 뷰(DetailInputView)로 넘겨주는 뷰 생성 함수
  func destinationView(_ mergedSlots: [MergedSlot]) -> some View {
    if let index = selectedSlotIndex {
      guard mergedSlots.indices.contains(index) else {
        print("mergedSlots out of range: \(index)")
        return AnyView(EmptyView())
      }
      let slot = mergedSlots[index]
      let timeSlot = TimeSlot(
        day: selectedDate,
        hour: slot.startHour,
        title: slot.title,
        startDate: slot.startDate,
        endDate: slot.endDate
      )
      return AnyView(DetailInputView(slot: timeSlot))
    } else {
      return AnyView(EmptyView())
    }
  }
  
  // 날짜 포맷터: '6월 4일(화)' 형태로 출력
  func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일(E)"
    return formatter.string(from: date)
  }
  
  // 초기화 함수: 일정 불러오기 + 접근 권한 요청
  func initialize() {
    fetchEvents()
    requestCalendarAccess()
  }
  
  // 캘린더 접근 권한 요청
  func requestCalendarAccess() {
    if #available(iOS 17.0, *) {
      store.requestFullAccessToEvents { granted, _ in
        print(granted ? " 접근 허용됨" : " 접근 거부됨")
      }
    } else {
      store.requestAccess(to: .event) { granted, _ in
        print(granted ? " 접근 허용됨" : " 접근 거부됨")
      }
    }
  }
  
  // 현재 선택된 날짜에 해당하는 이벤트 불러오기
  // 이벤트들을 TimeSlot 배열로 분해하여 저장
  func fetchEvents() {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: selectedDate)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else { return }
    
    let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
    let events = store.events(matching: predicate)
    
    // 이벤트들을 시간 단위로 쪼개어 TimeSlot 리스트로 변환
    occupiedSlots = events.flatMap { event in
      guard let start = event.startDate, let end = event.endDate else { return [TimeSlot]() }
      var slots: [TimeSlot] = []
      var current = start
      while current < end {
        let hour = calendar.component(.hour, from: current)
        slots.append(TimeSlot(
          day: calendar.startOfDay(for: current),
          hour: hour,
          title: event.title ?? "제목 없음",
          startDate: start,
          endDate: end
        ))
        guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
        current = next
      }
      return slots
    }.sorted(by: slotSort)
  }
  
  // 연속된 TimeSlot들을 병합하여 MergedSlot 리스트로 변환
  func mergeTimeSlots(_ slots: [TimeSlot]) -> [MergedSlot] {
    var merged: [MergedSlot] = []
    let sorted = slots.sorted(by: { $0.hour < $1.hour })
    var buffer: [TimeSlot] = []
    
    for slot in sorted {
      // 연속되면서 제목이 같은 경우 버퍼에 추가
      if buffer.isEmpty || (buffer.last!.title == slot.title && buffer.last!.hour + 1 == slot.hour) {
        buffer.append(slot)
      } else {
        // 그렇지 않으면 병합된 결과 추가 후 버퍼 초기화
        appendMerged(&merged, from: buffer)
        buffer = [slot]
      }
    }
    appendMerged(&merged, from: buffer)
    return merged
  }
  
  // TimeSlot 배열을 하나의 MergedSlot로 변환하여 배열에 추가
  func appendMerged(_ merged: inout [MergedSlot], from buffer: [TimeSlot]) {
    guard let first = buffer.first, let last = buffer.last else { return }
    merged.append(MergedSlot(title: first.title, startHour: first.hour, endHour: last.hour + 1, startDate: first.startDate, endDate: last.endDate))
  }
  
  // 날짜, 시간 순으로 TimeSlot 정렬하는 비교 함수
  func slotSort(a: TimeSlot, b: TimeSlot) -> Bool {
    (a.day, a.hour) < (b.day, b.hour)
  }
}

#Preview {
  SelectTaskView()
}
