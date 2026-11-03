// lib/modules/ui/golden_audit_dialog.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../logic.dart';
import '../services/golden_audit_service.dart';
import 'styles.dart';

/// Show Golden Audit & Fixture Health Index (FHI) Frosted Glass Dialog
Future<void> showGoldenAuditDialog({
  required BuildContext context,
  VoidCallback? onDialogClosed,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'GoldenAuditDialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => const GoldenAuditDialog(),
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

class GoldenAuditDialog extends StatefulWidget {
  const GoldenAuditDialog({super.key});

  @override
  State<GoldenAuditDialog> createState() => _GoldenAuditDialogState();
}

class _GoldenAuditDialogState extends State<GoldenAuditDialog> {
  final FocusNode _focusNode = FocusNode();
  String? _actionFeedback;

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

  void _showFeedback(String msg) {
    setState(() => _actionFeedback = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _actionFeedback == msg) {
        setState(() => _actionFeedback = null);
      }
    });
  }

  Color _gradeColor(FixtureHealthGrade grade) => switch (grade) {
    FixtureHealthGrade.certified => const Color(0xFF10B981),
    FixtureHealthGrade.warning => const Color(0xFFF59E0B),
    FixtureHealthGrade.critical => const Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final monitor = Provider.of<AdbMonitor>(context);
    final audit = monitor.goldenAudit;

    return ListenableBuilder(
      listenable: audit,
      builder: (context, _) {
        final report = audit.latestReport;
        final shiftCert = audit.currentShiftCertificate();
        final shiftLabel = GoldenAuditService.resolveShiftLabel(DateTime.now());
        final isShiftCertified = shiftCert != null;
        final isTesting = monitor.isRfTesting;

        final syssn = (monitor.info['SYSSN'] ?? 'N/A').trim();
        final pcasn = (monitor.info['PCASN'] ?? 'N/A').trim();
        final syspn = (monitor.info['SYSPN'] ?? 'N/A').trim();
        final hasValidDut =
            monitor.deviceConnected &&
            monitor.currentDut.isNotEmpty &&
            pcasn.isNotEmpty &&
            pcasn != 'N/A' &&
            !pcasn.startsWith('Đang');
        final isCurrentGolden =
            hasValidDut &&
            audit.isRegisteredGoldenBoard(syssn: syssn, pcasn: pcasn);

        final effectiveGrade =
            report?.grade ?? (shiftCert?.grade ?? FixtureHealthGrade.warning);
        final scoreColor = report != null
            ? _gradeColor(effectiveGrade)
            : (isShiftCertified
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B));

        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              if (!isTesting) {
                Navigator.of(context).pop();
              }
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
                    padding: const EdgeInsets.all(13),
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
                    child: Column(
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
                                Icons.verified_user_rounded,
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
                                    'Kiểm chuẩn Đồ gá & Bo mẫu',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$shiftLabel • KGU: ${audit.goldenBoards.length}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.55)
                                          : Colors.black54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Shift certification badge
                            Tooltip(
                              message: isShiftCertified
                                  ? 'Đã cấp chứng chỉ lúc ${shiftCert.formattedCertifiedTime} (Bo mẫu: ${shiftCert.goldenSyssn != "N/A" ? shiftCert.goldenSyssn : shiftCert.goldenPcasn})'
                                  : 'Chưa có Bo Mẫu KGU đạt FHI ≥ 85% trong ca này',
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isShiftCertified
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.15)
                                      : const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isShiftCertified
                                        ? const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.4)
                                        : const Color(
                                            0xFFF59E0B,
                                          ).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isShiftCertified
                                          ? Icons.verified_rounded
                                          : Icons.pending_actions_rounded,
                                      size: 10,
                                      color: isShiftCertified
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isShiftCertified
                                          ? 'ĐÃ CHỨNG NHẬN'
                                          : 'CHƯA CHUẨN CA',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: isShiftCertified
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              onPressed: isTesting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              tooltip: 'Đóng (Esc)',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // --- BODY ---
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Card: FHI Score Gauge & KGU status
                              SizedBox(
                                width: 118,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: scoreColor.withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'CHỈ SỐ FHI',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        report != null
                                            ? '${report.fhiScore}%'
                                            : (shiftCert != null
                                                  ? '${shiftCert.fhiScore}%'
                                                  : '--%'),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: scoreColor,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scoreColor.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          report != null
                                              ? report.grade.shortLabel
                                              : (shiftCert != null
                                                    ? shiftCert.grade.shortLabel
                                                    : 'NO DUT'),
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: scoreColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isCurrentGolden)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFF59E0B,
                                            ).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star_rounded,
                                                size: 10,
                                                color: Color(0xFFF59E0B),
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'BO MẪU KGU',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFF59E0B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Text(
                                          hasValidDut
                                              ? (syssn != 'N/A' &&
                                                        syssn != 'Chưa test MMI'
                                                    ? syssn
                                                    : pcasn)
                                              : 'Chưa cắm DUT',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Right Card: 4 Pillars + Diagnostics Note
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildPillarBar(
                                        label: 'Sóng PowerG',
                                        score: report?.powerGScore ?? 0,
                                        maxScore: 30,
                                        color: const Color(0xFF00C6FF),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 5),
                                      _buildPillarBar(
                                        label: 'Sóng SRF & Golden',
                                        score: report?.srfScore ?? 0,
                                        maxScore: 30,
                                        color: const Color(0xFFA855F7),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 5),
                                      _buildPillarBar(
                                        label: 'Cáp USB / Kim Pogo',
                                        score: report?.busStabilityScore ?? 0,
                                        maxScore: 20,
                                        color: const Color(0xFF10B981),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 5),
                                      _buildPillarBar(
                                        label: 'Định danh & BOM',
                                        score: report?.identityScore ?? 0,
                                        maxScore: 20,
                                        color: const Color(0xFFF59E0B),
                                        isDark: isDark,
                                      ),
                                      const Spacer(),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.black.withValues(
                                                  alpha: 0.25,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          _actionFeedback ??
                                              (report != null &&
                                                      report
                                                          .diagnosticsNotes
                                                          .isNotEmpty
                                                  ? report
                                                        .diagnosticsNotes
                                                        .first
                                                  : 'Cắm Bo Mẫu KGU đầu ca để tự động chấm điểm FHI & cấp chứng chỉ.'),
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            height: 1.2,
                                            color: _actionFeedback != null
                                                ? const Color(0xFF10B981)
                                                : (isDark
                                                      ? Colors.white70
                                                      : Colors.black87),
                                            fontWeight: _actionFeedback != null
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // --- FOOTER BUTTONS ---
                        Row(
                          children: [
                            // 1. Register / Unregister Golden Board
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: !hasValidDut
                                    ? null
                                    : () {
                                        if (isCurrentGolden) {
                                          audit.unregisterGoldenBoard(
                                            syssn: syssn,
                                            pcasn: pcasn,
                                          );
                                          _showFeedback(
                                            'Đã gỡ khỏi danh sách Bo Mẫu KGU.',
                                          );
                                        } else {
                                          final model =
                                              report?.modelName ?? 'DUT';
                                          audit.registerGoldenBoard(
                                            syssn: syssn,
                                            pcasn: pcasn,
                                            syspn: syspn,
                                            modelName: model,
                                            baselinePowerGMs:
                                                monitor
                                                    .powerGResult
                                                    ?.durationMs ??
                                                0,
                                            baselineSrfMs:
                                                monitor.srfResult?.durationMs ??
                                                0,
                                          );
                                          _showFeedback(
                                            'Đã đăng ký làm Bo Mẫu Chuẩn (KGU)!',
                                          );
                                        }
                                      },
                                icon: Icon(
                                  isCurrentGolden
                                      ? Icons.star_outline_rounded
                                      : Icons.workspace_premium_rounded,
                                  size: 13,
                                ),
                                label: Text(
                                  isCurrentGolden ? 'Gỡ KGU' : 'Đ.Ký KGU',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCurrentGolden
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 7,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 2. Re-evaluate / Retest RF
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: (!hasValidDut || isTesting)
                                    ? null
                                    : () {
                                        monitor.retestRf();
                                        _showFeedback(
                                          'Đang đo lại sóng RF & chấm FHI...',
                                        );
                                      },
                                icon: isTesting
                                    ? const SizedBox(
                                        width: 11,
                                        height: 11,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 13,
                                      ),
                                label: Text(
                                  isTesting ? 'Đang đo...' : 'Chấm lại',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0084FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 7,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 3. Copy Certificate
                            Flexible(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final text = report != null
                                      ? report.formatAuditCertificate()
                                      : 'Ca hiện tại: $shiftLabel — ${isShiftCertified ? "ĐÃ CHỨNG NHẬN (FHI: ${shiftCert.fhiScore}%)" : "CHƯA KIỂM CHUẨN ĐẦU CA"}';
                                  Clipboard.setData(ClipboardData(text: text));
                                  _showFeedback(
                                    'Đã sao chép Biên bản Kiểm chuẩn FHI!',
                                  );
                                },
                                icon: const Icon(
                                  Icons.content_copy_rounded,
                                  size: 12,
                                ),
                                label: const Text(
                                  'Copy C.Chỉ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black26,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 7,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPillarBar({
    required String label,
    required int score,
    required int maxScore,
    required Color color,
    required bool isDark,
  }) {
    final fraction = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              '$score/$maxScore',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4.5,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
