import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

// Define sort options enum
enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
}

// Extension to get display name for sort options
extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      case SortOption.dateAsc:
        return 'Date (Oldest first)';
      case SortOption.dateDesc:
        return 'Date (Newest first)';
      case SortOption.sizeAsc:
        return 'Size (Smallest first)';
      case SortOption.sizeDesc:
        return 'Size (Largest first)';
    }
  }
  
  IconData get icon {
    switch (this) {
      case SortOption.nameAsc:
        return Icons.sort_by_alpha;
      case SortOption.nameDesc:
        return Icons.sort_by_alpha;
      case SortOption.dateAsc:
        return Icons.access_time;
      case SortOption.dateDesc:
        return Icons.access_time;
      case SortOption.sizeAsc:
        return Icons.data_usage;
      case SortOption.sizeDesc:
        return Icons.data_usage;
    }
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'My PDF',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool isSearching = false;
  bool isLoading = false;
  bool isLoadingMore = false;
  String errorMessage = '';
  List<PdfFileInfo> allPdfFiles = [];
  List<PdfFileInfo> displayedPdfFiles = [];
  bool hasMoreFiles = true;
  int currentPage = 0;
  final int pageSize = 20;
  SortOption currentSortOption = SortOption.dateDesc;
  bool isSelectionMode = false;
  Set<String> selectedFiles = {};
  int androidSdkVersion = 0;
  bool isGridView = true;
  bool _showMultiSelectHint = true;
  bool _isFromGoogleAds = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
    _initializeApp();
    _checkInstallReferrer();
  }

  Future<void> _checkInstallReferrer() async {
    await Future.delayed(Duration(milliseconds: 500));
    
    if (!mounted) return;

    try {
      debugPrint('Fetching install referrer details...');
      const platform = MethodChannel('com.example.mypdf.test1/install_referrer');
      final String? referrerUrl = await platform.invokeMethod('getInstallReferrer');
      
      if (!mounted) return;

      debugPrint('Raw referrer details: $referrerUrl');

      // Try to decode the referrer URL if it's encoded
      String? decodedReferrerUrl;
      if (referrerUrl != null) {
        try {
          decodedReferrerUrl = Uri.decodeComponent(referrerUrl);
          debugPrint('Decoded referrer URL: $decodedReferrerUrl');
        } catch (e) {
          debugPrint('Error decoding referrer URL: $e');
          decodedReferrerUrl = referrerUrl;
        }
      }

      // Parse all UTM parameters
      Map<String, String?> utmParams = {};
      if (decodedReferrerUrl != null) {
        final params = decodedReferrerUrl.split('&');
        for (final param in params) {
          final parts = param.split('=');
          if (parts.length == 2) {
            final key = parts[0].trim();
            final value = Uri.decodeComponent(parts[1].trim());
            utmParams[key] = value;
            debugPrint('Parsed parameter: $key = $value');
          }
        }
      }

      // Extract UTM parameters
      final source = utmParams['utm_source'];
      final medium = utmParams['utm_medium'];
      final campaign = utmParams['utm_campaign'];
      final content = utmParams['utm_content'];
      final term = utmParams['utm_term'];

      debugPrint('Final parsed values:');
      debugPrint('Source: $source');
      debugPrint('Medium: $medium');
      debugPrint('Campaign: $campaign');
      debugPrint('Content: $content');
      debugPrint('Term: $term');

      // Show dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Referral Data Check',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Detection Time: ${_formatDateTime(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Raw Referral Data:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Original Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(decodedReferrerUrl ?? 'No referrer data',
                          style: TextStyle(fontFamily: 'monospace')),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Parsed Parameters:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildParamRow('Source', source),
                      _buildParamRow('Medium', medium),
                      _buildParamRow('Campaign', campaign),
                      _buildParamRow('Content', content),
                      if (term != null) _buildParamRow('Term', term),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Source Analysis:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getReferralSourceColor(source, medium),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Text(
                    _getReferralSourceText(source, medium),
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error checking install referrer: $e');
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Error',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text('Failed to check install referrer: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildParamRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value ?? 'Not set',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getReferralSourceColor(String? source, String? medium) {
    if (source == null || medium == null) return Colors.grey[50]!;
    
    if (source.contains('facebook') && medium.contains('social')) {
      return Colors.indigo[50]!;
    } else if (source.contains('google-adwords') || source.contains('google-ads')) {
      return Colors.blue[50]!;
    } else if (source == 'google-play' && medium == 'organic') {
      return Colors.green[50]!;
    }
    return Colors.grey[50]!;
  }

  String _getReferralSourceText(String? source, String? medium) {
    if (source == null || medium == null) return 'No referral data available';
    
    if (source.contains('facebook') && medium.contains('social')) {
      return 'User came from Facebook Ads campaign';
    } else if (source.contains('google-adwords') || source.contains('google-ads')) {
      return 'User came from Google Ads campaign';
    } else if (source == 'google-play' && medium == 'organic') {
      return 'Organic install from Google Play Store';
    }
    return 'Referral from: $source (medium: $medium)';
  }

  String? _getUtmParameter(String? url, String paramName) {
    if (url == null) return null;
    try {
      // First try to decode the URL if it's encoded
      String decodedUrl = url;
      try {
        decodedUrl = Uri.decodeComponent(url);
      } catch (e) {
        print('Error decoding URL: $e');
      }

      // Split the URL into parameters
      final params = decodedUrl.split('&');
      for (final param in params) {
        final parts = param.split('=');
        if (parts.length == 2 && parts[0].trim() == paramName.trim()) {
          return Uri.decodeComponent(parts[1].trim());
        }
      }
      return null;
    } catch (e) {
      print('Error parsing UTM parameter: $e');
      return null;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _formatDateTime(dateTime);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  // Method to activate search mode and ensure keyboard appears
  void _activateSearch() {
    setState(() {
      isSearching = true;
    });
    
    // Use a slightly longer delay and ensure keyboard is shown
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
        // Explicitly show keyboard
        TextInput.finishAutofillContext();
      }
    });
  }
  
  void _onSearchChanged() {
    _filterPdfFiles(_searchController.text);
  }
  
  void _filterPdfFiles(String query) async {
    if (query.isEmpty) {
      // Reset to pagination mode when search is cleared
    setState(() {
        currentPage = 0;
        _sortPdfFiles(); // Apply current sort before displaying
        final endIndex = pageSize < allPdfFiles.length ? pageSize : allPdfFiles.length;
        displayedPdfFiles = allPdfFiles.sublist(0, endIndex);
        hasMoreFiles = endIndex < allPdfFiles.length;
        isSearching = false;
      });
    } else {
      // Filter files based on search query
      List<PdfFileInfo> filteredFiles = allPdfFiles.where((file) {
        return file.fileName.toLowerCase().contains(query.toLowerCase()) ||
               file.file.path.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      // Apply current sort to filtered files
      _applySortToList(filteredFiles);
      
      setState(() {
        displayedPdfFiles = filteredFiles;
        hasMoreFiles = false;
      });
    }
  }
  
  // Apply sort to a list of PDF files
  void _applySortToList(List<PdfFileInfo> files) {
    try {
      switch (currentSortOption) {
        case SortOption.nameAsc:
          files.sort((a, b) => a.fileName.compareTo(b.fileName));
          break;
        case SortOption.nameDesc:
          files.sort((a, b) => b.fileName.compareTo(a.fileName));
          break;
        case SortOption.dateAsc:
          files.sort((a, b) {
            // Use the cached lastModified value instead of calling lastModifiedSync()
            return a.lastModified.compareTo(b.lastModified);
          });
          break;
        case SortOption.dateDesc:
          files.sort((a, b) {
            // Use the cached lastModified value instead of calling lastModifiedSync()
            return b.lastModified.compareTo(a.lastModified);
          });
          break;
        case SortOption.sizeAsc:
          files.sort((a, b) {
            // Use the cached fileSize value instead of calling lengthSync()
            return a.fileSize.compareTo(b.fileSize);
          });
          break;
        case SortOption.sizeDesc:
          files.sort((a, b) {
            // Use the cached fileSize value instead of calling lengthSync()
            return b.fileSize.compareTo(a.fileSize);
          });
          break;
      }
    } catch (e) {
      print('Error sorting files: $e');
    }
  }
  
  // Change the current sort option
  void _changeSortOption(SortOption option) {
    if (currentSortOption != option) {
      setState(() {
        currentSortOption = option;
        isLoading = true; // Show loading indicator while sorting
      });
      
      // Use Future.delayed to allow the loading indicator to show
      Future.delayed(Duration.zero, () async {
        _sortPdfFiles();
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
    }
  }

  // Load metadata for all files before sorting
  Future<void> _ensureMetadataLoaded(List<PdfFileInfo> files) async {
    final futures = <Future>[];
    for (final file in files) {
      futures.add(file._loadMetadataAsync());
    }
    await Future.wait(futures);
  }

  // New method to sort PDF files
  void _sortPdfFiles() {
    // Ensure metadata is loaded before sorting
    _ensureMetadataLoaded(allPdfFiles).then((_) {
      _applySortToList(allPdfFiles);
      
      // If we're displaying files, we need to update them too
      if (!isSearching && displayedPdfFiles.isNotEmpty) {
        if (mounted) {
          setState(() {
            currentPage = 0;
            final endIndex = pageSize < allPdfFiles.length ? pageSize : allPdfFiles.length;
            displayedPdfFiles = allPdfFiles.sublist(0, endIndex);
            hasMoreFiles = endIndex < allPdfFiles.length;
          });
        }
      } else if (isSearching) {
        // Re-apply search filter with new sort
        _filterPdfFiles(_searchController.text);
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore && 
        hasMoreFiles) {
      _loadMoreFiles();
    }
  }
  
  void _loadMoreFiles() {
    if (isLoadingMore || !hasMoreFiles || isSearching) return;
    
    setState(() {
      isLoadingMore = true;
    });
    
    currentPage++;
    final startIndex = currentPage * pageSize;
    
    if (startIndex >= allPdfFiles.length) {
      setState(() {
        hasMoreFiles = false;
        isLoadingMore = false;
      });
      return;
    }
    
    final endIndex = (startIndex + pageSize <= allPdfFiles.length) 
        ? startIndex + pageSize 
        : allPdfFiles.length;
    
    final newFiles = allPdfFiles.sublist(startIndex, endIndex);
    
    setState(() {
      displayedPdfFiles.addAll(newFiles);
      isLoadingMore = false;
      hasMoreFiles = endIndex < allPdfFiles.length;
    });
  }

  Future<void> _initializeApp() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        androidSdkVersion = androidInfo.version.sdkInt;
      }
      _checkPermissionAndLoadFiles();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to initialize app: $e';
      });
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      print('Requesting permissions...');
      if (Platform.isAndroid) {
        print('Android SDK version: $androidSdkVersion');
        if (androidSdkVersion <= 29) {
          // For Android 10 and below
          print('Requesting storage permission for Android 10 and below');
          final status = await Permission.storage.request();
          print('Storage permission status: ${status.isGranted}');
          return status.isGranted;
        } else {
          // For Android 11 and above
          print('Requesting manage external storage permission for Android 11+');
          
          // First check if we already have the permission
          final status = await Permission.manageExternalStorage.status;
          print('Current manage external storage status: ${status.isGranted}');
          
          if (!status.isGranted) {
            // Show a dialog explaining why we need the permission
            if (mounted) {
              final shouldRequest = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Storage Permission Required'),
                  content: const Text(
                    'This app needs storage permission to scan for PDF files on your device. '
                    'Please grant "All Files Access" permission in the next screen.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ) ?? false;
              
              if (!shouldRequest) {
                print('User denied permission request');
                return false;
              }
              
              // Request the permission
              final newStatus = await Permission.manageExternalStorage.request();
              print('New manage external storage status: ${newStatus.isGranted}');
              
              if (!newStatus.isGranted) {
                // If still not granted, open app settings
                if (mounted) {
                  final openSettings = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('Permission Required'),
                      content: const Text(
                        'Please enable "All Files Access" permission in Settings '
                        'to allow the app to scan for PDF files.'
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  ) ?? false;
                  
                  if (openSettings) {
                    print('Opening app settings');
                    await openAppSettings();
                  }
                }
              }
              
              // Check the status one final time
              final finalStatus = await Permission.manageExternalStorage.status;
              print('Final manage external storage status: ${finalStatus.isGranted}');
              return finalStatus.isGranted;
            }
          }
          
          return status.isGranted;
        }
      }
      return true;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _checkPermissionAndLoadFiles() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      currentPage = 0;
      displayedPdfFiles = [];
      allPdfFiles = [];
      hasMoreFiles = true;
    });

    try {
      final hasPermission = await _requestPermissions();
      
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'Storage permission denied';
          });
        }
        return;
      }

      await _loadPdfFiles();
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error checking permissions: $e';
        });
      }
    }
  }

  Future<List<String>> _getCommonPaths() async {
    List<String> paths = [];
    
    try {
      print('Getting common paths for PDF files...');
      
      // Add primary storage paths
      paths.add('/storage/emulated/0/Download');
      paths.add('/storage/emulated/0/Documents');
      paths.add('/storage/emulated/0/DCIM');
      paths.add('/storage/emulated/0');  // Root directory
      paths.add('/storage/emulated/0/Android/data');
      
      // Get app-specific directory
      final appDir = await getApplicationDocumentsDirectory();
      print('App directory: ${appDir.path}');
      paths.add(appDir.path);
      
      // Get external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        print('External directory: ${externalDir.path}');
        final String rootDir = externalDir.path.split('Android')[0];
        print('Root directory: $rootDir');
        paths.add(rootDir);
        paths.add(externalDir.path);
      } else {
        print('External directory is null');
      }
      
      // Get all external storage directories
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        print('Found ${externalDirs.length} external storage directories');
        for (var dir in externalDirs) {
          print('Additional external directory: ${dir.path}');
          paths.add(dir.path);
        }
      } else {
        print('No external storage directories found');
      }
      
      // Print all paths we're going to scan
      print('Will scan the following paths:');
      paths = paths.toSet().toList(); // Remove duplicates
      for (var path in paths) {
        print('- $path');
      }
      
    } catch (e) {
      print('Error getting common paths: $e');
    }
    
    return paths;
  }

  Future<void> _loadPdfFiles() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final List<File> files = [];
      final paths = await _getCommonPaths();
      
      print('Starting to scan directories for PDF files...');
      print('Total paths to scan: ${paths.length}');
      
      // First, scan directories to find PDF files
      for (final path in paths) {
        try {
          print('\nChecking directory: $path');
          final dir = Directory(path);
          final exists = await dir.exists();
          print('Directory exists: $exists');
          
          if (exists) {
            print('Starting to scan directory: $path');
            
            try {
              await for (var entity in dir.list(followLinks: false, recursive: true)) {
                try {
                  if (entity is File) {
                    final isFile = await entity.exists();
                    final isPdf = entity.path.toLowerCase().endsWith('.pdf');
                    print('Found file: ${entity.path}');
                    print('File exists: $isFile, Is PDF: $isPdf');
                    
                    if (isFile && isPdf) {
                      print('Adding PDF file: ${entity.path}');
                      files.add(entity);
                    }
                  }
                } catch (e) {
                  print('Error checking file ${entity.path}: $e');
                }
              }
            } catch (e) {
              print('Error listing directory $path: $e');
              continue;
            }
          }
        } catch (e) {
          print('Error accessing directory $path: $e');
          continue;
        }
      }

      print('\nTotal PDFs found: ${files.length}');
      if (files.isEmpty) {
        print('No PDF files found in any directory');
      } else {
        print('Found PDF files:');
        for (var file in files) {
          print('- ${file.path}');
        }
      }
      
      // Convert files to PdfFileInfo objects
      List<PdfFileInfo> pdfInfoList = [];
      for (var file in files) {
        pdfInfoList.add(PdfFileInfo(file: file));
      }
      
      // Load metadata in batches to prevent UI freezes
      const int batchSize = 10;
      for (int i = 0; i < pdfInfoList.length; i += batchSize) {
        final int end = (i + batchSize < pdfInfoList.length) ? i + batchSize : pdfInfoList.length;
        final batch = pdfInfoList.sublist(i, end);
        
        // Load metadata for this batch
        final futures = <Future>[];
        for (final pdfInfo in batch) {
          futures.add(pdfInfo._loadMetadataAsync());
        }
        await Future.wait(futures);
      }
      
      // Final sort and update
      pdfInfoList.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      
      if (mounted) {
        setState(() {
          allPdfFiles = pdfInfoList;
          
          // Load first page
          final endIndex = pageSize < pdfInfoList.length ? pageSize : pdfInfoList.length;
          displayedPdfFiles = pdfInfoList.sublist(0, endIndex);
          
          isLoading = false;
          hasMoreFiles = endIndex < pdfInfoList.length;
          
          if (files.isEmpty) {
            errorMessage = 'No PDF files found in common directories';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading PDF files: $e';
        });
      }
    }
  }

  void _deletePdf(PdfFileInfo pdfInfo) async {
    try {
      if (await pdfInfo.file.exists()) {
        // Close any open document to prevent file lock issues
        pdfInfo.closeDocument();
        
        // Delete the file
        await pdfInfo.file.delete();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: ${pdfInfo.fileName}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
          
          // Update the UI
          setState(() {
            // Remove from both lists
            allPdfFiles.remove(pdfInfo);
            displayedPdfFiles.remove(pdfInfo);
            
            // If we're in search mode, we might need to update the search results
            if (isSearching && _searchController.text.isNotEmpty) {
              _filterPdfFiles(_searchController.text);
            }
          });
        }
      } else {
        // File doesn't exist anymore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File no longer exists'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Still remove it from our lists
          setState(() {
            allPdfFiles.remove(pdfInfo);
            displayedPdfFiles.remove(pdfInfo);
          });
        }
      }
    } catch (e) {
      print('Error deleting file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add method to toggle selection mode
  void _toggleSelectionMode(PdfFileInfo? initialFile) {
    setState(() {
      isSelectionMode = !isSelectionMode;
      selectedFiles.clear();
      
      if (initialFile != null && isSelectionMode) {
        selectedFiles.add(initialFile.file.path);
      }
    });
  }
  
  // Add method to toggle file selection
  void _toggleFileSelection(PdfFileInfo pdfInfo) {
    setState(() {
      if (selectedFiles.contains(pdfInfo.file.path)) {
        selectedFiles.remove(pdfInfo.file.path);
        if (selectedFiles.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedFiles.add(pdfInfo.file.path);
        isSelectionMode = true;
      }
    });
  }
  
  // Add method to share multiple files
  void _shareSelectedFiles(BuildContext context) async {
    if (selectedFiles.isEmpty) return;
    
    try {
      final files = selectedFiles.map((path) => XFile(path)).toList();
      
      final result = await Share.shareXFiles(
        files,
        subject: 'Sharing ${files.length} PDF files',
        text: 'Check out these PDF files',
      );
      
      if (result.status == ShareResultStatus.dismissed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Share cancelled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Exit selection mode after sharing
      setState(() {
        isSelectionMode = false;
        selectedFiles.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing files: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  // Add method to delete multiple files
  void _deleteSelectedFiles() async {
    if (selectedFiles.isEmpty) return;
    
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDFs'),
        content: Text('Are you sure you want to delete ${selectedFiles.length} selected files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE', 
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (!shouldDelete) return;
    
    int successCount = 0;
    int failCount = 0;
    
    // Create a copy of the set to avoid modification during iteration
    final filesToDelete = Set<String>.from(selectedFiles);
    
    for (final path in filesToDelete) {
      try {
        if (await File(path).exists()) {
          // Delete the file
          await File(path).delete();
          successCount++;
        } else {
          // File doesn't exist anymore
          failCount++;
        }
      } catch (e) {
        print('Error deleting file: $e');
        failCount++;
      }
    }
    
    // Show result message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $successCount files${failCount > 0 ? ', failed to delete $failCount' : ''}'),
          duration: const Duration(seconds: 3),
          backgroundColor: successCount > 0 ? Colors.green : Colors.red,
        ),
      );
    }
    
    // Exit selection mode after deletion
    setState(() {
      isSelectionMode = false;
      selectedFiles.clear();
      
      // If we're in search mode, we might need to update the search results
      if (isSearching && _searchController.text.isNotEmpty) {
        _filterPdfFiles(_searchController.text);
      }
    });
  }
  
  // Add method to select all files
  void _selectAllFiles() {
    setState(() {
      if (selectedFiles.length == displayedPdfFiles.length) {
        // If all files are already selected, deselect all
        selectedFiles.clear();
        isSelectionMode = false;
      } else {
        // Otherwise, select all displayed files
        selectedFiles.clear();
        selectedFiles.addAll(displayedPdfFiles.map((file) => file.file.path));
      }
    });
  }

  void _openPdfViewer(PdfFileInfo pdfInfo) async {
    try {
      if (await pdfInfo.file.exists()) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(file: pdfInfo.file),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF file no longer exists'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing file: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search PDFs...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterPdfFiles('');
                    },
                  ),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                autofocus: true,
                onChanged: _filterPdfFiles,
              )
            : const Text('PDF Viewer'),
        actions: [
          if (!isSearching) IconButton(
            icon: const Icon(Icons.search),
            onPressed: _activateSearch,
            tooltip: 'Search',
          ),
          if (!isSearching) IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                isGridView = !isGridView;
              });
            },
            tooltip: isGridView ? 'Switch to List View' : 'Switch to Grid View',
          ),
          if (!isSearching) PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: _changeSortOption,
            itemBuilder: (context) => [
              for (final option in SortOption.values)
                PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        option.icon,
                        color: currentSortOption == option 
                            ? Theme.of(context).colorScheme.primary 
                            : null,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option.displayName,
                        style: TextStyle(
                          fontWeight: currentSortOption == option 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                          color: currentSortOption == option 
                              ? Theme.of(context).colorScheme.primary 
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (!isSearching) IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: themeProvider.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          if (!isSearching && !isSelectionMode) IconButton(
            icon: const Icon(Icons.text_snippet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExtractTextScreen(pdfFiles: allPdfFiles),
                ),
              );
            },
            tooltip: 'Extract Text',
          ),
          if (isSelectionMode) IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAllFiles,
            tooltip: 'Select All',
          ),
          if (isSelectionMode) IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareSelectedFiles(context),
            tooltip: 'Share Selected',
          ),
          if (isSelectionMode) IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedFiles,
            tooltip: 'Delete Selected',
          ),
          if (isSelectionMode) IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                isSelectionMode = false;
                selectedFiles.clear();
              });
            },
            tooltip: 'Exit Selection Mode',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for PDF files...', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (displayedPdfFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No PDF files found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checkPermissionAndLoadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!isSearching)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: _activateSearch,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 12),
            Text(
                        'Search PDFs...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
            ),
          ],
        ),
      ),
              ),
            ),
          ),
        if (isSearching && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Found ${displayedPdfFiles.length} results',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (!isSelectionMode && _showMultiSelectHint)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tip: Long press to select multiple files',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showMultiSelectHint = false;
                    });
                  },
                  iconSize: 16,
                ),
              ],
            ),
          ),
        Expanded(
          child: isGridView
              ? GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: displayedPdfFiles.length + (isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayedPdfFiles.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final pdfInfo = displayedPdfFiles[index];
                    return PdfGridItem(
                      pdfInfo: pdfInfo,
                      onTap: () {
                        if (isSelectionMode) {
                          _toggleFileSelection(pdfInfo);
                        } else {
                          _openPdfViewer(pdfInfo);
                        }
                      },
                      onLongPress: () => _toggleFileSelection(pdfInfo),
                      isSelected: selectedFiles.contains(pdfInfo.file.path),
                      isSelectionMode: isSelectionMode,
                    );
                  },
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: displayedPdfFiles.length + (isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayedPdfFiles.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final pdfInfo = displayedPdfFiles[index];
                    return PdfListItem(
                      pdfInfo: pdfInfo,
                      onTap: () {
                        if (isSelectionMode) {
                          _toggleFileSelection(pdfInfo);
                        } else {
                          _openPdfViewer(pdfInfo);
                        }
                      },
                      onLongPress: () => _toggleFileSelection(pdfInfo),
                      isSelected: selectedFiles.contains(pdfInfo.file.path),
                      isSelectionMode: isSelectionMode,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PdfFileInfo {
  final File file;
  int? _fileSize;
  DateTime? _lastModified;
  String? _extractedText;
  bool _isTextExtracted = false;
  bool _isExtractingText = false;
  
  PdfFileInfo({required this.file}) {
    _loadMetadataAsync();
    _loadCachedTextAsync();
  }
  
  Future<void> _loadMetadataAsync() async {
    try {
      final stat = await file.stat();
      _fileSize = stat.size;
      _lastModified = stat.modified;
    } catch (e) {
      print('Error loading metadata for ${file.path}: $e');
    }
  }

  // Get the cache file path for this PDF
  Future<String> get _cacheFilePath async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = file.path.split('/').last;
    final fileHash = sha256.convert(utf8.encode(file.path)).toString();
    return '${appDir.path}/cache/${fileHash}_$fileName.txt';
  }

  // Load cached text if available
  Future<void> _loadCachedTextAsync() async {
    try {
      final cachePath = await _cacheFilePath;
      final cacheFile = File(cachePath);
      
      if (await cacheFile.exists()) {
        final cacheStats = await cacheFile.stat();
        final pdfStats = await file.stat();
        
        // Only use cache if PDF hasn't been modified since cache was created
        if (cacheStats.modified.isAfter(pdfStats.modified)) {
          _extractedText = await cacheFile.readAsString();
          _isTextExtracted = true;
        }
      }
    } catch (e) {
      print('Error loading cached text: $e');
    }
  }

  // Save extracted text to cache
  Future<void> _saveToCache(String text) async {
    try {
      final cachePath = await _cacheFilePath;
      final cacheFile = File(cachePath);
      
      // Create cache directory if it doesn't exist
      final cacheDir = Directory(path.dirname(cachePath));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      await cacheFile.writeAsString(text);
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  Future<String> extractText() async {
    if (_extractedText != null && _isTextExtracted) {
      return _extractedText!;
    }
    
    if (_isExtractingText) {
      // Wait until extraction is complete to avoid multiple extractions
      while (_isExtractingText) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_extractedText != null) {
        return _extractedText!;
      }
    }
    
    _isExtractingText = true;
    try {
      // Use Syncfusion PDF to extract text
      final syncfusion.PdfDocument document = syncfusion.PdfDocument(inputBytes: await file.readAsBytes());
      final syncfusion.PdfTextExtractor extractor = syncfusion.PdfTextExtractor(document);
      final String text = extractor.extractText();
      document.dispose();
      
      _extractedText = text;
      _isTextExtracted = true;
      
      // Save to cache
      await _saveToCache(text);
      
      return _extractedText ?? '';
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    } finally {
      _isExtractingText = false;
    }
  }

  String get fileName => file.path.split('/').last;
  
  String get directoryName {
    final parts = file.path.split('/');
    return parts.length > 2 ? parts[parts.length - 2] : '';
  }
  
  int get fileSize => _fileSize ?? 0;
  
  DateTime get lastModified => _lastModified ?? DateTime.now();
  
  String get formattedSize {
    if (_fileSize == null) return 'Unknown';
    
    final kb = _fileSize! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
  
  String get formattedDate {
    if (_lastModified == null) return 'Unknown';
    return '${_lastModified!.day}/${_lastModified!.month}/${_lastModified!.year}';
  }

  Future<void> loadDocument() async {
    // Implementation of loadDocument method
  }
  
  Future<PdfPageImage?> getThumbnail({
    required int width,
    required int height,
  }) async {
    try {
      final document = await PdfDocument.openFile(file.path);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: width.toDouble(),
        height: height.toDouble(),
      );
      await page.close();
      await document.close();
      return pageImage;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  void closeDocument() {
    // Implementation of closeDocument method
  }
}

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

class _PdfGridItemState extends State<PdfGridItem> {
  PdfPageImage? _thumbnail;
  bool _isLoading = false;
  bool _isVisible = false;
  bool _thumbnailRequested = false;

  @override
  void initState() {
    super.initState();
    _isVisible = true;
    // Delay thumbnail generation to improve initial load performance
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isVisible) {
        _generateThumbnail();
      }
    });
  }

  @override
  void dispose() {
    _isVisible = false;
    super.dispose();
  }

  Future<void> _generateThumbnail() async {
    if (!mounted || !_isVisible || _thumbnailRequested) return;
    
    _thumbnailRequested = true;
    setState(() {
      _isLoading = true;
    });

    try {
      final thumbnail = await widget.pdfInfo.getThumbnail(
        width: 300,
        height: 400,
      );
      
      if (mounted && _isVisible) {
        setState(() {
          _thumbnail = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
      if (mounted && _isVisible) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // Always show a placeholder first for immediate visual feedback
                  Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    child: Center(
                      child: Icon(
                        Icons.picture_as_pdf,
                        size: 64,
                        color: colorScheme.primary.withOpacity(0.7),
                      ),
                    ),
                  ),
                  // Show thumbnail when loaded
                  if (_thumbnail != null)
                    Image(
                      image: MemoryImage(_thumbnail!.bytes),
                      fit: BoxFit.cover,
                    ),
                  // Show loading indicator over the placeholder
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  // Selection indicator
                  if (widget.isSelected)
                    Container(
                      color: colorScheme.primary.withOpacity(0.3),
                      child: Center(
                        child: Icon(
                          Icons.check_circle,
                          size: 48,
                          color: colorScheme.primary,
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
                      // File size
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
                      // Last modified date
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

class PdfListItem extends StatefulWidget {
  final PdfFileInfo pdfInfo;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const PdfListItem({
    Key? key,
    required this.pdfInfo,
    required this.onTap,
    this.onDelete,
    this.onLongPress,
    required this.isSelected,
    required this.isSelectionMode,
  }) : super(key: key);

  @override
  State<PdfListItem> createState() => _PdfListItemState();
}

class _PdfListItemState extends State<PdfListItem> {
  PdfPageImage? _thumbnail;
  bool _isLoading = false;
  bool _isVisible = false;
  bool _thumbnailRequested = false;

  @override
  void initState() {
    super.initState();
    _isVisible = true;
    // Delay thumbnail generation to improve initial load performance
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isVisible) {
        _generateThumbnail();
      }
    });
  }

  @override
  void dispose() {
    _isVisible = false;
    super.dispose();
  }

  Future<void> _generateThumbnail() async {
    if (!mounted || !_isVisible || _thumbnailRequested) return;
    
    _thumbnailRequested = true;
    setState(() {
      _isLoading = true;
    });

    try {
      final thumbnail = await widget.pdfInfo.getThumbnail(
        width: 150,
        height: 200,
      );
      
      if (mounted && _isVisible) {
        setState(() {
          _thumbnail = thumbnail;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
      if (mounted && _isVisible) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Selection indicator or checkbox
              if (widget.isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    widget.isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: widget.isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                    size: 24,
                  ),
                ),
              // Thumbnail container
              SizedBox(
                width: 60,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Placeholder
                    Container(
                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                      child: Center(
                        child: Icon(
                          Icons.picture_as_pdf,
                          size: 32,
                          color: colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ),
                    // Thumbnail
                    if (_thumbnail != null)
                      Image(
                        image: MemoryImage(_thumbnail!.bytes),
                        fit: BoxFit.cover,
                      ),
                    // Loading indicator
                    if (_isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    // Selection overlay for thumbnail
                    if (widget.isSelected && !widget.isSelectionMode)
                      Container(
                        color: colorScheme.primary.withOpacity(0.3),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            size: 24,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pdfInfo.fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.folder,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.pdfInfo.directoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // File size
                        Icon(
                          Icons.data_usage,
                          size: 14,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.pdfInfo.formattedSize,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PDFViewerScreen extends StatefulWidget {
  final File file;

  const PDFViewerScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  late PdfController _pdfController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.file.path),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _shareFile() async {
    try {
      final fileName = widget.file.path.split('/').last;
      final result = await Share.shareXFiles(
        [XFile(widget.file.path)],
        subject: 'Sharing PDF: $fileName',
        text: 'Check out this PDF file',
      );
      
      if (result.status == ShareResultStatus.dismissed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Share cancelled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _deleteFile() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete PDF'),
        content: const Text('Are you sure you want to delete this PDF file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldDelete || !mounted) return;

    try {
      await widget.file.delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF file deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.file.path.split('/').last,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
            tooltip: 'Share PDF',
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: _deleteFile,
            tooltip: 'Delete PDF',
          ),
        ],
      ),
      body: PdfView(
        controller: _pdfController,
        onDocumentLoaded: (document) {
          setState(() {
            _totalPages = document.pagesCount;
            _isReady = true;
          });
        },
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
      ),
      bottomNavigationBar: _isReady ? _buildNavigationBar() : null,
    );
  }

  Widget _buildNavigationBar() {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 0
                  ? () => _pdfController.previousPage(
                        curve: Curves.ease,
                        duration: const Duration(milliseconds: 200),
                      )
                  : null,
            ),
            Text(
              'Page ${_currentPage + 1} of $_totalPages',
              style: const TextStyle(fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _pdfController.nextPage(
                        curve: Curves.ease,
                        duration: const Duration(milliseconds: 200),
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Add this new class for the folder browser screen
class FolderBrowserScreen extends StatefulWidget {
  final Function(Directory) onFolderSelected;
  
  const FolderBrowserScreen({
    Key? key,
    required this.onFolderSelected,
  }) : super(key: key);
  
  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  Directory? _currentDirectory;
  List<FileSystemEntity> _entities = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final List<Directory> _navigationHistory = [];
  
  @override
  void initState() {
    super.initState();
    _initializeRootDirectory();
  }
  
  Future<void> _initializeRootDirectory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      if (Platform.isAndroid) {
        // Start with the storage directory on Android
        _currentDirectory = Directory('/storage/emulated/0');
      } else {
        // For other platforms, start with the documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        _currentDirectory = documentsDir;
      }
      
      await _loadCurrentDirectory();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing directory: $e';
      });
    }
  }
  
  Future<void> _loadCurrentDirectory() async {
    if (_currentDirectory == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final entities = <FileSystemEntity>[];
      
      await for (var entity in _currentDirectory!.list(followLinks: false)) {
        try {
          if (entity is Directory) {
            entities.add(entity);
          }
        } catch (e) {
          print('Error processing entity: $e');
        }
      }
      
      // Sort directories alphabetically
      entities.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
      
      setState(() {
        _entities = entities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading directory: $e';
      });
    }
  }
  
  void _navigateToDirectory(Directory directory) {
    if (_currentDirectory != null) {
      _navigationHistory.add(_currentDirectory!);
    }
    
    setState(() {
      _currentDirectory = directory;
    });
    
    _loadCurrentDirectory();
  }
  
  bool _canGoBack() {
    return _navigationHistory.isNotEmpty;
  }
  
  void _goBack() {
    if (_canGoBack()) {
      final previousDirectory = _navigationHistory.removeLast();
      setState(() {
        _currentDirectory = previousDirectory;
      });
      
      _loadCurrentDirectory();
    }
  }
  
  void _selectCurrentFolder() {
    if (_currentDirectory != null) {
      widget.onFolderSelected(_currentDirectory!);
      Navigator.pop(context);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Folders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _selectCurrentFolder,
            tooltip: 'Select this folder',
          ),
        ],
      ),
      body: Column(
        children: [
          // Current path display
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentDirectory?.path ?? 'Loading...',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Directory content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _entities.isEmpty
                        ? const Center(
                            child: Text('No folders found in this directory'),
                          )
                        : ListView.builder(
                            itemCount: _entities.length,
                            itemBuilder: (context, index) {
                              final entity = _entities[index];
                              final name = entity.path.split('/').last;
                              
                              return ListTile(
                                leading: const Icon(Icons.folder),
                                title: Text(name),
                                onTap: () {
                                  if (entity is Directory) {
                                    _navigateToDirectory(entity);
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _canGoBack() ? _goBack : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
            TextButton.icon(
              onPressed: _selectCurrentFolder,
              icon: const Icon(Icons.check_circle),
              label: const Text('Select This Folder'),
            ),
          ],
        ),
      ),
    );
  }
}

// Add the ExtractTextScreen class after the FolderBrowserScreen class
class ExtractTextScreen extends StatefulWidget {
  final List<PdfFileInfo> pdfFiles;
  
  const ExtractTextScreen({
    Key? key,
    required this.pdfFiles,
  }) : super(key: key);
  
  @override
  State<ExtractTextScreen> createState() => _ExtractTextScreenState();
}

class _ExtractTextScreenState extends State<ExtractTextScreen> {
  // Extraction state
  bool _isExtracting = false;
  bool _extractionComplete = false;
  double _extractionProgress = 0.0;
  int _processedFiles = 0;
  int _totalFiles = 0;
  String _currentFileName = '';
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  List<PdfFileInfo> _searchResults = [];
  
  // View state
  bool _isGridView = true;
  SortOption _currentSortOption = SortOption.dateDesc;
  
  @override
  void initState() {
    super.initState();
    _totalFiles = widget.pdfFiles.length;
    
    // Check if any files need extraction
    _checkExtractionStatus();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  // Check if text extraction is needed
  Future<void> _checkExtractionStatus() async {
    int extractedCount = 0;
    
    for (final file in widget.pdfFiles) {
      if (file._isTextExtracted) {
        extractedCount++;
      }
    }
    
    if (extractedCount == _totalFiles) {
      setState(() {
        _extractionComplete = true;
      });
    }
  }
  
  // Start the extraction process
  Future<void> _startExtraction() async {
    if (_isExtracting) return;
    
    setState(() {
      _isExtracting = true;
      _extractionProgress = 0.0;
      _processedFiles = 0;
    });
    
    // Process files in batches to keep UI responsive
    const int batchSize = 3;
    
    for (int i = 0; i < widget.pdfFiles.length; i += batchSize) {
      if (!mounted) break;
      
      final int end = (i + batchSize < widget.pdfFiles.length) ? i + batchSize : widget.pdfFiles.length;
      final batch = widget.pdfFiles.sublist(i, end);
      
      // Process this batch
      for (final file in batch) {
        if (!mounted) break;
        
        setState(() {
          _currentFileName = file.fileName;
        });
        
        try {
          // Extract text if not already extracted
          if (!file._isTextExtracted) {
            await file.extractText();
          }
          
          _processedFiles++;
          _extractionProgress = _processedFiles / _totalFiles;
          
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          print('Error extracting text from ${file.fileName}: $e');
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isExtracting = false;
        _extractionComplete = true;
      });
    }
  }
  
  // Search in extracted text
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = List.from(widget.pdfFiles);
        _applySortToList(_searchResults);
      });
      return;
    }
    
    final results = widget.pdfFiles.where((file) {
      // Search in filename
      if (file.fileName.toLowerCase().contains(query.toLowerCase())) {
        return true;
      }
      
      // Search in extracted text if available
      if (file._isTextExtracted && file._extractedText != null) {
        return file._extractedText!.toLowerCase().contains(query.toLowerCase());
      }
      
      return false;
    }).toList();
    
    _applySortToList(results);
    
    setState(() {
      _searchResults = results;
    });
  }
  
  // Apply sort to a list of PDF files
  void _applySortToList(List<PdfFileInfo> files) {
    try {
      switch (_currentSortOption) {
        case SortOption.nameAsc:
          files.sort((a, b) => a.fileName.compareTo(b.fileName));
          break;
        case SortOption.nameDesc:
          files.sort((a, b) => b.fileName.compareTo(a.fileName));
          break;
        case SortOption.dateAsc:
          files.sort((a, b) => a.lastModified.compareTo(b.lastModified));
          break;
        case SortOption.dateDesc:
          files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
          break;
        case SortOption.sizeAsc:
          files.sort((a, b) => a.fileSize.compareTo(b.fileSize));
          break;
        case SortOption.sizeDesc:
          files.sort((a, b) => b.fileSize.compareTo(a.fileSize));
          break;
      }
    } catch (e) {
      print('Error sorting files: $e');
    }
  }
  
  // Change the current sort option
  void _changeSortOption(SortOption option) {
    if (_currentSortOption != option) {
      setState(() {
        _currentSortOption = option;
        _applySortToList(_searchResults);
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search in PDF content...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  ),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                autofocus: true,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onChanged: _performSearch,
              )
            : const Text('PDF Content Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_extractionComplete && !_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
                
                // Use a slightly longer delay and ensure keyboard appears
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_searchFocusNode.canRequestFocus) {
                    _searchFocusNode.requestFocus();
                    // Explicitly show keyboard
                    TextInput.finishAutofillContext();
                  }
                });
              },
              tooltip: 'Search',
            ),
          if (_extractionComplete && !_isSearching)
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: _changeSortOption,
              itemBuilder: (context) => [
                for (final option in SortOption.values)
                  PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          color: _currentSortOption == option 
                              ? Theme.of(context).colorScheme.primary 
                              : null,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option.displayName,
                          style: TextStyle(
                            fontWeight: _currentSortOption == option 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: _currentSortOption == option 
                                ? Theme.of(context).colorScheme.primary 
                                : null,
                          ),
                        ),
                        if (_currentSortOption == option)
                          const Spacer()
                        else
                          const SizedBox.shrink(),
                        if (_currentSortOption == option)
                          Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
              ],
            ),
          if (_extractionComplete && !_isSearching)
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
              },
              tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (!_extractionComplete && !_isExtracting) {
      return _buildStartExtractionView();
    } else if (_isExtracting) {
      return _buildExtractionProgressView();
    } else if (_extractionComplete) {
      return _buildSearchResultsView();
    }
    
    // Fallback
    return const Center(child: CircularProgressIndicator());
  }
  
  Widget _buildStartExtractionView() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.text_snippet, size: 72, color: Colors.blue),
          ),
          const SizedBox(height: 24),
            const Text(
            'Extract Text from All PDFs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'This will extract text from all PDF files to enable faster searching. '
              'This process may take some time depending on the number of files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startExtraction,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Extraction'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExtractionProgressView() {
    final percentage = (_extractionProgress * 100).toInt();
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Extracting Text',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Processing: $_processedFiles of $_totalFiles files',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Current file: $_currentFileName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: LinearProgressIndicator(
              value: _extractionProgress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 16),
            Text(
            '$percentage%',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          const Text(
            'Please wait while we extract text from your PDF files. '
            'This will make searching much faster.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
            ),
          ],
        ),
    );
  }
  
  Widget _buildSearchResultsView() {
    // Initialize search results if empty
    if (_searchResults.isEmpty && _searchController.text.isEmpty) {
      _searchResults = List.from(widget.pdfFiles);
      _applySortToList(_searchResults);
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off, size: 72, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'No matching PDF files',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        if (!_isSearching)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = true;
                });
                
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_searchFocusNode.canRequestFocus) {
                    _searchFocusNode.requestFocus();
                    TextInput.finishAutofillContext();
                  }
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Search in PDF content...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_isSearching && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Found ${_searchResults.length} results',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isGridView 
              ? _buildGridView() 
              : _buildListView(),
        ),
      ],
    );
  }
  
  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final pdfInfo = _searchResults[index];
        return PdfGridItem(
          pdfInfo: pdfInfo,
          onTap: () => _openPdfViewer(pdfInfo),
          onDelete: null,
          onLongPress: null,
          isSelected: false,
          isSelectionMode: false,
        );
      },
    );
  }
  
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final pdfInfo = _searchResults[index];
        return PdfListItem(
          pdfInfo: pdfInfo,
          onTap: () => _openPdfViewer(pdfInfo),
          onDelete: null,
          onLongPress: null,
          isSelected: false,
          isSelectionMode: false,
        );
      },
    );
  }
  
  void _openPdfViewer(PdfFileInfo pdfInfo) async {
    try {
      if (await pdfInfo.file.exists()) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerScreen(file: pdfInfo.file),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF file no longer exists'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing file: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

