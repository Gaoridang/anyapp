//
//  APIKeySettingsView.swift
//  anyapp
//

import SwiftUI

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var hasStoredKey = GrokAPIKeyStore.hasKey
    @State private var selectedSTTMode = STTModeStore.mode
    @State private var onDeviceAvailable = AppleSpeechSTTClient.isOnDeviceAvailable
    @State private var errorMessage: String?
    @State private var showSaveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("음성 변환", selection: $selectedSTTMode) {
                        ForEach(STTMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(selectedSTTMode.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("음성 변환")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedSTTMode == .automatic {
                            Label {
                                Text(automaticProviderDescription)
                            } icon: {
                                Image(systemName: "arrow.triangle.branch")
                            }
                            .font(.footnote)
                        }

                        if selectedSTTMode == .onDevice || selectedSTTMode == .automatic {
                            Label {
                                Text(onDeviceAvailabilityDescription)
                            } icon: {
                                Image(systemName: onDeviceAvailable ? "checkmark.circle.fill" : "exclamationmark.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(onDeviceAvailable ? .green : .secondary)
                        }
                    }
                }

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
                } header: {
                    Text("Grok API")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedSTTMode) { _, newMode in
                STTModeStore.mode = newMode
            }
            .onAppear {
                onDeviceAvailable = AppleSpeechSTTClient.isOnDeviceAvailable
            }
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

    private var automaticProviderDescription: String {
        STTRouter(
            modeProvider: { selectedSTTMode },
            hasGrokKey: { hasStoredKey },
            onDeviceAvailability: { onDeviceAvailable }
        ).resolvedProvider(for: .automatic) == .grok
            ? "자동 모드: API 키가 있어 Grok을 사용합니다."
            : "자동 모드: API 키가 없어 기기 음성 인식을 사용합니다."
    }

    private var onDeviceAvailabilityDescription: String {
        onDeviceAvailable
            ? "기기 음성 인식 사용 가능"
            : "기기 음성 인식 불가 — 설정 > 일반 > 키보드 > 받아쓰기에서 한국어 설치"
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
