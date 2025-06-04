//
//  TimeSelectionModal.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI

/// 시간 선택 모달 뷰
/// 사용자가 하나의 슬롯을 선택한 후 시작 시간과 종료 시간을 확정하는 화면
struct TimeSelectionModal: View {
    let slot: TimeTableSlot                         // 선택된 슬롯 정보 (날짜, 시간, 예약 여부 등)
    let requiredDuration: TimeInterval              // 작업에 필요한 최소 지속 시간 (초 단위)
    let onConfirm: (Date, Date) -> Void             // 확정 시 콜백으로 시작/종료 시간을 넘김

    // 사용자 조정 가능한 시작/종료 시간
    @State private var startTime: Date
    @State private var endTime: Date

    /// 초기화 시점에서 slot의 시간에 기반하여 기본 시작 및 종료 시간 설정
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
            // 제목 및 날짜 표시
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

            // 시간 선택 DatePicker들
            VStack(spacing: 16) {
                timePickerRow(title: "시작 시간", time: $startTime)
                    .onChange(of: startTime) { newStart in
                        // 시작 시간이 변경되면 종료 시간도 자동 보정
                        endTime = Calendar.current.date(byAdding: .second, value: Int(requiredDuration), to: newStart) ?? newStart
                    }
                timePickerRow(title: "종료 시간", time: $endTime)
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 확정 버튼
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
            .disabled(!canConfirm) // 유효한 시간 아니면 비활성화

            Spacer()
        }
        .onAppear {
            // 진입 시 종료 시간을 시작 + duration 으로 보정
            endTime = Calendar.current.date(byAdding: .second, value: Int(requiredDuration), to: startTime) ?? startTime
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }

    /// 시작 < 종료, 그리고 최소 duration 이상이어야 버튼 활성화 가능
    private var canConfirm: Bool {
        startTime < endTime && endTime.timeIntervalSince(startTime) >= requiredDuration
    }

    /// 시간 선택용 Picker Row
    private func timePickerRow(title: String, time: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    /// 날짜 포맷터 (ex: 2025년 6월 3일 (화))
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }
}
