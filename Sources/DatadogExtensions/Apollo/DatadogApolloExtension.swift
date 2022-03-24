/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Datadog
import Apollo

/// An `Apollo.URLSessionClient` which augments and instruments tasks from an Apollo-owned `URLSession` with Datadog RUM and Tracing.
public class DDURLSessionClient: URLSessionClient {
    private var interceptor: URLSessionInterceptor? { URLSessionInterceptor.shared }
    
    // MARK: - Apollo.URLSessionClient
    
    public override func sendRequest(_ request: URLRequest, rawTaskCompletionHandler: URLSessionClient.RawCompletion? = nil, completion: @escaping URLSessionClient.Completion) -> URLSessionTask {
        let modifiedRequest = interceptor?.modify(request: request, session: session) ?? request
        let task = super.sendRequest(modifiedRequest, rawTaskCompletionHandler: rawTaskCompletionHandler, completion: completion)
        interceptor?.taskCreated(task: task, session: session)
        return task
    }

    // MARK: - Foundation.URLSessionDataDelegate

    public override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        super.urlSession(session, dataTask: dataTask, didReceive: data)
        interceptor?.taskReceivedData(task: dataTask, data: data)
    }
    
    // MARK: - Foundation.URLSessionTaskDelegate
    
    public override func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        super.urlSession(session, task: task, didCompleteWithError: error)
        interceptor?.taskCompleted(task: task, error: error)
    }
    
    public override func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        super.urlSession(session, task: task, didFinishCollecting: metrics)
        interceptor?.taskMetricsCollected(task: task, metrics: metrics)
    }
}
