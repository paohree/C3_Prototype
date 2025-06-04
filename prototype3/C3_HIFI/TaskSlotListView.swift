//
//  TaskSlotListView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI

// 작업 슬롯 리스트를 보여주는 뷰로, 사용자가 선택할 수 있는 슬롯들을 리스트로 나열한다.
struct TaskSlotListView: View {
  let mergedSlots: [MergedSlot] // 병합된 슬롯 리스트 (예: 같은 제목의 연속된 시간대를 하나로 묶은 슬롯)
  @Binding var selectedIndex: Int? // 현재 선택된 슬롯의 인덱스를 바인딩으로 관리한다.
  
  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        // mergedSlots 배열의 각 인덱스를 ForEach로 순회하며 슬롯 UI를 생성한다.
        ForEach(mergedSlots.indices, id: \.self) { index in
          let slot = mergedSlots[index] // 현재 인덱스에 해당하는 MergedSlot 객체
          
          Button(action: {
            selectedIndex = index // 버튼이 눌리면 해당 인덱스를 선택 인덱스로 설정
          }) {
            VStack(alignment: .leading) {
              Text(slot.title) // 슬롯 제목 출력
                .fontWeight(.semibold)
              Text("\(slot.startHour):00 ~ \(slot.endHour):00") // 시간 범위 출력
                .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            // 선택된 슬롯은 초록색, 아닌 경우 회색 배경
            .background(selectedIndex == index ? Color.green.opacity(0.9) : Color.gray.opacity(0.4))
            .cornerRadius(12)
            .overlay(
              HStack {
                Spacer()
                if selectedIndex == index {
                  // 선택된 항목에는 체크 마크 아이콘 표시
                  Image(systemName: "checkmark")
                    .padding(.trailing)
                }
              }
            )
          }
          .buttonStyle(.plain) // 기본 버튼 스타일 제거 (텍스트/색상 등 커스터마이징 목적)
        }
      }
      .padding(.horizontal)
    }
  }
}

// 미리보기용 래퍼 뷰: 실제 앱 실행 없이 SwiftUI Preview에서 확인 가능하게 함
#Preview {
  struct PreviewWrapper: View {
    @State private var selectedIndex: Int? = nil
    
    var body: some View {
      TaskSlotListView(
        mergedSlots: [
          MergedSlot(
            title: "카더가든 유튜브 촬영",
            startHour: 13,
            endHour: 15,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
          ),
          MergedSlot(
            title: "회의",
            startHour: 16,
            endHour: 17,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
          )
        ],
        selectedIndex: $selectedIndex
      )
    }
  }
  
  return PreviewWrapper()
}
