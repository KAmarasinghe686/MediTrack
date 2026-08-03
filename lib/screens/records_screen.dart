import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../models/medical_record.dart';
import '../services/record_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/screen_heroes.dart';
import '../l10n/app_strings.dart';
import 'upload_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final RecordService _recordService = RecordService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _gridView = false;
  bool _sortAscending = false;
  String _sortField = 'date';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MedicalRecord> _visibleRecords(List<MedicalRecord> records) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = records.where((record) {
      if (query.isEmpty) return true;
      final date = '${record.uploadDate.day}/${record.uploadDate.month}/${record.uploadDate.year}';
      return record.title.toLowerCase().contains(query) || date.contains(query);
    }).toList();
    filtered.sort((a, b) {
      final comparison = _sortField == 'name'
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : a.uploadDate.compareTo(b.uploadDate);
      return _sortAscending ? comparison : -comparison;
    });
    return filtered;
  }

  // ✅ SHOW IMAGE INSIDE THE APP
  Future<void> _viewRecord(MedicalRecord record) async {
    final url = record.fileUrl;
    
    if (url.contains('w3.org') || url.contains('example.com')) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('📄 Demo Document'),
            content: const Text('This is a demo record for testing.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // ✅ PDF - Open in browser
    if (_isPDF(url)) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        _showSnack('Could not open PDF: $e', Colors.red);
      }
      return;
    }

    // ✅ Image - Show in dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.type,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Could not load image', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        } catch (e) {
                          _showSnack('Could not open: $e', Colors.red);
                        }
                      },
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text('Open in Browser'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  bool _isPDF(String url) => url.toLowerCase().contains('.pdf');

  // ✅ Download (works for images AND PDFs)
  Future<void> _downloadRecord(MedicalRecord record) async {
    try {
      if (!await Permission.storage.request().isGranted) {
        _showSnack('Storage permission required', Colors.orange);
        return;
      }

      _showSnack('Downloading...', Colors.blue);

      final response = await http.get(Uri.parse(record.fileUrl));
      if (response.statusCode == 200) {
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) await directory.create(recursive: true);

        String ext = _isPDF(record.fileUrl) ? '.pdf' : '.jpg';
        String fileName = record.title.replaceAll(' ', '_') + ext;
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        _showSnack('✅ Downloaded: $fileName', Colors.green);
      } else {
        throw Exception('Failed to download');
      }
    } catch (e) {
      _showSnack('Download failed: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
      );
    }
  }

  // ✅ Edit Record
  Future<void> _editRecord(MedicalRecord record) async {
    final titleController = TextEditingController(text: record.title);
    String selectedType = record.type;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Edit Record'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Document Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Lab Result', child: Text('Lab Result')),
                  DropdownMenuItem(value: 'Prescription', child: Text('Prescription')),
                  DropdownMenuItem(value: 'Scan', child: Text('Scan')),
                  DropdownMenuItem(value: 'Medical Report', child: Text('Medical Report')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => selectedType = value!),
              ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                setState(() => isLoading = true);
                try {
                  await _recordService.updateRecord(record.id, titleController.text.trim(), selectedType);
                  if (mounted) {
                    _showSnack('✅ Record updated!', Colors.green);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  _showSnack('Update failed: $e', Colors.red);
                } finally {
                  if (mounted) setState(() => isLoading = false);
                }
              },
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Delete Record
  Future<void> _deleteRecord(MedicalRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text('Delete "${record.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _recordService.deleteRecord(record.id);
        _showSnack('🗑️ Record deleted', Colors.orange);
      } catch (e) {
        _showSnack('Delete failed: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : const Color(0xFF1A2B4A);
    final subtitleColor = isDark ? const Color(0xFF8899AA) : const Color(0xFF6B7A99);

    return Scaffold(
      appBar: AppBar(title: const Text('Medical Records')),
      body: FluidBlobBackground(
        
        child: StreamBuilder<List<MedicalRecord>>(
          stream: _recordService.getPatientRecords(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                        Text(context.tr('records_unavailable'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: () => setState(() {}), child: const Text('Retry')),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FadeSlideIn(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ?? Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_copy_rounded,
                            size: 100,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                              context.tr('no_records_yet'),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload your lab reports, prescriptions, and scans to access them securely anywhere.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: subtitleColor, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(context.tr('upload_record')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final records = _visibleRecords(snapshot.data!);
            final sortDateLabel = context.tr('sort_date');
            final sortNameLabel = context.tr('sort_name');
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: FadeSlideIn(
                    child: MediTrackIllustrationPanel(
                      title: context.tr('medical_records'),
                      subtitle: context.tr('health_summary'),
                      imageUrl: 'assets/images/records_illustration.png',
                      tags: ['Secure', 'Ready to share'],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: context.tr('search_name_or_date'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
                      filled: true,
                      fillColor: Theme.of(context).cardTheme.color,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      DropdownButton<String>(
                        value: _sortField,
                        underline: const SizedBox.shrink(),
                        items: [
                          DropdownMenuItem<String>(
                            value: 'date',
                            child: Text(sortDateLabel),
                          ),
                          DropdownMenuItem<String>(
                            value: 'name',
                            child: Text(sortNameLabel),
                          ),
                        ],
                        onChanged: (value) => setState(() => _sortField = value!),
                      ),
                      IconButton(
                        tooltip: _sortAscending ? context.tr('ascending') : context.tr('descending'),
                        onPressed: () => setState(() => _sortAscending = !_sortAscending),
                        icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: context.tr('list_view'),
                        onPressed: () => setState(() => _gridView = false),
                        color: !_gridView ? Theme.of(context).colorScheme.primary : null,
                        icon: const Icon(Icons.view_list_rounded),
                      ),
                      IconButton(
                        tooltip: context.tr('grid_view'),
                        onPressed: () => setState(() => _gridView = true),
                        color: _gridView ? Theme.of(context).colorScheme.primary : null,
                        icon: const Icon(Icons.grid_view_rounded),
                      ),
                    ],
                  ),
                ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 0),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Icon(
                        Icons.folder_shared_rounded,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _gridView
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: records.length,
                          itemBuilder: (_, index) =>
                              _buildGridRecordCard(records[index], subtitleColor),
                        )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: records.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return SectionHeader(
                          title: 'Your Documents',
                          subtitle: 'Lab reports, prescriptions and scans',
                          textColor: headingColor,
                          subtitleColor: subtitleColor,
                        );
                      }

                      final record = records[index - 1];
                      final bool isDemo = record.fileUrl.contains('w3.org') || record.fileUrl.contains('example.com');
                      final bool isPDF = _isPDF(record.fileUrl);

                      return FadeSlideIn(
                        delay: Duration(milliseconds: index * 50),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: Icon(
                              isPDF ? Icons.picture_as_pdf_rounded : (record.type == 'Scan' ? Icons.image_rounded : Icons.description_rounded),
                              color: isPDF ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              record.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${record.type} • ${record.uploadDate.day}/${record.uploadDate.month}/${record.uploadDate.year}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(color: subtitleColor, fontSize: 12),
                                    ),
                                  ),
                                  if (isDemo) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('DEMO', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_rounded, size: 20),
                                  onPressed: () => _viewRecord(record),
                                  tooltip: 'View document',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, size: 20),
                                  onPressed: isDemo ? null : () => _downloadRecord(record),
                                  tooltip: isDemo ? 'Demo records cannot be downloaded' : 'Download document',
                                  color: isDemo ? Colors.grey : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  onPressed: isDemo ? null : () => _editRecord(record),
                                  tooltip: isDemo ? 'Demo records cannot be edited' : 'Edit record',
                                  color: isDemo ? Colors.grey : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  onPressed: isDemo ? null : () => _deleteRecord(record),
                                  tooltip: isDemo ? 'Demo records cannot be deleted' : 'Delete record',
                                  color: isDemo ? Colors.grey : Colors.redAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildGridRecordCard(MedicalRecord record, Color subtitleColor) {
    final isDemo = record.fileUrl.contains('w3.org') ||
        record.fileUrl.contains('example.com');
    final isPdf = _isPDF(record.fileUrl);
    final icon = isPdf
        ? Icons.picture_as_pdf_rounded
        : record.type == 'Scan'
            ? Icons.image_rounded
            : Icons.description_rounded;
    final date =
        '${record.uploadDate.day}/${record.uploadDate.month}/${record.uploadDate.year}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isPdf
                  ? Colors.redAccent
                  : Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const Spacer(),
            Text(
              record.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${record.type} • $date',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_rounded, size: 20),
                  onPressed: () => _viewRecord(record),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: isDemo ? Colors.grey : Colors.redAccent,
                  onPressed: isDemo ? null : () => _deleteRecord(record),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
