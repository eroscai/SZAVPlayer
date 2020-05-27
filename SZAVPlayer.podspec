#
# Be sure to run `pod lib lint SZAVPlayer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SZAVPlayer'
  s.version          = '1.1.5'
  s.summary          = 'Swift AVPlayer, based on AVAssetResourceLoaderDelegate, support cache.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  SZAVPlayer is a lightweight audio player library, based on AVPlayer, pure-Swift. Video playing will be supported later.
                       DESC

  s.homepage         = 'https://github.com/eroscai/SZAVPlayer'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'eroscai' => 'csz0102@gmail.com' }
  s.source           = { :git => 'https://github.com/eroscai/SZAVPlayer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_version         = '5.0'

  s.source_files = 'Sources/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SZAVPlayer' => ['SZAVPlayer/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'CoreServices', 'AVFoundation'
end
