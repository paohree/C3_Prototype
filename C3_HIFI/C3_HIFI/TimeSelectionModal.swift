//
//  TimeSelectionModal.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI

struct TimeSelectionModal: View {
    let slot: TimeTableSlot
    let requiredDuration: TimeInterval
    let onConfirm: (Date, Date) -> Void

    @State private var startTime: Date
    @State private var endTime: Date

    init(slot: TimeTableSlot, requiredDuration: TimeInterval, onConfirm: @escaping (Date, Date) -> Void) {
        self.slot = slot
        self.requiredDuration = requiredDuration
        self.onConfirm = onConfirm

        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: slot.hour, minute: 0, second: 0, of: slot.date) ?? Date()
        let end = calendar.date(byAdding: .second, value: Int(requiredDuration), to: start) ?? start

        _startTime = State(initialValue: start)
        _endTime = State(initialValue: end)
    }

    var body: some View {
        VStack(spacing: 24) {
            // 제목과 날짜
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.title ?? "작업")
                    .font(.headline)
                    .foregroundColor(.green)
                Text(formattedDate(slot.date))
                    .font(.subheadline)
                Text("\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 시간 선택기
            VStack(spacing: 16) {
                timePickerRow(title: "시작 시간", time: $startTime)
                    .onChange(of: startTime) { newStart in
                        // 시작 시간 바꾸면 종료 시간도 보정
                        endTime = Calendar.current.date(byAdding: .second, value: Int(requiredDuration), to: newStart) ?? newStart
                    }
                timePickerRow(title: "종료 시간", time: $endTime)
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 확인 버튼
            Button {
              print("[TimeSelectionModal] 확정 버튼 눌림")
                onConfirm(startTime, endTime)
            } label: {
                Text("이 시간으로 확정하기")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canConfirm ? Color.green : Color.gray.opacity(0.3))
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .disabled(!canConfirm)

            Spacer()
        }
        .onAppear {
            // 보정: 종료 시간은 시작 시간 + duration
            endTime = Calendar.current.date(byAdding: .second, value: Int(requiredDuration), to: startTime) ?? startTime
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }

    private var canConfirm: Bool {
        startTime < endTime && endTime.timeIntervalSince(startTime) >= requiredDuration
    }

    private func timePickerRow(title: String, time: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }
}
