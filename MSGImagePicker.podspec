#
# Be sure to run `pod lib lint MSGImagePicker.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MSGImagePicker'
  s.version          = '0.1.0'
  s.summary          = 'A SwiftUI media picker for selecting photos and videos from the photo library.'

  s.description      = <<-DESC
MSGImagePicker is a pure SwiftUI library for selecting multiple photos and videos
from the device's photo library. It supports ordered multi-selection with visual
badges, an action bar with caption input, and is designed to be presentation-agnostic.
                       DESC

  s.homepage         = 'https://repo.vms.me/app/ios/msgimagepicker.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Francesco Cosentino' => 'francesco@messagenius.com' }
  s.source           = { :git => 'https://repo.vms.me/app/ios/msgimagepicker.git', :tag => s.version.to_s }

  s.swift_versions = '5.9'
  s.ios.deployment_target = '16.0'

  s.source_files = 'MSGImagePicker/Classes/**/*.swift'
  
  s.frameworks = 'Photos', 'PhotosUI', 'SwiftUI'
end
