inhibit_all_warnings!
use_frameworks!

def shared_pods
  pod 'BlockiesSwift'
  pod 'Kingfisher'
  pod 'TrustWalletCore'
  pod 'BigInt'
end

target 'Tokenary' do
  platform :osx, '11.4'
  shared_pods
end

target 'Tokenary iOS' do
  platform :ios, '15.0'
  shared_pods
end
