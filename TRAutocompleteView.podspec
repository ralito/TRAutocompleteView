Pod::Spec.new do |s|
  s.name         = "TRAutocompleteView"
  s.version      = "1.1"
  s.summary      = "Flexible and highly configurable auto complete view, attachable to any UITextField."

  s.homepage     = "https://github.com/amitmalhotra/TRAutocompleteView"
  s.license      = 'FreeBSD'
  s.author       = { "Amit Malhotra" => "mallu007@gmail.com" }

  s.source       = { :git => "https://github.com/amitmalhotra/TRAutocompleteView.git", :tag => "v1.1" }
  s.platform     = :ios, '5.0'
  s.source_files = 'src'
  s.requires_arc = true
  
  s.frameworks = 'CoreLocation'
  s.dependency 'AFNetworking', '~> 1.3.0'
  s.dependency 'FPPopover', '~> 1.4.1'
end
