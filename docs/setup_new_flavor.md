## To Setup New Flavor:
### 1. Update build.gradle in /android/app/

```gradle
    productFlavors {
        flavor {
            dimension "sambath", "flavor"
            applicationId "com.harmony.app" // or you can add '.sambath' to the end of 'com.harmony.app'
        }
    }
```

### 2. Add assets directory in pubspec.yaml
If you have assets that are only used in a specific flavor, this flow allow us to configure them to only be bundled into our app when building for that flavor (a specific flavor). This prevents app bundle size from being bloated by unused assets.
```yaml
flutter:
  assets:
    - assets/common/
    - path: assets/sambath/staging
      flavors:
        - sambathStg # make sure that you run app with 'sambathstg' flavor not 'sambathStg'
    - path: assets/sambath/prod/
      flavors:
        - sambathProd
```

## Refferences:
- [Conditionally bundling assets based on flavor](https://docs.flutter.dev/deployment/flavors#conditionally-bundling-assets-based-on-flavor)
