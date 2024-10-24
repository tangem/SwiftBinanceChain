Pod::Spec.new do |s|
  s.name         = 'BinanceChain'
  s.version      = '1.0.1-beta'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.summary      = 'BinanceChain'
  s.author       = { 'Michael Henderson' => 'roadkillrabbit@gmail.com' }
  s.homepage     = 'http://github.com/mh7821/SwiftBinanceChain/'
  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  s.source       = { :path => 'BinanceChain' }
  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS[config=Debug]' => '-D DEBUG'
  }
  s.swift_version = '5'
  s.default_subspecs = 'Core'
  s.static_framework = false

  s.subspec 'Core' do |sub|
    # 'SwiftProtobuf' dependency must be added via SPM

    sub.source_files = 'BinanceChain/Sources/Core/*.swift'
    sub.dependency 'BinanceChain/Protobuf'
    sub.dependency 'BinanceChain/Util'
    sub.dependency 'BinanceChain/Libraries'
    sub.dependency 'Alamofire'
    sub.dependency 'SwiftyJSON'
    sub.dependency 'SwiftDate'
  end

  s.subspec 'Util' do |sub|
    sub.source_files = 'BinanceChain/Sources/Util/*.swift'
  end

  s.subspec 'Protobuf' do |sub|
    sub.source_files = 'BinanceChain/Sources/Protobuf/*.swift'
  end

  s.subspec 'Libraries' do |sub|
    sub.source_files = 'BinanceChain/Sources/Libraries/*/*.swift'
  end

end
