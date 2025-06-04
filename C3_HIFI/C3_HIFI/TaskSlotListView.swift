//
//  TaskSlotListView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.
//

import SwiftUI

struct TaskSlotListView: View {
    let mergedSlots: [MergedSlot]
    @Binding var selectedIndex: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(mergedSlots.indices, id: \.self) { index in
                    let slot = mergedSlots[index]
                    Button(action: {
                        selectedIndex = index
                    }) {
                        VStack(alignment: .leading) {
                            Text(slot.title)
                                .fontWeight(.semibold)
                            Text("\(slot.startHour):00 ~ \(slot.endHour):00")
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedIndex == index ? Color.green.opacity(0.9) : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Spacer()
                                if selectedIndex == index {
                                    Image(systemName: "checkmark")
                                        .padding(.trailing)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

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
