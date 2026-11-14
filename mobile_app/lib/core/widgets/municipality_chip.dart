import 'package:flutter/material.dart';
import '../../core/constants/municipalities.dart';

/// Filter chip for a Rizal municipality.
class MunicipalityChip extends StatelessWidget {
  final RizalMunicipality municipality;
  final bool isSelected;
  final VoidCallback onSelected;

  const MunicipalityChip({
    super.key,
    required this.municipality,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(municipality.name),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFFFC800),
      checkmarkColor: const Color(0xFF033300),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF033300) : const Color(0xFF6B6B6B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF033300) : const Color(0xFFE5E5E5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

/// Category filter chip.
class CategoryChip extends StatelessWidget {
  final String id;
  final String name;
  final Color color;
  final bool isSelected;
  final VoidCallback onSelected;

  const CategoryChip({
    super.key,
    required this.id,
    required this.name,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(name),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: isSelected ? color : const Color(0xFFE5E5E5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
