Pod::Spec.new do |s|
  s.name             = 'SDVoicePlayer'
  s.version          = '1.1.0'
  s.summary          = '语音播放器。'

  s.homepage         = 'https://github.com/xq-120/SDVoicePlayer'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'xq-120' => '1204556447@qq.com' }
  s.source           = { :git => 'https://github.com/xq-120/SDVoicePlayer.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.swift_versions = '5.0'
  
  s.source_files = 'SDVoicePlayer/Classes/**/*'

  s.dependency "GCDWeakTimer", "~> 1.0.0"
end
