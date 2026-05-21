import Foundation
import CoreML

/// Runs on-device focus classification using the bundled Core ML model.
///
/// If the compiled model is unavailable (e.g. during development before
/// the Create ML training step is complete), the service falls back to a
/// deterministic heuristic predictor so the app remains fully functional.
///
/// No data leaves the device at any point.
final class FocusPredictionService {

    static let shared = FocusPredictionService()

    private var model: MLModel?

    private init() {
        // TODO: Replace "FocusLensModel" with the actual compiled model name
        // after running the Create ML training workflow described in ML/README_ML.md.
        // The compiled .mlmodelc bundle must be added to the Xcode target.
        if let modelURL = Bundle.main.url(forResource: "FocusLensModel", withExtension: "mlmodelc") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly  // Explicit: no neural engine needed for tabular model
                model = try MLModel(contentsOf: modelURL, configuration: config)
            } catch {
                print("[FocusPredictionService] Could not load ML model: \(error). Using fallback.")
            }
        } else {
            print("[FocusPredictionService] FocusLensModel.mlmodelc not found. Using heuristic fallback.")
        }
    }

    // MARK: - Public API

    /// Generates a focus prediction for a completed session.
    /// Returns nil if the session has no checkpoints (no meaningful data to predict from).
    func predict(for session: StudySession) -> FocusPrediction? {
        guard let features = SessionFeatures.build(from: session) else { return nil }

        let (category, confidence) = model != nil
            ? coreMLPredict(features: features)
            : heuristicPredict(features: features)

        let factors = explainPrediction(category: category, features: features)
        let summary = factors.map { "\($0.label): \($0.detail)" }.joined(separator: ". ")

        return FocusPrediction(
            category: category,
            confidence: confidence,
            factorSummary: summary
        )
    }

    // MARK: - Core ML Inference

    private func coreMLPredict(features: SessionFeatures) -> (FocusCategory, Double) {
        guard let model else { return heuristicPredict(features: features) }

        do {
            // Build the MLFeatureProvider matching the model's expected input schema.
            // Column names must match those used during Create ML training.
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "planned_duration_minutes": MLFeatureValue(double: features.plannedDurationMinutes),
                "checkpoint_count":         MLFeatureValue(double: features.checkpointCount),
                "average_focus_rating":     MLFeatureValue(double: features.averageFocusRating),
                "total_interruptions":      MLFeatureValue(double: features.totalInterruptions),
                "app_switch_count":         MLFeatureValue(double: features.appSwitchCount),
                "energy_level":             MLFeatureValue(double: features.energyLevel),
                "distraction_level_before": MLFeatureValue(double: features.distractionLevelBefore),
                "average_stress":           MLFeatureValue(double: features.averageStress),
                "average_difficulty":       MLFeatureValue(double: features.averageDifficulty),
                "environment_type":         MLFeatureValue(double: features.environmentType)
            ])

            let output = try model.prediction(from: input)

            // The tabular classifier outputs a label string and a probability dictionary.
            guard
                let labelValue = output.featureValue(for: "label"),
                let label = FocusCategory(rawValue: labelValue.stringValue)
            else {
                return heuristicPredict(features: features)
            }

            var confidence = 0.6  // default if probabilities unavailable
            if let probsValue = output.featureValue(for: "labelProbability"),
               let probs = probsValue.dictionaryValue as? [String: Double] {
                confidence = probs[label.rawValue] ?? 0.6
            }

            return (label, confidence)

        } catch {
            print("[FocusPredictionService] Core ML prediction failed: \(error). Using fallback.")
            return heuristicPredict(features: features)
        }
    }

    // MARK: - Heuristic Fallback

    /// Rule-based predictor used when the Core ML model is not available.
    /// Produces deterministic, explainable outputs for development and demo purposes.
    func heuristicPredict(features: SessionFeatures) -> (FocusCategory, Double) {
        let focusScore = features.averageFocusRating  // 1-5
        let stressScore = features.averageStress       // 1-5
        let interruptions = features.totalInterruptions
        let switches = features.appSwitchCount
        let energy = features.energyLevel              // 0, 1, 2

        // Weighted score: higher = better focus
        let positiveScore = (focusScore / 5.0) * 0.4 + (energy / 2.0) * 0.2
        let negativeScore = min(interruptions / 10.0, 1.0) * 0.2
                          + (stressScore / 5.0) * 0.1
                          + min(switches / 5.0, 1.0) * 0.1

        let composite = positiveScore - negativeScore

        switch composite {
        case 0.45...:
            return (.deepFocus, mapToConfidence(composite, range: 0.45...0.60))
        case 0.25..<0.45:
            return (.mixedFocus, mapToConfidence(composite, range: 0.25...0.45))
        case 0.10..<0.25:
            if stressScore >= 4 || energy == 0 {
                return (.recoveryNeeded, 0.68)
            }
            return (.distracted, mapToConfidence(composite, range: 0.10...0.25))
        default:
            return (.recoveryNeeded, mapToConfidence(max(0, composite), range: 0...0.10))
        }
    }

    // MARK: - Explainability

    /// Produces a short list of human-readable contributing factors.
    /// This is simple deterministic logic — it does not claim to explain
    /// the internal weights of the ML model.
    func explainPrediction(category: FocusCategory, features: SessionFeatures) -> [ContributingFactor] {
        var factors: [ContributingFactor] = []

        if features.averageFocusRating >= 4.0 {
            factors.append(ContributingFactor(label: "High self-rated focus", detail: "Your focus check-ins averaged \(String(format: "%.1f", features.averageFocusRating))/5"))
        } else if features.averageFocusRating <= 2.5 {
            factors.append(ContributingFactor(label: "Low self-rated focus", detail: "Your focus check-ins averaged \(String(format: "%.1f", features.averageFocusRating))/5"))
        }

        if features.totalInterruptions >= 5 {
            factors.append(ContributingFactor(label: "High interruption count", detail: "\(Int(features.totalInterruptions)) interruptions logged across checkpoints"))
        }

        if features.appSwitchCount >= 3 {
            factors.append(ContributingFactor(label: "Frequent task switching", detail: "\(Int(features.appSwitchCount)) app/task switches recorded"))
        }

        if features.averageStress >= 4.0 {
            factors.append(ContributingFactor(label: "Elevated stress level", detail: "Average stress was \(String(format: "%.1f", features.averageStress))/5"))
        }

        if features.energyLevel == 0 {
            factors.append(ContributingFactor(label: "Low energy at session start", detail: "Starting energy was reported as low"))
        }

        if factors.isEmpty {
            factors.append(ContributingFactor(label: "Balanced session profile", detail: "No single standout factor; overall pattern matched \(category.rawValue)"))
        }

        return factors
    }

    // MARK: - Helpers

    private func mapToConfidence(_ value: Double, range: ClosedRange<Double>) -> Double {
        guard range.upperBound > range.lowerBound else { return 0.65 }
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        // Map to a confidence window of 0.62 – 0.91 to avoid overclaiming certainty
        return 0.62 + (normalized * 0.29)
    }
}
