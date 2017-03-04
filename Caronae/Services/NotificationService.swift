import RealmSwift

class NotificationService: NSObject {
    static let instance = NotificationService()
    
    private override init() {
        // This prevents others from using the default '()' initializer for this class.
    }
    
    func getNotifications(of kinds: [Notification.Kind] = []) throws -> Results<Notification> {
        let realm = try Realm()
        
        var notifications = realm.objects(Notification.self)
        if !kinds.isEmpty {
            notifications = notifications.filter("kind IN %@", kinds.map { $0.rawValue })
        }
        return notifications
    }
    
    func createNotification(_ notification: Notification) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(notification, update: true)
            }
        } catch {
            NSLog("Error creating notification (%@)", error.localizedDescription)
        }
        
        notifyObservers()
    }
    
    func clearNotifications(forRideID rideID: Int? = nil, of kinds: [Notification.Kind] = []) {
        do {
            let realm = try Realm()
            var notifications = realm.objects(Notification.self)
            if let rideID = rideID {
                notifications = notifications.filter("rideID == %@", rideID)
            }
            if !kinds.isEmpty {
                notifications = notifications.filter("kind IN %@", kinds.map { $0.rawValue })
            }
            
            try realm.write {
                realm.delete(notifications)
            }
        } catch {
            NSLog("Error deleting notifications (%@)", error.localizedDescription)
        }
        
        notifyObservers()
    }
    
    private func notifyObservers() {
        NotificationCenter.default.post(name: Foundation.Notification.Name.CaronaeDidUpdateNotifications, object: self)
    }
}
