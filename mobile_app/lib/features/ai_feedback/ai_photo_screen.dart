import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AIPhotoScreen extends StatefulWidget {
  const AIPhotoScreen({super.key});

  @override
  State<AIPhotoScreen> createState() => _AIPhotoScreenState();
}

class _AIPhotoScreenState extends State<AIPhotoScreen> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  bool _isUploading = false;
  String _statusMessage = '';
  _AnalysisResult? _result;
  List<_AnalysisResult> _history = [];
  bool _isLoadingHistory = true;
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;

  static const String _bucket = 'inspection-photos';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await _supabase
          .from('analysis_results')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _history = (data as List<dynamic>).map((item) {
            final payload = (item['analysis_payload'] as Map<String, dynamic>?) ?? {};
            return _AnalysisResult(
              id: item['id']?.toString() ?? '',
              imageLabel: item['image_url'] != null
                  ? 'Site Capture — ${item["id"].toString().substring(0, 8)}'
                  : 'Analysis result',
              imageUrl: item['image_url'],
              date: item['created_at'] ?? '',
              progressScore: (payload['progress_score'] as num?)?.toInt() ?? 0,
              qualityScore: (payload['quality_score'] as num?)?.toInt() ?? 0,
              safetyScore: (payload['safety_compliance'] as num?)?.toInt() ?? 0,
              findings: List<String>.from(payload['findings'] ?? []),
              summary: payload['summary'] as String? ?? '',
            );
          }).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch AI history: \$e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() { _selectedImage = File(picked.path); _result = null; _statusMessage = ''; });
    }
  }

  Future<void> _analyze() async {
    if (_selectedImage == null) return;
    setState(() { _isAnalyzing = true; _isUploading = true; _statusMessage = 'Uploading photo...'; });

    String? imageUrl;
    try {
      // 1. Upload to Supabase Storage
      final userId = _supabase.auth.currentUser?.id ?? 'anon';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'ai-analysis/\$userId/\$ts.jpg';
      final bytes = await _selectedImage!.readAsBytes();
      await _supabase.storage.from(_bucket).uploadBinary(
        storagePath, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      imageUrl = _supabase.storage.from(_bucket).getPublicUrl(storagePath);
      if (mounted) setState(() { _isUploading = false; _statusMessage = 'Analysing with AI...'; });
    } catch (e) {
      debugPrint('[AI] Upload failed: \$e');
      if (mounted) setState(() { _isAnalyzing = false; _isUploading = false; _statusMessage = 'Upload failed. Check connection.'; });
      return;
    }

    try {
      // 2. Call Edge Function
      final response = await _supabase.functions.invoke('analyze-photo', body: {
        'image_url': imageUrl,
        'visit_id': null,
        'project_id': null,
      });

      if (response.status != 200) {
        throw Exception('Edge function returned \${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      final payload = data['result'] as Map<String, dynamic>? ?? {};
      final result = _AnalysisResult(
        id: data['id']?.toString() ?? '',
        imageLabel: 'Site Capture — \${DateTime.now().toIso8601String().substring(0, 10)}',
        imageUrl: imageUrl,
        date: DateTime.now().toIso8601String(),
        progressScore: (payload['progress_score'] as num?)?.toInt() ?? 0,
        qualityScore: (payload['quality_score'] as num?)?.toInt() ?? 0,
        safetyScore: (payload['safety_compliance'] as num?)?.toInt() ?? 0,
        findings: List<String>.from(payload['findings'] ?? []),
        summary: payload['summary'] as String? ?? '',
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = '';
          _result = result;
          _history.insert(0, result);
        });
      }
    } catch (e) {
      debugPrint('[AI] Analysis failed: \$e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = 'Analysis failed. Is the Edge Function deployed?';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('AI Photo Analysis', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            TextButton(
              onPressed: _fetchHistory,
              child: Text('Refresh', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Upload + Analyse Panel ──────────────────────────────────────────
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isAnalyzing ? null : _showPickerSheet,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          )
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.add_a_photo_outlined, color: Color(0xFF64748B), size: 40),
                            const SizedBox(height: 8),
                            Text('Tap to take or select a site photo',
                                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
                          ]),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _ScoreWidget(label: 'Progress', score: _result!.progressScore),
                    _ScoreWidget(label: 'Quality', score: _result!.qualityScore),
                    _ScoreWidget(label: 'Safety', score: _result!.safetyScore),
                  ]),
                  if (_result!.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_result!.summary,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ] else if (_statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_isAnalyzing) ...[
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6))),
                      const SizedBox(width: 10),
                    ],
                    Text(_statusMessage, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  ]),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_selectedImage == null || _isAnalyzing) ? null : _analyze,
                    icon: _isAnalyzing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_isAnalyzing ? 'Analysing...' : 'Analyse Photo',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── History List ───────────────────────────────────────────────────
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.history_edu_outlined, size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text('No analyses yet', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('Take a site photo to get AI scores',
                              style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 12)),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (ctx, i) {
                          final h = _history[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Flexible(child: Text(h.imageLabel,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A)),
                                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Text(h.date.length > 10 ? h.date.substring(0, 10) : h.date,
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                ]),
                                const SizedBox(height: 10),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                  _MiniScore(label: 'Progress', score: h.progressScore, color: const Color(0xFF3B82F6)),
                                  _MiniScore(label: 'Quality', score: h.qualityScore, color: const Color(0xFF10B981)),
                                  _MiniScore(label: 'Safety', score: h.safetyScore, color: const Color(0xFFF59E0B)),
                                ]),
                                if (h.findings.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ...h.findings.take(3).map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Icon(Icons.circle, size: 6, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(f, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)))),
                                    ]),
                                  )),
                                ],
                                if (h.summary.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(h.summary,
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: Text('Take Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library), title: Text('Choose from Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }
}

class _ScoreWidget extends StatelessWidget {
  final String label;
  final int score;
  const _ScoreWidget({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('\$score%', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  const _MiniScore({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('\$score%', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
    ]);
  }
}

class _AnalysisResult {
  final String id, imageLabel, date, summary;
  final String? imageUrl;
  final int progressScore, qualityScore, safetyScore;
  final List<String> findings;
  const _AnalysisResult({
    required this.id, required this.imageLabel, required this.date, required this.summary,
    this.imageUrl, required this.progressScore, required this.qualityScore,
    required this.safetyScore, required this.findings,
  });
}
