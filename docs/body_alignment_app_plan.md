# Body Alignment Visualization iOS App Plan

## 1. Overview
- **Goal**: Visualize body misalignment by mapping reference lines on user photos.
- **Primary Input**: Full-body photos captured in-app or imported from library.
- **Key Output**: Overlay of skeletal/keypoint lines with asymmetry indicators and recommendations.

## 2. Core Features
1. **Photo Capture & Import**
   - In-app camera with grid guides and AR overlay to guide posture.
   - Ability to import existing photos from the photo library.
2. **Pose Detection & Mapping**
   - Use Apple's Vision framework (`VNDetectHumanBodyPoseRequest`) for 2D keypoints.
   - For enhanced accuracy, integrate a custom Core ML pose estimation model (e.g., MoveNet) using `Vision`'s `VNCoreMLRequest`.
3. **Alignment Visualization**
   - Draw lines connecting key joints (shoulders, hips, knees, etc.) with `CAShapeLayer` over a `UIImageView`.
   - Compute angles and distances to highlight asymmetries (e.g., shoulder tilt, pelvic shift).
   - Provide color-coded indicators: green (aligned), yellow (minor deviation), red (major deviation).
4. **Analysis Summary**
   - Display textual report summarizing detected imbalances and suggesting stretching/exercise routines.
   - Allow exporting reports as PDF or image.
5. **History & Progress Tracking**
   - Save analyses with timestamps to Core Data.
   - Provide progress charts using `Charts` framework or SwiftUI Charts.
6. **User Privacy & On-Device Processing**
   - Process images on-device to ensure privacy.
   - Optional iCloud sync with user consent.

## 3. Architecture
- **App Layer**: SwiftUI for modern UI; use MVVM pattern for state management.
- **Modules**:
  - `CameraModule`: Handles capture session (`AVFoundation`) and AR guidance overlay.
  - `PoseDetectionModule`: Wraps Vision/Core ML requests and outputs normalized joint data.
  - `AnalysisModule`: Calculates deviations, generates recommendations.
  - `PersistenceModule`: Core Data model storing `PostureAssessment` entities (image reference, metrics, notes).
- **Services**:
  - `PhotoService`: Manage imports/exports.
  - `ReportService`: Create shareable reports.

## 4. User Flow
1. **Onboarding**: Brief tutorial on how to take photos for accurate analysis.
2. **Capture Screen**: Camera view with alignment guides. User captures photo or imports.
3. **Processing Screen**: Pose detection runs, then overlays skeleton and alignment lines.
4. **Results Screen**:
   - Visual overlay with toggles for different planes (frontal, sagittal if side photos are provided).
   - Metrics list (e.g., shoulder angle, hip level difference).
   - Action buttons: `Save`, `Compare`, `Share`.
5. **History Screen**: Gallery of previous assessments with filter by tags (e.g., "before workout").
6. **Settings**: Data privacy options, measurement units, reminders for periodic assessments.

## 5. Technical Considerations
- **Calibration**: Prompt user to include a reference object or use ARKit depth estimation to calculate scale.
- **Multiple Poses**: Support both front and side photos; allow manual adjustments if detection is off.
- **Localization**: Provide Japanese and English localization.
- **Accessibility**: VoiceOver-friendly descriptions, high-contrast overlays.
- **Testing**:
  - Unit tests for analysis calculations.
  - UI tests for capture and result flows using `XCTest` and `XCUITest`.
  - Benchmarking for real-time performance.

## 6. Roadmap
1. **MVP**:
   - Photo capture/import, single-plane pose detection, basic overlay, save & share.
2. **Phase 2**:
   - Progress tracking, comparison view, exercise recommendations.
3. **Phase 3**:
   - Multi-angle analysis, AR posture coaching, integration with Apple Health.

## 7. Resource Requirements
- **Team**: iOS engineer, ML engineer, UI/UX designer, physiotherapist consultant.
- **Timeline**: ~12 weeks for MVP (Discovery 2 weeks, Development 8 weeks, QA 2 weeks).

## 8. Future Enhancements
- Real-time AR posture correction using ARKit body tracking.
- Integration with wearables for continuous posture monitoring.
- Community features for sharing progress with trainers or clinicians.
