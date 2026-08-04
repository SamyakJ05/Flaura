# Flaura

**Flaura** is a privacy-first flower identification app for Android and iOS.
Choose or capture a photo, then classify it locally with a TensorFlow Lite
model trained on Oxford Flowers 102. No image is sent to a server for
classification.

> **Project status:** active course project and mobile ML baseline. The Android
> app is ready for device testing; iOS packaging requires Xcode signing.

## Features

- On-device recognition across 102 flower categories.
- Camera capture and photo-library selection.
- Confidence score for every prediction.
- A bundled TFLite model, so classification works offline after installation.
- One Flutter codebase for Android and iOS.

## Quick start

### Run the Flutter app

```bash
cd mobile_app
flutter pub get
flutter run
```

For iOS, use a physical device when validating TensorFlow Lite inference.

### Validate changes

```bash
cd mobile_app
flutter analyze
flutter test
```

## Architecture

```text
Camera / photo library
        |
        v
Flutter UI -> resize image to 224 x 224 RGB -> TFLite interpreter
                                                   |
                                                   v
                                       labels.json -> flower + confidence
```

| Area | Location |
| --- | --- |
| Flutter application | `mobile_app/` |
| Inference UI and preprocessing | `mobile_app/lib/main.dart` |
| Production model | `mobile_app/assets/models/flaura_flowers102.tflite` |
| Ordered model labels | `mobile_app/assets/models/labels.json` |
| 102-class training pipeline | `train_oxford102.py` |
| Legacy five-class prototype | `model.tflite`, `train_model.py`, and notebook |

## Model

The current model uses EfficientNetB0 transfer learning on the Oxford Flowers
102 dataset. Its measured test accuracy is **81.09%**.

This is a recognition aid, not a botanical authority. It is limited to the 102
classes in the bundled label file, and an unfamiliar flower may still receive a
high-confidence label. Keep `flaura_flowers102.tflite` and `labels.json`
together: output indexes depend on that exact label order.

## Retrain the model

Requirements: Python 3.12 or later, disk space for the dataset, and internet
access on the first run.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python train_oxford102.py --epochs 12
```

Training downloads Oxford Flowers 102 on first use and writes the model,
labels, metrics, and checkpoint to `artifacts/oxford102/`. To ship a retrained
model, copy both of these files into `mobile_app/assets/models/`:

```text
flaura_flowers102.tflite
labels.json
```

The original five-class notebook uses a separate legacy environment described
in `requirements-legacy.txt`.

## Android releases

Build packages from the Flutter project:

```bash
cd mobile_app
flutter build apk --release
flutter build appbundle --release
```

Use the `.aab` bundle for Google Play and the `.apk` for direct device testing.
Before publishing, configure a private upload keystore and release signing; do
not upload a debug-signed build to Play Console.

## iOS releases

Install full Xcode and CocoaPods, enroll in the Apple Developer Program, set
the `com.flaura.flaura` bundle ID and signing team in Xcode, then run:

```bash
cd mobile_app
flutter build ipa --release
```

Use the resulting IPA with TestFlight before submitting it through App Store
Connect.

## Contributing

1. Create a focused branch from `main`.
2. Keep model and label-file updates paired.
3. Run `flutter analyze` and `flutter test` before opening a pull request.
4. Describe any model, dataset, dependency, or permission changes clearly.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

## Documentation

- [Problem Statement](docs/Problem%20Statement.pdf)
- [Software Requirements Specification](docs/SRS%20Document.pdf)
- [Data Flow Diagram](docs/DFD.pdf)

## License

No open-source license has been selected yet. Do not redistribute the code,
model, or documentation without permission from the repository owner.
