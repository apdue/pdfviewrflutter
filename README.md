# MyPDF - Flutter PDF Management App

A modern Flutter application for managing PDF files with features like:

- PDF file scanning and viewing
- Text extraction with caching for improved performance
- Thumbnail generation and caching
- File sorting by name, date, and size
- Dark/Light theme toggle
- File operations (share, delete)
- Modern UI with smooth transitions and error handling

## Features

- **PDF Management**: View, sort, and organize PDF files
- **Smart Caching**: Cached text extraction and thumbnails for better performance
- **Modern UI**: Beautiful interface with smooth transitions and loading states
- **Theme Support**: Toggle between light and dark themes
- **File Operations**: Share and delete PDFs easily
- **Error Handling**: Robust error handling with retry mechanisms

## Getting Started

1. **Prerequisites**:
   - Flutter SDK
   - Android Studio / VS Code
   - Android SDK / Xcode (for iOS)

2. **Installation**:
   ```bash
   # Clone the repository
   git clone [repository-url]
   
   # Navigate to project directory
   cd mypdf
   
   # Install dependencies
   flutter pub get
   
   # Run the app
   flutter run
   ```

## Project Structure

```
lib/
├── models/
│   ├── pdf_file_info.dart
│   └── sort_option.dart
├── providers/
│   └── theme_provider.dart
├── screens/
├── widgets/
│   └── pdf_grid_item.dart
├── utils/
├── services/
└── main.dart
```

## Dependencies

- `pdfx`: PDF rendering and thumbnail generation
- `provider`: State management
- `path_provider`: File system access
- `share_plus`: File sharing functionality

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.
