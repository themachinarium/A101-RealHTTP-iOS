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

/// Identify a list of events you can monitor during the lifecycle of the client instance.
public protocol HTTPClientDelegate: AnyObject {
    typealias ExecutedRequest = (request: HTTPRequest, task: URLSessionTask)
    
    /// A new request is enqueued into the client's pool.
    ///
    /// - Parameters:
    ///   - client: client target of the request.
    ///   - request: request instance.
    func client(_ client: HTTPClient, didEnqueue request: ExecutedRequest)
    
    
    /// This method is called when a request is about to be retry due to failure.
    ///
    ///- Parameters:
    /// - `client`: client target of the request.
    /// - `request`: request to be re-executed.
    /// - `strategy`: retry strategy to follow.
    /// - `response`: original response which caused the retry strategy.
    func client(_ client: HTTPClient, request: ExecutedRequest,
                willRetryWithStrategy strategy: HTTPRetryStrategy,
                afterResponse response: HTTPResponse)
    
    /// The task is waiting until suitable connectivity is available before beginning the network load.
    /// This method is called if the waitsForConnectivity property of URLSessionConfiguration is true,
    /// and sufficient connectivity is unavailable.
    ///
    /// The delegate can use this opportunity to update the user interface; for example,
    /// by presenting an offline mode or a cellular-only mode.
    ///
    /// - Parameters:
    ///   - client: client target of the request.
    ///   - request: request instance.
    func client(_ client: HTTPClient, taskIsWaitingForConnectivity request: ExecutedRequest)
    
    /// Method is called when a http redirection is made.
    ///
    /// - Parameters:
    ///   - client: client target of the request.
    ///   - request: the original request.
    ///   - response: response received along with the redirect request.
    ///   - newRequest: the request to follow in redirect.
    func client(_ client: HTTPClient, willPerformRedirect request: ExecutedRequest,
                response: HTTPResponse, with newRequest: URLRequest)
    
    /// Client receive an auth challenge which will be managed by the `security` property of the
    /// request itself or global client's one.
    ///
    /// - Parameters:
    ///   - client: client target of the request.
    ///   - request: request instance.
    ///   - authChallenge: challenge received.
    func client(_ client: HTTPClient, didReceiveAuthChallangeFor request: ExecutedRequest,
                authChallenge: URLAuthenticationChallenge)
    
    /// Client executed the request and collected relative metrics stats.
    ///
    /// - Parameters:
    ///   - client: client target of the request.
    ///   - request: request instance.
    ///   - metrics: collected metrics data.
    func client(_ client: HTTPClient, didCollectedMetricsFor request: ExecutedRequest,
                metrics: HTTPMetrics)
    
    /// Client did complete the request.
    ///
    /// - Parameters:
    ///   - client:  client target of the request.
    ///   - request: request instance.
    ///   - response: response received (either success or error)
    func client(_ client: HTTPClient, didFinish request: ExecutedRequest,
                response: HTTPResponse)
    
}
