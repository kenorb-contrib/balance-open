//
//  CoinbaseAPI2.swift
//  BalancemacOS
//
//  Created by Eli Pacheco Hoyos on 1/29/18.
//  Copyright © 2018 Balanced Software, Inc. All rights reserved.
//

#if os(OSX)
    import AppKit
#else
    import UIKit
#endif

import Foundation

class CoinbaseAPI2: AbstractApi {
    private var lastState: String? = nil
    override var shouldHandleNoActionResponse: Bool { return true }
    
    override func prepareForAutentication() {
        let state = CoinbaseAutenticationConstants.state

        guard let coinbaseAutenticationURL = CoinbaseAutenticationConstants.getAuthenticationURL(with: state) else {
            log.debug("Error - Coinbase autentication url can't be created")
            return
        }
        
        do {
            #if os(OSX)
                _ = try NSWorkspace.shared.open(coinbaseAutenticationURL, options: [], configuration: [:])
            #else
                UIApplication.shared.open(coinbaseAutenticationURL)
            #endif
        } catch {
            // TODO: Better error handling
            log.error("Error - opening Coinbase authentication URL: \(error)")
        }
        
        lastState = state
    }
    
    override func startAutentication(with data: Any, completionBlock: @escaping ExchangeOperationCompletionHandler) -> Operation? {
        guard let request = createAutenticationRequest(with: data) else {
            return nil
        }
        
        return ExchangeOperation(with: self, request: request, resultBlock: completionBlock)
    }
        
    override func createRequest(for action: APIAction) -> URLRequest? {
        guard let ouathCredentials = action.credentials as? OAUTHCredentials,
            let url = action.url else {
                return nil
        }
        
        switch action.type {
        case .accounts, .transactions(_):
            var request = URLRequest(url: url)
            request.timeoutInterval = CoinbaseAutenticationConstants.connectionTimeout
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.httpMethod = HTTPMethod.GET
            request.setValue("Bearer " + ouathCredentials.accessToken, forHTTPHeaderField: "Authorization")
            request.setValue(CoinbaseAutenticationConstants.cbVersion, forHTTPHeaderField: "CB-VERSION")
            
            return request
        }
    }
    
    override func processApiErrors(from data: Data) -> Error? {
        if let dict = createDict(from: data), let coinbaseError = checkErrors(from: dict) {
            return coinbaseError
        }
        
        return nil
    }
    
    override func buildAccounts(from data: Data) -> Any {
        guard let preparedData = preprocessData(from: data),
            let accounts = try? JSONDecoder().decode([CoinbaseAccount2].self, from: preparedData) else {
                log.error("Error: unable to parse coinbase account from data \(String(data: data, encoding: .utf8) ?? "")")
                return []
        }
        return accounts
    }
    
    override func buildTransactions(from data: Data) -> Any {
        guard let preparedData = preprocessData(from: data),
            let transactions = try? JSONDecoder().decode([CoinbaseTransaction2].self, from: preparedData) else {
                log.error("Error: unable to parse coinbase transactions from data \(String(data: data, encoding: .utf8) ?? "")")
                return []
        }
        return transactions
    }
    
    override func buildDataFromNoAction(_ data: Data?) -> Any {
        let autentication = getAutenticationData(from: data)
        return autentication ?? ExchangeBaseError.other(message: "Data retrieved from autentication is not valid")
    }
    
    func refreshAccessToken(with credentials: OAUTHCredentials, completion: @escaping ExchangeOperationCompletionHandler) -> Operation?  {
        guard let refreshURL = URL(string: "\(CoinbaseAutenticationConstants.subServerUrl)coinbase/refreshToken") else {
            return nil
        }
        
        var request = URLRequest(url: refreshURL)
        request.timeoutInterval = CoinbaseAutenticationConstants.connectionTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = HTTPMethod.POST
        let parameters = "{\"refreshToken\":\"\(credentials.refreshToken)\"}"
        request.httpBody = parameters.data(using: .utf8)
        
        return ExchangeOperation(with: self, request: request, resultBlock: completion)
    }
    
}

// MARK: Private Methods

private extension CoinbaseAPI2 {
    func createAutenticationRequest(with data: Any) -> URLRequest? {
        guard let dict = data as? [String: Any],
            let state = dict[CoinbaseAuthenticationKey.state.rawValue] as? String,
            let code = dict[CoinbaseAuthenticationKey.code.rawValue] as? String else {
                log.debug("can't retrive data for begin autentication")
                return nil
        }
        
        guard state == lastState else {
            log.debug("State retrived from autentication callback is different")
            return nil
        }
        
        guard let callbackURL = CoinbaseAutenticationConstants.autenticationCallbackURL else {
            log.debug("Invalid callback url")
            return nil
        }
        
        lastState = nil
        
        var request = URLRequest(url: callbackURL)
        request.timeoutInterval = CoinbaseAutenticationConstants.connectionTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = HTTPMethod.POST
        let parameters = "{\"code\":\"\(code)\"}"
        request.httpBody = parameters.data(using: .utf8)
        
        return request
    }
    
    func getAutenticationData(from data: Data?) -> CoinbaseAutentication? {
        guard let jsonData = data else {
            return nil
        }
        
        do {
            let coinbaseAutentication = try JSONDecoder().decode(CoinbaseAutentication.self, from: jsonData)
            
            return coinbaseAutentication
        } catch  {
            print("Error parsing data from auntetication \(error)")
            return nil
        }
    }
    
    func checkErrors(from dict: [AnyHashable: Any]?) -> Error? {
        // Check for errors (they return an array, but as far as I know it's always one error
        guard let dict = dict, let errorDict = dict["errors"] as? [[String: AnyObject]] else {
            return nil
        }
 
        var errorArray: [Error] = []
        
        errorDict.forEach { (dict) in
            if let id = dict["id"] as? String,
                let coinbaseError = CoinbaseError(rawValue: id),
                let message = dict["message"] as? String {
                
                log.error("Coinbase Error: \(message)")
                errorArray.append(coinbaseError)
            } else {
                errorArray.append(ExchangeBaseError.other(message: "Unknown Error: \(dict["id"] as? String ?? "")"))
            }
        }
        
        return errorArray.first
    }
    
    func preprocessData(from data: Data) -> Data? {
        guard let rawData = try? JSONSerialization.jsonObject(with: data),
            let dict = rawData as? [String: AnyObject],
            let dataDict = dict["data"] as? [[String: AnyObject]] else {
                return nil
        }
        return try? JSONSerialization.data(withJSONObject: dataDict, options: .prettyPrinted)
    }
    
}

// MARK: Coinbase Authetication

enum CoinbaseAuthenticationKey: String, CodingKey  {
    case state = "state"
    case tokenType = "tokenType"
    case expiresIn = "expiresIn"
    case accessToken = "accessToken"
    case refreshToken = "refreshToken"
    case code = "code"
    case apiScope = "scope"
}

fileprivate struct CoinbaseAutenticationConstants {
    
    //mark: Coinbase app configurations
    static let cbVersion = "2017-05-19"
    static let connectionTimeout = 30.0
    static let subServerUrl = debugging.useLocalSubscriptionServer ? "http://localhost:8080/" : "https://api.balancemy.money/"
    static let clientId = "a6e15fbb0c3362b74360895f261fb079672c10eef79dcb72308c974408c5ce43"
    
    //mark: Authentication
    static let redirectUri = "balancemymoney%3A%2F%2Fcoinbase"
    static let responseType = "code"
    static let scope = "wallet%3Auser%3Aread,wallet%3Aaccounts%3Aread,wallet%3Atransactions%3Aread"
    
    static var state: String {
        return String.random(32)
    }
    
    static func getAuthenticationURL(with state: String) -> URL? {
        let autenticationURLText = "https://www.coinbase.com/oauth/authorize?"
            + "client_id=\(clientId)&"
            + "redirect_uri=\(redirectUri)&"
            + "state=\(state)&"
            + "response_type=\(responseType)&"
            + "scope=\(scope)&account=all"
        
        return URL(string: autenticationURLText)
    }
    
    static var autenticationCallbackURL: URL? {
        let callbackURL = "\(subServerUrl)coinbase/requestToken"
        
        return URL(string: callbackURL)
    }
    
}