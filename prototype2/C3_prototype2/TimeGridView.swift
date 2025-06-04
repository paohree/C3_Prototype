//
//  TimeGridView.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/2/25.
//

import SwiftUI

/// 재사용 가능한 시간표 그리드 뷰
struct TimeGridView: View {
  let busyMap: [Date: [Int: String]]          // 날짜별 시간별 일정 제목
  let hours: [Int] = Array(0..<24)                           // 기본적으로 0..<24
  let cellHeight: CGFloat                     // 셀 높이
  let onSelect: (_ date: Date, _ hour: Int) -> Void // 사용자가 비어 있는 셀을 선택했을 때 호출됨

  var body: some View {
    ScrollView([.horizontal, .vertical]) {
      HStack(alignment: .top, spacing: 0) {

        // 세로축: 시간
        VStack(spacing: 0) {
          Text("").frame(height: 30)
          ForEach(hours, id: \.self) { hour in
            Text(String(format: "%02d:00", hour))
              .font(.caption2)
              .frame(width: 60, height: cellHeight)
              .padding(1)
          }
        }

        // 날짜별 컬럼
        ForEach(busyMap.keys.sorted(), id: \.self) { date in
          VStack(spacing: 0) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
              .font(.caption)
              .frame(height: 30)

            ForEach(hours, id: \.self) { hour in
              let labelForHour = busyMap[date]?[hour] ?? ""
              let isHourBusy = !labelForHour.isEmpty

              Button {
                //빈 버튼 누르면 해당 버튼 시간~소요시간까지 해서 콜백. 외부 뷰로 넘어감
                if !isHourBusy {
                  onSelect(date, hour)
                }
              } label: {
                ZStack {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(isHourBusy ? Color.red.opacity(0.3) : Color.blue.opacity(0.2))
                    .frame(width: 80, height: cellHeight)
                  Text(isHourBusy ? labelForHour : "")
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 76)
                }
              }
              .disabled(isHourBusy)
              .padding(1)
            }
          }
        }
      }
      .padding()
    }
  }
}

#Preview {
  TimeGridView(
    busyMap: [
      Calendar.current.startOfDay(for: Date()): [9: "회의", 14: "점심"]
    ],
    cellHeight: 44,
    onSelect: { selectedDate, selectedHour in
      print("선택됨: \(selectedDate), \(selectedHour)시")
    }
  )
}
