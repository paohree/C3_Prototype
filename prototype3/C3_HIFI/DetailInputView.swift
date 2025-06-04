//  DetailInputView.swift
//  C3_HIFI
//
//  Created by YONGWON SEO on 6/3/25.

import SwiftUI

/// 사용자가 기존 작업을 기반으로 세부 정보를 입력하고, 가능한 시간을 확인하거나 보류할 수 있는 화면
struct DetailInputView: View {
  /// 이전 화면에서 선택한 작업 슬롯 정보
  let slot: TimeSlot
  
  /// 작업 가능 시작일
  @State private var startDate: Date
  /// 작업 마감일
  @State private var endDate: Date
  /// 하루 중 선호 시작 시간
  @State private var preferStartTime: Date
  /// 하루 중 선호 종료 시간
  @State private var preferEndTime: Date
  /// 보류 알림 표시 여부
  @State private var showAlert = false
  
  /// 기존 작업의 소요 시간 (초 단위)
  private let duration: TimeInterval
  
  /// 생성자에서 slot 기반으로 초기값 설정
  init(slot: TimeSlot) {
    self.slot = slot
    let calendar = Calendar.current
    
    // 시작일은 작업 시작일의 자정부터
    let defaultStart = calendar.startOfDay(for: slot.startDate)
    // 마감일은 시작일로부터 7일 뒤
    let defaultEnd = calendar.date(byAdding: .day, value: 7, to: defaultStart)!
    
    _startDate = State(initialValue: defaultStart)
    _endDate = State(initialValue: defaultEnd)
    
    // 기본 선호 시간은 9시부터 18시까지
    let preferredStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: defaultStart)!
    let preferredEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: defaultStart)!
    
    _preferStartTime = State(initialValue: preferredStart)
    _preferEndTime = State(initialValue: preferredEnd)
    
    duration = slot.endDate.timeIntervalSince(slot.startDate)
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 상단 제목 (기존 작업 제목)
      Text(slot.title)
        .font(.headline)
        .foregroundColor(.green)
        .padding(.horizontal)
      
      // 날짜 및 시간 입력 섹션
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
      
      // 조건 충족 시 이동 버튼과 보류 버튼 표시
      if startDate <= endDate && preferStartTime < preferEndTime {
        // 가능한 시간 보기 → TimeTableView로 이동
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
        
        // 작업 보류하기 버튼
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
  
  /// 날짜 선택용 행 생성 함수
  private func dateRow(title: String, selection: Binding<Date>) -> some View {
    HStack {
      Text(title)
      Spacer()
      DatePicker("", selection: selection, displayedComponents: .date)
        .labelsHidden()
    }
    .padding(.vertical, 8)
  }
  
  /// 시간 선택용 행 생성 함수
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
  
  /// 날짜 형식 변환기 (ex. 6월 3일(월))
  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일(E)"
    return formatter.string(from: date)
  }
}
