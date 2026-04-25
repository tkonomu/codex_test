import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Photos

@MainActor
final class VideoProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Float = 0
    @Published var statusMessage = ""

    private let context = CIContext(options: [
        .cacheIntermediates: false,
        .useSoftwareRenderer: false
    ])

    func applyEffect(inputURL: URL, preset: EffectPreset) async throws {
        isProcessing = true
        statusMessage = "Preparing export..."
        progress = 0
        defer {
            isProcessing = false
        }

        let asset = AVAsset(url: inputURL)
        let composition = AVMutableComposition()

        guard
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
            let compositionVideo = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw NSError(domain: "VideoProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video track not found"])
        }

        let videoDuration = try await asset.load(.duration)
        try compositionVideo.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )
        compositionVideo.preferredTransform = try await videoTrack.load(.preferredTransform)

        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudio = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudio.insertTimeRange(
                CMTimeRange(start: .zero, duration: videoDuration),
                of: audioTrack,
                at: .zero
            )
        }

        let videoComposition = AVVideoComposition(asset: composition) { [weak self] request in
            guard let self else {
                request.finish(with: NSError(domain: "VideoProcessor", code: -1))
                return
            }

            let source = request.sourceImage.clampedToExtent()
            let filtered = self.makeFilteredImage(from: source, preset: preset)
                .cropped(to: request.sourceImage.extent)
            request.finish(with: filtered, context: self.context)
        }

        videoComposition.renderSize = try await videoTrack.load(.naturalSize)
        videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(try await videoTrack.load(.nominalFrameRate).rounded(.up)))

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dirty_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = false
        export.videoComposition = videoComposition

        statusMessage = "Rendering..."

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    continuation.resume(throwing: export.error ?? NSError(domain: "VideoProcessor", code: 3))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "VideoProcessor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                default:
                    continuation.resume(throwing: NSError(domain: "VideoProcessor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unexpected export status"]))
                }
            }

            Task.detached { [weak self, weak export] in
                while let export, export.status == .exporting {
                    await MainActor.run {
                        self?.progress = export.progress
                    }
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
            }
        }

        statusMessage = "Saving to Photos..."
        try await saveToPhotoLibrary(videoURL: outputURL)
        progress = 1
        statusMessage = "Saved to Photos"
    }

    private func makeFilteredImage(from input: CIImage, preset: EffectPreset) -> CIImage {
        let tone = CIFilter.colorControls()
        tone.inputImage = input
        tone.saturation = preset.saturation
        tone.contrast = preset.contrast
        tone.brightness = preset.brightness

        let gamma = CIFilter.gammaAdjust()
        gamma.inputImage = tone.outputImage
        gamma.power = preset.gamma

        let lifted = (gamma.outputImage ?? input)
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 1 + preset.redLift, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1 + preset.blueLift, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
                ]
            )

        let shifted = makeChromaticAberration(from: lifted, shift: preset.chromaShift)
        let bloomed = addBloom(to: shifted, radius: preset.blurRadius, opacity: preset.bloomOpacity)
        return addNoise(to: bloomed, opacity: preset.noiseOpacity)
    }

    private func addBloom(to input: CIImage, radius: Float, opacity: Float) -> CIImage {
        let blur = input
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: input.extent)

        return blur
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
                ]
            )
            .applyingFilter(
                "CISourceOverCompositing",
                parameters: [kCIInputBackgroundImageKey: input]
            )
            .cropped(to: input.extent)
    }

    private func addNoise(to input: CIImage, opacity: Float) -> CIImage {
        let noise = CIFilter.randomGenerator().outputImage?
            .cropped(to: input.extent)
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 0.35, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.35, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.35, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
                ]
            )

        guard let noise else { return input }

        return noise
            .applyingFilter(
                "CISoftLightBlendMode",
                parameters: [kCIInputBackgroundImageKey: input]
            )
            .cropped(to: input.extent)
    }

    private func makeChromaticAberration(from input: CIImage, shift: Float) -> CIImage {
        let red = input
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector.zero,
                    "inputBVector": CIVector.zero,
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
                ]
            )
            .transformed(by: CGAffineTransform(translationX: CGFloat(shift), y: 0))

        let blue = input
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector.zero,
                    "inputGVector": CIVector.zero,
                    "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
                ]
            )
            .transformed(by: CGAffineTransform(translationX: -CGFloat(shift), y: 0))

        let green = input
            .applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector.zero,
                    "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                    "inputBVector": CIVector.zero,
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
                ]
            )

        return red
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: green])
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: blue])
            .cropped(to: input.extent)
    }

    private func saveToPhotoLibrary(videoURL: URL) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard newStatus == .authorized || newStatus == .limited else {
                throw NSError(domain: "VideoProcessor", code: 7, userInfo: [NSLocalizedDescriptionKey: "Photo Library permission denied"])
            }
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }
    }
}
