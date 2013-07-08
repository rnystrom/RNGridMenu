Pod::Spec.new do |s|
  s.name            = 'RNGridMenu'
  s.version         = '1.0.0'
  s.license         = 'MIT'
  s.platform        = :ios, '5.0'

  s.summary         = 'A grid menu with elastic layout, depth of field, and realistic animation.'
  s.homepage        = 'https://www.github.com/rnystrom/RNGridMenu'
  s.author          = { 'Ryan Nystrom' => 'rnystrom@whoisryannystrom.com'}
  s.source          = { :git => 'https://www.github.com/rnystrom/RNGridMenu' }

  s.source_files    = 'RNGridMenu.{h,m}'

  s.requires_arc    = true

  s.frameworks      = 'QuartzCore', 'Accelerate'
end