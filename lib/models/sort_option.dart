import 'package:flutter/material.dart';

enum SortOption {
  nameAsc,
  nameDesc,
  dateAsc,
  dateDesc,
  sizeAsc,
  sizeDesc,
}

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
      case SortOption.nameDesc:
        return Icons.sort_by_alpha;
      case SortOption.dateAsc:
      case SortOption.dateDesc:
        return Icons.access_time;
      case SortOption.sizeAsc:
      case SortOption.sizeDesc:
        return Icons.data_usage;
    }
  }
} 