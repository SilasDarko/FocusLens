# FocusLens — ML Model Training Guide

## Overview

FocusLens uses a **tabular classifier** trained with **Create ML** in Xcode. The model runs entirely on-device via Core ML and never sends data to a server.

This document describes how to train the model, integrate it into the app, and replace the heuristic fallback with a real `.mlmodel`.

---

## Model Type

| Property | Value |
|---|---|
| Framework | Create ML (`MLTabularClassifier`) |
| Task | Multi-class classification |
| Input | 10 numeric features |
| Output labels | `Deep Focus`, `Mixed Focus`, `Distracted`, `Recovery Needed` |

---

## Features

| Column name (CSV) | Description | Range |
|---|---|---|
| `planned_duration_minutes` | Planned session length in minutes | 5–240 |
| `checkpoint_count` | Number of checkpoints logged | 0–N |
| `average_focus_rating` | Mean self-rated focus across checkpoints | 1.0–5.0 |
| `total_interruptions` | Total interruptions across all checkpoints | 0–N |
| `app_switch_count` | Number of app/task switches logged | 0–N |
| `energy_level` | Starting energy: 0=Low, 1=Medium, 2=High | 0–2 |
| `distraction_level_before` | Pre-session distraction: 0=Low, 1=Medium, 2=High | 0–2 |
| `average_stress` | Mean self-rated stress across checkpoints | 1.0–5.0 |
| `average_difficulty` | Mean perceived difficulty across checkpoints | 1.0–5.0 |
| `environment_type` | Study environment: 0=Quiet, 1=Library, 2=SharedSpace, 3=Dorm, 4=Outdoors, 5=Noisy | 0–5 |

**Target column:** `label`  
**Label values:** `Deep Focus`, `Mixed Focus`, `Distracted`, `Recovery Needed`

---

## Training Steps (Xcode / Create ML)

### Option A — Create ML App (Recommended for beginners)

1. Open Xcode → **Xcode menu → Open Developer Tool → Create ML**
2. Create a new project → Select **Tabular Classifier**
3. Under **Training Data**, drag in `FocusLens/ML/training_data.csv`
4. Set **Target** to `label`
5. Leave all other columns as input features
6. Set **Algorithm** to `Boosted Tree` or `Random Forest`
7. Click **Train**
8. Once complete, click **Output → Export model as `.mlmodel`**
9. Name the exported file `FocusLensModel.mlmodel`
10. Drag the file into the Xcode project under `FocusLens/ML/`
11. Ensure the file is added to the `FocusLens` target (check "Target Membership" in the File Inspector)

### Option B — Swift Create ML Script

Run this script in a Swift Playground or command-line Swift tool:

```swift
import CreateML
import Foundation

let trainingDataURL = URL(fileURLWithPath: "/path/to/FocusLens/ML/training_data.csv")
let outputURL = URL(fileURLWithPath: "/path/to/FocusLens/ML/FocusLensModel.mlmodel")

let trainingData = try MLDataTable(contentsOf: trainingDataURL)

let classifier = try MLBoostedTreeClassifier(
    trainingData: trainingData,
    targetColumn: "label"
)

try classifier.write(to: outputURL)
print("Model saved to: \(outputURL.path)")
print("Training accuracy: \(classifier.trainingMetrics.classificationError)")
```

---

## After Training

Once `FocusLensModel.mlmodel` is added to the Xcode target:

1. Xcode automatically compiles it to `FocusLensModel.mlmodelc`
2. The compiled bundle is included in the app at build time
3. `FocusPredictionService` will automatically detect and use it

The auto-generated `FocusLensModel.swift` class provides a type-safe wrapper. You can optionally use it directly instead of `MLDictionaryFeatureProvider`, but `FocusPredictionService` currently uses the lower-level `MLModel` API to remain model-name-agnostic.

---

## Heuristic Fallback

If `FocusLensModel.mlmodelc` is not found at runtime (e.g. in the Simulator before model training is complete), `FocusPredictionService` automatically falls back to `heuristicPredict()`, a rule-based predictor. The app is fully functional in fallback mode — it simply uses deterministic rules instead of the trained classifier.

---

## Replacing the Sample Data

`training_data.csv` contains 50 hand-labeled synthetic examples. For a real deployment:

- Collect real user sessions (with explicit consent) and label them
- Aim for 200+ examples per class for reliable classifier performance
- Re-run the Create ML training workflow and replace the `.mlmodel` in the Xcode project

---

## Model Limitations

- The 50-example training set is for demonstration only
- Tabular classifiers on small datasets may overfit; accuracy figures should not be overclaimed
- All predictions are self-reported behavioral patterns, not clinical assessments
- The model does not capture temporal sequences within a session — only session-level aggregates
