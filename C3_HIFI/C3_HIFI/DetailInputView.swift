//
//  DetailInputView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI

struct DetailInputView: View {
    let slot: TimeSlot

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var preferStartTime: Date
    @State private var preferEndTime: Date
    @State private var showAlert = false

    private let duration: TimeInterval

    init(slot: TimeSlot) {
        self.slot = slot
        let calendar = Calendar.current

        // 초기값은 slot 기반
        let defaultStart = calendar.startOfDay(for: slot.startDate)
        let defaultEnd = calendar.date(byAdding: .day, value: 7, to: defaultStart)!

        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultEnd)

        let preferredStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: defaultStart)!
        let preferredEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: defaultStart)!

        _preferStartTime = State(initialValue: preferredStart)
        _preferEndTime = State(initialValue: preferredEnd)

        duration = slot.endDate.timeIntervalSince(slot.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(slot.title)
                .font(.headline)
                .foregroundColor(.green)
                .padding(.horizontal)

            VStack(spacing: 1) {
                dateRow(title: "작업 가능 시작일", selection: $startDate)
                dateRow(title: "작업 마감일", selection: $endDate)
                timeRow(label: "하루 중 선호 시간대", start: $preferStartTime, end: $preferEndTime)
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            if startDate <= endDate && preferStartTime < preferEndTime {
                NavigationLink(
                    destination: TimeTableView(
                        baseDate: startDate,
                        requiredDuration: duration,
                        preferStartHour: Calendar.current.component(.hour, from: preferStartTime),
                        preferEndHour: Calendar.current.component(.hour, from: preferEndTime),
                        taskTitle: slot.title
                    )
                ) {
                    Text("가능한 시간 보기")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                Button {
                    showAlert = true
                } label: {
                    Text("작업 보류하기")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white))
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("세부 정보 입력")
        .alert("작업이 보류되었습니다.", isPresented: $showAlert) {
            Button("보관함에서 보기", role: .cancel) {}
        } message: {
            Text("\(slot.title)\n\(formattedDate(slot.day)) (\(slot.hour):00 - \(slot.hour + 1):00)")
        }
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(.white)
    }

    private func dateRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    private func timeRow(label: String, start: Binding<Date>, end: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            HStack {
                Text("시작")
                Spacer()
                DatePicker("", selection: start, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            HStack {
                Text("종료")
                Spacer()
                DatePicker("", selection: end, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 8)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일(E)"
        return formatter.string(from: date)
    }
}
