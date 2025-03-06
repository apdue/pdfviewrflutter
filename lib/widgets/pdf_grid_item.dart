import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import '../models/pdf_file_info.dart';

class PdfGridItem extends StatefulWidget {
  final PdfFileInfo pdfInfo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const PdfGridItem({
    Key? key,
    required this.pdfInfo,
    required this.onTap,
    this.onDelete,
    this.onLongPress,
    required this.isSelected,
    required this.isSelectionMode,
  }) : super(key: key);

  @override
  State<PdfGridItem> createState() => _PdfGridItemState();
}

class _PdfGridItemState extends State<PdfGridItem> with AutomaticKeepAliveClientMixin {
  PdfPageImage? _thumbnail;
  bool _isLoading = false;
  bool _isVisible = false;
  bool _thumbnailRequested = false;
  bool _hasError = false;
  bool _thumbnailLoaded = false;
  int _retryCount = 0;
  static const int maxRetries = 2;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isVisible = true;
    _loadThumbnail();
  }

  @override
  void dispose() {
    _isVisible = false;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    if (!mounted || !_isVisible || _thumbnailRequested) return;
    
    _thumbnailRequested = true;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _thumbnailLoaded = false;
      _thumbnail = null;
    });

    try {
      print('Loading thumbnail for ${widget.pdfInfo.fileName}');
      final thumbnail = await widget.pdfInfo.getThumbnail(
        width: 300,
        height: 400,
      );
      
      if (!mounted || !_isVisible) return;

      setState(() {
        _thumbnail = thumbnail;
        _isLoading = false;
        _hasError = thumbnail == null;
        _thumbnailLoaded = thumbnail != null;
      });

      // If thumbnail failed to load and we haven't exceeded max retries, try again
      if (_hasError && _retryCount < maxRetries) {
        print('Retrying thumbnail generation for ${widget.pdfInfo.fileName} (Attempt ${_retryCount + 1})');
        _retryCount++;
        _thumbnailRequested = false;
        await Future.delayed(Duration(seconds: _retryCount * 2));
        _loadThumbnail();
      }
    } catch (e) {
      print('Error loading thumbnail for ${widget.pdfInfo.fileName}: $e');
      if (!mounted || !_isVisible) return;
      
      setState(() {
        _thumbnail = null;
        _isLoading = false;
        _hasError = true;
        _thumbnailLoaded = false;
      });

      // Retry on error if we haven't exceeded max retries
      if (_retryCount < maxRetries) {
        print('Retrying thumbnail generation after error (Attempt ${_retryCount + 1})');
        _retryCount++;
        _thumbnailRequested = false;
        await Future.delayed(Duration(seconds: _retryCount * 2));
        _loadThumbnail();
      }
    }
  }

  Widget _buildContentLayer(ColorScheme colorScheme) {
    // Show loading indicator
    if (_isLoading) {
      return Container(
        color: Colors.black.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              if (_retryCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Retry ${_retryCount}/${maxRetries}',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Show thumbnail if available
    if (_thumbnailLoaded && _thumbnail != null) {
      return Hero(
        tag: 'pdf_${widget.pdfInfo.filePath}',
        child: FadeInImage(
          placeholder: MemoryImage(Uint8List(0)),
          image: MemoryImage(_thumbnail!.bytes),
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 300),
          imageErrorBuilder: (context, error, stackTrace) {
            print('Error displaying thumbnail: $error');
            // Schedule a rebuild to show the placeholder
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _thumbnailLoaded = false;
                  _thumbnail = null;
                });
              }
            });
            return const SizedBox.shrink();
          },
        ),
      );
    }

    // Show placeholder icon
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 48,
            color: colorScheme.primary.withOpacity(0.7),
          ),
          if (_hasError && !_isLoading) ...[
            const SizedBox(height: 8),
            Text(
              _retryCount >= maxRetries
                  ? 'Preview not available'
                  : 'Retrying preview...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _retryCount >= maxRetries
                    ? colorScheme.error
                    : colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base background with gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.surfaceVariant.withOpacity(0.2),
                          colorScheme.surfaceVariant.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  
                  // Content layer with AnimatedSwitcher for smooth transitions
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<String>('${_thumbnailLoaded}_${_isLoading}_${_hasError}'),
                      child: _buildContentLayer(colorScheme),
                    ),
                  ),
                  
                  // Selection overlay
                  if (widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        color: colorScheme.primary.withOpacity(0.3),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            size: 48,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.pdfInfo.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.data_usage,
                            size: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.pdfInfo.formattedSize,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.pdfInfo.formattedDate,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 