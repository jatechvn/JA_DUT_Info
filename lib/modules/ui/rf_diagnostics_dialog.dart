// lib/modules/ui/rf_diagnostics_dialog.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'styles.dart';
import '../logic.dart';
import '../services/powerg_service.dart';
import '../services/srf_service.dart';

/// Show RF Diagnostics Frosted Glass Dialog
Future<void> showRfDiagnosticsDialog({
  required BuildContext context,
  VoidCallback? onDialogClosed,
}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  final isDark = theme.isDark;

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'RfDiagnosticsDialog',
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => const RfDiagnosticsDialog(),
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

class RfDiagnosticsDialog extends StatefulWidget {
  const RfDiagnosticsDialog({super.key});

  @override
  State<RfDiagnosticsDialog> createState() => _RfDiagnosticsDialogState();
}

class _RfDiagnosticsDialogState extends State<RfDiagnosticsDialog> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final monitor = Provider.of<AdbMonitor>(context);

    final pg = monitor.powerGResult;
    final srf = monitor.srfResult;
    final isTesting = monitor.isRfTesting;

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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141A24).withValues(alpha: 0.88)
                      : const Color(0xFFF0F4F8).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.70),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
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
                            color: const Color(0xFF0084FF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cell_tower_rounded,
                            size: 16,
                            color: Color(0xFF0084FF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chẩn đoán Sóng RF',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Text(
                                monitor.currentDut.isNotEmpty
                                    ? 'DUT: ${monitor.currentDut}'
                                    : 'Chưa có thiết bị',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          onPressed: isTesting ? null : () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          tooltip: 'Đóng (Esc)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // --- BODY: 2 BENTO TILES ---
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. PowerG Tile
                          Expanded(
                            child: _buildBentoCard(
                              title: 'PowerG',
                              icon: Icons.wifi_tethering_rounded,
                              accentColor: const Color(0xFF00C6FF),
                              isDark: isDark,
                              child: _buildPowerGContent(pg, isTesting, isDark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 2. SRF Tile
                          Expanded(
                            child: _buildBentoCard(
                              title: 'SRF (319/345/433)',
                              icon: Icons.sensors_rounded,
                              accentColor: const Color(0xFFA855F7),
                              isDark: isDark,
                              child: _buildSrfContent(srf, monitor.goldenPanelSerial, isTesting, isDark),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // --- FOOTER BUTTONS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Retest button
                        ElevatedButton.icon(
                          onPressed: isTesting
                              ? null
                              : () => monitor.retestRf(),
                          icon: isTesting
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 14),
                          label: Text(
                            isTesting ? 'Đang test...' : 'Kiểm tra lại',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0084FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        // Close button
                        TextButton(
                          onPressed: isTesting ? null : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          ),
                          child: const Text('Đóng', style: TextStyle(fontSize: 11)),
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
  }

  Widget _buildBentoCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPowerGContent(PowerGResult? pg, bool isTesting, bool isDark) {
    if (isTesting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 6),
            Text(
              'Đang kiểm tra...',
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    if (pg == null || !pg.isInstalled) {
      return Center(
        child: Text(
          'Không phát hiện card PowerG',
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isPass = pg.status == PowerGStatus.pass;
    final statusColor = isPass
        ? const Color(0xFF10B981)
        : (pg.status == PowerGStatus.mcuOk ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPass ? Icons.check_circle_rounded : (pg.status == PowerGStatus.mcuOk ? Icons.info_rounded : Icons.cancel_rounded),
                size: 11,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                isPass ? 'PASS' : (pg.status == PowerGStatus.mcuOk ? 'MCU OK' : 'FAIL'),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildInfoRow('Tần số:', pg.frequency, isDark),
        _buildInfoRow('FW MCU:', pg.fw, isDark),
        if (pg.comPort != null) _buildInfoRow('Cổng phát:', pg.comPort!, isDark),
        if (pg.sensorId != null) _buildInfoRow('Sensor ID:', pg.sensorId!, isDark),
      ],
    );
  }

  Widget _buildSrfContent(SrfResult? srf, String? goldenSerial, bool isTesting, bool isDark) {
    if (isTesting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 6),
            Text(
              'Đang kiểm tra...',
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    if (srf == null || !srf.isInstalled) {
      return Center(
        child: Text(
          'Không có card SRF\n(Matrix: 0000)',
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isPass = srf.status == SrfStatus.pass;
    final statusColor = isPass
        ? const Color(0xFF10B981)
        : (srf.status == SrfStatus.mcuOk ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPass ? Icons.check_circle_rounded : (srf.status == SrfStatus.mcuOk ? Icons.info_rounded : Icons.cancel_rounded),
                size: 11,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                isPass ? 'PASS' : (srf.status == SrfStatus.mcuOk ? 'MCU OK' : 'FAIL'),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildInfoRow('Matrix:', srf.matrix, isDark),
        if (goldenSerial != null) _buildInfoRow('Golden:', goldenSerial, isDark),
        Expanded(
          child: ListView.builder(
            itemCount: srf.slots.length,
            padding: EdgeInsets.zero,
            itemBuilder: (ctx, i) {
              final slot = srf.slots[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• Slot ${slot.slotNumber}: ${slot.frequency} (${slot.brand})',
                  style: TextStyle(fontSize: 9, color: isDark ? Colors.white70 : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
