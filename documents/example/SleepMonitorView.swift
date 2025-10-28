//
//  SleepMonitorView.swift
//  HealthKit_practice
//
//  Created by 나산하 on 8/6/25.
//

import SwiftUI
import UserNotifications

struct SleepSensorTestView: View {
    @StateObject private var sensorManager = TestSleepSensorManager()
    @State private var showingResults = false
    @State private var showingFileList = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 헤더
                    VStack(spacing: 10) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("수면 센서 테스트")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("센서 데이터 수집 및 JSON 출력 테스트")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // 상태 표시
                    StatusCardView(isMonitoring: sensorManager.isMonitoring)
                    
                    // 메인 버튼들
                    VStack(spacing: 15) {
                        if sensorManager.isMonitoring {
                            // 모니터링 중일 때
                            Button(action: {
                                sensorManager.stopTestCollection()
                                showingResults = true
                            }) {
                                HStack {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.title2)
                                    Text("데이터 수집 중지")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.red)
                                .cornerRadius(30)
                            }
                        } else {
                            // 대기 중일 때
                            VStack(spacing: 15) {
                                // 실제 센서 테스트 버튼
                                Button(action: {
                                    sensorManager.startTestCollection()
                                }) {
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                        Text("실제 센서 테스트 시작")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 60)
                                    .background(Color.blue)
                                    .cornerRadius(30)
                                }
                                
                                // 30초 빠른 테스트 버튼
                                Button(action: {
                                    Task {
                                        await sensorManager.runQuickTest()
                                        showingResults = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "timer")
                                        Text("30초 빠른 테스트")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                                }
                                
                                // 더미 데이터 테스트 버튼
                                Button(action: {
                                    sensorManager.generateDummyTestData()
                                    showingResults = true
                                }) {
                                    HStack {
                                        Image(systemName: "wand.and.stars")
                                        Text("더미 데이터 테스트")
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.purple)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.purple, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        
                        // 저장된 파일 보기 버튼
                        Button(action: {
                            showingFileList = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("저장된 테스트 데이터 보기")
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22.5)
                                    .stroke(Color.green, lineWidth: 1.5)
                            )
                        }
                        .disabled(sensorManager.isMonitoring)
                    }
                    .padding(.horizontal, 20)
                    
                    // 테스트 결과 미리보기
                    if !sensorManager.testResults.isEmpty {
                        TestResultsPreview(results: sensorManager.testResults)
                    }
                    
                    // 권한 상태 표시
                    PermissionStatusView()
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingResults) {
            TestResultsDetailView(
                sensorManager: sensorManager,
                isPresented: $showingResults
            )
        }
        .sheet(isPresented: $showingFileList) {
            SavedFilesListView(sensorManager: sensorManager)
        }
        .onAppear {
            requestNotificationPermission()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                print("알림 권한: \(granted ? "✅ 승인" : "❌ 거부")")
            }
        }
    }
}

// MARK: - 상태 카드
struct StatusCardView: View {
    let isMonitoring: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            if isMonitoring {
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                    
                    Text("센서 데이터 수집 중...")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("움직임과 소리를 감지하고 있습니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("센서 준비 완료")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("테스트를 시작해보세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 테스트 결과 미리보기
struct TestResultsPreview: View {
    let results: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("최근 테스트 결과")
                    .font(.headline)
                Spacer()
            }
            
            Text(results)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(10)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - 권한 상태 표시
struct PermissionStatusView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("필요한 권한")
                .font(.headline)
                .padding(.horizontal, 20)
            
            VStack(spacing: 5) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "마이크 권한",
                    description: "소음 레벨 측정",
                    isRequired: true
                )
                
                PermissionRow(
                    icon: "gyroscope",
                    title: "모션 센서",
                    description: "움직임 감지",
                    isRequired: true
                )
                
                PermissionRow(
                    icon: "bell.fill",
                    title: "알림 권한",
                    description: "테스트 완료 알림",
                    isRequired: false
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isRequired: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isRequired {
                        Text("필수")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 테스트 결과 상세 화면
struct TestResultsDetailView: View {
    @ObservedObject var sensorManager: TestSleepSensorManager
    @Binding var isPresented: Bool
    @State private var showingJSON = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !sensorManager.testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("테스트 결과 요약")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(sensorManager.testResults)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showingJSON = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("JSON 데이터 보기")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        }
                    } else {
                        Text("테스트 결과가 없습니다")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("테스트 결과")
            .navigationBarItems(trailing: Button("닫기") {
                isPresented = false
            })
        }
        .sheet(isPresented: $showingJSON) {
            JSONDataView(sensorManager: sensorManager)
        }
    }
}

// MARK: - JSON 데이터 화면
struct JSONDataView: View {
    @ObservedObject var sensorManager: TestSleepSensorManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    if let sleepData = sensorManager.currentSessionData,
                       let jsonString = sleepData.toJSONString() {
                        
                        Text("생성된 JSON 데이터")
                            .font(.headline)
                        
                        Text(jsonString)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                        
                        Button(action: {
                            UIPasteboard.general.string = jsonString
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("JSON 복사하기")
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    } else {
                        Text("JSON 데이터가 없습니다")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("JSON 데이터")
            .navigationBarItems(trailing: Button("닫기") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - 저장된 파일 목록
struct SavedFilesListView: View {
    @ObservedObject var sensorManager: TestSleepSensorManager
    @Environment(\.presentationMode) var presentationMode
    @State private var savedFiles: [URL] = []
    
    var body: some View {
        NavigationView {
            List {
                if savedFiles.isEmpty {
                    Text("저장된 테스트 데이터가 없습니다")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(savedFiles, id: \.self) { fileURL in
                        FileRowView(fileURL: fileURL, sensorManager: sensorManager)
                    }
                }
            }
            .navigationTitle("저장된 데이터")
            .navigationBarItems(trailing: Button("닫기") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                savedFiles = sensorManager.getAllTestFiles()
            }
        }
    }
}

struct FileRowView: View {
    let fileURL: URL
    let sensorManager: TestSleepSensorManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatFileName(fileURL.lastPathComponent))
                .font(.headline)
            
            Text(formatFileDate(fileURL.lastPathComponent))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .onTapGesture {
            _ = sensorManager.loadTestFile(from: fileURL)
        }
    }
    
    private func formatFileName(_ fileName: String) -> String {
        fileName
            .replacingOccurrences(of: "test_sleep_data_", with: "")
            .replacingOccurrences(of: ".json", with: "")
            .replacingOccurrences(of: "_", with: " ")
    }
    
    private func formatFileDate(_ fileName: String) -> String {
        let dateString = fileName
            .replacingOccurrences(of: "test_sleep_data_", with: "")
            .replacingOccurrences(of: ".json", with: "")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - 미리보기
struct SleepSensorTestView_Previews: PreviewProvider {
    static var previews: some View {
        SleepSensorTestView()
    }
}
