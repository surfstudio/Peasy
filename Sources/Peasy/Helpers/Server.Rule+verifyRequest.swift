//
//  Server.Rule+verifyRequest.swift
//  
//
//  Created by Kane Cheshire on 05/12/2019.
//

import Foundation

extension Server.Rule {

    func verify(_ request: Request) -> Bool {
        switch self {
        case .method(matches: let method): return request.method == method
        case .path(matches: let path): return request.path.matches(pathWithVariables: path)
        case .headers(contain: let header): return request.headers.contains(header)
        case .queryParameters(contain: let queryParam): return request.queryParameters.contains(queryParam)
        case .body(matches: let body): return matchBody(requestBody: request.body, ruleBody: body)
        case .custom(let handler): return handler(request)
        }
    }

    private func matchBody(requestBody: Data, ruleBody: [String: Any]) -> Bool {
        do {
            let object: Any = try JSONSerialization.jsonObject(with: requestBody, options: [])
            let dict = unwrapToDictionary(object)
            return dict as NSDictionary == ruleBody as NSDictionary
        } catch {
            return false
        }
    }

    private func unwrapToDictionary(_ object: Any) -> [String: Any] {
        if let dictionary = object as? [String: Any] {
            var dict = dictionary
            dictionary.forEach { pair in
                dict[pair.key] = unwrapToDictionary(pair.value)
            }
            return dict
        } else {
            return [:]
        }
    }

}
