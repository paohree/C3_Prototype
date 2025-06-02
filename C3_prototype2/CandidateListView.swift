//
//  CandidateListView.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI
import EventKit

struct CandidateListView: View {
  let title: String
  let duration: Int
  let deadline: Date
  let contactedDate: Date
  let searchStart: Date
  let selectedCalendar: EKCalendar           // 스케줄인풋뷰에서 받은 정보들을 변수에 할당
  
  @Environment(\.dismiss) private var dismiss      //이건 모달 닫을 때 쓰임
  
  private let eventStore = EKEventStore()          // 캘린더 접근 객체
  
  @State private var busyMap: [Date: [Int: String]] = [:]      // 날짜별 시간별 일정 제목이 들어간 맵
  
  @State private var loading = true                            // 달력 데이터가 많아서 못가져오면 보여줄 프로그래스 뷰 판단기준
  
  private let hours = Array(0..<24)             //시간대 세로 축
  
  private let cellHeight: CGFloat = 44          // 셀 높이
  
  var body: some View {
    NavigationStack {
      if loading {                         //로딩중이면
        ProgressView("시간 계산 중...")     //이 화면 뜨고
          .onAppear {                  //화면이 뜨면 바로 캘린더에 정보 요청함
            requestAccessAndPrepareMap()
          }
      } else if busyMap.isEmpty {           // 만약 캘린더 가져오고 시각적 맵을 만들었는데 비어있다면 아무것도 없다 표시
        Text("후보 시간이 없습니다")
          .font(.headline)
          .padding()
      } else {                              // 캘린더 가져와서 시각적 맵을 만들었고 내용이 있다면 아래로 들어감. 시간표를 그리겠다는 것임
        TimeGridView(
          busyMap: busyMap,
          //hours: hours,
          cellHeight: cellHeight,
          //onSelect 이거 콜백함수임 그래서 클로저 붙는데 내용은 애플캘린더에 전송한다는 내용임
          onSelect: { selectedDate, selectedHour in
            if let selectedStart = Calendar.current.date(bySettingHour: selectedHour, minute: 0, second: 0, of: selectedDate) {
              insertEvent(start: selectedStart)
              dismiss()
            }
          }
        )
        /*
        ScrollView([.horizontal, .vertical]) {  // 오른쪽 왼쪽으로 움직일 수 있음
          HStack(alignment: .top, spacing: 0) {
            
            // 세로축: 시간
            VStack(spacing: 0) {
              Text("").frame(height: 30)
              ForEach(hours, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                  .font(.caption2)
                  .frame(width: 60, height: cellHeight)
              }
              .padding(1)
            }
            
            // 날짜별 컬럼
            ForEach(busyMap.keys.sorted(), id: \.self) { date in
              VStack(spacing: 0) {
                
                // 날짜 보여줌
                Text(date.formatted(date: .abbreviated, time: .omitted))
                  .font(.caption)
                  .frame(height: 30)
                
                ForEach(hours, id: \.self) { hour in
                  let label = busyMap[date]?[hour] ?? "" //busymap에 내용이 없다면 ""임
                  let isBusy = !label.isEmpty            // 일정 넣을 수 있게 빈 셀을 버튼으로 만들어야 해서 만든 변수임
                  Button {
                    if !isBusy {
                      insertEvent(start: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date)!)
                      dismiss()
                    }
                  } label: {
                    ZStack {
                      RoundedRectangle(cornerRadius: 4)
                        .fill(isBusy ? Color.red.opacity(0.3) : Color.blue.opacity(0.2))
                        .frame(width: 80, height: cellHeight)
                      Text(isBusy ? label : "")
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(width: 76)
                    }
                  }
                  .disabled(isBusy)     //isbusy가 true면 버튼 비활성화임 일정 거기에 들어가면 안되니까
                  .padding(1)
                }
              }
            }
          }
          .padding()
        }
         */
        .navigationTitle("후보 시간 선택")
      }
    }
  }
  
  //캘린더 가져오는 함수임
  func requestAccessAndPrepareMap() {
    eventStore.requestFullAccessToEvents { granted, error in
      if granted { //캘린더 접근 권한이 있으면
        let map = buildBusyMap()   //일정 정보 가져오고 시각화할 map을 만듦
        DispatchQueue.main.async {
          self.busyMap = map
          self.loading = false    //다 만들었으면 false로 값 바꾸로 로딩 화면 없어질거임
        }
      } else {
        print("캘린더 접근 거부됨: \(error?.localizedDescription ?? "")")
        loading = false
      }
    }
  }
  
  //날짜별로, 시간 단위로 어떤 이벤트가 있는지 매핑함
  
  func buildBusyMap() -> [Date: [Int: String]] {
    print("검색범위: \(searchStart.formatted()) ~ \(deadline.formatted())")
    
    var result: [Date: [Int: String]] = [:] //날짜별로 각 딕셔너리 초기화
    let calendar = Calendar.current         //현재 캘린더 객체
    var current = calendar.startOfDay(for: searchStart)     //검색 시작 날짜의 시간을 00시 00분으로 설정
    
    //마감기한까지 반복할건데,
    while current <= deadline {
      
      //해당 날짜 하루 시작
      let dayStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: current)!
      
      //해당 날짜 하루 끝
      let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: current)!
      
      //위의 두 기준으로 일정 가져옴
      let predicate = eventStore.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
      let events = eventStore.events(matching: predicate)
      
      //시간 단위로 일정 제목을 저장할 딕셔너리도 초기화
      var hourMap: [Int: String] = [:]
      for event in events {
        let startHour = calendar.component(.hour, from: event.startDate)    //시작시간 시
        let endHour = calendar.component(.hour, from: event.endDate)        //종료시간 시
        for hour in startHour..<min(endHour, 24) {                          //해당 시간을 일정있음으로 표시
          hourMap[hour] = event.title //해당 시간에 일정 제목도 넣어줌
        }
      }
      
      result[current] = hourMap        //하루치 계산한거 하루치에 할당함
      current = calendar.date(byAdding: .day, value: 1, to: current)!      //그 다음 날짜 계산하러 가야 함
    }
    
    return result
  }
  
  //사용자가 선택한 셀 날짜에 일정을 넣어주기 위한 함수임
  func insertEvent(start: Date) {
    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = start
    event.endDate = Calendar.current.date(byAdding: .hour, value: duration, to: start)!
    event.calendar = selectedCalendar
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    event.notes = "연락온날:\(formatter.string(from: contactedDate))\n기한:\(formatter.string(from: deadline))"
    
    do {
      try eventStore.save(event, span: .thisEvent) // 이부분이 사실 핵심
      print("일정 등록 완료")
    } catch {
      print("저장 실패: \(error.localizedDescription)")
    }
  }
}

#Preview {
  let eventStore = EKEventStore()
  let calendars = eventStore.calendars(for: .event)
  let sampleCalendar = calendars.first ?? EKCalendar(for: .event, eventStore: eventStore)
  
  return CandidateListView(
    title: "예시 미팅",
    duration: 2,
    deadline: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
    contactedDate: Date(),
    searchStart: Date(),
    selectedCalendar: sampleCalendar
  )
}
