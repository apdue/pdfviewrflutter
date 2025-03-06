import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/pdf_file_info.dart';

class PdfViewerScreen extends StatefulWidget {
  final PdfFileInfo pdfInfo;

  const PdfViewerScreen({
    Key? key,
    required this.pdfInfo,
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfController _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      _pdfController = await PdfController(
        document: PdfDocument.openFile(widget.pdfInfo.filePath),
      );
      
      final document = await PdfDocument.openFile(widget.pdfInfo.filePath);
      _totalPages = await document.pagesCount;
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfInfo.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => widget.pdfInfo.share(),
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return PdfView(
      controller: _pdfController,
      onPageChanged: (page) {
        if (mounted) {
          setState(() {
            _currentPage = page;
          });
        }
      },
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (_, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_isLoading || _errorMessage != null) {
      return const SizedBox.shrink();
    }

    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.navigate_before),
              onPressed: _currentPage > 1
                  ? () => _pdfController.previousPage(
                        curve: Curves.easeInOut,
                        duration: const Duration(milliseconds: 200),
                      )
                  : null,
              tooltip: 'Previous page',
            ),
            Text(
              'Page $_currentPage of $_totalPages',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next),
              onPressed: _currentPage < _totalPages
                  ? () => _pdfController.nextPage(
                        curve: Curves.easeInOut,
                        duration: const Duration(milliseconds: 200),
                      )
                  : null,
              tooltip: 'Next page',
            ),
          ],
        ),
      ),
    );
  }
} 