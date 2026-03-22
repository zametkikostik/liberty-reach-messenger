import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/family_status_service.dart';
import '../models/models.dart';

/// 👨‍👩‍👧 Family Status Settings Screen
class FamilyStatusSettingsScreen extends StatefulWidget {
  const FamilyStatusSettingsScreen({super.key});

  @override
  State<FamilyStatusSettingsScreen> createState() => _FamilyStatusSettingsScreenState();
}

class _FamilyStatusSettingsScreenState extends State<FamilyStatusSettingsScreen> {
  final _familyStatusService = FamilyStatusService.instance;
  FamilyStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Семейный статус',
          style: GoogleFonts.firaCode(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Выберите ваш семейный статус:',
              style: GoogleFonts.firaCode(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            
            // Список статусов
            Expanded(
              child: ListView(
                children: FamilyStatus.values.map((status) {
                  return _buildStatusTile(status);
                }).toList(),
              ),
            ),
            
            // Кнопка сохранения
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _saveStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0080),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Сохранить',
                  style: GoogleFonts.firaCode(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(FamilyStatus status) {
    final isSelected = _selectedStatus == status;
    final icon = _familyStatusService.getStatusIcon(status);
    final text = _familyStatusService.getStatusText(status);
    final color = _familyStatusService.getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected 
          ? color.withOpacity(0.2) 
          : Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          text,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: color)
            : null,
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
      ),
    );
  }

  void _saveStatus() {
    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите статус', style: GoogleFonts.firaCode()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _familyStatusService.setFamilyStatus(_selectedStatus!);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Статус сохранён: ${_familyStatusService.getStatusText(_selectedStatus!)}',
          style: GoogleFonts.firaCode(),
        ),
        backgroundColor: const Color(0xFFFF0080),
      ),
    );

    Navigator.pop(context);
  }
}
