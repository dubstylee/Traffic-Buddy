//
//  LoginWithAmazonProxy.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 2/27/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import Foundation
import LoginWithAmazon

class LoginWithAmazonProxy {
    static let sharedInstance = LoginWithAmazonProxy()
    
    /**
     Authorize a user using LoginWithAmazon SDK.
     
     - parameter delegate: The `AIAuthenticationDelegate` to handle the result of the authorization request.
    */
    func login(delegate: AIAuthenticationDelegate) {
        AIMobileLib.authorizeUser(forScopes: Settings.Credentials.SCOPES, delegate: delegate, options: [kAIOptionScopeData: Settings.Credentials.SCOPE_DATA])
    }
    
    /**
     Clear the existing user authorization information from the LoginWithAmazon SDK.
     
     - parameter delegate: The `AIAuthenticationDelegate` to handle the result of the logout request.
    */
    func logout(delegate: AIAuthenticationDelegate) {
        AIMobileLib.clearAuthorizationState(delegate)
    }
    
    /**
     Get an access token for use with the LoginWithAmazon SDK.
     
     - parameter delegate: The `AIAutenticationDelegate` to handle to result of the request.
    */
    func getAccessToken(delegate: AIAuthenticationDelegate) {
        AIMobileLib.getAccessToken(forScopes: Settings.Credentials.SCOPES, withOverrideParams: nil, delegate: delegate)
    }
}
