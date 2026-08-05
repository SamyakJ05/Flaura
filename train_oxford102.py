"""Train Flaura's 102-class on-device flower classifier.

The model uses Oxford Flowers 102 through TensorFlow Datasets and exports a
float32 TensorFlow Lite model plus the exact ordered labels used at inference.
"""

import argparse
import json
from pathlib import Path

import tensorflow as tf
import tensorflow_datasets as tfds

AUTOTUNE = tf.data.AUTOTUNE
IMAGE_SIZE = 224
SEED = 42


def prepare(example: dict[str, tf.Tensor]) -> tuple[tf.Tensor, tf.Tensor]:
    image = tf.image.resize(example["image"], (IMAGE_SIZE, IMAGE_SIZE))
    return tf.cast(image, tf.float32), example["label"]


def build_model(class_count: int) -> tf.keras.Model:
    augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal", seed=SEED),
            tf.keras.layers.RandomRotation(0.1, seed=SEED),
            tf.keras.layers.RandomZoom(0.1, seed=SEED),
        ],
        name="augmentation",
    )
    backbone = tf.keras.applications.EfficientNetB0(
        include_top=False,
        weights="imagenet",
        input_shape=(IMAGE_SIZE, IMAGE_SIZE, 3),
    )
    backbone.trainable = False

    inputs = tf.keras.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, 3), name="image")
    x = augmentation(inputs)
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.25, seed=SEED)(x)
    outputs = tf.keras.layers.Dense(class_count, activation="softmax", name="probabilities")(x)
    model = tf.keras.Model(inputs, outputs, name="flaura_oxford102")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=[tf.keras.metrics.SparseCategoricalAccuracy(name="accuracy")],
    )
    return model


def export_tflite(model: tf.keras.Model, output_dir: Path) -> Path:
    # Training augmentation must not be part of the deployed graph. Random
    # image ops are unnecessary at inference time and are not available in
    # every mobile TensorFlow Lite runtime (notably iOS).
    backbone = model.get_layer("efficientnetb0")
    pooling = model.get_layer("global_average_pooling2d")
    dropout = model.get_layer("dropout")
    classifier = model.get_layer("probabilities")
    inference_input = tf.keras.Input(
        shape=(IMAGE_SIZE, IMAGE_SIZE, 3), name="image"
    )
    features = backbone(inference_input, training=False)
    features = pooling(features)
    features = dropout(features, training=False)
    inference_model = tf.keras.Model(inference_input, classifier(features))

    # Export through the legacy converter so the operator versions remain
    # compatible with the TensorFlow Lite 2.12 runtime shipped by iOS pods.
    concrete = tf.function(inference_model).get_concrete_function(
        tf.TensorSpec([1, IMAGE_SIZE, IMAGE_SIZE, 3], tf.float32, name="image")
    )
    converter = tf.lite.TFLiteConverter.from_concrete_functions(
        [concrete], inference_model
    )
    converter.experimental_new_converter = False
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    model_path = output_dir / "flaura_flowers102.tflite"
    model_path.write_bytes(converter.convert())
    return model_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts/oxford102"))
    args = parser.parse_args()
    if args.epochs < 1 or args.batch_size < 1:
        parser.error("--epochs and --batch-size must be positive")

    tf.keras.utils.set_random_seed(SEED)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    datasets, info = tfds.load(
        "oxford_flowers102",
        split=["train", "validation", "test"],
        as_supervised=False,
        with_info=True,
        data_dir="data/tfds",
    )
    train_raw, validation_raw, test_raw = datasets
    labels = info.features["label"].names

    def dataset_for(raw: tf.data.Dataset, training: bool = False) -> tf.data.Dataset:
        prepared = raw.map(prepare, num_parallel_calls=AUTOTUNE)
        if training:
            prepared = prepared.shuffle(1_020, seed=SEED, reshuffle_each_iteration=True)
        return prepared.batch(args.batch_size).prefetch(AUTOTUNE)

    train_data = dataset_for(train_raw, training=True)
    validation_data = dataset_for(validation_raw)
    test_data = dataset_for(test_raw)

    model = build_model(len(labels))
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=3, restore_best_weights=True
        ),
        tf.keras.callbacks.ModelCheckpoint(
            args.output_dir / "best.keras", monitor="val_accuracy", save_best_only=True
        ),
    ]
    model.fit(train_data, validation_data=validation_data, epochs=args.epochs, callbacks=callbacks)
    _, accuracy = model.evaluate(test_data, verbose=2)
    model_path = export_tflite(model, args.output_dir)
    (args.output_dir / "labels.json").write_text(json.dumps(labels, indent=2) + "\n")
    (args.output_dir / "metrics.json").write_text(
        json.dumps({"test_accuracy": float(accuracy), "class_count": len(labels)}, indent=2) + "\n"
    )
    print(f"Exported {model_path} with {len(labels)} labels; test accuracy: {accuracy:.2%}")


if __name__ == "__main__":
    main()
