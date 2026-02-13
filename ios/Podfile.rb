platform :ios, '13.0'

# Стандартный блок подключения Flutter
setup_flutter_pts = File.join(File.dirname(File.expand_path(__FILE__)), 'Flutter', 'generated_code_util.rb')
load setup_flutter_pts if File.exist?(setup_flutter_pts)

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.expand_path(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      # Это лечит большинство ошибок сборки на GitHub Actions
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end