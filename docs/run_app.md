## To run app

- staging

```bash
fvm flutter run --flavor $flavorStg -t lib/$main_file.dart --dart-define-from-file=configs/sambathStg.json
```

- development

```bash
fvm flutter run --flavor $flavorDev -t lib/$main_file.dart --dart-define-from-file=configs/sambathStg.json
```

- production

```bash
fvm flutter run --flavor $flavorProd -t lib/$main_file.dart --dart-define-from-file=configs/sambathStg.json
```
