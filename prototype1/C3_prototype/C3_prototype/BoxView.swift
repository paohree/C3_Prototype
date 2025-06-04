//
//  BoxView.swift
//  C3_prototype
//
//  Created by YONGWON SEO on 5/31/25.
//

import SwiftUI
import SwiftData

struct BoxView: View {
    @Query var schedules: [StoredSchedule]

    @State private var selectedSchedule: StoredSchedule? = nil
    @State private var showModal = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(schedules) { schedule in
                    Button {
                        selectedSchedule = schedule
                        showModal = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.title)
                                .font(.headline)

                            if let deadline = schedule.deadline {
                                Text("기한: \(deadline.formatted(date: .numeric, time: .omitted))")
                            }

                            if let contacted = schedule.contactedDate {
                                Text("연락: \(contacted.formatted(date: .numeric, time: .omitted))")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            // 삭제 로직
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteSchedule)
            }
            .navigationTitle("보관함")
            .sheet(item: $selectedSchedule) { schedule in
                ModalViewForStored(schedule: schedule, showModal: $showModal)
                    .presentationDetents([.medium, .large])
                    .onDisappear {
                        selectedSchedule = nil
                    }
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteSchedule(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(schedules[index])
        }
    }
}

#Preview {
    BoxView()
        .modelContainer(for: StoredSchedule.self, inMemory: true)
}
