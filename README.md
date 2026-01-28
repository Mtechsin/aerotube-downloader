# ✈️ AeroTube

> **A thoughtful, modern, and frustration-free YouTube Downloader for Windows.**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

## 📖 About

I built **AeroTube** because I was tired of the existing YouTube downloaders for Windows. They were either clunky, filled with ads, or just didn't feel right. I wanted a tool that was:

*   **Clean & Modern:** A UI that doesn't look like it's from 2005.
*   **Thoughtful:** Designed with the user in mind, prioritizing ease of use without sacrificing power.
*   **Reliable:** It just works.

This project is my personal take on what a downloader *should* be. It's built with Flutter and uses `yt-dlp` under the hood for robust download capabilities.

## ✨ Features

*   **Format Selection:** Choose between Video+Audio, Audio Only, or muted Video.
*   **Playlist Support:** Download entire playlists with ease.
*   **Modern UI:** Sleek, glass-morphism inspired interface.
*   **Settings:** Customizable download paths and theme options.
*   **Windows Optimized:** Native feel and performance on Windows.

## 🛠️ Building from Source

Want to build your own version or contribute? Here's how you can get started.

### Prerequisites

1.  **Flutter SDK:** [Install Flutter](https://docs.flutter.dev/get-started/install/windows)
2.  **Visual Studio:** Required for compiling the Windows runner (ensure "Desktop development with C++" is selected).
3.  **Git:** To clone the repository.

### Installation Steps

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/YOUR_USERNAME/aerotube.git
    cd aerotube
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the App (Debug Mode)**
    ```bash
    flutter run -d windows
    ```

4.  **Build Release Version**
    To create a standalone `.exe`:
    ```bash
    flutter build windows
    ```
    The output will be in `build/windows/runner/Release/`.

## 🤝 Contributing

Contributions are welcome! If you have ideas for features or want to fix a bug:

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---
*Built with ❤️ by [Your Name]*