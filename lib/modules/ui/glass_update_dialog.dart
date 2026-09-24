import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'styles.dart';
import '../constants.dart';
import '../services/ota_update_service.dart';

/// Mở hộp thoại cập nhật Bento Frosted Glass
Future<void> showGlassUpdateDialog({
  required BuildContext context,
  required UpdatePackageInfo packageInfo,
  VoidCallback? onDialogClosed,
}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  final isDark = theme.isDark;

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'GlassUpdateDialog',
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) =>
        GlassUpdateDialog(packageInfo: packageInfo),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.94,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  ).then((_) {
    onDialogClosed?.call();
  });
}

/// Hộp thoại thông báo cập nhật Bento Frosted Glass gọn gàng
class GlassUpdateDialog extends StatefulWidget {
  final UpdatePackageInfo packageInfo;

  const GlassUpdateDialog({super.key, required this.packageInfo});

  @override
  State<GlassUpdateDialog> createState() => _GlassUpdateDialogState();
}

class _GlassUpdateDialogState extends State<GlassUpdateDialog> {
  bool _isUpdating = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusText = 'Khởi tạo cập nhật...';
    });

    try {
      await OtaUpdateService().performUpdate(
        widget.packageInfo,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _progress = prog;
              _statusText = status;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;

    const accentCyan = Color(0xFF00ADB5);
    const accentEmerald = Color(0xFF10B981);
    const accentRose = Color(0xFFEF4444);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!_isUpdating &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 305),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.96)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.16 : 0.10,
                ),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? 0.04 : 0.03),
                        border: Border(
                          bottom: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), accentCyan],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: accentCyan.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.system_update_alt_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cập nhật JA_DUT_Info',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Đã phát hiện bản mới: ${widget.packageInfo.version.displayVersion}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: accentEmerald,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isUpdating)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              tooltip: 'Đóng',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              splashRadius: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),
                    ),

                    // 2. Body
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Version comparison badge row
                          Row(
                            children: [
                              // Current Version
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(
                                              alpha: isDark ? 0.05 : 0.04,
                                            ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hiện tại',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontFamily: 'Outfit',
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'v$appVersion',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Outfit',
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: accentCyan,
                                ),
                              ),
                              // New Version
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentEmerald.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: accentEmerald.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bản mới nhất',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontFamily: 'Outfit',
                                          color: accentEmerald,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Row(
                                        children: [
                                          Text(
                                            widget
                                                .packageInfo
                                                .version
                                                .displayVersion,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Outfit',
                                              color: accentEmerald,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            widget.packageInfo.formattedSize,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontFamily: 'Outfit',
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Release Notes Section
                          Row(
                            children: [
                              const Icon(
                                Icons.article_outlined,
                                size: 12,
                                color: accentCyan,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nội dung cập nhật',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                  color: accentCyan,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 70),
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (isDark ? Colors.black : Colors.grey.shade100)
                                      .withValues(alpha: isDark ? 0.35 : 0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.packageInfo.releaseNotes
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? widget.packageInfo.releaseNotes!
                                    : 'Bản phát hành bao gồm các cải tiến hiệu năng, tính năng mới và các bản vá lỗi bảo mật.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.35,
                                  fontFamily: 'Outfit',
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          // Progress Bar & Status
                          if (_isUpdating) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress,
                                backgroundColor:
                                    (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  accentCyan,
                                ),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Outfit',
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                    color: accentCyan,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Error Message if failed
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accentRose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentRose.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 14,
                                    color: accentRose,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Outfit',
                                        color: accentRose,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 3. Footer Buttons
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? 0.03 : 0.02),
                        border: Border(
                          top: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!_isUpdating)
                            OutlinedButton(
                              key: const ValueKey('btn-update-later'),
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                foregroundColor: isDark
                                    ? Colors.white70
                                    : Colors.black87,
                                side: BorderSide(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.16),
                                ),
                              ),
                              child: const Text(
                                'Để sau',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            key: const ValueKey('btn-update-now'),
                            onPressed: _isUpdating ? null : _startUpdate,
                            icon: _isUpdating
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 14),
                            label: Text(
                              _isUpdating
                                  ? 'Đang cập nhật...'
                                  : 'Cập nhật ngay',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: accentEmerald,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
