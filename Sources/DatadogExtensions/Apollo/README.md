# Datadog Integration for Apollo

`DatadogApolloExtension` enables auto-instrumentation of `Apollo.URLSessionClient`.
It's a counterpart of `DDURLSessionDelegate`, which is provided for native `URLSession` instrumentation.

## Getting started

### CocoaPods

To include the Datadog integration for [Apollo][1] in your project, add the
following to your `Podfile`:
```ruby
pod 'DatadogSDKApolloExtension'
```
`DatadogSDKApolloExtension` requires Datadog SDK `1.10.0` or higher and `Apollo 0.50` or higher.

### Carthage and SPM

The Datadog [Apollo][1] integration doesn't support [Carthage][2] or [SPM][3], however, the code needed for set up is very low. You may want to include the source files from this folder directly in your project.

### Initial setup

Follow the regular steps for initializing Datadog SDK for [Tracing][4] or [RUM][5].

The standard setup for auto-instrumentation of `URLSession`-backed network requests is to set `DDURLSessionDelegate` as the `URLSession` delegate. However, Apollo also wants its concrete class `URLSessionClient` to be the `URLSessionDataDelegate` and `URLSessionTaskDelegate`. Thus, the workaround is to extend `Apollo.URLSessionClient` and forward along [all required events (as of this writing)][6] to DataDog's shared `URLSessionInterceptor` instance. In addition to the `URLSession*Delegate` overrides, to support tracing the `Apollo.URLSessionClient` method `sendRequest(...)` is overriden in order to augment the request headers and to grab a reference to the `URLSessionTask` to forward to the `URLSessionInterceptor`.

```swift
import DatadogApolloExtension
import Apollo

let cache = InMemoryNormalizedCache()
let store = ApolloStore(cache: cache)

let interceptorProvider = DefaultInterceptorProvider(client: URLSessionClient(),
                                                     shouldInvalidateClientOnDeinit: true,
                                                     store: store)
let networkTransport = RequestChainNetworkTransport(interceptorProvider: interceptorProvider,
                                                    endpointURL: url)

return ApolloClient(networkTransport: networkTransport, store: store)
```


## Contributing

Pull requests are welcome. First, open an issue to discuss what you would like to change. For more information, read the [Contributing Guide](../../../CONTRIBUTING.md).

## License

[Apache License, v2.0](../../../LICENSE)

[1]: https://github.com/apollographql/apollo-ios
[2]: https://github.com/Carthage/Carthage
[3]: https://swift.org/package-manager/
[4]: https://docs.datadoghq.com/tracing/setup_overview/setup/ios/
[5]: https://docs.datadoghq.com/real_user_monitoring/ios
[6]: https://docs.datadoghq.com/real_user_monitoring/ios/troubleshooting/#using-ddurlsessiondelegate-with-your-own-session-delegate
