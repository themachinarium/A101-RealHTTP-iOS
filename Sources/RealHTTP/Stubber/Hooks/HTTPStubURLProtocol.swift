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

public class HTTPStubURLProtocol: URLProtocol {
    
    /// This class support only certain common type of schemes.
    private static let supportedSchemes = ["http", "https"]
    
    /// For delayed responses.
    private var responseWorkItem: DispatchWorkItem?
    
    public override var task: URLSessionTask? {
      urlSessionTask
    }
    
    private var urlSessionTask: URLSessionTask?

    
    // MARK: - Overrides
    
    /// The following call is called when a new request is about to being executed.
    /// The following stub subclass supports only certain schemes, http and https so we
    /// want to reply affermative (and therefore manage it) only for these schemes.
    /// When false other registered protocol classes are queryed to respond.
    ///
    /// - Parameter request: request to validate.
    /// - Returns: Bool
    public override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme,
              Self.supportedSchemes.contains(scheme) else {
            return false
        }
        
        // Pass filter for ignore urls
        return HTTPStubber.shared.shouldHandle(request)
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    public override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        false
    }
    
    init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
      super.init(request: task.currentRequest!, cachedResponse: cachedResponse, client: client)
      self.urlSessionTask = task
    }

    
    public override func startLoading() {
        var request = self.request
        
        // Get the cookie storage that applies to this request.
        var cookieStorage = HTTPCookieStorage.shared
        if let session = task?.value(forKey: "session") as? URLSession,
           let configurationCookieStorage = session.configuration.httpCookieStorage {
            cookieStorage = configurationCookieStorage
        }
        
        // Get the cookies that apply to this URL and add them to the request headers.
        if let url = request.url, let cookies = cookieStorage.cookies(for: url) {
            if request.allHTTPHeaderFields == nil {
                request.allHTTPHeaderFields = [String: String]()
            }
            request.allHTTPHeaderFields!.merge(HTTPCookie.requestHeaderFields(with: cookies)) { (current, _) in
                current
            }
        }
        
        // Find the stubbed response for this request.
        guard  let httpMethod = request.method,
               let matchedRequest = HTTPStubber.shared.suitableStubForRequest(request),
               let stubProvider = matchedRequest.responses[httpMethod],
               let stubResponse = stubProvider.response(forURLRequest: request, matchedStub: matchedRequest)?.adaptForRequest(request),
               request.url != nil else {
            // If not found we throw an error
            client?.urlProtocol(self, didFailWithError: HTTPStubberErrors.matchStubNotFound(request))
            return
        }
        
        guard let delay = stubResponse.responseDelay else {
            finishRequest(request, withStub: stubResponse, cookies: cookieStorage)
            return
        }
        
        // Perform delayed reply
        self.responseWorkItem = DispatchWorkItem(block: { [weak self] in
            self?.finishRequest(request, withStub: stubResponse, cookies: cookieStorage)
        })

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated)
            .asyncAfter(deadline: .now() + delay, execute: responseWorkItem!)
    }
    
    public override func stopLoading() {
        responseWorkItem?.cancel()
    }
    
    // MARK: - Private Functions
    
    private func finishRequest(_ request: URLRequest, withStub stubResponse: HTTPStubResponse, cookies: HTTPCookieStorage) {
        let url = request.url!
        let headers = stubResponse.headers.asDictionary
        let cookiesToSet = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        cookies.setCookies(cookiesToSet, for: request.url!, mainDocumentURL: url)

        if let failureError = stubResponse.failError { // request should fail with given error
            client?.urlProtocol(self, didFailWithError: failureError)
            return
        }
        
        let statusCode = stubResponse.statusCode
        let response = HTTPURLResponse(url: url,
                                       statusCode: statusCode.rawValue,
                                       httpVersion: nil,
                                       headerFields: headers)
        
        // Handle redirects
        let isRedirect =
            statusCode.responseType == .redirection &&
            (statusCode != .notModified && statusCode != .useProxy)
        
        if isRedirect, let location = stubResponse.body?.data?.redirectLocation {
            // Includes redirection call to client.
            // A redirect to the client must contain `Location:<URL>` inside the body.
            var redirect = URLRequest(url: location)
            if let cookiesInRedirect = cookies.cookies(for: url) {
                redirect.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookiesInRedirect)
            }
            client?.urlProtocol(self, wasRedirectedTo: redirect, redirectResponse: response!)
        }
        
        // Send response
        client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
        if let data = stubResponse.body?.data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    
}
