import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class PdfFileInfo {
  final File file;
  final String fileName;
  final DateTime lastModified;
  final int size;
  final String filePath;
  String? _cachedText;
  DateTime? _cacheTimestamp;
  PdfPageImage? _cachedThumbnail;
  bool _isGeneratingThumbnail = false;

  PdfFileInfo({
    required this.file,
    required this.fileName,
    required this.lastModified,
    required this.size,
    required this.filePath,
  });

  static Future<PdfFileInfo> fromFile(File file) async {
    final stats = await file.stat();
    return PdfFileInfo(
      file: file,
      fileName: path.basename(file.path),
      lastModified: stats.modified,
      size: stats.size,
      filePath: file.path,
    );
  }

  String get formattedSize {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = this.size.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(lastModified);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return DateFormat('MMM d, y').format(lastModified);
  }

  Future<bool> exists() async {
    return await file.exists();
  }

  Future<void> delete() async {
    await file.delete();
  }

  Future<void> share() async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  Future<PdfPageImage?> getThumbnail({
    double width = 300,
    double height = 400,
  }) async {
    try {
      // Return cached thumbnail if available
      if (_cachedThumbnail != null) {
        print('Returning cached thumbnail for $fileName');
        return _cachedThumbnail;
      }

      // If already generating a thumbnail, wait for it to complete
      while (_isGeneratingThumbnail) {
        print('Waiting for existing thumbnail generation for $fileName');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _isGeneratingThumbnail = true;
      print('Generating thumbnail for $fileName');
      
      // Check if file exists and is readable
      if (!await exists()) {
        print('File does not exist: $filePath');
        _isGeneratingThumbnail = false;
        return null;
      }

      PdfDocument? document;
      PdfPage? page;

      try {
        // Try to open the PDF document
        document = await PdfDocument.openFile(filePath);
        if (document == null) {
          print('Failed to open PDF document: $filePath');
          return null;
        }

        // Get the first page
        page = await document.getPage(1);
        if (page == null) {
          print('Failed to get first page of PDF: $filePath');
          return null;
        }

        // Try to render the page
        final pageImage = await page.render(
          width: width,
          height: height,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 90,
        );

        if (pageImage == null) {
          print('Failed to render page image: $filePath');
          return null;
        }

        // Cache the successful thumbnail
        _cachedThumbnail = pageImage;
        print('Successfully generated thumbnail for $fileName');
        return pageImage;

      } finally {
        // Clean up resources
        if (page != null) {
          await page.close();
        }
        if (document != null) {
          await document.close();
        }
        _isGeneratingThumbnail = false;
      }

    } catch (e, stackTrace) {
      print('Error generating thumbnail for $fileName:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      _isGeneratingThumbnail = false;
      return null;
    }
  }

  Future<String> extractText() async {
    if (_cachedText != null && _cacheTimestamp != null) {
      final fileStats = await file.stat();
      if (fileStats.modified.isAtSameMomentAs(_cacheTimestamp!)) {
        return _cachedText!;
      }
    }

    try {
      final document = syncfusion.PdfDocument(inputBytes: await file.readAsBytes());
      final extractor = syncfusion.PdfTextExtractor(document);
      final extractedText = extractor.extractText();
      document.dispose();

      _cachedText = extractedText;
      _cacheTimestamp = (await file.stat()).modified;

      return extractedText;
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    }
  }
} 