Pod::Spec.new do |s|
  s.name         = "DatadogSDKApolloExtension"
  s.module_name  = "DatadogApolloExtension"
  s.version      = "1.10.0-beta1"
  s.summary      = "An Unofficial Extension of the Datadog Swift SDK for Apollo."
  
  s.homepage     = "https://www.datadoghq.com"
  s.social_media_url   = "https://twitter.com/datadoghq"

  s.license            = { :type => "Apache", :file => 'LICENSE' }
  s.authors            = { 
    "Kristin Karpack" => "kristinkarpack@gmail.com"
  }

  s.swift_version      = '5.1'
  s.ios.deployment_target = '12.0'

  # :tag must follow DatadogSDK version below
  s.source = { :git => "https://github.com/DataDog/dd-sdk-ios.git", :tag => s.version.to_s }

  s.source_files = ["Sources/DatadogExtensions/Apollo/**/*.swift"]
  s.dependency 'DatadogSDK', s.version.to_s
  s.dependency 'Apollo', '~> 0.50'
end
