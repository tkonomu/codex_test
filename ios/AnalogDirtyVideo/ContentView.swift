import PhotosUI
import SwiftUI

struct ContentView: View {
    @StateObject private var processor = VideoProcessor()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedMovieURL: URL?
    @State private var selectedPreset: EffectPreset = .heavy
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Input") {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()) {
                            Label(
                                selectedMovieURL == nil ? "動画を選択" : "動画を選び直す",
                                systemImage: "video"
                            )
                        }

                    if let selectedMovieURL {
                        Text(selectedMovieURL.lastPathComponent)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Preset") {
                    Picker("Effect", selection: $selectedPreset) {
                        ForEach(EffectPreset.all) { preset in
                            Text(preset.name).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("処理") {
                    Button {
                        Task { await processVideo() }
                    } label: {
                        if processor.isProcessing {
                            HStack {
                                ProgressView()
                                Text("処理中... \(Int(processor.progress * 100))%")
                            }
                        } else {
                            Label("エフェクトをかけて写真に保存", systemImage: "sparkles.rectangle.stack")
                        }
                    }
                    .disabled(selectedMovieURL == nil || processor.isProcessing)

                    if !processor.statusMessage.isEmpty {
                        Text(processor.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Dirty Video")
        }
        .task(id: selectedItem) {
            guard let selectedItem else { return }
            do {
                if let movieData = try await selectedItem.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mov")
                    try movieData.write(to: tempURL)
                    selectedMovieURL = tempURL
                }
            } catch {
                alertMessage = "動画の読み込みに失敗しました: \(error.localizedDescription)"
            }
        }
        .alert("Error", isPresented: .constant(alertMessage != nil), actions: {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        }, message: {
            Text(alertMessage ?? "")
        })
    }

    private func processVideo() async {
        guard let selectedMovieURL else { return }
        do {
            try await processor.applyEffect(inputURL: selectedMovieURL, preset: selectedPreset)
        } catch {
            alertMessage = "変換に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
