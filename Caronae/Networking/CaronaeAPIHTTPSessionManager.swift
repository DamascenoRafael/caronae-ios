import AFNetworking

class CaronaeAPIHTTPSessionManager: AFHTTPSessionManager {
    static let instance = CaronaeAPIHTTPSessionManager()
   
    private init() {
        let baseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "CaronaeAPIBaseURL") as! String)
        super.init(baseURL: baseURL, sessionConfiguration: .default)
        requestSerializer = CaronaeAPIRequestSerializer()
        responseSerializer = CaronaeAPIResponseSerializer()
        requestSerializer.timeoutInterval = 30
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class CaronaeAPIRequestSerializer: AFJSONRequestSerializer {
    override func request(withMethod method: String, urlString URLString: String, parameters: Any?, error: NSErrorPointer) -> NSMutableURLRequest {
        // Add user token to the HTTP headers
        self.setValue(UserService.instance.userToken, forHTTPHeaderField: "token")

        // Add user FB token to the HTTP headers
        self.setValue(UserService.instance.userFacebookToken, forHTTPHeaderField: "Facebook-Token")
        
        return super.request(withMethod: method, urlString: URLString, parameters: parameters, error: error)
    }
}


class CaronaeAPIResponseSerializer: AFJSONResponseSerializer {
    override func responseObject(for response: URLResponse?, data: Data?, error: NSErrorPointer) -> Any? {
        let responseObject = super.responseObject(for: response, data: data, error: error)
        if let error = error,
            let response = response as? HTTPURLResponse,
            response.statusCode == 401 {
            error.pointee = CaronaeError.invalidCredentials
            
            DispatchQueue.main.async {
                if UserService.instance.user != nil {
                    UserService.instance.signOut(force: true)
                }
            }
        }
        return responseObject
    }
}
