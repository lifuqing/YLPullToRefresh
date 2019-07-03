#
# Be sure to run `pod lib lint YLPullToRefresh.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YLPullToRefresh'
  s.version          = '1.0.0'
  s.summary          = '下拉刷新和上拉加载更多.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
支持下拉刷新和上拉加载更多，预加载和封底功能
                       DESC

  s.homepage         = 'https://github.com/lifuqing/YLPullToRefresh'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'lifuqing' => 'lifuqing001@ke.com' }
  s.source           = { :git => 'https://github.com/lifuqing/YLPullToRefresh.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'YLPullToRefresh/Classes/**/*'
  s.resource     = 'YLPullToRefresh/Assets/**/*.{bundle}'
  
  # s.resource_bundles = {
  #   'YLPullToRefresh' => ['YLPullToRefresh/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
