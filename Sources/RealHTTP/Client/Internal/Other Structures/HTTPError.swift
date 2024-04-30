//
//  RealHTTP
//  Lightweight Async/Await Network Layer/Stubber for Swift
//
//  Created & Maintained by Mobile Platforms Team @ ImmobiliareLabs.it
//  Email: mobile@immobiliare.it
//  Web: http://labs.immobiliare.it
//
//  Authors:
//   - Daniele Margutti <hello@danielemargutti.com>
//
//  Copyright ©2022 Immobiliare.it SpA.
//  Licensed under MIT License.
//

import Foundation

/// `HTTPError` represent an object which wrap all the infos related to an
/// error occurred inside the library itself.
public struct HTTPError: LocalizedError, CustomStringConvertible {
    
    /// HTTP Status Code if available.
    public let statusCode: HTTPStatusCode
    
    /// Cocoa related code.
    public var cocoaCode: Int?
    
    /// Underlying error.
    public let error: Error?
    
    /// Category of the error.
    public internal(set) var category: ErrorCategory
    
    /// Additional user info.
    public var userInfo: [String: Any]?
    
    /// Custom error message.
    public let message: String?
    
    // MARK: - Initialization
        
    public init(_ type: ErrorCategory,
                code: HTTPStatusCode = .none,
                error: Error? = nil,
                userInfo: [String: Any]? = nil,
                cocoaCode: Int? = nil) {
        self.category = type
        self.statusCode = code
        self.error = error
        self.userInfo = userInfo
        self.cocoaCode = cocoaCode
        self.message = error?.localizedDescription
    }
    
    public init(_ type: ErrorCategory, message: String) {
        self.category = type
        self.message = message
        self.statusCode = .none
        self.cocoaCode = nil
        self.error = nil
    }
    
    // MARK: - Public Properties
    
    public var errorDescription: String? {
        return (message ?? error?.localizedDescription)
    }
    
    /// Return `true` if error is related to a missing connectivity.
    public var isConnectivityError: Bool {
        cocoaCode == -1009
    }
    
    /// Return `true` if error is about a missing authorization.
    public var isNotAuthorized: Bool {
        statusCode == .unauthorized
    }
    
    public var description: String {
        "HTTPError {httpCode=\(statusCode), category=\(category), cocoa=\(cocoaCode ?? 0), description='\(errorDescription ?? "")'}"
    }
    
}

// MARK: - ErrorType

public extension HTTPError {
    
    /// Typology of errors:
    /// - `invalidURL`: invalid URL provided, request cannot be executed
    /// - `multipartInvalidFile`: multipart form, invalid file has been set (not found or permissions error)
    /// - `multipartFailedStringEncoding`: failed to encode multipart form
    /// - `jsonEncodingFailed`: encoding in JSON failed
    /// - `urlEncodingFailed`: encoding in URL failed
    /// - `network`: network related error
    /// - `missingConnection`: connection cannot be established
    /// - `invalidResponse`: invalid response received
    /// - `failedBuildingURLRequest`: failed to build URLRequest (wrong parameters)
    /// - `objectDecodeFailed`: object decoding failed
    /// - `emptyResponse`: empty response received from server
    /// - `maxRetryAttemptsReached`: the maximum number of retries for request has been reached
    /// - `sessionError`: error related to the used session instances (may be a systemic error or it was invalidated)
    /// - `other`: any internal error, you can use it as your own handler.
    /// - `cancelled`: cancelled by user.
    /// - `validatorFailure`: failure returned by a validator set.
    /// - `internal`: internal library error occurred.
    enum ErrorCategory: Int {
        case invalidURL
        case multipartInvalidFile
        case multipartFailedStringEncoding
        case multipartStreamReadFailed
        case jsonEncodingFailed
        case urlEncodingFailed
        case network
        case missingConnection
        case invalidResponse
        case failedBuildingURLRequest
        case objectDecodeFailed
        case emptyResponse
        case retryAttemptsReached
        case sessionError
        case other
        case cancelled
        case timeout
        case validatorFailure
        case `internal`
    }
    
}

// MARK: - HTTPError (URLResponse)

extension HTTPError {
    
    /// Parse the response of an HTTP operation and return `nil` if no error has found,
    /// a valid `HTTPError` if call has failed.
    ///
    /// - Parameter httpResponse: response from http layer.
    /// - Returns: HTTPError?
    internal static func fromResponse(_ response: HTTPDataLoaderResponse?) -> HTTPError? {
        guard let response = response else { return nil }
        // If HTTP is an error or an error has received we can create the error object
        let httpCode = HTTPStatusCode.fromResponse(response.urlResponse)
        let isError = (response.error != nil || httpCode.responseType != .success)
        
        guard isError else {
            return nil
        }
        
        // Evaluate error kind
        let cocoaErrorCode = (response.error as NSError?)?.code
        let userInfo = (response.error as NSError?)?.userInfo
        let errorType: HTTPError.ErrorCategory = (response.error as NSError?)?.errorType ?? .network
        
        return HTTPError(errorType,
                         code: httpCode,
                         error: response.error,
                         userInfo: userInfo,
                         cocoaCode: cocoaErrorCode)
    }
    
}

// MARK: - Swift.Error

extension NSError {
    
    var errorType: HTTPError.ErrorCategory {
        switch (domain, code) {
        case (NSURLErrorDomain, URLError.notConnectedToInternet.rawValue):
            return .missingConnection
        case (NSURLErrorDomain, URLError.networkConnectionLost.rawValue):
            return .missingConnection
        case (NSURLErrorDomain, URLError.cannotLoadFromNetwork.rawValue):
            return .missingConnection
        case (NSURLErrorDomain, URLError.dataNotAllowed.rawValue):
            return .missingConnection
        case (NSURLErrorDomain, URLError.timedOut.rawValue):
            return .timeout
        default:
            return .network
        }
    }
    
}
