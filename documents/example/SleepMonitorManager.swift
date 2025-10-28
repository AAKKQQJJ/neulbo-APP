//
//  SleepMonitorManager.swift
//  HealthKit_practice
//
//  Created by 나산하 on 8/6/25.
//

import Foundation
import CoreMotion
import AVFoundation

class TestSleepSensorManager: ObservableObject {
    // MARK: - Properties
    @Published var isMonitoring = false
    @Published var currentSessionData: SleepData?
    @Published var testResults: String = ""
    
    private let motionManager = CMMotionManager()
    private let audioEngine = AVAudioEngine()
    
    private var sleepStartTime: Date?
    private var lastSoundSampleTime: Date?
    private var motionDataArray: [MotionData] = []
    private var soundDataArray: [SoundData] = []
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        requestPermissions()
    }
    
    // MARK: - Public Test Methods
    
    /// 테스트용 센서 데이터 수집 시작
    func startTestCollection() {
        guard !isMonitoring else {
            print("⚠️ 이미 모니터링 중입니다")
            return
        }
        
        sleepStartTime = Date()
        lastSoundSampleTime = Date() // 소리 샘플링 시간 초기화
        isMonitoring = true
        motionDataArray.removeAll()
        soundDataArray.removeAll()
        
        startSensorCollection()
        
        print("🧪 테스트 센서 데이터 수집 시작")
        print("📊 움직임 센서: \(motionManager.isAccelerometerAvailable ? "✅" : "❌")")
        print("🔊 오디오 센서: 시작 중...")
    }
    
    /// 테스트용 센서 데이터 수집 종료
    func stopTestCollection() {
        guard isMonitoring else {
            print("⚠️ 모니터링 중이 아닙니다")
            return
        }
        
        isMonitoring = false
        stopSensorCollection()
        
        generateTestResults()
        saveTestData()
        
        print("🧪 테스트 센서 데이터 수집 종료")
    }
    
    /// 짧은 테스트 실행 (30초)
    func runQuickTest() async {
        print("🚀 30초 빠른 테스트 시작")
        
        startTestCollection()
        
        // 30초 대기
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        
        stopTestCollection()
        
        await MainActor.run {
            print(self.testResults)
        }
    }
    
    /// 더미 데이터로 테스트 (센서 없이)
    func generateDummyTestData() {
        print("🎭 더미 데이터 생성 테스트")
        
        let startTime = Date()
        let endTime = Date().addingTimeInterval(3600) // 1시간 후
        
        var dummyMotion: [MotionData] = []
        var dummySound: [SoundData] = []
        
        // 더미 움직임 데이터 생성 (1분마다)
        for i in 0..<60 {
            let timestamp = startTime.addingTimeInterval(Double(i * 60))
            let motion = MotionData(
                timestamp: timestamp,
                sleepStartTime: startTime,
                x: Double.random(in: -0.1 ... 0.1),
                y: Double.random(in: -1.1 ... -0.9), // 중력 방향
                z: Double.random(in: -0.1 ... 0.1)
            )
            dummyMotion.append(motion)
        }
        
        // 더미 소리 데이터 생성 (10초마다)
        for i in 0..<360 {
            let timestamp = startTime.addingTimeInterval(Double(i * 10))
            let sound = SoundData(
                timestamp: timestamp,
                sleepStartTime: startTime,
                decibelLevel: Float.random(in: -60.0 ... -30.0)
            )
            dummySound.append(sound)
        }
        
        let dummySleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            motionData: dummyMotion,
            soundData: dummySound
        )
        
        currentSessionData = dummySleepData
        testResults = dummySleepData.testSummary
        
        print("✅ 더미 데이터 생성 완료")
        print(testResults)
        
        // JSON 출력 테스트
        if let jsonString = dummySleepData.toJSONString() {
            print("\n📄 생성된 JSON 데이터 (처음 500자):")
            print(String(jsonString.prefix(500)) + "...")
        }
    }
    
    // MARK: - 센서 데이터 수집
    
    private func startSensorCollection() {
        startMotionSensors()
        startAudioSensors()
    }
    
    private func stopSensorCollection() {
        motionManager.stopAccelerometerUpdates()
        audioEngine.stop()
    }
    
    private func startMotionSensors() {
        guard motionManager.isAccelerometerAvailable else {
            print("❌ 가속도계를 사용할 수 없습니다")
            return
        }
        
        // 테스트용으로 1초마다 측정
        motionManager.accelerometerUpdateInterval = 1.0
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self,
                  let accelerometerData = data,
                  let startTime = self.sleepStartTime else {
                if let error = error {
                    print("❌ 가속도계 오류: \(error)")
                }
                return
            }
            
            let motionData = MotionData(
                timestamp: Date(),
                sleepStartTime: startTime,
                x: accelerometerData.acceleration.x,
                y: accelerometerData.acceleration.y,
                z: accelerometerData.acceleration.z
            )
            
            self.motionDataArray.append(motionData)
            
            // 테스트용 실시간 로그
            let magnitude = sqrt(motionData.x*motionData.x + motionData.y*motionData.y + motionData.z*motionData.z)
            print("📱 움직임 수집: \(String(format: "%.3f", magnitude))g (\(self.motionDataArray.count)개)")
        }
    }
    
    private func startAudioSensors() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // 테스트용으로 0.5초마다 측정
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, time in
            guard let self = self,
                  let startTime = self.sleepStartTime else { return }
            
            let decibelLevel = self.calculateDecibelLevel(from: buffer)
            
            let soundData = SoundData(
                timestamp: Date(),
                sleepStartTime: startTime,
                decibelLevel: decibelLevel
            )
            
            self.soundDataArray.append(soundData)
            
            // 테스트용 실시간 로그 (조용할 때만)
            if self.soundDataArray.count % 10 == 0 { // 10개마다 출력
                print("🔊 소음 수집: \(String(format: "%.1f", decibelLevel))dB (\(self.soundDataArray.count)개)")
            }
        }
        
        do {
            try audioEngine.start()
            print("✅ 오디오 센서 시작됨")
        } catch {
            print("❌ 오디오 센서 시작 실패: \(error)")
        }
    }
    
    // MARK: - 테스트 결과 생성
    
    private func generateTestResults() {
        guard let startTime = sleepStartTime else {
            testResults = "❌ 시작 시간 정보가 없습니다"
            return
        }
        
        let endTime = Date()
        let sleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            motionData: motionDataArray,
            soundData: soundDataArray
        )
        
        currentSessionData = sleepData
        testResults = sleepData.testSummary + "\n" + sleepData.dataQuality
        
        // 입력/출력 데이터 검증
        validateInputOutput(sleepData)
    }
    
    private func validateInputOutput(_ sleepData: SleepData) {
        print("\n🔍 입력/출력 검증 결과:")
        print("═══════════════════════════════════════")
        
        // 입력 데이터 검증
        print("📥 입력 데이터:")
        print("  - 움직임 센서 작동: \(motionManager.isAccelerometerAvailable ? "✅" : "❌")")
        print("  - 오디오 센서 작동: \(audioEngine.isRunning ? "✅" : "❌")")
        print("  - 수집된 움직임 데이터: \(sleepData.motionData.count)개")
        print("  - 수집된 소리 데이터: \(sleepData.soundData.count)개")
        
        // 출력 데이터 검증
        print("\n📤 출력 데이터:")
        print("  - JSON 변환: \(sleepData.toJSONString() != nil ? "✅" : "❌")")
        print("  - 데이터 유효성: \(sleepData.isValidTestData ? "✅" : "❌")")
        print("  - 세션 ID 생성: \(sleepData.sessionId.isEmpty ? "❌" : "✅")")
        print("  - 시간 계산: \(sleepData.duration > 0 ? "✅" : "❌")")
        
        // 데이터 품질 검증
        print("\n📊 데이터 품질:")
        print("  - \(sleepData.dataQuality)")
        
        if sleepData.isValidTestData {
            print("\n🎉 테스트 성공! 모든 입력/출력이 정상 작동합니다.")
        } else {
            print("\n⚠️ 테스트 부분 실패. 데이터 수집 시간을 늘려보세요.")
        }
    }
    
    // MARK: - 데이터 저장
    
    private func saveTestData() {
        guard let sleepData = currentSessionData,
              let startTime = sleepStartTime else {
            print("❌ 저장할 데이터가 없습니다")
            return
        }
        
        do {
            guard let jsonData = sleepData.toJSONData() else {
                throw NSError(domain: "JSONConversion", code: -1)
            }
            
            let fileURL = createTestFileURL(for: startTime)
            try jsonData.write(to: fileURL)
            
            print("💾 테스트 데이터 저장 완료:")
            print("📁 파일: \(fileURL.lastPathComponent)")
            print("📦 크기: \(jsonData.count) bytes")
            
        } catch {
            print("❌ 테스트 데이터 저장 실패: \(error)")
        }
    }
    
    // MARK: - 헬퍼 메서드
    
    private func calculateDecibelLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return -160.0 }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 1e-8))
        return max(db, -160.0)
    }
    
    private func createTestFileURL(for date: Date) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "test_sleep_data_\(DateFormatter.fileNameFormatter.string(from: date)).json"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    // MARK: - 권한 및 설정
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            print("❌ 오디오 세션 설정 실패: \(error)")
        }
    }
    
    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                print("🔐 마이크 권한: \(granted ? "✅ 승인" : "❌ 거부")")
            }
        }
    }
    
    // MARK: - 파일 관리
    
    func getAllTestFiles() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: nil,
                options: []
            )
            
            return fileURLs.filter {
                $0.pathExtension == "json" &&
                $0.lastPathComponent.hasPrefix("test_sleep_data_")
            }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            print("❌ 테스트 파일 목록 조회 실패: \(error)")
            return []
        }
    }
    
    func loadTestFile(from url: URL) -> SleepData? {
        do {
            let jsonData = try Data(contentsOf: url)
            let sleepData = SleepData.fromJSONData(jsonData)
            
            if let data = sleepData {
                print("📂 테스트 파일 로드 성공: \(url.lastPathComponent)")
                print(data.testSummary)
            }
            
            return sleepData
        } catch {
            print("❌ 테스트 파일 로드 실패: \(error)")
            return nil
        }
    }
    
    func printTestJSON() {
        guard let sleepData = currentSessionData else {
            print("❌ 출력할 데이터가 없습니다")
            return
        }
        
        if let jsonString = sleepData.toJSONString() {
            print("\n📄 생성된 JSON 데이터:")
            print("═══════════════════════════════════════")
            print(jsonString)
            print("═══════════════════════════════════════")
        }
    }
}

// MARK: - Extensions (사용하지 않으므로 제거하거나 참고용)
/*
extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일 HH:mm"
        return formatter
    }()
}
*/
