// ScheduleModel.swift
// C3_prototype
//
// Created by YONGWON SEO on 5/31/25.
//

import Foundation
import SwiftData

@Model
class StoredSchedule {
    @Attribute(.unique) var id: String
    var title: String
    var startDate: Date?
    var endDate: Date?
    var duration: Int
    var source: String?
    var deadline: Date?
    var contactedDate: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        duration: Int,
        source: String? = nil,
        deadline: Date? = nil,
        contactedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.source = source
        self.deadline = deadline
        self.contactedDate = contactedDate
    }
}
