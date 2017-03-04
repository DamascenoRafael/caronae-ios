import FBSDKCoreKit
import FBSDKLoginKit
import Foundation
import RealmSwift
import Firebase

class UserService: NSObject {
    static let instance = UserService()
    let api = CaronaeAPIHTTPSessionManager.instance
    
    private override init() {
        // This prevents others from using the default '()' initializer for this class.
    }
    
    private(set) lazy var user: User? = {
        let userID: Int = UserDefaults.standard.integer(forKey: "user_id")
        
        do {
            // If the user ID was not found, we need to check for a legacy user and migrate it
            guard userID != 0 else {
                return try self.migrateUserToRealm()
            }
            
            let realm = try Realm()
            return realm.object(ofType: User.self, forPrimaryKey: userID)
        } catch {
            NSLog("Error reading or migrating current user (%@)", error.localizedDescription)
            return nil
        }
    }()
    
    private(set) var userToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "token")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "token")
        }
    }
    
    var userGCMToken: String? {
        get {
            return UserDefaults.standard.string(forKey: "gcmToken")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "gcmToken")
        }
    }
    
    var userFacebookToken: String? {
        return FBSDKAccessToken.current()?.tokenString
    }
    
    var userTopic: String? {
        guard let user = self.user else {
            return nil
        }
        return "/topics/user-\(user.id)"
    }
    
    func signIn(withUser idUFRJ: String, token: String, success: @escaping (_ user: User) -> Void, error: @escaping (_ error: CaronaeError) -> Void) {
        let params = [ "id_ufrj": idUFRJ, "token": token ]
        api.post("/user/login", parameters: params, success: { task, responseObject in
            guard let responseObject = responseObject as? [String: Any],
            let userJson = responseObject["user"] as? [String: Any],
            let user = User(JSON: userJson) else {
                NSLog("Error parsing user response")
                error(.invalidResponse)
                return
            }
            
            do {
                let realm = try Realm()
                try realm.write {
                    realm.add(user, update: true)
                }
            } catch let realmError {
                NSLog("Error saving the current user in the Realm: \(realmError.localizedDescription)")
            }

            // Update the current user
            self.user = user
            self.userToken = token
            UserDefaults.standard.set(user.id, forKey: "user_id")
            
            self.notifyObservers()
            
            success(user)
            
        }, failure: { task, err in
            NSLog("Failed to sign in: \(err.localizedDescription)")
            
            var authenticationError: CaronaeError = .invalidResponse
            if let response = task?.response as? HTTPURLResponse {
                switch response.statusCode {
                case 403, 401:
                    authenticationError = .invalidCredentials
                default:
                    authenticationError = .invalidResponse
                }
            }
            
            error(authenticationError)
        })
    }
    
    func signOut() {
        signOut(force: false)
    }
    
    func signOut(force: Bool = false) {
        // Unsubscribe from FCM user topic
        if let userTopic = self.userTopic {
            NSLog("Unsubscribing from: \(userTopic)")
            FIRMessaging.messaging().unsubscribe(fromTopic: userTopic)
        }
        
        // Clear database
        do {
            let realm = try Realm()
            try realm.write {
                realm.deleteAll()
            }
        } catch {
            NSLog("Error deleting Realm. %@", error.localizedDescription)
        }
        
        // Clear notifications
        NotificationService.instance.clearNotifications()
        
        // Logout from Facebook
        FBSDKLoginManager().logOut()
        
        // Clear current user
        self.user = nil
        UserDefaults.standard.removeObject(forKey: "user_id")
        
        notifyObservers(force: force)
    }
    
    func updateUser(_ user: User, success: @escaping () -> Void, error: @escaping (_ error: Error) -> Void) {
        api.put("/user", parameters: user.toJSON(), success: { task, responseObject in
            
            let currentUser = self.user!
            
            do {
                let realm = try Realm()
                try realm.write {
                    currentUser.phoneNumber = user.phoneNumber
                    currentUser.email = user.email
                    currentUser.carOwner = user.carOwner
                    currentUser.carModel = user.carModel
                    currentUser.carPlate = user.carPlate
                    currentUser.carColor = user.carColor
                    currentUser.location = user.location
                    currentUser.profilePictureURL = user.profilePictureURL
                }
            } catch let realmError {
                error(realmError)
            }
            
            NotificationCenter.default.post(name: Foundation.Notification.Name.CaronaeDidUpdateUser, object: self)
            success()
        }, failure: { _, err in
            error(err)
        })
    }
    
    func updateFacebookID(_ id: Any, token: Any, success: @escaping () -> Void, error: @escaping (_ error: Error) -> Void) {
        let params = [
            "token": token,
            "id": id
        ]
        
        api.put("/user/saveFaceId", parameters: params, success: { task, responseObject in
            success()
        }, failure: { _, err in
            error(err)
        })
    }
    
    func getPhotoFromUFRJ(success: @escaping (_ url: String) -> Void, error: @escaping (_ error: Error) -> Void) {
        api.get("/user/intranetPhotoUrl", parameters: nil, success: { task, responseObject in
            guard let response = responseObject as? [String: Any],
                let url = response["url"] as? String else {
                    error(CaronaeError.invalidResponse)
                    return
            }
            
            success(url)
        }, failure: { _, err in
            error(err)
        })
    }
    
    func getPhotoFromFacebook(success: @escaping (_ url: String) -> Void, error: @escaping (_ error: Error) -> Void) {
        let request = FBSDKGraphRequest(graphPath: "me/picture?type=large&redirect=false", parameters: ["fields": "url"])!
        request.start(completionHandler: { connection, result, err in
            guard err == nil,
            let response = result as? [String: Any],
            let data = response["data"] as? [String: Any],
                let url = data["url"] as? String else {
                    error(CaronaeError.invalidResponse)
                    return
            }
            
            success(url)
        })
    }

    
    func ridesCountForUser(withID id: Int, success: @escaping (_ offered: Int, _ taken: Int) -> Void, error: @escaping (_ error: Error) -> Void) {
        api.get("/ride/getRidesHistoryCount/\(id)", parameters: nil, success: { task, responseObject in
            guard let response = responseObject as? [String: Any],
                let offered = response["offeredCount"] as? Int,
                let taken = response["takenCount"] as? Int else {
                    error(CaronaeError.invalidResponse)
                    return
            }
            
            // Cache the rides count if the user is persisted
            do {
                let realm = try Realm()
                if let user = realm.object(ofType: User.self, forPrimaryKey: id) {
                    try realm.write {
                        user.numDrives = offered
                        user.numRides = taken
                    }
                }
            } catch {
                NSLog("Error persisting the rides count of the user with id \(id)")
            }
            
            success(offered, taken)
        }, failure: { _, err in
            error(err)
        })
    }
    
    // This actually should use the user's ID instead of the Facebook ID
    // but would need to refactor the API...
    func mutualFriendsForUser(withFacebookID facebookID: String, success: @escaping (_ friends: [User], _ totalCount: Int) -> Void, error: @escaping (_ error: Error) -> Void) {
        guard !facebookID.isEmpty, userFacebookToken != nil else {
            error(CaronaeError.notLoggedInWithFacebook)
            return
        }
        
        api.get("/user/\(facebookID)/mutualFriends", parameters: nil, success: { task, responseObject in
            guard let response = responseObject as? [String: Any],
            let friendsJson = response["mutual_friends"] as? [[String: Any]],
                let totalCount = response["total_count"] as? Int else {
                    error(CaronaeError.invalidResponse)
                    return
            }
            
            let friends = friendsJson.flatMap { User(JSON: $0) }
            success(friends, totalCount)
        }, failure: { _, err in
            error(err)
        })
    }
    
    private func notifyObservers(force: Bool = false) {
        NotificationCenter.default.post(name: Foundation.Notification.Name.CaronaeDidUpdateUser, object: self, userInfo: [CaronaeSignOutRequiredKey: force])
    }
    
    private func migrateUserToRealm() throws -> User {
        guard let userJson = UserDefaults.standard.dictionary(forKey: "user") else {
            throw CaronaeError.notLoggedIn
        }
        
        guard let user = User(JSON: userJson) else {
            throw CaronaeError.invalidUser
        }
        
        let realm = try Realm()
        try realm.write {
            realm.add(user, update: true)
        }
        
        UserDefaults.standard.set(user.id, forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user")
        UserDefaults.standard.removeObject(forKey: "userCreatedRides")
        
        // Migrate requested rides
        if let requests = UserDefaults.standard.array(forKey: "cachedJoinRequests") as? [Int] {
            let migratedRequests = requests.map { RideRequest(rideID: $0) }

            try realm.write {
                realm.add(migratedRequests, update: true)
            }
            
            UserDefaults.standard.removeObject(forKey: "cachedJoinRequests")
        }
        
        return user
    }
}
