import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  final _expiryController = TextEditingController();
  String? _selectedFilePath;
  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _expiryController.dispose();
    super.dispose();
  }

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

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate != null && !_expiryDate!.isBefore(today)
          ? _expiryDate!
          : today,
      firstDate: today,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiryDate = picked;
      _expiryController.text = DateFormat('MMM d, yyyy').format(picked);
    });
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
    if (widget.documentType.requiresExpiry && _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select the ${widget.documentType.title} expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (widget.documentType.requiresExpiry && _expiryDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiry = DateTime(
        _expiryDate!.year,
        _expiryDate!.month,
        _expiryDate!.day,
      );
      if (expiry.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document expiry cannot be in the past.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.uploadInstructorCredentialDocument(
        userId: userId,
        documentType: widget.documentType,
        file: File(filePath),
        expiresAt: _expiryDate,
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
    final fileName = _selectedFilePath?.split('/').last;

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
                      fontSize: 20,
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
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.documentType.description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 22),
              InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _pickDocument,
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
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
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4EDFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.upload_rounded,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        fileName ?? 'Tap to upload',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'or take a photo',
                        style: TextStyle(
                          fontSize: 14,
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
              if (widget.documentType.requiresExpiry) ...[
                TextField(
                  controller: _expiryController,
                  readOnly: true,
                  onTap: _pickExpiryDate,
                  decoration: InputDecoration(
                    labelText: '${widget.documentType.title} expiry date',
                    hintText: 'Select expiry date',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCEPTABLE FORMATS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'PDF, JPEG, JPG, or PNG. Maximum file size is 10MB.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'UPLOAD GUIDELINES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 20),
              const _GuidelineRow(
                label: 'Ensure all four corners of the document are visible',
              ),
              const SizedBox(height: 14),
              const _GuidelineRow(
                label: 'Text must be clear and easily legible',
              ),
              const SizedBox(height: 14),
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
              fontSize: 15,
              height: 1.45,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}
