import Foundation

struct EffectPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let saturation: Float
    let contrast: Float
    let brightness: Float
    let gamma: Float
    let redLift: Float
    let blueLift: Float
    let blurRadius: Float
    let bloomOpacity: Float
    let noiseOpacity: Float
    let chromaShift: Float

    static let mild = EffectPreset(
        id: "mild",
        name: "Mild",
        saturation: 1.12,
        contrast: 1.05,
        brightness: 0.02,
        gamma: 0.98,
        redLift: 0.04,
        blueLift: 0.02,
        blurRadius: 6,
        bloomOpacity: 0.22,
        noiseOpacity: 0.08,
        chromaShift: 1.0
    )

    static let heavy = EffectPreset(
        id: "heavy",
        name: "Heavy",
        saturation: 1.25,
        contrast: 1.12,
        brightness: 0.05,
        gamma: 0.94,
        redLift: 0.08,
        blueLift: 0.04,
        blurRadius: 10,
        bloomOpacity: 0.35,
        noiseOpacity: 0.14,
        chromaShift: 2.0
    )

    static let brutal = EffectPreset(
        id: "brutal",
        name: "Brutal",
        saturation: 1.38,
        contrast: 1.18,
        brightness: 0.08,
        gamma: 0.9,
        redLift: 0.12,
        blueLift: 0.08,
        blurRadius: 14,
        bloomOpacity: 0.48,
        noiseOpacity: 0.2,
        chromaShift: 3.0
    )

    static let all: [EffectPreset] = [.mild, .heavy, .brutal]
}
