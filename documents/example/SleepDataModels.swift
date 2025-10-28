import Foundation

// MARK: - 테스트용 수면 데이터 구조
struct SleepData: Codable {
    // 세션 기본 정보
    let sessionId: String                   // 세션 구분용 ID
    let startTime: Date                     // 수면 시작 시간
    let endTime: Date                       // 수면 종료 시간
    let duration: TimeInterval              // 총 수면 시간 (초)
    
    // 원시 센서 데이터
    let motionData: [MotionData]            // 움직임 데이터
    let soundData: [SoundData]              // 소리 데이터
    
    init(startTime: Date, endTime: Date, motionData: [MotionData], soundData: [SoundData]) {
        self.sessionId = UUID().uuidString
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.motionData = motionData
        self.soundData = soundData
    }
}

// MARK: - 움직임 데이터
struct MotionData: Codable {
    let timestamp: Date                     // 측정 시점
    let relativeTime: TimeInterval          // 수면 시작 대비 상대 시간 (초)
    
    // 3축 가속도 원시 값
    let x: Double                           // X축 가속도 (g)
    let y: Double                           // Y축 가속도 (g)
    let z: Double                           // Z축 가속도 (g)
    
    init(timestamp: Date, sleepStartTime: Date, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.relativeTime = timestamp.timeIntervalSince(sleepStartTime)
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - 소리 데이터
struct SoundData: Codable {
    let timestamp: Date                     // 측정 시점
    let relativeTime: TimeInterval          // 수면 시작 대비 상대 시간 (초)
    let decibelLevel: Float                 // 소음 레벨 (dB)
    
    init(timestamp: Date, sleepStartTime: Date, decibelLevel: Float) {
        self.timestamp = timestamp
        self.relativeTime = timestamp.timeIntervalSince(sleepStartTime)
        self.decibelLevel = decibelLevel
    }
}

// MARK: - JSON 변환 헬퍼
extension SleepData {
    
    // JSON 문자열로 변환 (테스트용 출력)
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ JSON 변환 실패: \(error)")
            return nil
        }
    }
    
    // JSON 바이너리 데이터로 변환 (파일 저장용)
    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            return try encoder.encode(self)
        } catch {
            print("❌ JSON 데이터 변환 실패: \(error)")
            return nil
        }
    }
    
    // JSON에서 복원
    static func fromJSONData(_ data: Data) -> SleepData? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SleepData.self, from: data)
        } catch {
            print("❌ JSON 파싱 실패: \(error)")
            return nil
        }
    }
}

// MARK: - 테스트용 데이터 요약
extension SleepData {
    
    var testSummary: String {
        let hours = Int(duration / 3600)
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
        
        let motionMagnitudes = motionData.map { sqrt($0.x*$0.x + $0.y*$0.y + $0.z*$0.z) }
        let avgMotion = motionMagnitudes.isEmpty ? 0 : motionMagnitudes.reduce(0, +) / Double(motionMagnitudes.count)
        let maxMotion = motionMagnitudes.max() ?? 0
        
        let avgSound = soundData.isEmpty ? 0 : soundData.reduce(0) { $0 + $1.decibelLevel } / Float(soundData.count)
        let maxSound = soundData.map { $0.decibelLevel }.max() ?? 0
        
        // DateFormatter를 직접 생성해서 사용
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM월 dd일 HH:mm"
        
        return """
        📊 수면 데이터 테스트 요약
        ═══════════════════════════════════════
        🆔 세션 ID: \(sessionId)
        ⏰ 수면 시간: \(hours)시간 \(minutes)분
        📅 시작: \(displayFormatter.string(from: startTime))
        📅 종료: \(displayFormatter.string(from: endTime))
        
        📱 움직임 데이터: \(motionData.count)개 포인트
        📊 평균 움직임: \(String(format: "%.3f", avgMotion))g
        📊 최대 움직임: \(String(format: "%.3f", maxMotion))g
        
        🔊 소리 데이터: \(soundData.count)개 포인트  
        📊 평균 소음: \(String(format: "%.1f", avgSound))dB
        📊 최대 소음: \(String(format: "%.1f", maxSound))dB
        ═══════════════════════════════════════
        """
    }
    
    var isValidTestData: Bool {
        return duration > 60 && !motionData.isEmpty && !soundData.isEmpty
    }
    
    var dataQuality: String {
        guard isValidTestData else { return "❌ 테스트 데이터 부족" }
        
        let motionDensity = Double(motionData.count) / duration
        let soundDensity = Double(soundData.count) / duration
        
        if motionDensity > 0.1 && soundDensity > 0.5 {
            return "✅ 양질의 테스트 데이터"
        } else if motionDensity > 0.05 && soundDensity > 0.2 {
            return "⚠️ 보통 품질의 테스트 데이터"
        } else {
            return "⚠️ 테스트 데이터 밀도 부족"
        }
    }
}
