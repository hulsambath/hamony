### Flutter Launcher Icons

## Add flutter launcher icons for new flavor [![flutter_launcher_icons](https://img.shields.io/badge/Flutter%20Community-flutter__launcher__icons-blue)](https://pub.dev/packages/flutter_launcher_icons)
* Create a new `flutter_launcher_icons-flavor.yaml` file in project level
* In `flutter_launcher_icons-flavor.yaml`:

```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/dimension/flavor/dimension_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/dimension/flavor/dimension_icon.png"
  min_sdk_android: 21

  flavors:
    sambathStg:
      image_path: "assets/dimension/flavor/dimension_icon.png"
      android: true
      ios: true
      web:
        generate: true
        image_path: "assets/dimension/flavor/dimension_icon.png"
        background_color: "#FFFFFF"
        theme_color: "#FFFFFF"  # custom the flavor color
      windows:
        generate: true
        image_path: "assets/sambath/staging/harmony_icon.png"
      macos:
        generate: true
        image_path: "assets/sambath/staging/harmony_icon.png"
```
* After create `flutter_launcher_icons-flavor.yaml`, run the command:
```bash
dart run flutter_launcher_icons -f flavor
```
