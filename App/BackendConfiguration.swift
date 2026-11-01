import Foundation

enum BackendConfiguration {
    static func client() -> StaffAccessClient? {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else { return nil }
        return try? StaffAccessClient(url: url, publishableKey: key)
    }
}
