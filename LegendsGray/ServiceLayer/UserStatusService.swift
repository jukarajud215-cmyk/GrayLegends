import Foundation

final class UserStatusService {
    static let shared = UserStatusService()
    
    private let kIsNonOrganic = "is_non_organic_user"
    
    /// Стал ли юзер однажды "рекламным" (Non-organic)
    var isNonOrganicUser: Bool {
        get { UserDefaults.standard.bool(forKey: kIsNonOrganic) }
        set { UserDefaults.standard.set(newValue, forKey: kIsNonOrganic) }
    }
    
    /// Полный сброс (для тестов)
    func reset() {
        UserDefaults.standard.removeObject(forKey: kIsNonOrganic)
        // Если вдруг захотим хранить что-то еще, добавим удаление тут
        UserDefaults.standard.synchronize()
        print("🧹 [UserStatusService] Статус сброшен. Юзер снова как 'чистый'.")
    }
}
