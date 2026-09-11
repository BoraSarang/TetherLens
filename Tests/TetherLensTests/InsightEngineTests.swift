import Testing
import Foundation
@testable import TetherLens

private func noon() -> Date {
    var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    c.hour = 12
    return Calendar.current.date(from: c)!
}

private func todayKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

@Suite struct InsightEngineTests {

    @Test func 소진예측_자정전소진이면_시각반환() {
        // 정오에 6GB/10GB 사용 → 같은 페이스면 20시 소진 (자정 전)
        let now = noon()
        let used: Int64 = 6_000_000_000
        let quota: Int64 = 10_000_000_000
        let result = InsightEngine.projectedExhaustion(usedToday: used, quotaBytes: quota, now: now)
        #expect(result != nil)
        #expect(result! > now)
        #expect(result! < Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!)
    }

    @Test func 소진예측_자정이후면_nil() {
        // 정오에 1GB/10GB → 자정 이후 소진 예상
        #expect(InsightEngine.projectedExhaustion(usedToday: 1_000_000_000, quotaBytes: 10_000_000_000, now: noon()) == nil)
    }

    @Test func 소진예측_15분미만이면_nil() {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 0; c.minute = 5
        let early = Calendar.current.date(from: c)!
        #expect(InsightEngine.projectedExhaustion(usedToday: 5_000_000_000, quotaBytes: 6_000_000_000, now: early) == nil)
    }

    @Test func 소진예측_이미초과면_now반환() {
        let now = noon()
        let result = InsightEngine.projectedExhaustion(usedToday: 11_000_000_000, quotaBytes: 10_000_000_000, now: now)
        #expect(result == now)
    }

    @Test func 급증_2배이상이면_배율반환() {
        let key = todayKey()
        let days = [(day: key, total: Int64(300_000_000))] + (1...7).map { (day: "past-\($0)", total: Int64(100_000_000)) }
        #expect(InsightEngine.surgeTriggered(dailyTotals: days, todayKey: key) == 3.0)
    }

    @Test func 급증_baseline미만이면_nil() {
        let key = todayKey()
        let days = [(day: key, total: Int64(30_000_000))] + (1...7).map { (day: "past-\($0)", total: Int64(5_000_000)) }
        #expect(InsightEngine.surgeTriggered(dailyTotals: days, todayKey: key) == nil)
    }

    @Test func 주범앱_40프로이상_50MB이상이면_발동() {
        let apps = [("Safari", Int64(60_000_000)), ("Mail", Int64(30_000_000)), ("Notes", Int64(10_000_000))]
        let result = InsightEngine.topOffender(apps: apps)
        #expect(result?.appName == "Safari")
        #expect(result?.ratio == 0.6)
    }

    @Test func 주범앱_시스템프로세스는_제외() {
        let apps = [("nsurlsessiond", Int64(900_000_000)), ("Safari", Int64(60_000_000)), ("Mail", Int64(40_000_000))]
        let result = InsightEngine.topOffender(apps: apps)
        #expect(result?.appName == "Safari")
    }

    @Test func 야간소모_30프로이상이면_발동() {
        let hours = (0..<24).map { (hour: $0, total: $0 < 6 ? Int64(20_000_000) : Int64(5_000_000)) }
        // 야간 120MB / 전체 210MB = 57%
        let share = InsightEngine.nightDrainShare(hourlyTotals: hours, todayTotal: 210_000_000)
        #expect(share != nil)
        #expect(share! > 0.5)
    }

    @Test func 업로드편중_40프로이상이면_발동() {
        #expect(InsightEngine.uploadHeavyShare(upload: 50_000_000, total: 100_000_000) == 0.5)
        #expect(InsightEngine.uploadHeavyShare(upload: 20_000_000, total: 100_000_000) == nil)
    }

    @Test func build_IP5개이상이면_ipChurn포함() {
        let pid = UUID()
        let profile = InsightInput.ProfileData(
            id: pid, name: "Test", quotaBytes: nil,
            todayUpload: 1_000_000, todayDownload: 2_000_000,
            dailyTotals: [], hourlyTotals: [], recentDistinctIPs: 6)
        let input = InsightInput(topApps: [], profiles: [profile], todayKey: todayKey(), now: Date())
        let items = InsightEngine.build(input)
        #expect(items.count == 1)
        #expect(items[0].kind == .ipChurn)
        #expect(items[0].count == 6)
    }

    @Test func build_조용하면_빈배열() {
        let pid = UUID()
        let profile = InsightInput.ProfileData(
            id: pid, name: "Test", quotaBytes: nil,
            todayUpload: 1_000_000, todayDownload: 2_000_000,
            dailyTotals: [], hourlyTotals: [], recentDistinctIPs: 1)
        let input = InsightInput(topApps: [], profiles: [profile], todayKey: todayKey(), now: Date())
        #expect(InsightEngine.build(input).isEmpty)
    }
}
