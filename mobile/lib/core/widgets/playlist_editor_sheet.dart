import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../../features/library/presentation/cubit/library_cubit.dart';
import '../theme/app_colors.dart';
import 'playlist_cover_mosaic.dart';

/// Bottom sheet partagée pour créer ou modifier une playlist sans dupliquer la logique.
class PlaylistEditorSheet extends StatefulWidget {
  final PlaylistModel? existingPlaylist;

  const PlaylistEditorSheet({
    super.key,
    this.existingPlaylist,
  });

  /// Ouvre la feuille de création/édition et retourne la playlist créée ou mise à jour.
  static Future<PlaylistModel?> show(
    BuildContext context, {
    PlaylistModel? existingPlaylist,
  }) {
    final libraryCubit = context.read<LibraryCubit>();
    return showModalBottomSheet<PlaylistModel>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: libraryCubit,
        child: PlaylistEditorSheet(existingPlaylist: existingPlaylist),
      ),
    );
  }

  @override
  State<PlaylistEditorSheet> createState() => _PlaylistEditorSheetState();
}

class _PlaylistEditorSheetState extends State<PlaylistEditorSheet> {
  late final TextEditingController _nameController;
  String? _selectedLocalPath;
  bool _clearCustomCover = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingPlaylist != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingPlaylist?.name ?? '');
    final existingCover = widget.existingPlaylist?.coverUrl ?? '';
    if (existingCover.startsWith('file://') ||
        existingCover.startsWith('http://local.image/')) {
      final path = existingCover
          .replaceFirst('file://', '')
          .replaceFirst('http://local.image/', '');
      if (path.isNotEmpty && File(path).existsSync()) {
        _selectedLocalPath = path;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<String?> _persistPickedImage(XFile pickedFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savedFile = File(
        '${dir.path}/playlist_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(pickedFile.path).copy(savedFile.path);
      return savedFile.path;
    } catch (_) {
      return pickedFile.path;
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (pickedFile == null || !mounted) return;
    final savedPath = await _persistPickedImage(pickedFile);
    if (!mounted) return;
    setState(() {
      _selectedLocalPath = savedPath;
      _clearCustomCover = false;
    });
  }

  bool get _hasCustomCover {
    if (_clearCustomCover) return false;
    if (_selectedLocalPath != null && File(_selectedLocalPath!).existsSync()) {
      return true;
    }
    final remote = widget.existingPlaylist?.coverUrl ?? '';
    return remote.isNotEmpty &&
        !remote.startsWith('file://') &&
        !remote.startsWith('http://local.image/');
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final libraryCubit = context.read<LibraryCubit>();

    if (_isEditing) {
      final existing = widget.existingPlaylist!;
      String? nextCover;
      if (_clearCustomCover) {
        nextCover = '';
      } else if (_selectedLocalPath != null) {
        nextCover = 'http://local.image/$_selectedLocalPath';
      }
      await libraryCubit.updatePlaylistDetails(
        existing.id,
        name: name,
        coverUrl: nextCover,
      );
      final normalizedCover = nextCover != null && nextCover.startsWith('http://local.image/')
          ? nextCover.replaceFirst('http://local.image/', 'file://')
          : nextCover;
      if (!mounted) return;
      Navigator.pop(
        context,
        existing.copyWith(
          name: name,
          coverUrl: normalizedCover ?? existing.coverUrl,
        ),
      );
      return;
    }

    final cover = _selectedLocalPath != null ? 'http://local.image/$_selectedLocalPath' : '';
    PlaylistModel? optimisticResult;
    var popped = false;

    final future = libraryCubit.createPlaylist(
      name,
      coverUrl: cover,
      onOptimisticCreated: (localPlaylist) {
        optimisticResult = localPlaylist;
        if (mounted && !popped) {
          popped = true;
          Navigator.pop(context, localPlaylist);
        }
      },
    );

    final created = await future;
    if (mounted && !popped) {
      popped = true;
      Navigator.pop(context, optimisticResult ?? created);
    }
  }

  Widget _buildCoverPreview() {
    if (!_clearCustomCover &&
        _selectedLocalPath != null &&
        File(_selectedLocalPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(_selectedLocalPath!),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_isEditing) {
      final previewModel = _clearCustomCover
          ? widget.existingPlaylist!.copyWith(coverUrl: '')
          : widget.existingPlaylist!;
      return PlaylistCoverMosaic(
        playlist: previewModel,
        size: 120,
        height: 126,
        borderRadius: 16,
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.primary.withValues(alpha: 0.9),
            size: 32,
          ),
          const SizedBox(height: 6),
          Text(
            "Pochette",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141418),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isEditing ? "Modifier la playlist" : "Nouvelle playlist",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _pickCoverImage,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomRight,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _buildCoverPreview(),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF141418),
                              width: 2.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasCustomCover) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.65),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedLocalPath = null;
                        _clearCustomCover = true;
                      });
                    },
                    icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 15),
                    label: const Text(
                      "Utiliser la mosaïque 3 pochettes",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: "Nom de la playlist",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nameController,
                  builder: (context, value, _) {
                    final canSubmit = value.text.trim().isNotEmpty && !_isSubmitting;
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmit
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: canSubmit ? _submit : null,
                        child: Text(
                          _isEditing ? "Enregistrer" : "Créer la playlist",
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: canSubmit ? Colors.black : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: Text(
                    "Annuler",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
