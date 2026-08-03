"""Train Flaura's five-class flower classifier and export a TFLite model.

Run in a Python 3.9 virtual environment after installing requirements-legacy.txt.
"""

from pathlib import Path

import tensorflow as tf
from tflite_model_maker import image_classifier
from tflite_model_maker.config import ExportFormat
from tflite_model_maker.image_classifier import DataLoader

DATASET_URL = "https://storage.googleapis.com/download.tensorflow.org/example_images/flower_photos.tgz"
DATASET_NAME = "flower_photos.tgz"
OUTPUT_DIR = Path("artifacts")
MODEL_NAME = "flaura_flower_classifier.tflite"
SEED = 42


def load_data() -> DataLoader:
    """Download the public flower dataset once and return a labelled loader."""
    archive = tf.keras.utils.get_file(DATASET_NAME, DATASET_URL, extract=True)
    dataset_dir = Path(archive).parent / "flower_photos"
    return DataLoader.from_folder(str(dataset_dir))


def main() -> None:
    tf.keras.utils.set_random_seed(SEED)
    OUTPUT_DIR.mkdir(exist_ok=True)

    data = load_data()
    train_data, remainder = data.split(0.8)
    validation_data, test_data = remainder.split(0.5)

    model = image_classifier.create(train_data, validation_data=validation_data)
    loss, accuracy = model.evaluate(test_data)
    print(f"Test loss: {loss:.4f}; test accuracy: {accuracy:.2%}")

    model.export(export_dir=str(OUTPUT_DIR), tflite_filename=MODEL_NAME)
    model.export(export_dir=str(OUTPUT_DIR), export_format=ExportFormat.LABEL)
    model.evaluate_tflite(str(OUTPUT_DIR / MODEL_NAME), test_data)


if __name__ == "__main__":
    main()
