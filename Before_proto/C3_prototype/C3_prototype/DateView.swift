import SwiftUI
import EventKit
import SwiftData

struct TimeSlot: Hashable { //이벤트킷에서 가져온 일정들이 이 형태로 다뤄짐
    let day: Date
    let hour: Int
    let title: String
}

struct DateView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var storedSchedules: [StoredSchedule]
    
    @State var selectedDate: Date = Date()             //일정이 들어가도 될지에 찾아볼 날짜
    @State var occupiedSlots: Set<TimeSlot> = []       //일정이 잡혀있는 시간들 보여주기 위함임
                                                               //예시로 11시부터 12시까지 여러개의 일정이 있을 수 있으나 하나만 보여줌 Set이라서

    @State var newTitle: String = ""                   //사용자가 입력할 일정의 이름
    @State var startTime: Date = Date()                //사용자가 입력할 일정이 들어갈 시작 시간
    @State var estimatedDuration: Int = 1              //사용자가 입력할 예상 소요 시간
    @State var deadlineDate: Date = Date()             // 사용자가 설정하는 "언제까지 해야 하는지", 기한임 메모에 넣을 것임
    @State var contactedDate: Date = Date()            // 사용자가 입력하는 "언제 연락이 왔는지", 이것도 메모에 넣어야 할 것 같음 URL안먹힘
    @State var showInputSheet = false                  //사용자가 입력할 일정을 모달로 해보려고 넣은 변수임

    @State var calendars: [EKCalendar] = []            //기기에 있는 모든 캘린더 목록, 이벤트킷에서 불러옴
    @State var selectedCalendar: EKCalendar?           //사용자가 입력할 캘린더. (아무것도 안넣으면 맨위에 있는 걸로 설정되게 할 것임)
    
    //@State private var timeEndInList:Int = 0

    private let store = EKEventStore()                         // 캘린더 접근하기 위한 객체임

    var body: some View {
         NavigationStack {
             VStack(spacing: 16) {
                 DatePicker("등록하려는 날짜 선택", selection: $selectedDate, displayedComponents: [.date])
                     .padding(.horizontal)

                 VStack {
                     Text("\(formattedWeekday(from: selectedDate)) 입니다")
                     Button("캘린더 일정 불러오기") {
                         requestAccessAndFetchEvents()
                     }
                     .buttonStyle(.borderedProminent)
                 }

                 let sortedSlots = Array(occupiedSlots).sorted(by: slotSort)
                 List(sortedSlots, id: \.self) { slot in
                     Text("\(slot.hour):00 ~ \(slot.hour+1):00 - \(slot.title)")
                 }
                 .listStyle(.plain)

                 Button("새 일정 입력") {
                     startTime = selectedDate
                     deadlineDate = selectedDate
                     contactedDate = selectedDate
                     showInputSheet = true
                 }
                 .padding(.bottom, 10)
             }
             .navigationTitle("일정 등록")
             .sheet(isPresented: $showInputSheet) {
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
                     onSave: {
                         validateAndInsertSchedule()
                     },
                     onHold: {
                         showInputSheet = false
                     }
                 )
             }
             .gesture(
                 DragGesture()
                     .onEnded { value in
                         if value.translation.width < -50 {
                             selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                             requestAccessAndFetchEvents()
                         } else if value.translation.width > 50 {
                             selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                             requestAccessAndFetchEvents()
                         }
                     }
             )
         }
         .onAppear {
             calendars = store.calendars(for: .event)
             if selectedCalendar == nil {
                 selectedCalendar = calendars.first
             }
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

    // 일정 가져오는 부분임
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
            showInputSheet = false
            requestAccessAndFetchEvents()
        } catch {
            print("저장 실패: \(error.localizedDescription)")
        }
    }

    
    //리스트에서 시간순 정렬할 때 쓰임
    func slotSort(a: TimeSlot, b: TimeSlot) -> Bool {
        if a.day != b.day {
            return a.day < b.day // 날짜가 다르면 날짜 순으로 정렬
        } else {
            return a.hour < b.hour // 날짜가 같으면 시간 순으로 정렬
        }
    }

    
    //디버그할때 쓰임 Date를 string으로
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd (E)"
        return formatter.string(from: date)
    }
    
    func formattedWeekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR") // 한국어 요일
        formatter.dateFormat = "EEEE" // 요일 전체 (예: 월요일)
        return formatter.string(from: date)
    }
}

#Preview {
    DateView()
}
