//
//  ScheduleInputView.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI
import EventKit


// 일정 등록 뷰에서 일정 정보를 넣고 누를 수 있는 버튼이 두개가 있는데, 하나는 보관함이고 하나는 후보시간 찾기임
// 후보 시간 찾기 버튼을 누르면 모달이 뜨고 모달에서 캘린더 조회, 시각화까지 해서 뷰로 보여주는데
// 모달에 정보를 넘겨주기 위한 것이 아래의 스트럭쳐. 모달이 켜지면 정보가 스트럭쳐가 있다가 닫으면 없어짐
// 보관함으로 넘기려면 그건 앱이 켜고 꺼지든 저장이 되어 있어야 하니까 swiftdata로 저장 삭제 조회를 하게 할 것임

// 이게 모달로 넘길때 값들을 따로따로 넘기니까
// 업데이트 문제가 난건지 모달에서 정확하게 일정 범위가 먹히지 않는 상황이 나왔음
// 그래서 스트럭쳐로 했던건데 위의 문제는 안 남
// 왜 차이가 나는지는 정확하게 잘 모르겠음

struct CandidateInput: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let duration: Int
    let deadline: Date
    let contactedDate: Date
    let searchStart: Date
    let selectedCalendar: EKCalendar
}

struct ScheduleInputView: View {
    
    //보류한 일정은 스위프트데이터 이용해야 하니까 있는 스위프트데이터 컨텍스트임
    @Environment(\.modelContext) private var modelContext
    
    //모달을 띄우기 위한 변수임
    @State private var candidateInput: CandidateInput? = nil
    
    //사용자가 입력할 값들임.
    @State private var searchStartDate: Date = Date()
    @State private var title: String = ""
    @State private var duration: Int = 1
    @State private var deadline: Date = Date()
    @State private var contactedDate: Date = Date()

    // 일정을 캘린더로 보낼 때 그 일정이 어떤 캘린더 소속인지도 중요한 것 같아서 어떤 캘린더가 있는지 가져오기 위한 부분임
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendarID: String = ""
    @State private var selectedCalendar: EKCalendar?
    private let eventStore = EKEventStore()

    var body: some View {
        NavigationStack {
            Form {
                // 검색 또는 보관하려는 일정에 관련된 뷰 요소임
                Section(header: Text("일정 정보")) {
                    TextField("제목", text: $title)

                    Stepper(value: $duration, in: 1...12) {
                        Text("예상 소요 시간: \(duration)시간")
                    }

                    DatePicker("검색 시작 시점", selection: $searchStartDate, in: Date()..., displayedComponents: [.date])

                    DatePicker("마감 기한", selection: $deadline, displayedComponents: .date)

                    DatePicker("연락 온 날", selection: $contactedDate, displayedComponents: .date)

                    Picker("캘린더 선택", selection: $selectedCalendarID) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            Text(calendar.title).tag(calendar.calendarIdentifier)
                        }
                    }
                    //사용자가 다른 캘린더 선택 시 다른 캘린더에 넣어줘야 하니까 변수 업데이트
                    //ID는 그냥 문자열이니까 거기에 맞는 캘린더 값으로 바꾸는 것임
                    .onChange(of: selectedCalendarID) { oldValue, newValue in
                        selectedCalendar = calendars.first { calendar in calendar.calendarIdentifier == newValue }
                    }
                }

                HStack {
                    
                    //버튼 두개 배치 하나는 스위프트데이터 이용해서 보관함에 저장할 버튼, 하나는 후보 시간 보여줄 버튼
                    
                    Button{
                        let stored = StoredSchedule(
                            title: title,
                            duration: duration,
                            deadline: deadline,
                            contactedDate: contactedDate,
                            searchStart: Calendar.current.startOfDay(for: searchStartDate),
                            calendarID: selectedCalendar?.calendarIdentifier
                        )
                        modelContext.insert(stored)
                        print("보류하기 버튼 눌림")
                    }label:{
                        Text("일정 보류하기")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    
                    Button{
                        if let selectedCalendar {
                            candidateInput = CandidateInput(
                                title: title,
                                duration: duration,
                                deadline: deadline,
                                contactedDate: contactedDate,
                                searchStart: Calendar.current.startOfDay(for: searchStartDate),
                                selectedCalendar: selectedCalendar
                            )
                        }
                    }label:{
                        Text("후보시간 찾기")
                    }
                    .disabled(selectedCalendar == nil)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("일정 등록")
            .onAppear {
                requestCalendarAccess()
            }
            .sheet(item: $candidateInput) { input in
                CandidateListView(
                    title: input.title,
                    duration: input.duration,
                    deadline: input.deadline,
                    contactedDate: input.contactedDate,
                    searchStart: input.searchStart,
                    selectedCalendar: input.selectedCalendar
                )
            }
        }
    }
    
    //캘린더 목록 가져와야해서 있는 캘린더 접속 부분임
    func requestCalendarAccess() {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted {
                let editableCalendars = eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
                DispatchQueue.main.async {
                    calendars = editableCalendars
                    if let first = editableCalendars.first {
                        selectedCalendarID = first.calendarIdentifier
                        selectedCalendar = first
                    }
                }
            } else {
                print("캘린더 접근 권한 없음: \(error?.localizedDescription ?? "알 수 없음")")
            }
        }
    }
}


#Preview {
    ScheduleInputView()
}
