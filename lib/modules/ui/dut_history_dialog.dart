// lib/modules/ui/dut_history_dialog.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'styles.dart';
import '../logic.dart';
import '../services/dut_history_service.dart';

/// Show Session DUT History Frosted Glass Dialog
Future<void> showDutHistoryDialog({
  required BuildContext context,
  VoidCallback? onDialogClosed,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'DutHistoryDialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => const DutHistoryDialog(),
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

class DutHistoryDialog extends StatefulWidget {
  const DutHistoryDialog({super.key});

  @override
  State<DutHistoryDialog> createState() => _DutHistoryDialogState();
}

class _DutHistoryDialogState extends State<DutHistoryDialog> {
  final FocusNode _focusNode = FocusNode();
  String? _copiedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _copyText(String text, String feedback) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedStatus = feedback);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedStatus == feedback) {
        setState(() => _copiedStatus = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final monitor = Provider.of<AdbMonitor>(context);
    final history = monitor.history;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 396,
                height: 295,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141A24).withValues(alpha: 0.90)
                      : const Color(0xFFF0F4F8).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.70),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.45 : 0.18,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ListenableBuilder(
                  listenable: history,
                  builder: (context, _) {
                    final entries = history.entries;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- HEADER ---
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lịch sử DUT trong phiên (${entries.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    _copiedStatus ??
                                        'Lưu tối đa 30 DUT gần nhất ngay cả khi đã rút cáp',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: _copiedStatus != null
                                          ? const Color(0xFF10B981)
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : Colors.black54),
                                      fontWeight: _copiedStatus != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              tooltip: 'Đóng (Esc)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // --- BODY: LIST OF HISTORICAL DUTS ---
                        Expanded(
                          child: entries.isEmpty
                              ? Center(
                                  child: Text(
                                    'Chưa có thiết bị DUT nào được ghi nhận trong phiên.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: entries.length,
                                  padding: EdgeInsets.zero,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 5),
                                  itemBuilder: (ctx, i) =>
                                      _buildHistoryItem(entries[i], isDark),
                                ),
                        ),

                        const SizedBox(height: 8),

                        // --- FOOTER ---
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: entries.isEmpty
                                  ? null
                                  : () => _copyText(
                                      history.formatAllHistoryReport(),
                                      'Đã sao chép toàn bộ ${entries.length} bản ghi!',
                                    ),
                              icon: const Icon(
                                Icons.copy_all_rounded,
                                size: 13,
                              ),
                              label: const Text(
                                'Copy tất cả',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0084FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (entries.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  history.clearHistory();
                                  setState(
                                    () => _copiedStatus = 'Đã xóa lịch sử.',
                                  );
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 13,
                                  color: Color(0xFFEF4444),
                                ),
                                label: const Text(
                                  'Xóa',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 7,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              child: const Text(
                                'Đóng',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(DutHistoryEntry entry, bool isDark) {
    final isIq5 = entry.modelName == 'IQ5';
    final modelColor = isIq5
        ? const Color(0xFF00C6FF)
        : const Color(0xFFA855F7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: modelColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: modelColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              entry.modelName,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: modelColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.syssn != "N/A" ? entry.syssn : entry.pcasn} • ${entry.stationResult}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      entry.formattedTime,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'PCA: ${entry.pcasn} | IMEI: ${entry.imei}',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Sao chép thông số DUT này',
            child: InkWell(
              onTap: () => _copyText(
                entry.formatReport(),
                'Đã copy: ${entry.syssn != "N/A" ? entry.syssn : entry.pcasn}',
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0084FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.content_copy_rounded,
                  size: 12,
                  color: Color(0xFF0084FF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
