//
//  APIKeySettingsView.swift
//  anyapp
//

import SwiftUI

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var hasStoredKey = GrokAPIKeyStore.hasKey
    @State private var errorMessage: String?
    @State private var showSaveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("xAI API 키", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("API 키는 iOS Keychain에만 저장됩니다. 앱 소스나 Git에는 포함되지 않습니다.")
                }

                Section {
                    if hasStoredKey {
                        Label("키가 저장되어 있습니다", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("저장된 키 없음", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Grok API 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: saveKey)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if hasStoredKey {
                    ToolbarItem(placement: .bottomBar) {
                        Button("키 삭제", role: .destructive, action: deleteKey)
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSaveConfirmation {
                    Text("저장됨")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        }
    }

    private func saveKey() {
        errorMessage = nil
        do {
            try GrokAPIKeyStore.save(apiKey)
            apiKey = ""
            hasStoredKey = true
            withAnimation {
                showSaveConfirmation = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation {
                    showSaveConfirmation = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteKey() {
        errorMessage = nil
        do {
            try GrokAPIKeyStore.delete()
            apiKey = ""
            hasStoredKey = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    APIKeySettingsView()
}
