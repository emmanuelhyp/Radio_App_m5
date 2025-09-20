
# Radio M5 93.5 FM - Flutter App (Pro Starter)

Cette version ajoute:
- Lecture en arrière-plan + notifications via `just_audio_background` + `audio_service`.
- Affichage du titre (si le flux fournit des métadonnées).
- Écran de paramètres simple.
- Bouton de partage.

## Installer
1. Installer Flutter: https://flutter.dev/docs/get-started/install
2. Ouvrir le projet dans VSCode/Android Studio

## Dépendances
`pubspec.yaml` contient: just_audio, audio_service, just_audio_background, share_plus, provider.

## Android
- Pour que les notifications fonctionnent correctement, assure-toi que `minSdkVersion >= 21` dans `android/app/build.gradle`.
- Le manifeste Android a besoin des permissions internet (déjà incluse par Flutter).

## Lancer en debug
```
flutter pub get
flutter run
```

## Construire APK
```
flutter build apk --release
```

## Construire IPA (iOS)
Suivre la doc Flutter pour iOS: https://flutter.dev/docs/deployment/ios
Tu auras besoin d'un Mac et d'un compte développeur pour publier sur l'App Store.
