import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'styles.dart';
import '../services/ota_update_service.dart';

/// Mở hộp thoại cấu hình LAN OTA
Future<void> showOtaSettingsDialog({
  required BuildContext context,
  VoidCallback? onDialogClosed,
}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  final isDark = theme.isDark;

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'OtaSettingsDialog',
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => const OtaSettingsDialog(),
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

class OtaSettingsDialog extends StatefulWidget {
  const OtaSettingsDialog({super.key});

  @override
  State<OtaSettingsDialog> createState() => _OtaSettingsDialogState();
}

class _OtaSettingsDialogState extends State<OtaSettingsDialog> {
  late TextEditingController _serverPathController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late String _checkInterval;

  bool _isTesting = false;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final config = OtaUpdateService().config;
    _serverPathController = TextEditingController(text: config.serverPath);
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    _checkInterval = config.checkInterval;
  }

  @override
  void dispose() {
    _serverPathController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
    });

    final path = _serverPathController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    try {
      final connected = await OtaUpdateService().connectSmbShare(
        path: path,
        username: user,
        password: pass,
      );
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = connected;
          _testMessage = connected
              ? 'Kết nối máy chủ LAN thành công!'
              : 'Không thể truy cập thư mục máy chủ.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testMessage = 'Lỗi kết nối: $e';
        });
      }
    }
  }

  void _openConfigFolder() {
    final file = OtaUpdateService().getConfigFile();
    if (Platform.isWindows) {
      if (file.existsSync()) {
        Process.run('explorer.exe', ['/select,', file.path]);
      } else {
        Process.run('explorer.exe', [file.parent.path]);
      }
    }
  }

  Future<void> _saveConfig() async {
    final current = OtaUpdateService().config;
    final updated = current.copyWith(
      serverPath: _serverPathController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      checkInterval: _checkInterval,
    );
    await OtaUpdateService().saveExternalConfigFile(updated);
    if (mounted) {
      Navigator.of(context).pop();
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
        if (event is KeyDownEvent &&
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
            width: 410,
            constraints: const BoxConstraints(maxHeight: 315),
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
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
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), accentCyan],
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.settings_suggest_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cài đặt LAN OTA Update',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.folder_open_rounded,
                              size: 16,
                            ),
                            tooltip: 'Mở thư mục config',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            splashRadius: 16,
                            color: accentCyan,
                            onPressed: _openConfigFolder,
                          ),
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

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Server Path
                            Text(
                              'Đường dẫn máy chủ LAN (UNC Share):',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                              height: 32,
                              child: TextField(
                                controller: _serverPathController,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Outfit',
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  hintText:
                                      r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_DUT_Info',
                                  hintStyle: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Username & Password row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tài khoản:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'Outfit',
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 30,
                                        child: TextField(
                                          controller: _usernameController,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Outfit',
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mật khẩu:',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'Outfit',
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      SizedBox(
                                        height: 30,
                                        child: TextField(
                                          controller: _passwordController,
                                          obscureText: true,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Outfit',
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                            isDense: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Check Interval row
                            Row(
                              children: [
                                Text(
                                  'Tần suất kiểm tra:',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Outfit',
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 28,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _checkInterval,
                                      isDense: true,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'Outfit',
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'daily',
                                          child: Text(
                                            'Hàng ngày (Khuyên dùng)',
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'weekly',
                                          child: Text('Hàng tuần'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'monthly',
                                          child: Text('Hàng tháng'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'off',
                                          child: Text('Tắt tự động kiểm tra'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _checkInterval = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Test Connection row
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _isTesting
                                      ? null
                                      : _testConnection,
                                  icon: _isTesting
                                      ? const SizedBox(
                                          width: 11,
                                          height: 11,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  accentCyan,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.network_check_rounded,
                                          size: 13,
                                        ),
                                  label: Text(
                                    _isTesting
                                        ? 'Đang kiểm tra...'
                                        : 'Thử kết nối máy chủ',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    foregroundColor: accentCyan,
                                    side: const BorderSide(
                                      color: accentCyan,
                                      width: 0.9,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_testMessage != null)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          _testSuccess == true
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded,
                                          size: 14,
                                          color: _testSuccess == true
                                              ? accentEmerald
                                              : accentRose,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _testMessage!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.w600,
                                              color: _testSuccess == true
                                                  ? accentEmerald
                                                  : accentRose,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Buttons
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
                          OutlinedButton(
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
                            ),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saveConfig,
                            style: FilledButton.styleFrom(
                              backgroundColor: accentCyan,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                            ),
                            child: const Text(
                              'Lưu cấu hình',
                              style: TextStyle(
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
