
Pod::Spec.new do |s|
  s.name             = 'NPlayer'
  s.version          = '0.0.1'
  s.summary          = '易用的播放器'
  s.swift_version    = "5.0"


# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
                        player for TaiHao
                       DESC

  s.homepage         = 'https://gitee.com/icicle'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'bluedream5161@gmail.com' => 'bluedream5161@gmail.com' }
  s.source           = { :git => 'https://gitee.com/icicle/NPlayer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'NPlayer/*.swift'
  
  # s.resource_bundles = {
  #   'TT' => ['TT/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
