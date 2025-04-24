Pod::Spec.new do |s|

    # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

    s.name                  = "swift-secp256k1"
    s.version               = "0.20.0-prerelease-1"
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
        :sha256 => "3ba806e07fadd0c4201135d7219be7128652f2f7612fb348d02c6891d857d047"
    }

    # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.requires_arc = true
    s.module_name = "P256K"
    s.swift_version = "6.0"
    s.vendored_frameworks = "P256K.xcframework"

end