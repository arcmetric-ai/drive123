import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/instructor_document_type.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_circle_icon_button.dart';
import '../../widgets/app_primary_button.dart';

class InstructorDocumentUploadScreen extends StatefulWidget {
  const InstructorDocumentUploadScreen({
    super.key,
    required this.documentType,
  });

  final InstructorDocumentType documentType;

  @override
  State<InstructorDocumentUploadScreen> createState() =>
      _InstructorDocumentUploadScreenState();
}

class _InstructorDocumentUploadScreenState
    extends State<InstructorDocumentUploadScreen> {
  final _imagePicker = ImagePicker();
  String? _selectedFilePath;
  bool _isSubmitting = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedFilePath = picked.path);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;
    setState(() => _selectedFilePath = path);
  }

  Future<void> _submit() async {
    final filePath = _selectedFilePath;
    final userId = SupabaseService.currentUser?.id;
    if (filePath == null || filePath.isEmpty || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a file before submitting.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.uploadInstructorCredentialDocument(
        userId: userId,
        documentType: widget.documentType,
        file: File(filePath),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.documentType.title} uploaded.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload document: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName =
        _selectedFilePath == null ? null : _selectedFilePath!.split('/').last;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 56,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Add Document',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                widget.documentType.uploadTitle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.documentType.description,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 28),
              InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _pickDocument,
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4EDFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.upload_rounded,
                          color: AppColors.primary,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        fileName == null ? 'Tap to upload' : fileName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'or take a photo',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Camera'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Photos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FD),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ACCEPTABLE FORMATS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        _FormatChip(label: 'PDF', color: Color(0xFFFF3B30)),
                        SizedBox(width: 14),
                        _FormatChip(label: 'JPEG', color: Color(0xFF3478F6)),
                        SizedBox(width: 14),
                        _FormatChip(label: 'PNG', color: Color(0xFF00C853)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'UPLOAD GUIDELINES',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 20),
              const _GuidelineRow(
                label: 'Ensure all four corners of the document are visible',
              ),
              SizedBox(height: 14),
              const _GuidelineRow(
                label: 'Text must be clear and easily legible',
              ),
              SizedBox(height: 14),
              const _GuidelineRow(
                label: 'Maximum file size is 10MB',
              ),
              const SizedBox(height: 32),
              AppPrimaryButton(
                label: 'Submit Document',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A111827),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _GuidelineRow extends StatelessWidget {
  const _GuidelineRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              height: 1.45,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}
