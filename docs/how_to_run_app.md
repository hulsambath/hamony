## To run app

- staging

```bash
fvm flutter run --enable-experiment=macros --flavor $flavorStg -t lib/$main_file.dart
```

- development

```bash
fvm flutter run --enable-experiment=macros --flavor $flavorDev -t lib/$main_file.dart
```

- production

```bash
fvm flutter run --enable-experiment=macros --flavor $flavorProd -t lib/$main_file.dart
```
