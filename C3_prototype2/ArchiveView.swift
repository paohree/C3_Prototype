//
//  ArchiveView.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \StoredSchedule.savedAt, order: .reverse) var storedSchedules: [StoredSchedule]

    @State private var showClearAllAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if storedSchedules.isEmpty {
                    Text("보관함이 비어있습니다")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(storedSchedules) { schedule in
                            NavigationLink(destination: ScheduleDetailView(schedule: schedule)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(schedule.title)
                                        .font(.headline)
                                    Text("기한: \(schedule.deadline.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                    if let contacted = schedule.contactedDate {
                                        Text("연락 온 날: \(contacted.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("보관함")
            .toolbar {
                if !storedSchedules.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("모두 비우기") {
                            showClearAllAlert = true
                        }
                    }
                }
            }
            .alert("정말 모든 일정을 삭제하시겠습니까?", isPresented: $showClearAllAlert) {
                Button("삭제", role: .destructive) {
                    clearAll()
                }
                Button("취소", role: .cancel) {}
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = storedSchedules[index]
            context.delete(item)
        }
        do {
            try context.save()
        } catch {
            print("삭제 실패: \(error.localizedDescription)")
        }
    }

    private func clearAll() {
        for item in storedSchedules {
            context.delete(item)
        }
        do {
            try context.save()
        } catch {
            print("전체 삭제 실패: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ArchiveView()
}
