import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';

const _maxAttachmentSize = 10 * 1024 * 1024;
const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'pdf', 'mp4', 'mov'};

class AttachmentPicker extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<PlatformFile> files;
  final ValueChanged<List<PlatformFile>> onChanged;
  final bool allowCamera;

  const AttachmentPicker({
    super.key,
    required this.title,
    required this.emptyText,
    required this.files,
    required this.onChanged,
    this.allowCamera = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showPickerMenu(context),
                icon: const Icon(Icons.add_circle_outline_sharp, size: 16),
                label: const Text('ДОБАВИТЬ'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                emptyText.toUpperCase(),
                style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            )
          else
            ...files.asMap().entries.map(
                  (entry) => _PickedFileRow(
                    file: entry.value,
                    onRemove: () {
                      final next = [...files]..removeAt(entry.key);
                      onChanged(next);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showPickerMenu(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_sharp),
                title: const Text('СДЕЛАТЬ ФОТО'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_sharp),
              title: const Text('ВЫБРАТЬ ИЗОБРАЖЕНИЕ'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.description_sharp),
              title: const Text('ВЫБРАТЬ ФАЙЛ'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    PlatformFile? file;
    if (source == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions.toList(),
        withData: true,
      );
      file = result?.files.single;
    } else {
      final image = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 88,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        file = PlatformFile(name: image.name, size: bytes.length, bytes: bytes);
      }
    }

    if (file == null) return;
    final error = validateAttachment(file);
    if (error != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toUpperCase()), backgroundColor: AppColors.brandRed));
      return;
    }
    onChanged([...files, file]);
  }
}

class AttachmentList extends StatelessWidget {
  final List<Attachment> attachments;

  const AttachmentList({super.key, required this.attachments});

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'ВЛОЖЕНИЯ',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        ...attachments.map(
          (item) => InkWell(
            onTap: () => openAttachment(item.url),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(_iconFor(item.fileType), color: AppColors.brandRed, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name.toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: AppColors.brandBlack, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.open_in_new_sharp, size: 14, color: AppColors.textHint),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String? validateAttachment(PlatformFile file) {
  final extension = (file.extension ?? file.name.split('.').last).toLowerCase();
  if (!_allowedExtensions.contains(extension)) {
    return 'Недопустимый формат файла';
  }
  if (file.size > _maxAttachmentSize) {
    return 'Максимальный размер 10 МБ';
  }
  if (file.bytes == null) {
    return 'Ошибка чтения файла';
  }
  return null;
}

Future<void> openAttachment(String url) async {
  final uri = _attachmentUri(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Uri _attachmentUri(String url) {
  final parsed = Uri.parse(url);
  if (parsed.hasScheme) return parsed;
  final api = Uri.parse(ApiClient.baseUrl);
  return api.replace(path: url, query: '');
}

IconData _iconFor(String type) {
  switch (type) {
    case 'image':
      return Icons.image_sharp;
    case 'pdf':
      return Icons.picture_as_pdf_sharp;
    case 'video':
      return Icons.videocam_sharp;
    default:
      return Icons.insert_drive_file_sharp;
  }
}

class _PickedFileRow extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;

  const _PickedFileRow({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.attach_file_sharp, size: 18, color: AppColors.brandRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.brandBlack, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_sharp, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
