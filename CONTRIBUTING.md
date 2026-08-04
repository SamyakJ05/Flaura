# Contributing to Flaura

Thanks for improving Flaura. Keep changes small, testable, and easy to review.

## Development workflow

1. Create a branch from `main`.
2. Make one focused change.
3. Run the checks below.
4. Open a pull request with a concise description and test evidence.

```bash
cd mobile_app
flutter analyze
flutter test
```

## Model changes

The model and `labels.json` are a matched pair. When updating either one,
replace both files in `mobile_app/assets/models/`, record the evaluation result,
and state the source dataset and training configuration in the pull request.

## Security and privacy

Do not commit signing keys, provisioning profiles, `key.properties`, API keys,
or user images. Keep camera and photo permissions limited to their stated use.
