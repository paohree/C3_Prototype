//
//  ModalView.swift
//  C3_prototype
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI
import EventKit
import SwiftData

struct ModalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedSchedules: [StoredSchedule]

    @Binding var selectedDate: Date
    @Binding var occupiedSlots: Set<TimeSlot>

    @Binding var newTitle: String
    @Binding var startTime: Date
    @Binding var estimatedDuration: Int
    @Binding var deadlineDate: Date
    @Binding var contactedDate: Date
    @Binding var showInputSheet: Bool
    @Binding var calendars: [EKCalendar]
    @Binding var selectedCalendar: EKCalendar?

    private let store = EKEventStore()

    var onSave: () -> Void
    var onHold: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("새 일정 입력").font(.headline)) {
                    TextField("제목", text: $newTitle)

                    HStack {
                        Text("시작 시간")
                        Spacer()
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }

                    Stepper(value: $estimatedDuration, in: 1...12) {
                        Text("예상 소요 시간: \(estimatedDuration)시간")
                    }

                    Picker("캘린더 선택", selection: $selectedCalendar) {
                        ForEach(calendars, id: \.self) { calendar in
                            Text(calendar.title).tag(Optional(calendar))
                        }
                    }

                    DatePicker("기한 (언제까지)", selection: $deadlineDate, displayedComponents: [.date])
                    DatePicker("연락 온 날", selection: $contactedDate, displayedComponents: [.date])

                    HStack {
                        Spacer()
                        Button("일정 등록") {
                            validateAndInsertSchedule()
                            
                            // 입력값 초기화
                            newTitle = ""
                            startTime = selectedDate
                            estimatedDuration = 1
                            deadlineDate = selectedDate
                            contactedDate = selectedDate
                            selectedCalendar = calendars.first
                            
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.vertical)
                        Spacer()
                    }
                }

                Section {
                    Button(role: .destructive) {
                        // SwiftData 중복 확인 후 삽입
                        if !storedSchedules.contains(where: {
                            $0.title == newTitle && $0.startDate == startTime
                        }) {
                            let schedule = StoredSchedule(
                                title: newTitle,
                                startDate: startTime,
                                endDate: nil,
                                duration: estimatedDuration,
                                source: selectedCalendar?.title,
                                deadline: deadlineDate,
                                contactedDate: contactedDate
                            )
                            modelContext.insert(schedule)
                            try? modelContext.save()
                            print("보류 일정 저장 완료")
                        } else {
                            print("중복 일정 존재함 → 저장 생략")
                        }

                        // 입력값 초기화
                        newTitle = ""
                        startTime = selectedDate
                        estimatedDuration = 1
                        deadlineDate = selectedDate
                        contactedDate = selectedDate
                        selectedCalendar = calendars.first
                        
                        showInputSheet = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("보류하기")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("일정 입력")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        
                        // 입력값 초기화
                        newTitle = ""
                        startTime = selectedDate
                        estimatedDuration = 1
                        deadlineDate = selectedDate
                        contactedDate = selectedDate
                        selectedCalendar = calendars.first
                        
                        showInputSheet = false
                    }
                }
            }
        }
    }
    
    // 사용자가 만든 일정을 애플캘린더로 보낼 때 쓰임.
    func validateAndInsertSchedule() {
        let startDate = startTime
        guard let endDate = Calendar.current.date(byAdding: .hour, value: estimatedDuration, to: startDate) else {
            print("소요 시간 계산 실패")
            return
        }

        let event = EKEvent(eventStore: store)
        event.title = newTitle
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = selectedCalendar ?? store.defaultCalendarForNewEvents
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let contactString = formatter.string(from: contactedDate)  // 연락 온 날
        let dueString = formatter.string(from: deadlineDate)          // 기한

        event.notes = "연락온날:\(contactString)\n기한:\(dueString)"

        print("일정 저장 시도 중: \(event.title ?? "제목 없음")")
        print("시작: \(event.startDate ?? Date())")
        print("종료: \(event.endDate ?? Date())")
        print("캘린더: \(event.calendar.title)")

        do {
            try store.save(event, span: .thisEvent)
            print("일정 저장 성공")
            requestAccessAndFetchEvents()
        } catch {
            print("저장 실패: \(error.localizedDescription)")
        }
    }
    
    // 캘린더 접근 권한 요청하고 일정 가져옴
    func requestAccessAndFetchEvents() {
        print("이벤트 접근 요청")
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in
                handleAccess(granted: granted, error: error)
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                handleAccess(granted: granted, error: error)
            }
        }
    }
    private func handleAccess(granted: Bool, error: Error?) {
        guard granted else {
            print("접근 거부됨: \(error?.localizedDescription ?? "알 수 없음")")
            return
        }

        print("이벤트 가져오는 중")

        //현재 기기 기준으로 일정 계산함
        //시간대 안정해주면 UTC로 돌아오기 때문에 설정
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        
        //이벤트킷에서 이벤트를 불러오려면 시작점, 끝점이 필요함 그래서 만드는것임
        
        //시작한 날짜의 시간까지 설정해줌
        var startComponents = calendar.dateComponents(in: timeZone, from: selectedDate)
        startComponents.hour = 0
        startComponents.minute = 0
        startComponents.second = 0
        guard let startOfDay = calendar.date(from: startComponents) else {
            print("startOfDay 계산 실패")
            return
        }

        //선택한 날짜의 23:59:59를 끝으로 잡음
        var endComponents = startComponents
        endComponents.hour = 23
        endComponents.minute = 59
        endComponents.second = 59
        guard let endOfDay = calendar.date(from: endComponents) else {
            print("endOfDay 계산 실패")
            return
        }
        
        //이벤트킷에서 이벤트를 불러오려면 시작점, 끝점이 필요함 그래서 만드는것임

        
        //지정한 범위의 일정을 모두 가져옴
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)

        
        print("가져온 이벤트 개수: \(events.count)")
        print("가져온 이벤트 형태: \(events)")
        print("")

        //그래서 이벤트킷에서 가져온 일정 자체는 timeSlot 형태임 간단함
        var slots = Set<TimeSlot>()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        //그래서 일정을 받아와서 시간 단위로 나눠줌
        for event in events {
            guard let start = event.startDate, let end = event.endDate else { continue }
            
            // 기한이랑 연락온날 모두 메모에 있으니까 파싱해줘야 함. nil인 경우를 고려해 if let 옵셔널
            if let notes = event.notes {
                let lines = notes.components(separatedBy: "\n")
                for line in lines {
                    let pair = line.components(separatedBy: ":")
                    if pair.count == 2 {
                        let key = pair[0]
                        let value = pair[1]

                        if key == "연락온날" {
                            if let date = formatter.date(from: value) {
                                print("연락온날: \(date)")
                            }
                        } else if key == "기한" {
                            if let date = formatter.date(from: value) {
                                print("기한: \(date)")
                            }
                        }
                    }
                }
            }

            print("\(event.title ?? "제목 없음")")
            print("시작: \(start)")
            print("종료: \(end)")
            print("캘린더 이름: \(event.calendar.title)")

            
            //통으로 넘어온 이벤트를 한시간 단위로 분할하는 부분
            var current = start
            while current < end {
                let dayStart = calendar.startOfDay(for: current)
                let hour = calendar.component(.hour, from: current)
                slots.insert(TimeSlot(day: dayStart, hour: hour, title: event.title ?? "제목 없음"))

                print("슬롯 생성됨: \(formattedDate(dayStart)) - \(hour):00")

                guard let next = calendar.date(byAdding: .hour, value: 1, to: current) else { break }
                current = next
            }
            print("")
        }

        //메인스레드로 한번에 UI 상태 업데이트. 뷰에서의 리스트와 바인딩되어 있음.
        DispatchQueue.main.async {
            self.occupiedSlots = slots
        }
    }
    
    //디버그할때 쓰임 Date를 string으로
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd (E)"
        return formatter.string(from: date)
    }
    
}
#Preview {
    struct ModalPreviewWrapper: View {
        @State private var selectedDate = Date()
        @State private var occupiedSlots: Set<TimeSlot> = []
        @State private var newTitle = "회의"
        @State private var startTime = Date()
        @State private var estimatedDuration = 2
        @State private var deadlineDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        @State private var contactedDate = Date()
        @State private var showInputSheet = true
        @State private var calendars: [EKCalendar] = []
        @State private var selectedCalendar: EKCalendar?

        var body: some View {
            ModalView(
                selectedDate: $selectedDate,
                occupiedSlots: $occupiedSlots,
                newTitle: $newTitle,
                startTime: $startTime,
                estimatedDuration: $estimatedDuration,
                deadlineDate: $deadlineDate,
                contactedDate: $contactedDate,
                showInputSheet: $showInputSheet,
                calendars: $calendars,
                selectedCalendar: $selectedCalendar,
                onSave: {},
                onHold: {}
            )
        }
    }

    return ModalPreviewWrapper()
        .modelContainer(for: StoredSchedule.self, inMemory: true)
}
