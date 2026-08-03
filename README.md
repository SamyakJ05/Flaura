# Flaura

Flaura is a cross-platform flower identification app for Android and iOS. It
uses an on-device TensorFlow Lite model trained on the Oxford Flowers 102
dataset, so a photo can be classified without sending it to a server.

## What is included

- `mobile_app/` - Flutter application with camera and photo-library input.
- `mobile_app/assets/models/` - production TFLite model and its ordered
  102-class label map.
- `train_oxford102.py` - reproducible Oxford Flowers 102 training and export
  pipeline.
- `artifacts/oxford102/` - ignored local training outputs, including metrics
  and checkpoints when you retrain.
- `model.tflite`, `train_model.py`, and the notebook - preserved legacy
  five-class prototype assets.
- Course requirement and data-flow documents.

## Model

The current 102-class model uses EfficientNetB0 transfer learning and reached
**81.09% test accuracy** on Oxford Flowers 102. It expects an RGB image and
resizes it to 224 × 224 pixels in the app before inference.

The bundled model has a matching `labels.json` file. Keep the two files
together: prediction indexes are meaningful only with that label order.

## Run the mobile app

Install Flutter, then run:

```bash
cd mobile_app
flutter pub get
flutter run
```

On iOS, test the TensorFlow Lite flow on a physical device. The app requests
camera and photo-library access only when the corresponding action is used.

## Retrain the model

Use Python 3.12 or later:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python train_oxford102.py --epochs 12
```

The first run downloads and prepares Oxford Flowers 102. Exports are written
to `artifacts/oxford102/`; copy the new `flaura_flowers102.tflite` and
`labels.json` into `mobile_app/assets/models/` together before rebuilding the
app.

## Validation

```bash
cd mobile_app
flutter analyze
flutter test
```

## Project history

Flaura began as a CSD326 software-engineering course project. The repository
now includes its original documentation and a production-ready mobile ML
baseline.
