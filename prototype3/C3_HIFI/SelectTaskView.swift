//
//  SelectTaskView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI
import EventKit

struct TimeSlot: Hashable, Identifiable {
    let id = UUID()
    let day: Date
    let hour: Int
    let title: String
    let startDate: Date
    let endDate: Date
}

struct MergedSlot: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let startHour: Int
    let endHour: Int
    let startDate: Date
    let endDate: Date
}

struct SelectTaskView: View {
    @State private var occupiedSlots: [TimeSlot] = []
    @State private var selectedDate = Date()
    @State private var selectedSlotIndex: Int? = nil
    @State private var navigate = false

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
        
       // Divider()
        
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
        
        //Divider()
        
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

    var headerSection: some View {
        HStack {
            Text("기존 작업이 등록된 날짜를 선택해주세요.")
            Spacer()
        }
    }

    var datePickerSection: some View {
        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
            .onChange(of: selectedDate) { _, _ in fetchEvents() }
            .labelsHidden()
            .padding(.horizontal, 8)
            //.background(Color.gray.opacity(0.3))
            //.clipShape(RoundedRectangle(cornerRadius: 8))
    }

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

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일(E)"
        return formatter.string(from: date)
    }

    func initialize() {
        fetchEvents()
        requestCalendarAccess()
    }

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

    func fetchEvents() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)

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

    func mergeTimeSlots(_ slots: [TimeSlot]) -> [MergedSlot] {
        var merged: [MergedSlot] = []
        let sorted = slots.sorted(by: { $0.hour < $1.hour })
        var buffer: [TimeSlot] = []

        for slot in sorted {
            if buffer.isEmpty || (buffer.last!.title == slot.title && buffer.last!.hour + 1 == slot.hour) {
                buffer.append(slot)
            } else {
                appendMerged(&merged, from: buffer)
                buffer = [slot]
            }
        }
        appendMerged(&merged, from: buffer)
        return merged
    }

    func appendMerged(_ merged: inout [MergedSlot], from buffer: [TimeSlot]) {
        guard let first = buffer.first, let last = buffer.last else { return }
        merged.append(MergedSlot(title: first.title, startHour: first.hour, endHour: last.hour + 1, startDate: first.startDate, endDate: last.endDate))
    }

    func slotSort(a: TimeSlot, b: TimeSlot) -> Bool {
        (a.day, a.hour) < (b.day, b.hour)
    }
}

#Preview {
    SelectTaskView()
}
