//
//  AppleSignIn.swift
//  NoIReject
//
//  Helpers for Sign in with Apple → Supabase id_token grant.
//

import Foundation
import CryptoKit

enum AppleSignInNonce {
    /// Returns (rawNonce, sha256Nonce). Send `sha256Nonce` to Apple in the request,
    /// and `rawNonce` to Supabase when exchanging the id_token.
    static func make(length: Int = 32) -> (raw: String, hashed: String) {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var raw = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            assert(status == errSecSuccess)
            for byte in randoms where remaining > 0 {
                if byte < charset.count {
                    raw.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        let hashed = SHA256.hash(data: Data(raw.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return (raw, hashed)
    }
}
