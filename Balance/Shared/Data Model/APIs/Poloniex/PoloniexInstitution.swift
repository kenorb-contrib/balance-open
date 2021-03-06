//
//  PoloniexInstitution.swift
//  Balance
//
//  Created by Benjamin Baron on 8/29/17.
//  Copyright © 2017 Balanced Software, Inc. All rights reserved.
//

import Foundation

class PoloniexInstitution: ApiInstitution {
    let source: Source = .poloniex
    let sourceInstitutionId: String = ""
    
    var currencyCode: String = ""
    var usernameLabel: String = ""
    var passwordLabel: String = ""
    var name: String = "Poloniex"
    var products: [String] = []
    var type: String = ""
    var url: String? = "https://poloniex.com/login"
    var fields: [Field]
    
    init() {
        let keyField = Field(name: "API Key", type: .key, value: nil)
        let secretField = Field(name: "Secret", type: .secret, value: nil)
        self.fields = [keyField, secretField]
    }
}
