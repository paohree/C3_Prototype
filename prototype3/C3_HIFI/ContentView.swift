//
//  ContentView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

/*
SelectTaskView
 ├─ onAppear → initialize()
 │   ├─ requestCalendarAccess()
 │   │   └─ EventKit 권한 요청
 │   └─ fetchEvents(for: selectedDate)
 │       ├─ EventKit에서 일정 불러오기
 │       ├─ TimeSlot 생성
 │       │   └─ TimeSlot(day, hour, title, startDate, endDate)
 │       └─ occupiedSlots 저장: [TimeSlot]
 │
 ├─ 날짜 선택(DatePicker) → fetchEvents() 재호출
 │
 ├─ mergeTimeSlots(slots: [TimeSlot]) → [MergedSlot]
 │   ├─ 동일한 날짜(day)에 대해 연속된 hour 병합
 │   └─ MergedSlot(title, startHour, endHour, startDate, endDate)
 │
 ├─ TaskSlotListView(mergedSlots: [MergedSlot])
 │   └─ 사용자 선택 시 selectedIndex 변경
 │
 └─ NavigationLink(destinationView())
     └─ mergedSlots[selectedIndex] → TimeSlot 생성
         └─ DetailInputView(TimeSlot)
         └─ 변환: MergedSlot → TimeSlot

EKEvent -> TimeSlot -> MergedSlot -> TimeSlot 흐름임

 
 
 
 
 
DetailInputView
 ├─ 입력 받은 TimeSlot 기반 초기 상태값 세팅
 │   ├─ startDate = day의 시작
 │   ├─ endDate = startDate + 7일
 │   ├─ preferStartTime = 오전 9시
 │   └─ preferEndTime = 오후 6시
 │
 ├─ 사용자: 날짜와 선호 시간 범위 선택
 │
 └─ NavigationLink
     └─ TimeTableView(
           baseDate = startDate,
           requiredDuration = slot.endDate - slot.startDate,
           preferStartHour = preferStartTime.hour,
           preferEndHour = preferEndTime.hour,
           taskTitle = slot.title
         )
 
 TimeSlot -> 필요한 데이터만 뽑아서 TimeTable에 넘겨줌
 
 
 
 
 
 

TimeTableView
 ├─ onAppear → loadEventsFromCalendar()
 │   ├─ EventKit 이벤트 로드: 현재 주차 기준
 │   ├─ events → TimeTableSlot[] 생성
 │   │   └─ TimeTableSlot(date, hour, title, isOccupied)
 │   └─ slots 상태값에 저장
 │
 ├─ UI 구성
 │   ├─ preferStartHour~preferEndHour 시간 세로축
 │   └─ 주차의 날짜 가로축 → 시간표 렌더링
 │
 ├─ 슬롯 선택(handleSlotSelection(slot: TimeTableSlot))
 │   ├─ 사용자가 선택한 슬롯에서 duration만큼 연속 체크
 │   ├─ 가능 시: selectedSlot 설정 + showModal = true
 │   └─ 불가 시: alertTrigger = .failure(...)
 │
 └─ sheet(isPresented: showModal)
     └─ TimeSelectionModal(
           slot: selectedSlot,
           requiredDuration: requiredDuration,
           onConfirm: (start, end)
         )
 
 
 
 
 

TimeSelectionModal
 ├─ 전달 받은 TimeTableSlot 기반 초기화
 │   ├─ startTime = slot.date + slot.hour
 │   └─ endTime = startTime + requiredDuration
 │
 ├─ 시작 시간 변경 시 → 종료 시간 보정
 │
 └─ onConfirm(start, end)
     └─ TimeTableView → validateSlotAvailability(start)
         ├─ 가능한 경우 → confirmSchedule(start, end)
         │   ├─ 기존 이벤트 삭제
         │   ├─ 새로운 이벤트 생성 (EKEvent)
         │   └─ alertTrigger = .success(...)
         └─ 불가능 → alertTrigger = .failure(...)
 */

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

