//
//  LoginView.swift
//  NoIReject
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var pendingAppleNonce: String?
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text("🧘")
                    .font(.system(size: 64))
                Text("NoIReject")
                    .font(.largeTitle.bold())
                Text("Track your moments. Own your day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($focused, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await auth.signIn(email: email.trimmed, password: password) } }

                Button {
                    Task { await auth.signIn(email: email.trimmed, password: password) }
                } label: {
                    if auth.isAuthenticating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign In").bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(auth.isAuthenticating)

                Button {
                    Task { await auth.signUp(email: email.trimmed, password: password) }
                } label: {
                    Text("Create Account")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .disabled(auth.isAuthenticating)

                HStack {
                    VStack { Divider() }
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                .padding(.vertical, 4)

                SignInWithAppleButton(.signIn) { request in
                    let (raw, hashed) = AppleSignInNonce.make()
                    pendingAppleNonce = raw
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = hashed
                } onCompletion: { result in
                    switch result {
                    case .success(let authz):
                        guard let cred = authz.credential as? ASAuthorizationAppleIDCredential,
                              let tokenData = cred.identityToken,
                              let idToken = String(data: tokenData, encoding: .utf8),
                              let raw = pendingAppleNonce else {
                            auth.reportAuthError("Apple sign-in failed: missing token")
                            return
                        }
                        Task {
                            await auth.signInWithApple(idToken: idToken, rawNonce: raw)
                            pendingAppleNonce = nil
                        }
                    case .failure(let err):
                        if (err as? ASAuthorizationError)?.code != .canceled {
                            auth.reportAuthError(err.localizedDescription)
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(auth.isAuthenticating)

                if let err = auth.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    LoginView().environmentObject(AuthService())
}
