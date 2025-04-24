Pod::Spec.new do |s|

    # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

    s.name                  = "swift-secp256k1"
    s.version               = "0.20.0-prerelease-0"
    s.summary               = "P256K: Elliptic curve public key cryptography, ECDH, and Schnorr Signatures for Bitcoin."
    s.description           = "Open-source library for a substantial portion of the APIs of libsecp256k1. Written in Swift for native iOS, macOS, tvOS, watchOS, and visionOS."
    s.homepage              = "https://github.com/21-DOT-DEV/swift-secp256k1"

    # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    
    s.license               = { :type => "MIT", :file => "LICENSE" }

    # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
    
    s.author                = { "21-DOT-DEV" => "satoshi@21.dev" }
    s.social_media_url      = "https://primal.net/21"

    # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

    s.ios.deployment_target = "18.0"
    s.osx.deployment_target = "15.0"
    s.tvos.deployment_target = "18.0"
    s.watchos.deployment_target = "11.0"
    #s.visionos.deployment_target = "2.0"

    # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

    s.source = {
        :http => "https://github.com/21-DOT-DEV/swift-secp256k1/releases/download/#{s.version}/P256K.xcframework.zip",
        :sha256 => "286b82ffcade89092c536e669b44b84d2726229e9f54e56cd6fa86323f2e1f09"
    }

    # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.requires_arc = true
    s.module_name = "P256K"
    s.swift_version = "6.0"
    s.vendored_frameworks = "P256K.xcframework"

end