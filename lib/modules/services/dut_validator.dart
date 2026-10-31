// lib/modules/services/dut_validator.dart

/// Smart hardware parameter validation and cross-model consistency checker
/// for Qolsys IQ4 / IQ5 DUTs.
class DutValidator {
  const DutValidator._();

  static const Set<String> _transientValues = {
    'N/A',
    'Đang đọc...',
    'Đang chờ boot...',
    'Đang kiểm tra...',
    'Đang kiểm tra sóng RF...',
    'Loading...',
  };

  static bool _isTransient(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty || _transientValues.contains(trimmed);
  }

  /// Validates a 15-digit IMEI using the standard Luhn checksum algorithm.
  static bool isValidImei(String rawImei) {
    final clean = rawImei.trim().replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{15}$').hasMatch(clean)) return false;
    if (clean == '000000000000000') return false;

    int sum = 0;
    for (int i = 0; i < 15; i++) {
      int digit = int.parse(clean[i]);
      // In a 15-digit IMEI, odd 0-based indices (1, 3, ..., 13) are doubled
      if (i.isOdd) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  static bool _isExplicitIq5Pcasn(String pcasn) {
    final u = pcasn.trim().toUpperCase();
    return u.startsWith('QB95') || u.startsWith('QB85') || u.startsWith('QC95');
  }

  static bool _isExplicitIq4Pcasn(String pcasn) {
    final u = pcasn.trim().toUpperCase();
    return u.startsWith('QB94') ||
        u.startsWith('QB84') ||
        u.startsWith('QB74') ||
        u.startsWith('QB64') ||
        u.startsWith('QC94') ||
        u.startsWith('QD94');
  }

  static bool _isExplicitIq5Sys(String syssn, String syspn) {
    final sn = syssn.trim().toUpperCase();
    final pn = syspn.trim().toUpperCase();
    return sn.startsWith('QP5') ||
        sn.startsWith('QH5') ||
        sn.startsWith('QR5') ||
        pn.startsWith('IQP5') ||
        pn.startsWith('IQH5') ||
        pn.startsWith('IQR5') ||
        pn.startsWith('IQ5');
  }

  static bool _isExplicitIq4Sys(String syssn, String syspn) {
    final sn = syssn.trim().toUpperCase();
    final pn = syspn.trim().toUpperCase();
    return sn.startsWith('QP4') ||
        sn.startsWith('QH4') ||
        sn.startsWith('QR4') ||
        sn.startsWith('QPH') ||
        pn.startsWith('IQP4') ||
        pn.startsWith('IQH4') ||
        pn.startsWith('IQR4') ||
        pn.startsWith('IQRP') ||
        pn.startsWith('IQ4');
  }

  /// Detects cross-model mismatch between board PCASN and system SYSSN/SYSPN
  /// (e.g., IQ5 board flashed with IQ4 system serial/part number or vice versa).
  static bool hasModelMismatch(Map<String, String> info) {
    final pcasn = info['PCASN'] ?? '';
    final syssn = info['SYSSN'] ?? '';
    final syspn = info['SYSPN'] ?? '';

    if (_isTransient(pcasn)) return false;

    final pcasnIs5 = _isExplicitIq5Pcasn(pcasn);
    final pcasnIs4 = _isExplicitIq4Pcasn(pcasn);
    if (!pcasnIs5 && !pcasnIs4) return false;

    final validSyssn = !_isTransient(syssn) && syssn != 'Chưa test MMI'
        ? syssn
        : '';
    final validSyspn = !_isTransient(syspn) && syspn != 'Chưa test MMI'
        ? syspn
        : '';

    if (pcasnIs5 && _isExplicitIq4Sys(validSyssn, validSyspn)) {
      return true;
    }
    if (pcasnIs4 && _isExplicitIq5Sys(validSyssn, validSyspn)) {
      return true;
    }
    return false;
  }

  /// Evaluates whether a specific field card should render in warning state.
  static bool isFieldWarning(
    String key,
    String value,
    Map<String, String> allInfo,
  ) {
    final trimmed = value.trim();
    if (_isTransient(trimmed)) return false;

    switch (key) {
      case 'LCMPN':
        return trimmed.contains('không được chạy lại') ||
            trimmed.contains('ko nạp màn hình') ||
            trimmed.contains('lỗi hiển thị');
      case 'PCASN':
        return hasModelMismatch(allInfo);
      case 'SYSSN':
      case 'SYSPN':
        if (trimmed == 'Chưa test MMI') return true;
        return hasModelMismatch(allInfo);
      case 'IMEI':
        return !isValidImei(trimmed);
      case 'CPU':
        final lower = trimmed.toLowerCase();
        return lower == 'msm' || lower == 'unknown' || lower.contains('error');
      case 'RF':
        final upper = trimmed.toUpperCase();
        return upper.contains('FAIL') ||
            upper.contains('LỖI') ||
            trimmed.contains('Lỗi');
      default:
        return false;
    }
  }
}
