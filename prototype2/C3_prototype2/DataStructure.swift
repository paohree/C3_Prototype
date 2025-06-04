//
//  DataStructure.swift
//  C3_prototype2
//
//  Created by YONGWON SEO on 6/1/25.
//

import Foundation
import SwiftData

// SwiftData로 관리되는 보류 일정 모델
@Model
class StoredSchedule {
    var title: String
    var duration: Int           // 시간 단위임
    var deadline: Date          // 이 날이 검색할 마지막 날
    var contactedDate: Date?    // 선택 사항
    var searchStart: Date       // 검색 시작 시점
    var calendarID: String?     // 선택한 캘린더 ID
    var savedAt: Date           // 보관 시점

    init(
        title: String,
        duration: Int,
        deadline: Date,
        contactedDate: Date? = nil,
        searchStart: Date,
        calendarID: String? = nil,
        savedAt: Date = .now
    ) {
        self.title = title
        self.duration = duration
        self.deadline = deadline
        self.contactedDate = contactedDate
        self.searchStart = searchStart
        self.calendarID = calendarID
        self.savedAt = savedAt
    }
}


