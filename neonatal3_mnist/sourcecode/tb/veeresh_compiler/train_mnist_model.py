import os

os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("TF_ENABLE_ONEDNN_OPTS", "0")

import numpy as np
import tensorflow as tf
import tf_keras

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EPOCHS = int(os.environ.get("MNIST_EPOCHS", "8"))
TRAIN_LIMIT = int(os.environ.get("MNIST_TRAIN_LIMIT", "60000"))
MODEL_OUT = os.environ.get("MNIST_MODEL_OUT", os.path.join(SCRIPT_DIR, "mnist_model"))

try:
    from tf_keras.datasets import mnist
except Exception:
    from tensorflow.keras.datasets import mnist


def main():
    (x_train, y_train), (x_test, y_test) = mnist.load_data()
    x_train = x_train.astype(np.float32) / 255.0
    x_test = x_test.astype(np.float32) / 255.0

    if TRAIN_LIMIT > 0:
        x_train = x_train[:TRAIN_LIMIT]
        y_train = y_train[:TRAIN_LIMIT]

    model = tf_keras.Sequential([
        tf_keras.layers.Input(shape=(28, 28), name="mnist_input"),
        tf_keras.layers.Conv1D(8, 3, padding="same", activation="relu", name="conv1"),
        tf_keras.layers.MaxPooling1D(2, name="pool1"),
        tf_keras.layers.Conv1D(16, 3, padding="same", activation="relu", name="conv2"),
        tf_keras.layers.MaxPooling1D(2, name="pool2"),
        tf_keras.layers.Flatten(name="flatten"),
        tf_keras.layers.Dense(32, activation="relu", name="dense1"),
        tf_keras.layers.Dense(10, activation=None, name="dense_logits"),
    ])

    model.compile(
        optimizer=tf_keras.optimizers.Adam(1e-3),
        loss=tf_keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=[tf_keras.metrics.SparseCategoricalAccuracy(name="sparse_acc")],
    )

    callbacks = [
        tf_keras.callbacks.EarlyStopping(
            monitor="val_sparse_acc",
            patience=2,
            restore_best_weights=True,
            mode="max",
        )
    ]

    model.summary()
    model.fit(
        x_train,
        y_train,
        epochs=EPOCHS,
        batch_size=128,
        validation_split=0.1,
        callbacks=callbacks,
        verbose=2,
    )
    loss, acc = model.evaluate(x_test, y_test, verbose=0)
    print(f"[MNIST_TRAIN] test_loss={loss:.4f} test_sparse_acc={acc:.4f}")

    model.save(MODEL_OUT)
    print(f"[MNIST_TRAIN] saved model to {MODEL_OUT}")


if __name__ == "__main__":
    main()
