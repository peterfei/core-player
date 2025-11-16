# CorePlayer (影核播放器)

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.38.1-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%7CAndroid%7CWeb%7CWindows%7CmacOS%7CLinux-orange.svg)](#features)

**CorePlayer** - The New Core of Video Playback

*Core-Driven, Boundless Vision*

English | [中文](./README.md)

</div>

## 🎯 Brand Philosophy

**CorePlayer** - The "core engine" of video playback, just like a computer's CPU, providing powerful performance for every playback.

- **Core**: Core, engine, our technical strength
- **Player**: Playback, performance, our functional focus

We are committed to creating the most core, most powerful, and smoothest video playback experience, allowing every frame to be perfectly presented.

## ✨ Core Advantages

### 🚀 MVP Core Features (Implemented)
- ✅ **Cross-platform Support** - Supports iOS, Android, Web, Windows, macOS, Linux
- ✅ **Smart File Selection** - Automatically adapts to Web and desktop platforms
- ✅ **Complete Playback Control** - Play/pause, progress adjustment, volume control
- ✅ **Fullscreen Mode** - Immersive viewing experience
- ✅ **Responsive UI** - Modern Material Design interface
- ✅ **Auto-hide Controls** - Automatically hides after 3 seconds for focused viewing

### ⚡ Technical Features
- 🔄 **Seamless Playback** - Supports multiple video formats
- ⏯️ **Playback Control** - Play/pause, fast forward/rewind
- 📊 **Progress Display** - Real-time display of playback progress and remaining time
- 🔊 **Volume Control** - One-click mute/unmute
- 📱 **Fullscreen Toggle** - Supports landscape/portrait switching

## 🚀 Quick Start

### Requirements
```
Flutter 3.38.1 or higher
Dart 3.10.0 or higher
```

### Install Dependencies
```bash
flutter pub get
```

### Run Application
```bash
# Run on Chrome browser
flutter run -d chrome

# Run on specific platform
flutter run -d android    # Android device
flutter run -d ios       # iOS device
flutter run -d macos     # macOS desktop
flutter run -d windows   # Windows desktop
flutter run -d linux     # Linux desktop
```

### Build Release Version
```bash
# Web version
flutter build web

# Desktop versions
flutter build windows
flutter build macos
flutter build linux

# Mobile versions
flutter build apk
flutter build ios
```

## 🏗️ Project Architecture

```
lib/
├── main.dart                 # Application entry
└── screens/
    ├── home_screen.dart      # Main interface
    ├── player_screen.dart    # Player interface
    └── settings_screen.dart  # Settings interface
```

### Tech Stack
- **Framework**: Flutter 3.38.1
- **Video Engine**: media_kit + media_kit_video
- **File Picker**: file_picker
- **State Management**: StatefulWidget
- **UI Framework**: Material Design 3

## 🎯 Usage Instructions

### Basic Operations
1. **Add Video**: Click the `+` button in the bottom right of main interface
2. **Playback Control**: Click the large play/pause button in the center of player
3. **Progress Adjustment**: Drag the progress bar at the bottom
4. **Volume Control**: Click the volume icon in the top right
5. **Fullscreen Playback**: Click the fullscreen icon in the top right
6. **Show Controls**: Click anywhere on screen to show/hide control interface

### Advanced Features
- **Auto-hide**: Control interface automatically hides after 3 seconds
- **Gesture Operation**: Supports tap to toggle control interface visibility
- **Cross-platform**: Automatically adapts file selection methods for different platforms

## 🛣️ Product Roadmap

### Near-term Goals (V1.1) - Core Optimization
- [ ] Playback history
- [ ] Video thumbnail display
- [ ] Playlist management
- [ ] Dark/light theme switching

### Medium-term Goals (V1.2) - Feature Enhancement
- [ ] Subtitle support (SRT, ASS formats)
- [ ] Playback speed adjustment (0.5x - 2.0x)
- [ ] Aspect ratio adjustment (16:9, 4:3, adaptive)
- [ ] Screenshot function

### Long-term Vision (V2.0) - Ecosystem Building
- [ ] Online streaming playback
- [ ] Network video download
- [ ] AI intelligent recommendations
- [ ] Video transcoding function
- [ ] Cloud synchronization

## 🤝 Contributing Guidelines

We welcome all developers to contribute! Whether it's bug fixes, feature suggestions, or code optimization, we are very grateful.

### How to Contribute
1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Standards
- Follow Flutter official code standards
- Keep code clean and readable
- Add necessary comments
- Ensure cross-platform compatibility

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Excellent cross-platform development framework
- [media_kit](https://github.com/media-kit/media-kit) - Powerful video playback engine
- [file_picker](https://github.com/miguelpruivo/flutter_file_picker) - Convenient file selection plugin

## 📞 Contact Us

If you have any questions, suggestions, or cooperation intentions, please contact us through:

- 📧 Email: [your-email@example.com]
- 💬 WeChat: [your-wechat-id]
- 🐛 Issue: [Project Issues page](issues)

---

<div align="center">

**CorePlayer** - The New Core of Video Playback

*Make every playback a core experience*

</div>