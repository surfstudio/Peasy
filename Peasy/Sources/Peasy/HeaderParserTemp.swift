//
//  HeaderParserTemp.swift
//  IntegratedMockTestUITests
//
//  Created by Kane Cheshire on 28/11/2019.
//  Copyright © 2019 kane.codes. All rights reserved.
//

import Foundation

// TOOD: Make sure it's easy to test timeouts and no connection

struct RequestParser { // TODO: Doesn't work with raw binaries
    
    enum State {
        case notStarted
        case receivingHeader(partialHeader: Data)
        case receivingBody(fullHeader: Data, partialBody: Data, progress: Int)
        case finished(Request)
    }
    
    private var state: State = .notStarted
    
    mutating func parse(_ data: Data) -> State { // TODO: Test with large requests
        if let rangeOfHeaderEnd = data.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A])) {
            handle(rangeOfHeaderEnd: rangeOfHeaderEnd, in: data)
        } else {
            handle(partialData: data)
        }
        return state
    }
    
    private mutating func handle(rangeOfHeaderEnd: Range<Data.Index>, in data: Data) {
        let header = data[data.startIndex ..< rangeOfHeaderEnd.lowerBound]
        let body = data[rangeOfHeaderEnd.upperBound ..< data.endIndex]
        switch state {
            case .notStarted:
                let length = contentLength(from: header)
                if body.count == length {
                    let parsedHeader = parseHeader(header)
                    state = .finished(Request(method: parsedHeader.method, path: parsedHeader.path, headers: parsedHeader.headers, body: body))
                } else {
                    print("c")
                    let progress = body.count / length
                    state = .receivingBody(fullHeader: header, partialBody: body, progress: progress)
                }
            case .receivingHeader(let partialHeader):
                let fullHeader = partialHeader + header
                let length = contentLength(from: fullHeader)
                if body.count == length {
                    let parsedHeader = parseHeader(header)
                    state = .finished(Request(method: parsedHeader.method, path: parsedHeader.path, headers: parsedHeader.headers, body: body))
                } else {
                    print("b")
                    let progress = body.count / length
                    state = .receivingBody(fullHeader: header, partialBody: body, progress: progress)
                }
            case .finished, .receivingBody: fatalError("Shouldn't be possible")
            
        }
    }
    
    private mutating func handle(partialData: Data) {
        switch state {
            case .notStarted:
                state = .receivingHeader(partialHeader: partialData)
            case .receivingHeader(let partialHeader):
                state = .receivingHeader(partialHeader: partialHeader + partialData)
            case .receivingBody(let header, let partialBody, _):
                let length = contentLength(from: header)
                let body = partialBody + partialData
                if body.count == length {
                    let parsedHeader = parseHeader(header)
                    state = .finished(Request(method: parsedHeader.method, path: parsedHeader.path, headers: parsedHeader.headers, body: body))
                } else {
                    print("a", length, body.count)
                    let progress = body.count / length
                    state = .receivingBody(fullHeader: header, partialBody: body, progress: progress)
            }
            case .finished: fatalError()
        }
    }
    
    private func parseHeader(_ data: Data) -> (method: Request.Method, path: String, headers: [Request.Header]) {
        let header = String(data: data, encoding: .utf8)!
        var lines = header.split(separator: "\r\n")
        let status = lines.removeFirst()
        let statusComponents = status.split(separator: " ")
        let method = String(statusComponents[0])
        let path = String(statusComponents[1])
        let headers = parseHeaders(lines.map { String($0) }) // TODO: Might not need to map
        return (Request.Method(rawValue: method)!, path, headers)
    }
    
    private func parseHeaders(_ lines: [String]) -> [Request.Header] {
        return lines.map { line in
            let headerComponents = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let name = headerComponents[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = headerComponents[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return Request.Header(name: name, value: value)
        }
    }
    
    private func contentLength(from headerData: Data) -> Int {
        let header = parseHeader(headerData)
        let contentHeader = header.headers.first { $0.name.lowercased() == "content-length" }
        return Int(contentHeader?.value ?? "") ?? 0
    }
    
}