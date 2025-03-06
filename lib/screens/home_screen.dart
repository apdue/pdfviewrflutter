import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pdf_file_info.dart';
import '../models/sort_option.dart';
import '../providers/theme_provider.dart';
import '../widgets/pdf_grid_item.dart';
import '../widgets/pdf_list_item.dart';
import '../widgets/pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  DateTime? _lastBackPressed;
  
  List<PdfFileInfo> _pdfFiles = [];
  List<PdfFileInfo> _filteredFiles = [];
  List<PdfFileInfo> _selectedFiles = [];
  bool _isLoading = true;
  bool _isGridView = true;
  bool _isSelectionMode = false;
  SortOption _currentSortOption = SortOption.nameAsc;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdfFiles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPdfFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final directory = Directory('/storage/emulated/0');
      final List<PdfFileInfo> files = [];

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          try {
            final pdfInfo = await PdfFileInfo.fromFile(entity);
            files.add(pdfInfo);
          } catch (e) {
            print('Error loading PDF file ${entity.path}: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _pdfFiles = files;
          _applySearchAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading PDF files: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applySearchAndSort() {
    final searchQuery = _searchController.text.toLowerCase();
    var filtered = _pdfFiles;

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((file) {
        return file.fileName.toLowerCase().contains(searchQuery);
      }).toList();
    }

    switch (_currentSortOption) {
      case SortOption.nameAsc:
        filtered.sort((a, b) => a.fileName.compareTo(b.fileName));
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) => b.fileName.compareTo(a.fileName));
        break;
      case SortOption.dateAsc:
        filtered.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case SortOption.dateDesc:
        filtered.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case SortOption.sizeAsc:
        filtered.sort((a, b) => a.size.compareTo(b.size));
        break;
      case SortOption.sizeDesc:
        filtered.sort((a, b) => b.size.compareTo(a.size));
        break;
    }

    setState(() {
      _filteredFiles = filtered;
    });
  }

  void _toggleFileSelection(PdfFileInfo file) {
    setState(() {
      if (_selectedFiles.contains(file)) {
        _selectedFiles.remove(file);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(file);
      }
    });
  }

  Future<void> _openPdfViewer(PdfFileInfo pdfInfo) async {
    if (!await pdfInfo.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF file not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(file: pdfInfo.file),
      ),
      (route) => false,
    );
  }

  Future<void> _deleteSelectedFiles() async {
    final count = _selectedFiles.length;
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Are you sure you want to delete $count selected file(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      for (final file in _selectedFiles) {
        await file.delete();
      }

      setState(() {
        _pdfFiles.removeWhere((file) => _selectedFiles.contains(file));
        _selectedFiles.clear();
        _isSelectionMode = false;
        _applySearchAndSort();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count file(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _shareSelectedFiles() async {
    for (final file in _selectedFiles) {
      await file.share();
    }

    setState(() {
      _selectedFiles.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedFiles.clear();
          });
          return;
        }

        // Show exit dialog
        if (mounted) {
          final bool exitConfirmed = await _showExitDialog();
          if (exitConfirmed && mounted) {
            // Use SystemNavigator.pop() to exit the app
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSelectionMode
              ? Text('${_selectedFiles.length} selected')
              : const Text('My PDF Files'),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _selectedFiles.isNotEmpty ? _shareSelectedFiles : null,
                tooltip: 'Share selected files',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _selectedFiles.isNotEmpty ? _deleteSelectedFiles : null,
                tooltip: 'Delete selected files',
              ),
            ] else ...[
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
                tooltip: _isGridView ? 'Switch to list view' : 'Switch to grid view',
              ),
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort files',
                onSelected: (option) {
                  setState(() {
                    _currentSortOption = option;
                    _applySearchAndSort();
                  });
                },
                itemBuilder: (context) => SortOption.values.map((option) {
                  return PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          size: 20,
                          color: _currentSortOption == option
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option.displayName,
                          style: TextStyle(
                            color: _currentSortOption == option
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            fontWeight: _currentSortOption == option
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              IconButton(
                icon: Icon(
                  Provider.of<ThemeProvider>(context).isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () {
                  Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                },
                tooltip: 'Toggle theme',
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search PDF files...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applySearchAndSort();
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => _applySearchAndSort(),
              ),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton(
                onPressed: _loadPdfFiles,
                tooltip: 'Refresh',
                child: const Icon(Icons.refresh),
              ),
      ),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPdfFiles,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No PDF files found'
                  : 'No PDF files match your search',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _applySearchAndSort();
                  _searchFocusNode.unfocus();
                },
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      );
    }

    return _isGridView
        ? GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: _filteredFiles.length,
            itemBuilder: (context, index) {
              final file = _filteredFiles[index];
              return PdfGridItem(
                pdfInfo: file,
                onTap: _isSelectionMode
                    ? () => _toggleFileSelection(file)
                    : () => _openPdfViewer(file),
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _toggleFileSelection(file);
                  });
                },
                isSelected: _selectedFiles.contains(file),
                isSelectionMode: _isSelectionMode,
              );
            },
          )
        : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: _filteredFiles.length,
            itemBuilder: (context, index) {
              final file = _filteredFiles[index];
              return PdfListItem(
                pdfInfo: file,
                onTap: _isSelectionMode
                    ? () => _toggleFileSelection(file)
                    : () => _openPdfViewer(file),
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _toggleFileSelection(file);
                  });
                },
                isSelected: _selectedFiles.contains(file),
                isSelectionMode: _isSelectionMode,
              );
            },
          );
  }

  Future<bool> _showExitDialog() async {
    try {
      final bool? shouldExit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildExitDialog(context),
      );
      
      return shouldExit == true;
    } catch (e) {
      print('Error showing exit dialog: $e');
      return false;
    }
  }

  Widget _buildExitDialog(BuildContext context) {
    final TextEditingController confirmController = TextEditingController();
    
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          title: Column(
            children: [
              Icon(
                Icons.exit_to_app,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure?',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Type "YES" to confirm exit',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'YES',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setDialogState(() {
                    // Trigger rebuild on text change
                  });
                },
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('STAY'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmController.text.toUpperCase() == 'YES' 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.error.withOpacity(0.3),
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: confirmController.text.toUpperCase() == 'YES' 
                ? () => Navigator.of(context).pop(true) 
                : null,
              child: const Text('EXIT'),
            ),
          ],
        );
      },
    );
  }
} 