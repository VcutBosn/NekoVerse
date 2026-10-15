import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';

import 'menu.dart' as menuui;
// import 'rat.dart' as ratui; // <- aktifkan saat rat.dart siap

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const NekoVerseApp());
}

final ValueNotifier<Color> accentNotifier =
    ValueNotifier(AccentPresets.crimson);

class AccentPresets {
  static const crimson = Color(0xFFD91E36);
  static const violet = Color(0xFFB794F6);
  static const cyan = Color(0xFF22D3EE);
  static const amber = Color(0xFFFBBF24);

  static const Map<String, Color> all = {
    'CRIMSON': crimson,
    'VIOLET': violet,
    'CYAN': cyan,
    'AMBER': amber,
  };

  static const Map<String, IconData> icons = {
    'CRIMSON': Icons.bloodtype_rounded,
    'VIOLET': Icons.auto_awesome_rounded,
    'CYAN': Icons.water_drop_rounded,
    'AMBER': Icons.local_fire_department_rounded,
  };

  static String labelOf(Color c) {
    for (final entry in all.entries) {
      if (entry.value == c) return entry.key;
    }
    return 'CRIMSON';
  }
}

// ═════════════════════════════════════════════════════════════════
// SECURE CREDENTIALS (layer 1 — embedded in APK)
// ═════════════════════════════════════════════════════════════════
class SecureCredentials {
  static const Map<String, String> _accounts = {
    'toya': '1122',
  };

  static bool matches(String username, String password) {
    final expected = _accounts[username.trim().toLowerCase()];
    return expected != null && expected == password;
  }
}

// ═════════════════════════════════════════════════════════════════
// APP SESSION — backend-only login, device binding, auto-login
// ═════════════════════════════════════════════════════════════════
class AppSession {
  static const _keyToken = 'nv_session_token';
  static const _keyDeviceId = 'nv_device_id';
  static const _keyUsername = 'nv_session_username';
  static const _keyRole = 'nv_session_role';
  static const _keyExpired = 'nv_session_expired';
  static const _keyUserId = 'nv_session_userid';
  static const _keyEmail = 'nv_session_email';
  static const _keyCreatedAt = 'nv_session_created_at';
  static const _keyAvatarPath = 'nv_session_avatar_path';

  static String? _token;
  static String? _deviceId;
  static UserProfile? _profile;

  static String? get token => _token;
  static String? get deviceId => _deviceId;
  static UserProfile? get profile => _profile;
  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _deviceId = prefs.getString(_keyDeviceId);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = _generateDeviceId();
      await prefs.setString(_keyDeviceId, _deviceId!);
    }
    final u = prefs.getString(_keyUsername);
    final r = prefs.getString(_keyRole);
    final e = prefs.getString(_keyExpired);
    final id = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyEmail) ?? '';
    final avatar = prefs.getString(_keyAvatarPath) ?? '';
    final createdAt = DateTime.tryParse(prefs.getString(_keyCreatedAt) ?? '') ??
        DateTime.now();
    if (u != null && r != null && e != null) {
      _profile = UserProfile(
        id: id ?? 'NEKO-UNKNOWN',
        username: u,
        avatarPath: avatar,
        expired: e,
        role: r,
        email: email,
        createdAt: createdAt,
      );
    }
  }

  static String _generateDeviceId() {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(24, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static UserProfile _profileFromServer(Map data) {
    final existing = _profile;
    return UserProfile(
      id: '${data['id'] ?? existing?.id ?? 'NEKO-UNKNOWN'}',
      username: '${data['username'] ?? existing?.username ?? ''}',
      avatarPath: existing?.avatarPath ?? '',
      expired: '${data['expired'] ?? existing?.expired ?? ''}',
      role: '${data['role'] ?? existing?.role ?? 'basic'}',
      email: '${data['email'] ?? existing?.email ?? ''}',
      createdAt:
          DateTime.tryParse('${data['created_at'] ?? data['createdAt'] ?? ''}') ??
              existing?.createdAt ??
              DateTime.now(),
    );
  }

  static Future<bool> refreshProfile() async {
    if (!hasToken) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('${Cfg.backendBase}/api/profile');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      req.headers.set('X-Device-ID', _deviceId ?? '');
      final res = await req.close().timeout(const Duration(seconds: 8));
      final bodyText = await utf8.decoder
          .bind(res)
          .join()
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final decoded = jsonDecode(bodyText);
      if (decoded is! Map || decoded['ok'] != true || decoded['user'] is! Map) {
        return false;
      }
      _profile =
          _profileFromServer(Map<String, dynamic>.from(decoded['user'] as Map));
      await _persistAll();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> validate() async {
    if (!hasToken) return false;
    try {
      final uri = Uri.parse('${Cfg.backendBase}/api/session');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final req =
            await client.getUrl(uri).timeout(const Duration(seconds: 8));
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
        req.headers.set('X-Device-ID', _deviceId ?? '');
        final res = await req.close().timeout(const Duration(seconds: 8));
        final bodyText = await utf8.decoder
            .bind(res)
            .join()
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(bodyText) as Map?;
          if (data != null && data['ok'] == true && data['valid'] == true) {
            final u = data['user'];
            if (u is Map) {
              _profile = _profileFromServer(Map<String, dynamic>.from(u));
              await _persistProfileCache();
            }
            return true;
          }
        }
        await clear();
        return false;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }

  static Future<String?> login({
    required String username,
    required String password,
  }) async {
    final user = username.trim();
    if (user.isEmpty || password.isEmpty) {
      return 'Username dan password wajib diisi.';
    }

    try {
      final uri = Uri.parse('${Cfg.backendBase}/api/login');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final req =
            await client.postUrl(uri).timeout(const Duration(seconds: 12));
        req.headers.contentType = ContentType.json;
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        req.write(jsonEncode({
          'username': user,
          'password': password,
          'device_id': _deviceId,
        }));

        final res = await req.close().timeout(const Duration(seconds: 12));
        final bodyText = await utf8.decoder
            .bind(res)
            .join()
            .timeout(const Duration(seconds: 12));

        Map<String, dynamic> data;
        try {
          final decoded = jsonDecode(bodyText);
          if (decoded is! Map) {
            return 'Respons server tidak valid.';
          }
          data = Map<String, dynamic>.from(decoded);
        } catch (_) {
          return 'Respons server bukan JSON.';
        }

        if (res.statusCode == 200 && data['ok'] == true) {
          final newToken = '${data['access_token'] ?? data['token'] ?? ''}';
          if (newToken.isEmpty) return 'Token tidak diterima dari server.';

          _token = newToken;
          final u = data['user'];
          if (u is Map) {
            _profile = _profileFromServer(Map<String, dynamic>.from(u));
          }

          if (_profile == null) {
            await clear();
            return 'Data akun dari server tidak lengkap.';
          }

          await _persistAll();
          return null;
        }

        switch ('${data['error'] ?? ''}') {
          case 'device_mismatch':
            return 'Akun sudah terikat ke perangkat lain.';
          case 'device_already_has_account':
            return 'Perangkat ini sudah terikat ke akun lain.';
          case 'license_expired':
            return 'Masa aktif akun sudah berakhir.';
          case 'rate_limited':
            return 'Terlalu banyak percobaan. Coba lagi nanti.';
          case 'invalid_credentials':
            return 'Username atau password salah.';
          case 'device_id_required':
            return 'ID perangkat tidak ditemukan.';
          default:
            return '${data['message'] ?? data['error'] ?? 'Login gagal.'}';
        }
      } finally {
        client.close(force: true);
      }
    } on TimeoutException {
      return 'Server tidak menjawab. Periksa koneksi dan coba lagi.';
    } on SocketException {
      return 'Tidak bisa terhubung ke server. Periksa koneksi internet.';
    } catch (e) {
      return 'Terjadi kesalahan: ${e.toString()}';
    }
  }

  static Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_keyToken, _token!);
    await _persistProfileCache();
  }

  static Future<void> _persistProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    final p = _profile;
    if (p == null) return;
    await prefs.setString(_keyUsername, p.username);
    await prefs.setString(_keyRole, p.role);
    await prefs.setString(_keyExpired, p.expired);
    await prefs.setString(_keyUserId, p.id);
    await prefs.setString(_keyEmail, p.email);
    await prefs.setString(_keyAvatarPath, p.avatarPath);
    await prefs.setString(_keyCreatedAt, p.createdAt.toIso8601String());
  }

  static Future<void> updateAvatar(String path) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(avatarPath: path);
    await _persistProfileCache();
  }

  static Future<void> logout() async {
    if (hasToken) {
      try {
        final uri = Uri.parse('${Cfg.backendBase}/api/logout');
        final client =
            HttpClient()..connectionTimeout = const Duration(seconds: 6);
        try {
          final req =
              await client.postUrl(uri).timeout(const Duration(seconds: 6));
          req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
          req.headers.set('X-Device-ID', _deviceId ?? '');
          await req.close().timeout(const Duration(seconds: 6));
        } finally {
          client.close(force: true);
        }
      } catch (_) {}
    }
    await clear();
  }

  static Future<bool> deleteAccount() async {
    if (!hasToken || _deviceId == null || _deviceId!.isEmpty) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('${Cfg.backendBase}/api/account');
      final req =
          await client.deleteUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      req.headers.set('X-Device-ID', _deviceId!);
      final res = await req.close().timeout(const Duration(seconds: 8));
      final bodyText = await utf8.decoder
          .bind(res)
          .join()
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final decoded = jsonDecode(bodyText);
      return decoded is Map && decoded['ok'] == true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> clear() async {
    _token = null;
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyExpired);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAvatarPath);
    await prefs.remove(_keyCreatedAt);
    // _keyDeviceId SENGAJA tidak dihapus → device tetap terikat.
  }
}

class NekoVerseApp extends StatelessWidget {
  const NekoVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NekoVerse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF04030A),
        fontFamily: 'bug',
        splashFactory: InkSparkle.splashFactory,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB794F6),
          secondary: Color(0xFFFF4D9D),
          surface: Color(0xFF0A0812),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// CONFIG & PALETTE
// ═════════════════════════════════════════════════════════════════

class Cfg {
  static const String background = 'gallery/background.png';
  static const String neko = 'gallery/neko.png';
  static const String logoPage = 'gallery/page.png';
  static const String siang = 'gallery/siang.png';
  static const String malam = 'gallery/malam.png';
  static const String introMusic = 'sound/intro.mp3';
  static const String bugFont = 'bug';
  static const String vampireFont = 'vampire';

  static const String backendBase =
      'http://ridogantengbangetpanel.pterodactylxcz.my.id:3488';
}

class P {
  static const bgDeep = Color(0xFF010104);
  static const bg = Color(0xFF04030A);
  static const bgMid = Color(0xFF09071A);
  static const bgElevated = Color(0xFF0E0B20);
  static const surface = Color(0xFF12102A);
  static const surfaceLight = Color(0xFF1A1738);
  static const surfaceHover = Color(0xFF232050);
  static const border = Color(0xFF2A2548);
  static const borderSoft = Color(0xFF1A1630);
  static const borderBright = Color(0xFF3D3870);

  static const bone = Color(0xFFE5DCC8);
  static const boneSoft = Color(0xFFC8BFA8);
  static const boneDeep = Color(0xFF9B9078);

  static const violet = Color(0xFFB794F6);
  static const violetDeep = Color(0xFF6D28D9);
  static const violetSoft = Color(0xFFD4BFFF);
  static const violetNeon = Color(0xFF9D5CFF);

  static const blood = Color(0xFF8B0A1A);
  static const bloodBright = Color(0xFFC21628);
  static const bloodDeep = Color(0xFF4D0710);
  static const crimson = Color(0xFFD91E36);
  static const rose = Color(0xFFFF2D55);
  static const rust = Color(0xFF8B3A1A);

  static const sick = Color(0xFF7BA37A);
  static const rot = Color(0xFF4A6B4A);
  static const coral = Color(0xFFFB7185);

  static const cyan = Color(0xFF22D3EE);
  static const cyanDeep = Color(0xFF0891B2);
  static const teal = Color(0xFF4A8B7A);

  static const amber = Color(0xFFFBBF24);
  static const orange = Color(0xFFB5672E);
  static const gold = Color(0xFFC4A34A);

  static const pink = Color(0xFFB85C8A);
  static const pinkDeep = Color(0xFF7A2E52);
  static const plasma = Color(0xFFFF00AA);

  static const text = Color(0xFFEDE4D3);
  static const text2 = Color(0xFFB5AB96);
  static const text3 = Color(0xFF807568);
  static const text4 = Color(0xFF544A40);
  static const text5 = Color(0xFF332C26);
}

class S {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

class R {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 32;
  static const double pill = 999;
}

class T {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 280);
  static const medium = Duration(milliseconds: 450);
  static const slow = Duration(milliseconds: 700);
}

// ═════════════════════════════════════════════════════════════════
// USER PROFILE STORE
// ═════════════════════════════════════════════════════════════════

class UserProfile {
  final String id;
  final String username;
  final String avatarPath;
  final String expired;
  final String role;
  final String email;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.avatarPath,
    required this.expired,
    required this.role,
    required this.email,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? avatarPath,
    String? expired,
    String? role,
    String? email,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarPath: avatarPath ?? this.avatarPath,
      expired: expired ?? this.expired,
      role: role ?? this.role,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get initial => username.isEmpty ? '?' : username[0].toUpperCase();

  int? get daysUntilExpiry {
    try {
      final normalized = expired.trim();
      DateTime? date = DateTime.tryParse(normalized);
      if (date == null) {
        final parts = normalized.split('/');
        if (parts.length != 3) return null;
        date = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
      final now = DateTime.now();
      final target = DateTime(date.year, date.month, date.day);
      final today = DateTime(now.year, now.month, now.day);
      return target.difference(today).inDays;
    } catch (_) {
      return null;
    }
  }

  String get expiryStatus {
    final days = daysUntilExpiry;
    if (days == null) return 'TIDAK DIKETAHUI';
    if (days < 0) return 'SUDAH EXPIRED';
    if (days == 0) return 'EXPIRED HARI INI';
    if (days <= 7) return 'SEGERA EXPIRED';
    if (days <= 30) return 'AKAN EXPIRED';
    return 'PERMANEN';
  }

  Color get expiryColor {
    final days = daysUntilExpiry;
    if (days == null) return P.text3;
    if (days < 0) return P.coral;
    if (days <= 7) return P.coral;
    if (days <= 30) return P.amber;
    return P.sick;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'avatarPath': avatarPath,
        'expired': expired,
        'role': role,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };

  static UserProfile fromJson(Map<String, dynamic> j) => UserProfile(
        id: '${j['id'] ?? ''}',
        username: '${j['username'] ?? 'Guest'}',
        avatarPath: '${j['avatarPath'] ?? ''}',
        expired: '${j['expired'] ?? ''}',
        role: '${j['role'] ?? 'basic'}',
        email: '${j['email'] ?? ''}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );
}

class ProfileStore {
  static const _keyId = 'nv_profile_id';
  static const _keyUsername = 'nv_profile_username';
  static const _keyAvatar = 'nv_profile_avatar';
  static const _keyExpired = 'nv_profile_expired';
  static const _keyRole = 'nv_profile_role';
  static const _keyEmail = 'nv_profile_email';
  static const _keyCreated = 'nv_profile_created';

  static final ValueNotifier<UserProfile?> notifier =
      ValueNotifier<UserProfile?>(null);

  static UserProfile? get current => notifier.value;

  static String generateId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = math.Random.secure();
    final buffer = StringBuffer('NEKO-');
    for (int i = 0; i < 10; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(chars[rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  static Future<UserProfile> loadOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyId);
    if (existing != null && existing.isNotEmpty) {
      final profile = UserProfile(
        id: existing,
        username: prefs.getString(_keyUsername) ?? 'GUEST USER',
        avatarPath: prefs.getString(_keyAvatar) ?? '',
        expired: prefs.getString(_keyExpired) ?? _defaultExpiredString(),
        role: prefs.getString(_keyRole) ?? 'basic',
        email: prefs.getString(_keyEmail) ?? '',
        createdAt: DateTime.tryParse(prefs.getString(_keyCreated) ?? '') ??
            DateTime.now(),
      );
      notifier.value = profile;
      return profile;
    }
    final created = UserProfile(
      id: generateId(),
      username: 'GUEST USER',
      avatarPath: '',
      expired: _defaultExpiredString(),
      role: 'basic',
      email: '',
      createdAt: DateTime.now(),
    );
    await _persist(created);
    notifier.value = created;
    return created;
  }

  static String _defaultExpiredString() {
    final now = DateTime.now();
    final target = DateTime(now.year + 1, now.month, now.day);
    return '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _persist(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId, profile.id);
    await prefs.setString(_keyUsername, profile.username);
    await prefs.setString(_keyAvatar, profile.avatarPath);
    await prefs.setString(_keyExpired, profile.expired);
    await prefs.setString(_keyRole, profile.role);
    await prefs.setString(_keyEmail, profile.email);
    await prefs.setString(_keyCreated, profile.createdAt.toIso8601String());
  }

  static Future<void> save(UserProfile profile) async {
    await _persist(profile);
    notifier.value = profile;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyAvatar);
    await prefs.remove(_keyExpired);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyCreated);
    notifier.value = null;
  }
}

class AvatarStore {
  static Future<String> saveAvatar(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/avatars');
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    final ext = file.path.split('.').last;
    final target = File(
      '${avatarDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.saveTo(target.path);
    return target.path;
  }

  static Future<void> deleteAvatar(String path) async {
    if (path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

// ═════════════════════════════════════════════════════════════════
// SHARED UI
// ═════════════════════════════════════════════════════════════════

class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Tap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _p = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _p = false),
      onTapCancel: () => setState(() => _p = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _p ? widget.scale : 1.0,
        duration: T.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final Color? tint;
  final double blur;
  final bool glow;
  final Color? glowColor;
  final double borderWidth;

  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(S.lg),
    this.radius = R.lg,
    this.borderColor,
    this.tint,
    this.blur = 24,
    this.glow = false,
    this.glowColor,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? P.surface.withOpacity(0.68),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? P.border.withOpacity(0.5),
              width: borderWidth,
            ),
            boxShadow: [
              if (glow)
                BoxShadow(
                  color: (glowColor ?? P.violet).withOpacity(0.22),
                  blurRadius: 44,
                  spreadRadius: -8,
                ),
              const BoxShadow(
                color: Color(0x99000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class Halo extends StatefulWidget {
  final Color color;
  final double size;
  const Halo({super.key, this.color = P.crimson, this.size = 8});

  @override
  State<Halo> createState() => _HaloState();
}

class _HaloState extends State<Halo> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _HaloPainter(_c.value, widget.color, widget.size),
          size: Size(widget.size * 3, widget.size * 3),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final double t;
  final Color color;
  final double size;
  _HaloPainter(this.t, this.color, this.size);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    canvas.drawCircle(
      c,
      size * 1.7 * t,
      Paint()..color = color.withOpacity((1 - t) * 0.55),
    );
    canvas.drawCircle(
      c,
      size * 0.55,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.t != t;
}

class SignalBars extends StatefulWidget {
  final Color color;
  final double height;
  final int barCount;
  const SignalBars({
    super.key,
    required this.color,
    this.height = 14,
    this.barCount = 4,
  });

  @override
  State<SignalBars> createState() => _SignalBarsState();
}

class _SignalBarsState extends State<SignalBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.barCount * 5.5,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.barCount, (i) {
            final phase = (_c.value + i * 0.18) % 1.0;
            final h =
                0.35 + (0.65 * (math.sin(phase * math.pi * 2) * 0.5 + 0.5));
            return Container(
              width: 3.2,
              height: widget.height * h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class Clock extends StatefulWidget {
  final TextStyle? style;
  const Clock({super.key, this.style});

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  Timer? _t;
  DateTime _n = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _n = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _n.hour.toString().padLeft(2, '0');
    final m = _n.minute.toString().padLeft(2, '0');
    final s = _n.second.toString().padLeft(2, '0');
    return Text(
      '$h:$m:$s',
      style: widget.style ??
          const TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: P.bone,
            letterSpacing: 2,
          ),
    );
  }
}

class NumCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const NumCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(v.toInt().toString(), style: style),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// BACKGROUND
// ═════════════════════════════════════════════════════════════════

class Star extends StatefulWidget {
  final Widget child;
  const Star({super.key, required this.child});

  @override
  State<Star> createState() => _StarState();
}

class _StarState extends State<Star> with TickerProviderStateMixin {
  late AnimationController _stars;
  late AnimationController _nebula;

  @override
  void initState() {
    super.initState();
    _stars = AnimationController(
        vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
    _nebula = AnimationController(
        vsync: this, duration: const Duration(seconds: 40))
      ..repeat();
  }

  @override
  void dispose() {
    _stars.dispose();
    _nebula.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [P.bgDeep, P.bg, P.bgMid, P.bg],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
        Positioned.fill(
          child: Image.asset(
            Cfg.background,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  P.bgDeep.withOpacity(0.82),
                  P.bgDeep.withOpacity(0.55),
                  P.bgDeep.withOpacity(0.92),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _nebula,
                builder: (_, __) => CustomPaint(
                  painter: _NebulaPainter(_nebula.value),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _stars,
                builder: (_, __) => CustomPaint(
                  painter: _StarsPainter(_stars.value),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _VignettePainter()),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  final double t;
  _StarsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 180; i++) {
      final seed = i * 137;
      final x = ((seed * 73) % size.width.toInt()).toDouble();
      final baseY = ((seed * 41) % size.height.toInt()).toDouble();
      final y = (baseY - (t * size.height * 0.08)) % size.height;
      final twinkle = (math.sin(t * math.pi * 5 + i * 0.7) + 1) * 0.5;
      final alpha = 0.05 + twinkle * 0.55;
      final r = 0.5 + (seed % 4) * 0.4;
      paint.color = P.bone.withOpacity(alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.t != t;
}

class _NebulaPainter extends CustomPainter {
  final double t;
  _NebulaPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = [
      _NB(Offset(size.width * 0.2, size.height * 0.15), size.width * 0.85,
          P.blood, 0.2),
      _NB(Offset(size.width * 0.85, size.height * 0.35), size.width * 0.7,
          P.violetDeep, 0.22),
      _NB(Offset(size.width * 0.5, size.height * 0.85), size.width * 0.65,
          P.rot, 0.09),
      _NB(Offset(size.width * 0.1, size.height * 0.65), size.width * 0.55,
          P.bloodDeep, 0.18),
    ];
    for (int i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final drift = math.sin(t * math.pi * 2 + i) * 60;
      final c = Offset(b.center.dx + drift, b.center.dy + drift * 0.5);
      canvas.drawCircle(
        c,
        b.radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              b.color.withOpacity(b.opacity),
              b.color.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: b.radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) => old.t != t;
}

class _NB {
  final Offset center;
  final double radius;
  final Color color;
  final double opacity;
  _NB(this.center, this.radius, this.color, this.opacity);
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Colors.transparent,
            P.bgDeep.withOpacity(0.5),
            P.bgDeep.withOpacity(0.9),
          ],
          stops: const [0.45, 0.85, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) => false;
}

// ═════════════════════════════════════════════════════════════════
// SPLASH SCREEN — fingerprint hold
// ═════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<double> _fade;
  late AnimationController _pulse;
  late AnimationController _ring;
  Timer? _holdTimer;
  double _progress = 0.0;
  bool _holding = false;
  bool _completed = false;
  bool _navigating = false;
  int? _activePointer;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    AppSession.init();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    _ring.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_completed || _navigating) return;
    setState(() => _holding = true);
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _progress += 0.01;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _completed = true;
          t.cancel();
        }
      });
      if (_progress >= 1.0 && !_navigating) {
        _completeHold();
      }
    });
  }

  void _cancelHold() {
    if (_completed || _navigating) return;
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _holding = false;
      _progress = 0.0;
    });
  }

  Future<void> _completeHold() async {
    if (_navigating) return;
    _navigating = true;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await AppSession.init();
    final hasSession = AppSession.hasToken && await AppSession.validate();
    if (!mounted) return;

    if (hasSession && AppSession.profile != null) {
      await ProfileStore.save(AppSession.profile!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MusicIntroScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).floor();

    return Scaffold(
      backgroundColor: P.bgDeep,
      body: Star(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.xl, vertical: S.lg),
              child: Column(
                children: [
                  const SizedBox(height: S.xl),
                  _topRow(),
                  const SizedBox(height: S.xl),
                  _buildLogo(),
                  const SizedBox(height: S.lg),
                  const Text(
                    'NekoVerse',
                    style: TextStyle(
                      fontFamily: Cfg.vampireFont,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                      letterSpacing: 2,
                      height: 1.0,
                      shadows: [
                        Shadow(color: P.crimson, blurRadius: 24),
                        Shadow(color: P.violet, blurRadius: 34),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'S E C U R E   T E R M I N A L',
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: P.bone.withOpacity(0.6),
                      letterSpacing: 3.2,
                    ),
                  ),
                  const SizedBox(height: S.lg),
                  _buildInfoCard(),
                  const Spacer(),
                  _buildFingerprint(percent),
                  const SizedBox(height: S.lg),
                  _buildHoldLabel(percent),
                  const SizedBox(height: S.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: P.bgElevated.withOpacity(0.85),
            borderRadius: BorderRadius.circular(R.pill),
            border: Border.all(color: P.sick.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Halo(color: P.sick, size: 3),
              SizedBox(width: 6),
              Text(
                'SECURE',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: P.sick,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Text(
          'V2.0',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: P.text3,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ring,
            builder: (_, __) => Transform.rotate(
              angle: _ring.value * math.pi * 2,
              child: CustomPaint(
                size: const Size(140, 140),
                painter: _DashedRingPainter(color: P.crimson),
              ),
            ),
          ),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.0,
                colors: [
                  Color(0xFF7A0A18),
                  Color(0xFF4D0710),
                  Color(0xFF1A0208),
                ],
              ),
              border: Border.all(color: P.crimson.withOpacity(0.6), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: P.crimson.withOpacity(0.65),
                  blurRadius: 40,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                Cfg.logoPage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      fontFamily: Cfg.vampireFont,
                      fontSize: 62,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Glass(
      radius: R.lg,
      tint: P.bgElevated.withOpacity(0.85),
      borderColor: P.border.withOpacity(0.55),
      padding: const EdgeInsets.all(S.md),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: P.sick, size: 18),
          SizedBox(width: S.sm),
          Expanded(
            child: Text(
              'Autentikasi backend + device binding. Satu akun hanya untuk satu perangkat.',
              style: TextStyle(
                fontFamily: Cfg.bugFont,
                fontSize: 10,
                color: P.text2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprint(int percent) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_activePointer != null) return;
        _activePointer = e.pointer;
        _startHold();
      },
      onPointerUp: (e) {
        if (_activePointer != e.pointer) return;
        _activePointer = null;
        _cancelHold();
      },
      onPointerCancel: (e) {
        if (_activePointer != e.pointer) return;
        _activePointer = null;
        _cancelHold();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _ring]),
        builder: (_, __) {
          final pulseVal = _pulse.value;
          final ringVal = _ring.value;
          final activeColor = _completed
              ? P.sick
              : _holding
                  ? P.crimson
                  : P.violet;
          return SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < 3; i++)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) {
                      final offset = (pulseVal + i * 0.33) % 1.0;
                      final size = 120 + offset * 80;
                      return Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: activeColor.withOpacity((1 - offset) * 0.5),
                            width: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                Transform.rotate(
                  angle: ringVal * math.pi * 2,
                  child: CustomPaint(
                    size: const Size(168, 168),
                    painter: _DashedRingPainter(color: activeColor),
                  ),
                ),
                CustomPaint(
                  size: const Size(148, 148),
                  painter: _ProgressRingPainter(
                    progress: _progress,
                    color: activeColor,
                    background: P.border.withOpacity(0.4),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeColor.withOpacity(0.28),
                        P.bgDeep.withOpacity(0.9),
                      ],
                    ),
                    border: Border.all(
                      color: activeColor.withOpacity(0.7),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(_holding ? 0.6 : 0.35),
                        blurRadius: _holding ? 34 : 20,
                        spreadRadius: _holding ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _completed
                        ? Icons.check_rounded
                        : Icons.fingerprint_rounded,
                    size: 56,
                    color: _completed
                        ? P.sick
                        : _holding
                            ? P.bone
                            : P.boneSoft,
                  ),
                ),
                if (_holding || _progress > 0)
                  Positioned(
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: P.bgDeep.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(R.pill),
                        border: Border.all(
                          color: activeColor.withOpacity(0.7),
                        ),
                      ),
                      child: Text(
                        '$percent%',
                        style: TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: activeColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHoldLabel(int percent) {
    return Column(
      children: [
        Text(
          _completed
              ? 'AKSES DIBERIKAN'
              : _holding
                  ? 'MEMPROSES $percent%'
                  : 'T A H A N   S I D I K   J A R I',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: _completed
                ? P.sick
                : _holding
                    ? P.crimson
                    : P.bone.withOpacity(0.8),
            letterSpacing: 2.6,
            height: 1.3,
          ),
        ),
        const SizedBox(height: S.sm),
        Text(
          _completed
              ? 'Memeriksa sesi...'
              : 'Tahan sampai 100% untuk melanjutkan',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: P.text3,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const segments = 48;
    for (int i = 0; i < segments; i++) {
      if (i % 3 == 0) continue;
      final a1 = (i / segments) * math.pi * 2;
      final a2 = a1 + (math.pi * 2 / segments) * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a1,
        a2 - a1,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => old.color != color;
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color background;
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = background
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + math.pi * 2,
          colors: [color.withOpacity(0.4), color, color],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );

      final angle = -math.pi / 2 + math.pi * 2 * progress;
      final endPoint = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawCircle(
        endPoint,
        4,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(endPoint, 2.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ═════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late AnimationController _ringRotation;
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _ringRotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ringRotation.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Username dan password wajib diisi.');
      HapticFeedback.mediumImpact();
      return;
    }

    if (!SecureCredentials.matches(user, pass)) {
      setState(() => _error = 'Username atau password salah.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await AppSession.login(username: user, password: pass);

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      HapticFeedback.heavyImpact();
      return;
    }

    final profile = AppSession.profile;
    if (profile != null) await ProfileStore.save(profile);

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MusicIntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bgDeep,
      body: Star(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: S.xl, vertical: S.lg),
                child: Column(
                  children: [
                    const SizedBox(height: S.xl),
                    _buildLogo(),
                    const SizedBox(height: S.xl),
                    _buildWelcome(),
                    const SizedBox(height: S.xxl),
                    _buildAuthTerminal(),
                    const SizedBox(height: S.lg),
                    _buildFooter(),
                    const SizedBox(height: S.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 220,
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: P.violet.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: P.rose.withOpacity(0.25),
                        blurRadius: 60,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringRotation,
                  builder: (_, __) => Transform.rotate(
                    angle: _ringRotation.value * math.pi * 2,
                    child: CustomPaint(
                      size: const Size(154, 154),
                      painter: _LoginDashedRingPainter(),
                    ),
                  ),
                ),
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 1.0,
                      colors: [
                        Color(0xFF7A0A18),
                        Color(0xFF4D0710),
                        Color(0xFF1A0208),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    border: Border.all(
                      color: P.crimson.withOpacity(0.55),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: P.crimson.withOpacity(0.6),
                        blurRadius: 34,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'R',
                      style: TextStyle(
                        fontFamily: Cfg.vampireFont,
                        fontSize: 78,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 0.85,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'REVENANT',
            style: TextStyle(
              fontFamily: Cfg.vampireFont,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: P.bone,
              letterSpacing: 3.5,
              height: 1.0,
              shadows: [
                Shadow(color: P.rose, blurRadius: 22),
                Shadow(color: P.violet, blurRadius: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      children: [
        Text(
          'W E L C O M E   B A C K',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: P.boneSoft.withOpacity(0.75),
            letterSpacing: 3.2,
          ),
        ),
        const SizedBox(height: S.sm),
        const Text(
          'Sign in to continue',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: P.text2,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthTerminal() {
    return Glass(
      radius: R.xl,
      tint: P.bgElevated.withOpacity(0.9),
      borderColor: P.violet.withOpacity(0.45),
      padding: const EdgeInsets.all(S.lg),
      glow: true,
      glowColor: P.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: P.violet,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: P.violet, blurRadius: 8)],
                ),
              ),
              const SizedBox(width: S.sm),
              const Text(
                'AUTH TERMINAL',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 2.4,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: P.sick.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(R.pill),
                  border: Border.all(color: P.sick.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Halo(color: P.sick, size: 3),
                    SizedBox(width: 5),
                    Text(
                      'ONLINE',
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: P.sick,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: S.lg),
          _fieldLabel('USERNAME'),
          const SizedBox(height: 6),
          _inputField(
            controller: _userCtrl,
            focus: _userFocus,
            hint: 'Enter your username',
            icon: Icons.person_outline_rounded,
            nextFocus: _passFocus,
          ),
          const SizedBox(height: S.md),
          _fieldLabel('PASSWORD'),
          const SizedBox(height: 6),
          _inputField(
            controller: _passCtrl,
            focus: _passFocus,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            onSubmit: _doLogin,
            trailing: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: P.text3,
                size: 18,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: S.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.md, vertical: S.sm),
              decoration: BoxDecoration(
                color: P.crimson.withOpacity(0.12),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: P.crimson.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.error_outline_rounded,
                        color: P.crimson, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      _error!,
                      style: const TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 10.5,
                        color: P.coral,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: S.lg),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: Cfg.bugFont,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: P.boneSoft,
        letterSpacing: 2.2,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
    FocusNode? nextFocus,
    VoidCallback? onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: P.bgDeep.withOpacity(0.85),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: P.border.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const SizedBox(width: S.md),
          Icon(icon, size: 18, color: P.violet),
          const SizedBox(width: S.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              obscureText: obscure,
              cursorColor: P.violet,
              onSubmitted: (_) {
                if (onSubmit != null) {
                  onSubmit();
                } else if (nextFocus != null) {
                  nextFocus.requestFocus();
                }
              },
              textInputAction: onSubmit != null
                  ? TextInputAction.done
                  : TextInputAction.next,
              style: const TextStyle(
                fontFamily: Cfg.bugFont,
                fontSize: 13,
                color: P.bone,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 12,
                  color: P.text4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (trailing != null) trailing else const SizedBox(width: S.md),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Tap(
      onTap: _loading ? null : _doLogin,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.md),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [P.cyan, P.violet, P.violetDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: P.violet.withOpacity(0.55),
              blurRadius: 26,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.md),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LOGIN',
                            style: TextStyle(
                              fontFamily: Cfg.bugFont,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                    color: Colors.black45, blurRadius: 8),
                              ],
                            ),
                          ),
                          SizedBox(width: S.sm),
                          Icon(Icons.double_arrow_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Tap(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hubungi admin untuk mendapatkan akses.'),
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.md),
        decoration: BoxDecoration(
          color: P.bgElevated.withOpacity(0.7),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: P.border.withOpacity(0.6)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 16, color: P.boneSoft),
            SizedBox(width: S.sm),
            Text(
              'No Access? Buy Here',
              style: TextStyle(
                fontFamily: Cfg.bugFont,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: P.bone,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginDashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = P.violet.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const segments = 44;
    for (int i = 0; i < segments; i++) {
      final a1 = (i / segments) * math.pi * 2;
      final a2 = a1 + (math.pi * 2 / segments) * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a1,
        a2 - a1,
        false,
        paint,
      );
    }

    final innerPaint = Paint()
      ..color = P.rose.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const innerSegments = 32;
    final innerRadius = radius - 14;
    for (int i = 0; i < innerSegments; i++) {
      final a1 = (i / innerSegments) * math.pi * 2;
      final a2 = a1 + (math.pi * 2 / innerSegments) * 0.45;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        a1,
        a2 - a1,
        false,
        innerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoginDashedRingPainter old) => false;
}

// ═════════════════════════════════════════════════════════════════
// MUSIC INTRO SCREEN
// ═════════════════════════════════════════════════════════════════

class MusicIntroScreen extends StatefulWidget {
  const MusicIntroScreen({super.key});

  @override
  State<MusicIntroScreen> createState() => _MusicIntroScreenState();
}

class _MusicIntroScreenState extends State<MusicIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<double> _fade;
  late AnimationController _disc;
  late AnimationController _pulse;
  AudioPlayer? _player;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(minutes: 3, seconds: 1);
  bool _playing = false;
  bool _audioFailed = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _disc = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final player = AudioPlayer();
      _player = player;
      player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      player.onPlayerComplete.listen((_) {
        if (mounted) _goToDashboard();
      });
      await player.play(AssetSource(Cfg.introMusic));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioFailed = true;
          _playing = false;
        });
        Timer(const Duration(seconds: 5), () {
          if (mounted) _goToDashboard();
        });
      }
    }
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _goToDashboard() async {
    try {
      await _player?.stop();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _skip() async {
    HapticFeedback.mediumImpact();
    await _goToDashboard();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _player?.dispose();
    _entrance.dispose();
    _disc.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double get _progressRatio {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bgDeep,
      body: Star(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.xl, vertical: S.lg),
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildTag(),
                  const SizedBox(height: S.lg),
                  _buildTitle(),
                  const SizedBox(height: S.xxl),
                  _buildDisc(),
                  const SizedBox(height: S.xxl),
                  _buildNowPlaying(),
                  const SizedBox(height: S.xl),
                  _buildProgressBar(),
                  const Spacer(),
                  _buildSkip(),
                  const SizedBox(height: S.lg),
                  if (_audioFailed)
                    Text(
                      'Audio asset tidak ditemukan, lanjut otomatis...',
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 10,
                        color: P.text3,
                        letterSpacing: 0.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFFFA000)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.6),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'M',
              style: TextStyle(
                fontFamily: Cfg.vampireFont,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'McLAREN AUDIO',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Text(
                    'AKUN ',
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: P.text3,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    AppSession.profile?.username ?? 'Guest',
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: P.violet,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: P.bgElevated.withOpacity(0.85),
            borderRadius: BorderRadius.circular(R.pill),
            border: Border.all(
              color: (_playing ? P.sick : P.text3).withOpacity(0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Halo(color: _playing ? P.sick : P.text3, size: 3),
              const SizedBox(width: 5),
              Text(
                _playing ? 'PLAYING' : 'READY',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: _playing ? P.sick : P.text3,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: S.xl, vertical: S.sm),
      decoration: BoxDecoration(
        color: P.violet.withOpacity(0.12),
        borderRadius: BorderRadius.circular(R.pill),
        border: Border.all(color: P.violet.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: P.violet.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: const Text(
        'I N T R O   S O U N D T R A C K',
        style: TextStyle(
          fontFamily: Cfg.bugFont,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: P.violetSoft,
          letterSpacing: 2.4,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'INTRO McLAREN',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Cfg.vampireFont,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: P.bone,
            letterSpacing: 2.4,
            height: 1.0,
            shadows: [
              Shadow(color: P.violet, blurRadius: 22),
              Shadow(color: Colors.black, blurRadius: 30),
            ],
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Purple Racing Audio System',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 10,
            color: P.text3,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDisc() {
    return AnimatedBuilder(
      animation: _disc,
      builder: (_, __) {
        return SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final p = _pulse.value;
                  return Container(
                    width: 240 + p * 20,
                    height: 240 + p * 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: P.violet.withOpacity(0.35 * (1 - p)),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: P.violet.withOpacity(0.5),
                    width: 1.6,
                  ),
                ),
              ),
              Transform.rotate(
                angle: _disc.value * math.pi * 2,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFF1A0E2E),
                        Color(0xFF3A1A50),
                        Color(0xFF1A0E2E),
                        Color(0xFF2A1538),
                        Color(0xFF1A0E2E),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: P.violet.withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (int i = 1; i <= 6; i++)
                        Container(
                          width: 200 - i * 22,
                          height: 200 - i * 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                        ),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF6B00),
                              Color(0xFFFFA000),
                              Color(0xFFE65100),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFFFF6B00).withOpacity(0.55),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'McLaren',
                            style: TextStyle(
                              fontFamily: Cfg.bugFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: P.bone,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNowPlaying() {
    return Glass(
      radius: R.lg,
      tint: P.bgElevated.withOpacity(0.9),
      borderColor: P.border.withOpacity(0.55),
      padding: const EdgeInsets.all(S.md),
      child: Row(
        children: [
          _EqualizerBar(color: P.violet, animate: _playing),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _audioFailed
                      ? 'AUDIO TIDAK TERSEDIA'
                      : _playing
                          ? 'MEMUTAR INTRO MUSIC'
                          : 'MENUNGGU...',
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: P.bone,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'McLaren Engineer · Purple Racing',
                  style: TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 9,
                    color: P.text3,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(_progressRatio * 100).floor()}%',
            style: const TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: P.violet,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Glass(
      radius: R.lg,
      tint: P.bgElevated.withOpacity(0.9),
      borderColor: P.border.withOpacity(0.55),
      padding: const EdgeInsets.all(S.md),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(R.pill),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: P.border.withOpacity(0.5),
                ),
                FractionallySizedBox(
                  widthFactor: _progressRatio,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [P.violet, P.plasma],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: S.sm),
          Row(
            children: [
              Text(
                _fmt(_position),
                style: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: P.boneSoft,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                _fmt(_duration),
                style: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: P.boneSoft,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkip() {
    return Tap(
      onTap: _skip,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: S.xxl, vertical: S.md),
        decoration: BoxDecoration(
          color: P.bgElevated.withOpacity(0.9),
          borderRadius: BorderRadius.circular(R.pill),
          border: Border.all(color: P.violet.withOpacity(0.6)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SKIP INTRO',
              style: TextStyle(
                fontFamily: Cfg.bugFont,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: P.bone,
                letterSpacing: 2.4,
              ),
            ),
            SizedBox(width: S.sm),
            Icon(Icons.skip_next_rounded, color: P.violet, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EqualizerBar extends StatefulWidget {
  final Color color;
  final bool animate;
  const _EqualizerBar({required this.color, required this.animate});

  @override
  State<_EqualizerBar> createState() => _EqualizerBarState();
}

class _EqualizerBarState extends State<_EqualizerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _EqualizerBar old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 20,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (i) {
            final phase = (_c.value + i * 0.25) % 1.0;
            final h =
                0.35 + 0.65 * (math.sin(phase * math.pi * 2) * 0.5 + 0.5);
            return Container(
              width: 4,
              height: 20 * h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// BUBBLE + SECTION TITLE + MARQUEE
// ═════════════════════════════════════════════════════════════════

class CircleBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  final double size;
  final Widget? image;
  const CircleBubble({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
    this.size = 46,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  P.surfaceLight.withOpacity(0.95),
                  P.surface.withOpacity(0.9),
                ],
              ),
              border: Border.all(color: color.withOpacity(0.45), width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.22),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
                const BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: image ?? Icon(icon, color: color, size: size * 0.44),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [P.rose, P.crimson],
                  ),
                  borderRadius: BorderRadius.circular(R.pill),
                  border: Border.all(color: P.bgDeep, width: 1.8),
                ),
                child: Center(
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final String? trailing;
  final VoidCallback? onTrailing;
  const SectionTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    this.subtitle,
    this.trailing,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent, accent.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: S.md),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(R.sm),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: S.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  color: P.bone,
                  height: 1.0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: P.text3,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: S.sm),
        if (trailing != null)
          Tap(
            onTap: onTrailing ?? () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(R.pill),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      color: accent,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 11, color: accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class Marquee extends StatefulWidget {
  final List<String> items;
  const Marquee({super.key, required this.items});

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 380),
    )..repeat();
    _scroll = ScrollController();
    _c.addListener(_tick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    _scroll.jumpTo(_c.value * max);
  }

  @override
  void dispose() {
    _c.removeListener(_tick);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: accentNotifier,
      builder: (_, accent, __) => Container(
        height: 34,
        decoration: BoxDecoration(
          color: P.bgElevated.withOpacity(0.85),
          borderRadius: BorderRadius.circular(R.pill),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.pill),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: const [0.0, 0.08, 0.92, 1.0],
            ).createShader(rect),
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 100,
              itemBuilder: (_, i) {
                final item = widget.items[i % widget.items.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: S.md, vertical: S.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item,
                        style: const TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: P.boneSoft,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: P.boneDeep.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PULSE STRIP
// ═════════════════════════════════════════════════════════════════

class PulseTelemetry {
  final String label;
  final IconData icon;
  final Color color;
  final List<double> history;
  final String value;
  final String unit;
  const PulseTelemetry({
    required this.label,
    required this.icon,
    required this.color,
    required this.history,
    required this.value,
    required this.unit,
  });
}

class PulseStrip extends StatefulWidget {
  const PulseStrip({super.key});

  @override
  State<PulseStrip> createState() => _PulseStripState();
}

class _PulseStripState extends State<PulseStrip>
    with TickerProviderStateMixin {
  late AnimationController _shift;
  final List<double> _cpuHist = List.generate(24, (_) => 0.3);
  final List<double> _ramHist = List.generate(24, (_) => 0.5);
  final List<double> _netHist = List.generate(24, (_) => 0.2);
  Timer? _tick;
  final math.Random _rng = math.Random();
  int _cpu = 24;
  int _ram = 62;
  int _net = 38;

  @override
  void initState() {
    super.initState();
    _shift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _tick = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() {
        _cpu = (_cpu + _rng.nextInt(21) - 10).clamp(8, 92);
        _ram = (_ram + _rng.nextInt(13) - 6).clamp(30, 92);
        _net = (_net + _rng.nextInt(31) - 15).clamp(5, 98);
        _cpuHist.removeAt(0);
        _cpuHist.add(_cpu / 100.0);
        _ramHist.removeAt(0);
        _ramHist.add(_ram / 100.0);
        _netHist.removeAt(0);
        _netHist.add(_net / 100.0);
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetries = [
      PulseTelemetry(
        label: 'CPU',
        icon: Icons.memory_rounded,
        color: P.crimson,
        history: _cpuHist,
        value: '$_cpu',
        unit: '%',
      ),
      PulseTelemetry(
        label: 'RAM',
        icon: Icons.storage_rounded,
        color: P.violet,
        history: _ramHist,
        value: '$_ram',
        unit: '%',
      ),
      PulseTelemetry(
        label: 'NET',
        icon: Icons.bolt_rounded,
        color: P.cyan,
        history: _netHist,
        value: '$_net',
        unit: 'Mb',
      ),
    ];

    return Glass(
      radius: R.lg,
      tint: P.bgElevated.withOpacity(0.9),
      borderColor: P.border.withOpacity(0.5),
      padding: const EdgeInsets.all(S.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: P.sick,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE PULSE',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 1.8,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _shift,
                builder: (_, __) {
                  final phase = (_shift.value * math.pi * 2);
                  return Row(
                    children: List.generate(3, (i) {
                      final p = (phase + i * 1.2) % (math.pi * 2);
                      final opacity =
                          0.3 + 0.7 * (math.sin(p) * 0.5 + 0.5);
                      return Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: P.crimson.withOpacity(opacity),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 6),
              const Text(
                'REALTIME',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: P.crimson,
                  letterSpacing: 1.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: S.md),
          Row(
            children:
                telemetries.map((t) => Expanded(child: _cell(t))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _cell(PulseTelemetry t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(t.icon, size: 11, color: t.color),
              const SizedBox(width: 4),
              Text(
                t.label,
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: t.color,
                  letterSpacing: 1.2,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: t.value,
                      style: const TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: P.bone,
                        letterSpacing: 0.3,
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: t.unit,
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: t.color.withOpacity(0.8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RepaintBoundary(
            child: SizedBox(
              height: 26,
              child: CustomPaint(
                painter: _PulseLinePainter(t.history, t.color),
                size: const Size(double.infinity, 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _PulseLinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final step = size.width / (data.length - 1);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - data[i] * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final lastX = (data.length - 1) * step;
    final lastY = size.height - data.last * (size.height - 4) - 2;
    canvas.drawCircle(
      Offset(lastX, lastY),
      1.4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PulseLinePainter old) => true;
}

// ═════════════════════════════════════════════════════════════════
// STORY (FIXED) — no "+", avatar photo, media support
// ═════════════════════════════════════════════════════════════════

enum StoryMediaType { text, image, video }

class StoryData {
  final String username;
  final String avatarText;
  final String avatarPath; // local avatar path (kalau ada)
  final Color c1;
  final Color c2;
  final bool isOwn;
  final bool isLive;
  final int count;
  final String? id;
  final String? storyText;
  final String? mediaUrl;
  final StoryMediaType mediaType;
  final DateTime? createdAt;

  const StoryData({
    required this.username,
    required this.avatarText,
    this.avatarPath = '',
    required this.c1,
    required this.c2,
    this.isOwn = false,
    this.isLive = false,
    this.count = 1,
    this.id,
    this.storyText,
    this.mediaUrl,
    this.mediaType = StoryMediaType.text,
    this.createdAt,
  });
}

class StoryCircle extends StatefulWidget {
  final StoryData data;
  final VoidCallback onTap;
  final bool isPosting;
  const StoryCircle({
    super.key,
    required this.data,
    required this.onTap,
    this.isPosting = false,
  });

  @override
  State<StoryCircle> createState() => _StoryCircleState();
}

class _StoryCircleState extends State<StoryCircle>
    with TickerProviderStateMixin {
  late AnimationController _rot;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _rot = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _rot.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final hasAvatar = d.avatarPath.isNotEmpty;

    return Tap(
      onTap: widget.onTap,
      scale: 0.88,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (d.isLive && !d.isOwn)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 80 + _pulse.value * 12,
                        height: 80 + _pulse.value * 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: P.crimson
                                .withOpacity(0.6 * (1 - _pulse.value)),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  // Ring
                  if (widget.isPosting)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: P.violet.withOpacity(0.75),
                          width: 2.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: P.violet.withOpacity(0.5),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    )
                  else if (d.isOwn)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: P.boneDeep.withOpacity(0.4),
                          width: 1.6,
                        ),
                      ),
                    )
                  else
                    AnimatedBuilder(
                      animation: _rot,
                      builder: (_, __) => Transform.rotate(
                        angle: _rot.value * math.pi * 2,
                        child: CustomPaint(
                          size: const Size(80, 80),
                          painter: _StoryRingPainter(d.c1, d.c2, d.isLive),
                        ),
                      ),
                    ),
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: P.bgDeep,
                      border: Border.all(color: P.bgDeep, width: 2),
                    ),
                    child: ClipOval(
                      child: hasAvatar
                          ? Image.file(
                              File(d.avatarPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initialAvatar(d),
                            )
                          : _initialAvatar(d),
                    ),
                  ),
                  // NO "+" ADD BADGE — dihapus
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isPosting ? 'POSTING' : (d.isOwn ? 'KAMU' : d.username.toUpperCase()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Cfg.bugFont,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: widget.isPosting
                    ? P.violet
                    : (d.isOwn ? P.violetSoft : P.text2),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialAvatar(StoryData d) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [d.c1, d.c2],
        ),
      ),
      child: Center(
        child: Text(
          d.avatarText,
          style: const TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: P.bone,
          ),
        ),
      ),
    );
  }
}

class _StoryRingPainter extends CustomPainter {
  final Color c1;
  final Color c2;
  final bool isLive;
  _StoryRingPainter(this.c1, this.c2, this.isLive);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final gradient = SweepGradient(
      colors: isLive
          ? [P.crimson, P.bloodBright, P.crimson, P.blood]
          : [c1, c2, c1],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = gradient
            .createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryRingPainter old) => true;
}

// Story Viewer — handle text / image / video
class StoryVideoContent extends StatefulWidget {
  final String url;
  final bool isLocal;

  const StoryVideoContent({
    super.key,
    required this.url,
    required this.isLocal,
  });

  @override
  State<StoryVideoContent> createState() => _StoryVideoContentState();
}

class _StoryVideoContentState extends State<StoryVideoContent> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant StoryVideoContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.isLocal != widget.isLocal) {
      _disposeController();
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      final controller = widget.isLocal
          ? VideoPlayerController.file(File(widget.url))
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Video tidak dapat diputar.');
      }
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 9 / 16,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class StoryViewerScreen extends StatefulWidget {
  final StoryData story;
  const StoryViewerScreen({super.key, required this.story});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Content
            Positioned.fill(
              child: _buildContent(s),
            ),
            // Top bar with progress + user info
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progressCtrl.value,
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        valueColor:
                            AlwaysStoppedAnimation(accentNotifier.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1.4,
                          ),
                        ),
                        child: ClipOval(
                          child: s.avatarPath.isNotEmpty
                              ? Image.file(
                                  File(s.avatarPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      s.avatarText,
                                      style: const TextStyle(
                                        fontFamily: Cfg.bugFont,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [s.c1, s.c2],
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.avatarText,
                                      style: const TextStyle(
                                        fontFamily: Cfg.bugFont,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.username,
                              style: const TextStyle(
                                fontFamily: Cfg.bugFont,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            if (s.createdAt != null)
                              Text(
                                _formatTime(s.createdAt!),
                                style: const TextStyle(
                                  fontFamily: Cfg.bugFont,
                                  fontSize: 9,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StoryData s) {
    if (s.mediaType == StoryMediaType.image &&
        s.mediaUrl != null &&
        s.mediaUrl!.isNotEmpty) {
      return _buildMedia(s);
    }
    if (s.mediaType == StoryMediaType.video &&
        s.mediaUrl != null &&
        s.mediaUrl!.isNotEmpty) {
      return _buildMedia(s);
    }
    return _buildText(s);
  }

  Widget _buildMedia(StoryData s) {
    final url = s.mediaUrl!;
    final isLocal = !url.startsWith('http');
    return Stack(
      fit: StackFit.expand,
      children: [
        if (s.mediaType == StoryMediaType.image)
          isLocal
              ? Image.file(File(url), fit: BoxFit.contain)
              : Image.network(url, fit: BoxFit.contain)
        else
          StoryVideoContent(url: url, isLocal: isLocal),
        // Caption overlay
        if (s.storyText != null && s.storyText!.trim().isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(S.xl, S.xl, S.xl, S.xxl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
              child: Text(
                s.storyText!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildText(StoryData s) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.c1, P.bgDeep, s.c2],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: S.xxl),
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            s.storyText ?? 'Story ini tidak memiliki teks.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.4,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}

// ═════════════════════════════════════════════════════════════════
// TOOL CAROUSEL — 2 menu saja
// ═════════════════════════════════════════════════════════════════

class ToolData {
  final String code;
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final List<Color> colors;
  final String statLabel;
  final String statValue;
  final bool danger;
  final bool isCoding;
  const ToolData({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.colors,
    required this.statLabel,
    required this.statValue,
    this.danger = true,
    this.isCoding = false,
  });
}

class ToolCarousel extends StatefulWidget {
  final List<ToolData> tools;
  final ValueChanged<String>? onToolTap;
  const ToolCarousel({super.key, required this.tools, this.onToolTap});

  @override
  State<ToolCarousel> createState() => _ToolCarouselState();
}

class _ToolCarouselState extends State<ToolCarousel>
    with TickerProviderStateMixin {
  late PageController _ctrl;
  late AnimationController _auto;
  int _current = 0;
  double _pageOffset = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.85);
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() => _pageOffset = _ctrl.page ?? 0);
    });
    _auto = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          final next = (_current + 1) % widget.tools.length;
          _ctrl.animateToPage(
            next,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          );
          _auto.forward(from: 0);
        }
      });
    _auto.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _auto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _ctrl,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.tools.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _auto.forward(from: 0);
            },
            itemBuilder: (_, i) {
              final tool = widget.tools[i];
              final distance =
                  (i - _pageOffset).abs().clamp(0.0, 1.0).toDouble();
              final scale = 1.0 - distance * 0.12;
              final opacity = 1.0 - distance * 0.3;
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _ToolCard(
                        tool: tool,
                        isActive: i == _current,
                        onTap: () => widget.onToolTap?.call(tool.code),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: S.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.tools.length, (i) {
            final active = i == _current;
            final tool = widget.tools[i];
            return GestureDetector(
              onTap: () {
                _ctrl.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
                _auto.forward(from: 0);
              },
              child: AnimatedContainer(
                duration: T.normal,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: active ? 40 : 8,
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(
                          colors: [tool.colors[0], tool.colors[1]])
                      : null,
                  color: active ? null : P.text5.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(R.pill),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final ToolData tool;
  final bool isActive;
  final VoidCallback onTap;
  const _ToolCard({
    required this.tool,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c1 = tool.colors[0];
    final c2 = tool.colors[1];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1, c2],
          ),
          boxShadow: [
            BoxShadow(
              color: c1.withOpacity(0.5),
              blurRadius: 34,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.xl),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.16),
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -20,
                bottom: -30,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    tool.icon,
                    size: 200,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(S.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(R.md),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.45),
                              width: 1.3,
                            ),
                          ),
                          child: Icon(tool.icon,
                              color: Colors.white, size: 26),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(R.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tool.isCoding ? 'OPEN' : 'EXPLORE',
                                style: TextStyle(
                                  fontFamily: Cfg.bugFont,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: c1,
                                  letterSpacing: 1.5,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: c1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tool.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                    const SizedBox(height: S.md),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(R.xs),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            tool.code,
                            style: const TextStyle(
                              fontFamily: Cfg.bugFont,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.4,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(R.xs),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tool.statLabel,
                                  style: TextStyle(
                                    fontFamily: Cfg.bugFont,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withOpacity(0.75),
                                    letterSpacing: 1.0,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tool.statValue,
                                  style: const TextStyle(
                                    fontFamily: Cfg.bugFont,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// NEWS
// ═════════════════════════════════════════════════════════════════

class NewsData {
  final String category;
  final String title;
  final String description;
  final String source;
  final String time;
  final String imageUrl;
  final Color c1;
  final Color c2;
  final IconData icon;
  final bool isLive;
  final String? linkUrl;
  final DateTime? publishedAt;
  const NewsData({
    required this.category,
    required this.title,
    required this.description,
    required this.source,
    required this.time,
    required this.imageUrl,
    required this.c1,
    required this.c2,
    required this.icon,
    this.isLive = false,
    this.linkUrl,
    this.publishedAt,
  });
}

class NewsCarousel extends StatefulWidget {
  final List<NewsData> items;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  const NewsCarousel({
    super.key,
    required this.items,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel>
    with TickerProviderStateMixin {
  late PageController _ctrl;
  late AnimationController _auto;
  int _current = 0;
  double _pageOffset = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.92);
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() => _pageOffset = _ctrl.page ?? 0);
    });
    _auto = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            mounted &&
            widget.items.isNotEmpty) {
          final next = (_current + 1) % widget.items.length;
          _ctrl.animateToPage(
            next,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          );
          _auto.forward(from: 0);
        }
      });
    _auto.forward();
  }

  @override
  void didUpdateWidget(covariant NewsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length &&
        widget.items.isNotEmpty) {
      _current = 0;
      _auto.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ctrl.hasClients) _ctrl.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _auto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return _empty();
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _ctrl,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.items.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              _auto.forward(from: 0);
            },
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final distance =
                  (i - _pageOffset).abs().clamp(0.0, 1.0).toDouble();
              final scale = 1.0 - distance * 0.05;
              final opacity = 1.0 - distance * 0.25;
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _NewsCard(item: item),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: S.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final active = i == _current;
            final item = widget.items[i];
            return GestureDetector(
              onTap: () {
                _ctrl.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
                _auto.forward(from: 0);
              },
              child: AnimatedContainer(
                duration: T.normal,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: active ? 42 : 8,
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(colors: [item.c1, item.c2])
                      : null,
                  color: active ? null : P.text5.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(R.pill),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _empty() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25133B), Color(0xFF100B20), Color(0xFF351320)],
        ),
        border: Border.all(color: P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rss_feed_rounded, color: P.bone, size: 30),
          const Spacer(),
          Text(
            widget.loading ? 'MENGAMBIL BERITA…' : 'BERITA BELUM TERSEDIA',
            style: const TextStyle(
              fontFamily: Cfg.bugFont,
              color: P.bone,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.error ?? 'Menghubungkan ke feed berita.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: P.text2, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: S.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.loading ? null : widget.onRetry,
              icon: widget.loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('PERBARUI BERITA'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsData item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl.trim().isNotEmpty
        ? item.imageUrl.trim()
        : _fallbackCover(item);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final rawUrl = item.linkUrl;
        final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
        if (uri == null) return;
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.xl),
          boxShadow: [
            BoxShadow(
              color: item.c1.withOpacity(0.4),
              blurRadius: 32,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.xl),
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isEmpty
                    ? _fallback()
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return _loading();
                        },
                        errorBuilder: (_, __, ___) => _fallback(),
                      ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(S.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(R.xs),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.22)),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.6,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.82),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: S.md),
                    Row(
                      children: [
                        _pill(Icons.access_time_rounded, item.time),
                        const SizedBox(width: 6),
                        _pill(Icons.source_rounded, item.source),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.c1, item.c2],
        ),
      ),
      child: Center(
        child: Icon(item.icon,
            color: Colors.white.withOpacity(0.3), size: 80),
      ),
    );
  }

  Widget _loading() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.c1, item.c2],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(P.bone.withOpacity(0.7)),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(R.xs),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

String _fallbackCover(NewsData item) {
  final lower = '${item.category} ${item.title}'.toLowerCase();
  if (lower.contains('siber') ||
      lower.contains('security') ||
      lower.contains('hacker') ||
      lower.contains('malware') ||
      lower.contains('keamanan') ||
      lower.contains('serangan')) {
    return 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=1200&q=85';
  }
  return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1200&q=85';
}

// ═════════════════════════════════════════════════════════════════
// LIVE SERVICES
// ═════════════════════════════════════════════════════════════════

class WeatherData {
  final String city;
  final int temperature;
  final int feelsLike;
  final int humidity;
  final int windSpeed;
  final String condition;
  final bool isDay;
  final double precipitation;
  final DateTime? updatedAt;
  final DateTime? sunrise;
  final DateTime? sunset;

  const WeatherData({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.isDay,
    this.precipitation = 0,
    this.updatedAt,
    this.sunrise,
    this.sunset,
  });
}

class ChatMessageData {
  final String id;
  final String sender;
  final String message;
  final DateTime timestamp;

  const ChatMessageData({
    required this.id,
    required this.sender,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessageData.fromJson(Map<String, dynamic> json) {
    return ChatMessageData(
      id: '${json['id'] ?? ''}',
      sender: '${json['sender'] ?? 'Unknown'}',
      message: '${json['message'] ?? ''}',
      timestamp: DateTime.tryParse('${json['timestamp'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class LiveServices {
  static const Duration _timeout = Duration(seconds: 14);

  static Future<String> _getText(Uri uri, {Map<String, String>? headers}) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'NekoVerse/1.0');
      headers?.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(_timeout);
      final body = await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Server mengembalikan HTTP ${response.statusCode}.');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  static Future<WeatherData> fetchWeather() async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '-6.2088',
      'longitude': '106.8456',
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,is_day',
      'daily': 'sunrise,sunset',
      'timezone': 'Asia/Jakarta',
      'wind_speed_unit': 'ms',
    });
    final body = await _getText(uri);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> ||
        decoded['current'] is! Map<String, dynamic>) {
      throw const FormatException('Format data cuaca tidak valid.');
    }
    final current = decoded['current'] as Map<String, dynamic>;
    final daily = decoded['daily'] is Map
        ? decoded['daily'] as Map<String, dynamic>
        : <String, dynamic>{};
    DateTime? sunrise;
    DateTime? sunset;
    try {
      final sunriseList = daily['sunrise'];
      final sunsetList = daily['sunset'];
      if (sunriseList is List && sunriseList.isNotEmpty) {
        sunrise = DateTime.tryParse('${sunriseList.first}');
      }
      if (sunsetList is List && sunsetList.isNotEmpty) {
        sunset = DateTime.tryParse('${sunsetList.first}');
      }
    } catch (_) {}

    num value(String key) {
      final raw = current[key];
      if (raw is num) return raw;
      return num.tryParse('$raw') ?? 0;
    }

    final code = value('weather_code').round();
    final isDay = value('is_day').round() == 1;
    return WeatherData(
      city: 'Jakarta',
      temperature: value('temperature_2m').round(),
      feelsLike: value('apparent_temperature').round(),
      humidity: value('relative_humidity_2m').round().clamp(0, 100).toInt(),
      windSpeed: value('wind_speed_10m').round().clamp(0, 150).toInt(),
      precipitation: value('precipitation').toDouble(),
      condition: _weatherCondition(code, isDay),
      isDay: isDay,
      updatedAt: DateTime.now(),
      sunrise: sunrise,
      sunset: sunset,
    );
  }

  static String _weatherCondition(int code, bool isDay) {
    if (code == 0) return isDay ? 'Cerah' : 'Cerah malam';
    if (code == 1) return 'Cerah berawan';
    if (code == 2) return 'Berawan';
    if (code == 3) return 'Mendung';
    if (code == 45 || code == 48) return 'Berkabut';
    if ([51, 53, 55, 56, 57].contains(code)) return 'Gerimis';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return 'Hujan';
    if ([71, 73, 75, 77, 85, 86].contains(code)) return 'Hujan salju';
    if (code == 95 || code == 96 || code == 99) return 'Badai petir';
    return 'Cuaca berubah';
  }

  static Future<List<NewsData>> fetchNews() async {
    const sources = <Map<String, String>>[
      {
        'url': 'https://feeds.feedburner.com/TheHackersNews',
        'name': 'The Hacker News'
      },
      {
        'url': 'https://www.bleepingcomputer.com/feed/',
        'name': 'BleepingComputer'
      },
      {'url': 'https://www.kompas.com/getrss/tekno', 'name': 'Kompas Tekno'},
    ];

    final batches = await Future.wait(sources.map((source) async {
      try {
        final xml = await _getText(Uri.parse(source['url']!));
        return _parseRss(xml, source['name']!);
      } catch (_) {
        return <NewsData>[];
      }
    }));

    final results = <NewsData>[];
    final seenTitles = <String>{};
    for (final batch in batches) {
      for (final article in batch) {
        if (seenTitles.add(article.title.toLowerCase())) {
          results.add(article);
        }
      }
    }

    if (results.isEmpty) {
      final fallbackUri = Uri.https('news.google.com', '/rss/search', {
        'q': 'teknologi OR "keamanan siber" OR AI when:2d',
        'hl': 'id',
        'gl': 'ID',
        'ceid': 'ID:id',
      });
      final xml = await _getText(fallbackUri);
      results.addAll(_parseRss(xml, 'Google News RSS'));
    }

    results.sort((a, b) {
      final aDate = a.publishedAt ?? DateTime(1970);
      final bDate = b.publishedAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    if (results.isEmpty) {
      throw const FormatException(
          'Feed berita kosong atau format RSS berubah.');
    }
    return results.take(12).toList(growable: false);
  }

  static List<NewsData> _parseRss(String xml, String defaultSource) {
    final itemMatches = RegExp(
      r'<item\b[^>]*>([\s\S]*?)</item>',
      caseSensitive: false,
    ).allMatches(xml);
    final results = <NewsData>[];
    final seenTitles = <String>{};

    for (final itemMatch in itemMatches) {
      final itemXml = itemMatch.group(1) ?? '';
      String field(String tag) {
        final match = RegExp(
          r'<' + tag + r'(?:\s[^>]*)?>([\s\S]*?)</' + tag + r'>',
          caseSensitive: false,
        ).firstMatch(itemXml);
        return _cleanXml(match?.group(1) ?? '');
      }

      final title = field('title').trim();
      final link = field('link').trim();
      final source = field('source').trim();
      final description = field('description').trim();
      final pubDate = field('pubDate').trim();
      final validUri = Uri.tryParse(link);
      if (title.isEmpty ||
          link.isEmpty ||
          validUri == null ||
          (validUri.scheme != 'https' && validUri.scheme != 'http') ||
          !seenTitles.add(title.toLowerCase())) {
        continue;
      }

      DateTime? published;
      if (pubDate.isNotEmpty) {
        published = DateTime.tryParse(pubDate);
        if (published == null) {
          try {
            published = HttpDate.parse(pubDate);
          } catch (_) {
            published = null;
          }
        }
      }

      final titleLower = title.toLowerCase();
      final securityNews = defaultSource.toLowerCase().contains('hacker') ||
          defaultSource.toLowerCase().contains('bleeping') ||
          titleLower.contains('siber') ||
          titleLower.contains('keamanan') ||
          titleLower.contains('serangan');
      final c1 = securityNews ? P.crimson : P.violet;
      final c2 = securityNews ? P.bloodDeep : P.violetDeep;
      results.add(NewsData(
        category: securityNews ? 'KEAMANAN SIBER' : 'TEKNOLOGI',
        title: title,
        description: description.isEmpty
            ? 'Buka sumber berita untuk membaca laporan lengkap.'
            : (description.length > 190
                ? '${description.substring(0, 187)}…'
                : description),
        source: source.isEmpty ? defaultSource : source,
        time: _relativeAge(published),
        imageUrl: _extractImageUrl(itemXml, link),
        c1: c1,
        c2: c2,
        icon: securityNews ? Icons.security_rounded : Icons.newspaper_rounded,
        isLive: published != null &&
            DateTime.now().difference(published.toLocal()) <
                const Duration(hours: 3),
        linkUrl: link,
        publishedAt: published,
      ));
    }
    return results;
  }

  static String _extractImageUrl(String itemXml, String articleUrl) {
    final patterns = <RegExp>[
      RegExp(
        r'''<img\b[^>]*\b(?:src|data-src|data-original)\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<(?:media:thumbnail|media:content)\b[^>]*\burl\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<enclosure\b[^>]*\burl\s*=\s*["']([^"']+)["'][^>]*/?>''',
        caseSensitive: false,
      ),
    ];

    final searchableXml = itemXml
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(searchableXml)) {
        var candidate = (match.group(1) ?? '').trim();
        if (candidate.isEmpty) continue;
        candidate = candidate
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&#x2F;', '/')
            .replaceAll('&#47;', '/');

        Uri? uri = Uri.tryParse(candidate);
        final base = Uri.tryParse(articleUrl);
        if (uri != null && uri.scheme.isEmpty && base != null) {
          if (candidate.startsWith('//')) {
            uri = Uri.tryParse('${base.scheme}:$candidate');
          } else {
            uri = base.resolveUri(uri);
          }
        }
        if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
          continue;
        }

        final lower = candidate.toLowerCase();
        final looksLikeImage = RegExp(
          r'\.(?:jpe?g|png|webp|gif|avif)(?:[?#].*)?$|(?:image|thumbnail|img|media)',
          caseSensitive: false,
        ).hasMatch(lower);
        if (!looksLikeImage && pattern.pattern.contains('enclosure')) continue;
        return uri.toString();
      }
    }
    return '';
  }

  static String _cleanXml(String input) {
    var value = input
        .replaceAll(RegExp(r'<!\[CDATA\['), '')
        .replaceAll(RegExp(r'\]\]>'), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
    value = value.replaceAllMapped(
      RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'),
      (match) {
        final raw = match.group(1)!;
        final code = raw.startsWith('x')
            ? int.tryParse(raw.substring(1), radix: 16)
            : int.tryParse(raw);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      },
    );
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _relativeAge(DateTime? published) {
    if (published == null) return 'TERBARU';
    final age = DateTime.now().difference(published.toLocal());
    if (age.isNegative || age.inMinutes < 2) return 'BARU SAJA';
    if (age.inMinutes < 60) return '${age.inMinutes} MENIT';
    if (age.inHours < 24) return '${age.inHours} JAM';
    return '${age.inDays} HARI';
  }

  static Map<String, String> _authHeaders() {
    final token = AppSession.token ?? '';
    final device = AppSession.deviceId ?? '';
    return {
      if (token.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer $token',
      if (device.isNotEmpty) 'X-Device-ID': device,
      HttpHeaders.acceptHeader: 'application/json',
    };
  }

  // ─── STORY (dengan media support) ───
  static Future<List<StoryData>> fetchStories() async {
    final token = AppSession.token;
    final deviceId = AppSession.deviceId;
    if (token == null ||
        token.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      throw const HttpException('Sesi login belum tersedia.');
    }

    final uri = Uri.parse('${Cfg.backendBase}/api/chats/stories');
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      _authHeaders().forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(_timeout);
      final body =
          await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Server story mengembalikan HTTP ${response.statusCode}.');
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw const FormatException('Format story dari backend tidak valid.');
      }

      const palettes = <List<Color>>[
        [P.violet, P.violetDeep],
        [P.crimson, P.bloodDeep],
        [P.teal, P.rot],
        [P.orange, P.rust],
        [P.cyan, P.cyanDeep],
        [P.pink, P.pinkDeep],
      ];

      final currentUser =
          (AppSession.profile?.username ?? '').toLowerCase();
      final currentAvatarPath = AppSession.profile?.avatarPath ?? '';

      final results = <StoryData>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final record = Map<String, dynamic>.from(item);
        final username = '${record['username'] ?? 'Guest'}'.trim();
        final storyText = '${record['text'] ?? ''}'.trim();
        final mediaUrl = '${record['media_url'] ?? ''}'.trim();
        final mediaTypeStr = '${record['media_type'] ?? 'text'}'.trim();

        final rawCreated =
            '${record['timestamp'] ?? record['created_at'] ?? ''}';
        final createdAt = DateTime.tryParse(rawCreated);

        // skip kalau username kosong DAN tidak ada text DAN tidak ada media
        if (username.isEmpty) continue;
        if (storyText.isEmpty && mediaUrl.isEmpty) continue;
        if (createdAt == null) continue;

        final safeName = username;
        final paletteIndex = safeName.codeUnits
                .fold<int>(0, (sum, unit) => sum + unit) %
            palettes.length;
        final palette = palettes[paletteIndex];
        final isOwn = safeName.toLowerCase() == currentUser;

        StoryMediaType mediaType = StoryMediaType.text;
        if (mediaTypeStr.toLowerCase() == 'image') {
          mediaType = StoryMediaType.image;
        } else if (mediaTypeStr.toLowerCase() == 'video') {
          mediaType = StoryMediaType.video;
        } else if (mediaUrl.isNotEmpty) {
          final lower = mediaUrl.toLowerCase();
          if (lower.contains('.mp4') ||
              lower.contains('.mov') ||
              lower.contains('.webm')) {
            mediaType = StoryMediaType.video;
          } else {
            mediaType = StoryMediaType.image;
          }
        }

        results.add(StoryData(
          id: '${record['id'] ?? ''}',
          username: safeName,
          avatarText: safeName.charactersFirst,
          avatarPath: isOwn ? currentAvatarPath : '',
          c1: palette[0],
          c2: palette[1],
          isOwn: isOwn,
          isLive: DateTime.now().difference(createdAt.toLocal()) <
              const Duration(hours: 3),
          storyText: storyText.isEmpty ? null : storyText,
          mediaUrl: mediaUrl.isEmpty ? null : mediaUrl,
          mediaType: mediaType,
          createdAt: createdAt,
        ));
      }
      return results;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> publishStory({
    required String username,
    required String text,
    String? mediaUrl,
    StoryMediaType mediaType = StoryMediaType.text,
  }) async {
    final token = AppSession.token;
    final deviceId = AppSession.deviceId;
    if (token == null ||
        token.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      throw const HttpException('Sesi login belum tersedia.');
    }

    final uri = Uri.parse('${Cfg.backendBase}/api/chats/stories');
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(uri).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      _authHeaders().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({
        'text': text.trim(),
        'media_url': mediaUrl ?? '',
        'media_type': mediaType.name,
      }));

      final response = await request.close().timeout(_timeout);
      final body =
          await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Server story mengembalikan HTTP ${response.statusCode}.');
      }
      final decoded = body.isEmpty ? null : jsonDecode(body);
      if (decoded is Map && decoded['ok'] != true) {
        throw HttpException(
            '${decoded['message'] ?? decoded['error'] ?? 'Story gagal dipublikasi.'}');
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<ChatMessageData>> fetchChats() async {
    final token = AppSession.token;
    final deviceId = AppSession.deviceId;
    if (token == null ||
        token.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      throw const HttpException('Sesi login belum tersedia.');
    }

    final uri = Uri.parse('${Cfg.backendBase}/api/chats');
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      _authHeaders().forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(_timeout);
      final body =
          await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Server chat mengembalikan HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw const FormatException('Format chat dari backend tidak valid.');
      }
      return decoded
          .whereType<Map>()
          .map((raw) =>
              ChatMessageData.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }

  static Future<ChatMessageData> sendChat(String message) async {
    final token = AppSession.token;
    final deviceId = AppSession.deviceId;
    if (token == null ||
        token.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      throw const HttpException('Sesi login belum tersedia.');
    }

    final uri = Uri.parse('${Cfg.backendBase}/api/chats');
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(uri).timeout(_timeout);
      request.headers.contentType = ContentType.json;
      _authHeaders().forEach((k, v) => request.headers.set(k, v));
      request.write(jsonEncode({'message': message.trim()}));

      final response = await request.close().timeout(_timeout);
      final body =
          await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Server chat mengembalikan HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['ok'] != true || decoded['item'] is! Map) {
        throw const FormatException('Respons chat tidak valid.');
      }
      return ChatMessageData.fromJson(
          Map<String, dynamic>.from(decoded['item'] as Map));
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> fetchBackendStatus() async {
    final uri = Uri.parse('${Cfg.backendBase}/api/status');
    final body = await _getText(uri);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respons status backend tidak valid.');
    }
    return decoded;
  }
}

extension _FirstCharacter on String {
  String get charactersFirst =>
      isEmpty ? '?' : substring(0, 1).toUpperCase();
}

// ═════════════════════════════════════════════════════════════════
// WEATHER CARD
// ═════════════════════════════════════════════════════════════════

class WeatherCard extends StatefulWidget {
  final WeatherData? data;
  final bool loading;
  final String? error;
  final VoidCallback? onRefresh;
  const WeatherCard({
    super.key,
    required this.data,
    this.loading = false,
    this.error,
    this.onRefresh,
  });

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard>
    with TickerProviderStateMixin {
  late AnimationController _arc;

  @override
  void initState() {
    super.initState();
    _arc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _arc.dispose();
    super.dispose();
  }

  double get _sunProgress {
    final d = widget.data;
    if (d == null || d.sunrise == null || d.sunset == null) {
      return d?.isDay == true ? 0.5 : 0.15;
    }
    final now = DateTime.now();
    final rise = d.sunrise!;
    final set = d.sunset!;
    if (now.isBefore(rise)) return 0.0;
    if (now.isAfter(set)) return 1.0;
    final total = set.difference(rise).inSeconds;
    final passed = now.difference(rise).inSeconds;
    return (passed / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d == null) return _placeholder();
    final bgAsset = d.isDay ? Cfg.siang : Cfg.malam;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.xxl),
        boxShadow: [
          BoxShadow(
            color: (d.isDay ? P.amber : P.violet).withOpacity(0.35),
            blurRadius: 38,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.xxl),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: d.isDay
                        ? const [
                            Color(0xFFD18A56),
                            Color(0xFF8D5364),
                            Color(0xFF302343)
                          ]
                        : const [
                            Color(0xFF5A4A88),
                            Color(0xFF26345B),
                            Color(0xFF0D1020)
                          ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.65,
                child: Image.asset(
                  bgAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.02),
                      Colors.black.withOpacity(0.14),
                      Colors.black.withOpacity(0.42),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 92,
              child: Material(
                color: Colors.black.withOpacity(0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.loading ? null : widget.onRefresh,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: widget.loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(S.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(R.pill),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: P.bone),
                        const SizedBox(width: 5),
                        Text(
                          d.city.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: Cfg.bugFont,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: P.bone,
                            letterSpacing: 1.4,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${d.temperature}',
                        style: const TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -2,
                          height: 1.0,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12, left: 4),
                        child: Text(
                          '°C',
                          style: TextStyle(
                            fontFamily: Cfg.bugFont,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            d.condition.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: Cfg.bugFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.95),
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: S.md),
                  Row(
                    children: [
                      _stat(Icons.thermostat_rounded, 'TERASA',
                          '${d.feelsLike}°C'),
                      const SizedBox(width: 6),
                      _stat(Icons.water_drop_rounded, 'LEMBAP',
                          '${d.humidity}%'),
                      const SizedBox(width: 6),
                      _stat(Icons.air_rounded, 'ANGIN',
                          '${d.windSpeed} m/s'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.xxl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB56D4D), Color(0xFF5D385A), Color(0xFF17192E)],
        ),
        border: Border.all(color: P.bone.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CUACA JAKARTA',
            style: TextStyle(
              fontFamily: Cfg.bugFont,
              color: P.bone,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            widget.loading
                ? 'MENGAMBIL DATA CUACA…'
                : 'DATA CUACA BELUM TERSEDIA',
            style: const TextStyle(
              fontFamily: Cfg.bugFont,
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.error ?? 'Menghubungkan ke layanan cuaca.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: S.md),
          Align(
            alignment: Alignment.bottomLeft,
            child: OutlinedButton.icon(
              onPressed: widget.loading ? null : widget.onRefresh,
              icon: widget.loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('COBA LAGI'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side:
                    BorderSide(color: Colors.white.withOpacity(0.45)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: P.bone),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: P.bone.withOpacity(0.65),
                      letterSpacing: 0.9,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// ORBITAL MENU
// ═════════════════════════════════════════════════════════════════

class OrbitalItem {
  final String label;
  final String sub;
  final IconData icon;
  final Color c1;
  final Color c2;
  final VoidCallback onTap;
  const OrbitalItem({
    required this.label,
    required this.sub,
    required this.icon,
    required this.c1,
    required this.c2,
    required this.onTap,
  });
}

class OrbitalMenu extends StatefulWidget {
  final List<OrbitalItem> items;
  final double height;
  const OrbitalMenu({super.key, required this.items, this.height = 380});

  @override
  State<OrbitalMenu> createState() => _OrbitalMenuState();
}

class _OrbitalMenuState extends State<OrbitalMenu>
    with TickerProviderStateMixin {
  late AnimationController _orbit;
  late AnimationController _logoPulse;
  late AnimationController _ringSpin;
  late AnimationController _ringSpinReverse;
  late AnimationController _entrance;
  String? _selectedLabel;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 70),
    )..repeat();
    _logoPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _ringSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
    _ringSpinReverse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 38),
    )..repeat();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _orbit.dispose();
    _logoPulse.dispose();
    _ringSpin.dispose();
    _ringSpinReverse.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final count = items.length;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final shortest = math.min(w, h);
          final center = Offset(w / 2, h / 2);
          final orbitRadius = shortest * 0.33;
          final planetSize = shortest * 0.16;
          final logoSize = shortest * 0.26;

          return AnimatedBuilder(
            animation: Listenable.merge([
              _orbit,
              _logoPulse,
              _ringSpin,
              _ringSpinReverse,
              _entrance,
            ]),
            builder: (_, __) {
              final rotation = _orbit.value * 2 * math.pi;
              final pulse = _logoPulse.value;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _OrbitBackdropPainter(
                          center: center,
                          orbitRadius: orbitRadius,
                          rotation: rotation,
                          planetSize: planetSize,
                          pulse: pulse,
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(count, (i) {
                    final angle =
                        (i / count) * 2 * math.pi - math.pi / 2 + rotation;
                    final dx = math.cos(angle) * orbitRadius;
                    final dy = math.sin(angle) * orbitRadius;
                    final pos = center + Offset(dx, dy);

                    final delay = i * 0.07;
                    final localT = ((_entrance.value * 1.3) - delay)
                        .clamp(0.0, 1.0)
                        .toDouble();
                    final scale = Curves.easeOutBack.transform(localT);
                    final selected = _selectedLabel == items[i].label;

                    return Positioned(
                      left: pos.dx - planetSize / 2,
                      top: pos.dy - planetSize / 2,
                      width: planetSize,
                      height: planetSize,
                      child: Transform.scale(
                        scale: scale.clamp(0.0, 1.2).toDouble(),
                        child: Opacity(
                          opacity: localT.clamp(0.0, 1.0).toDouble(),
                          child: _PlanetItem(
                            item: items[i],
                            size: planetSize,
                            selected: selected,
                            pulse: pulse,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(
                                  () => _selectedLabel = items[i].label);
                              items[i].onTap();
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    left: center.dx - logoSize / 2,
                    top: center.dy - logoSize / 2,
                    width: logoSize,
                    height: logoSize,
                    child: IgnorePointer(
                      child: _CenterLogo(
                        size: logoSize,
                        pulse: pulse,
                        rotate: _ringSpin,
                        rotateReverse: _ringSpinReverse,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _OrbitBackdropPainter extends CustomPainter {
  final Offset center;
  final double orbitRadius;
  final double rotation;
  final double planetSize;
  final double pulse;

  _OrbitBackdropPainter({
    required this.center,
    required this.orbitRadius,
    required this.rotation,
    required this.planetSize,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowRect =
        Rect.fromCircle(center: center, radius: orbitRadius * 1.6);
    canvas.drawCircle(
      center,
      orbitRadius * 1.55,
      Paint()
        ..shader = RadialGradient(
          colors: [P.blood.withOpacity(0.16), P.blood.withOpacity(0.0)],
        ).createShader(glowRect),
    );

    canvas.drawCircle(
      center,
      orbitRadius,
      Paint()
        ..color = P.blood.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawCircle(
      center,
      orbitRadius - planetSize * 0.85,
      Paint()
        ..color = P.violet.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawCircle(
      center,
      orbitRadius + planetSize * 0.75,
      Paint()
        ..color = P.crimson.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawCircle(
      center,
      orbitRadius + planetSize * 0.75 + pulse * 8,
      Paint()
        ..color = P.bloodBright.withOpacity(0.16 * (1 - pulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitBackdropPainter old) => true;
}

class _PlanetItem extends StatefulWidget {
  final OrbitalItem item;
  final double size;
  final bool selected;
  final double pulse;
  final VoidCallback onTap;

  const _PlanetItem({
    required this.item,
    required this.size,
    required this.selected,
    required this.pulse,
    required this.onTap,
  });

  @override
  State<_PlanetItem> createState() => _PlanetItemState();
}

class _PlanetItemState extends State<_PlanetItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final selected = widget.selected;
    final glow = 0.55 + math.sin(widget.pulse * math.pi * 2) * 0.28;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : (selected ? 1.15 : 1.0),
        duration: T.normal,
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.c1
                          .withOpacity(selected ? 0.9 : 0.5 * glow),
                      blurRadius: selected ? 30 : 22,
                    ),
                  ],
                ),
              ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.5),
                    radius: 1.1,
                    colors: [
                      Color.lerp(P.bone, widget.item.c1, 0.35)!,
                      widget.item.c1,
                      widget.item.c2,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: P.bone.withOpacity(selected ? 0.85 : 0.45),
                    width: selected ? 1.8 : 1.2,
                  ),
                ),
              ),
              Container(
                width: size * 0.52,
                height: size * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.item.icon,
                  color: P.bone,
                  size: size * 0.32,
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: P.bone.withOpacity(0.9),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterLogo extends StatelessWidget {
  final double size;
  final double pulse;
  final Animation<double> rotate;
  final Animation<double> rotateReverse;

  const _CenterLogo({
    required this.size,
    required this.pulse,
    required this.rotate,
    required this.rotateReverse,
  });

  @override
  Widget build(BuildContext context) {
    final glow = 0.55 + math.sin(pulse * math.pi * 2) * 0.28;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([rotate, rotateReverse]),
        builder: (_, __) {
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: P.crimson.withOpacity(glow * 0.65),
                        blurRadius: 44,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: size * 0.78,
                  height: size * 0.78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [P.crimson, P.blood, P.violetDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: P.crimson.withOpacity(0.7),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: P.bgDeep,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        Cfg.logoPage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [P.blood, P.violetDeep],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.remove_red_eye_rounded,
                              color: P.bone,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// COMMAND PALETTE
// ═════════════════════════════════════════════════════════════════

class CommandItem {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Future<void> Function() action;
  const CommandItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.action,
  });
}

class CommandPalette extends StatefulWidget {
  final List<CommandItem> commands;
  const CommandPalette({super.key, required this.commands});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  late AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _controller.addListener(() {
      setState(() => _query = _controller.text.toLowerCase().trim());
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<CommandItem> get _filtered {
    if (_query.isEmpty) return widget.commands;
    return widget.commands.where((c) {
      return c.label.toLowerCase().contains(_query) ||
          c.description.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: fade,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(S.lg),
            child: Column(
              children: [
                Glass(
                  radius: R.xl,
                  tint: P.bgElevated.withOpacity(0.95),
                  borderColor: P.crimson.withOpacity(0.55),
                  padding: const EdgeInsets.symmetric(
                      horizontal: S.lg, vertical: S.md),
                  glow: true,
                  glowColor: P.crimson,
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: P.crimson, size: 22),
                      const SizedBox(width: S.md),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          cursorColor: P.crimson,
                          style: const TextStyle(
                            fontFamily: Cfg.bugFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: P.bone,
                            letterSpacing: 0.6,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'CARI COMMAND ATAU MENU...',
                            hintStyle: TextStyle(
                              fontFamily: Cfg.bugFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: P.text3,
                              letterSpacing: 1.2,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      Tap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: P.surface,
                            borderRadius: BorderRadius.circular(R.xs),
                            border: Border.all(color: P.border),
                          ),
                          child: const Text(
                            'ESC',
                            style: TextStyle(
                              fontFamily: Cfg.bugFont,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: P.text3,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: S.md),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada hasil untuk "$_query"',
                            style: const TextStyle(color: P.text3),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: S.sm),
                          itemBuilder: (_, i) => _tile(results[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(CommandItem cmd) {
    return Tap(
      onTap: () async {
        Navigator.of(context).pop();
        await Future.delayed(const Duration(milliseconds: 180));
        await cmd.action();
      },
      child: Glass(
        radius: R.md,
        tint: P.bgElevated.withOpacity(0.85),
        borderColor: cmd.color.withOpacity(0.3),
        padding: const EdgeInsets.all(S.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cmd.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: cmd.color.withOpacity(0.4)),
              ),
              child: Icon(cmd.icon, color: cmd.color, size: 20),
            ),
            const SizedBox(width: S.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cmd.label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                      letterSpacing: 1.0,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cmd.description,
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 9.5,
                      color: P.text2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_return_rounded,
                color: cmd.color.withOpacity(0.6), size: 16),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// NAV BAR — HOME | MENU | [RAT] | TOOLS | SETTING
// Layout: Home - Menu - (RAT center button) - Tools - Setting
// ═════════════════════════════════════════════════════════════════

class NavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  const NavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.onCenterTap,
  });

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> with TickerProviderStateMixin {
  late AnimationController _pulse;
  late AnimationController _shimmer;
  late AnimationController _center;

  // index: 0=HOME, 1=MENU, 2=TOOLS (di kanan center), 3=SETTING
  static const _items = [
    _NItem(Icons.home_outlined, Icons.home_rounded, 'HOME', P.violet),
    _NItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'MENU',
        P.blood),
    _NItem(Icons.build_outlined, Icons.build_rounded, 'TOOLS', P.cyan),
    _NItem(Icons.settings_outlined, Icons.settings_rounded, 'SETTING',
        P.teal),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _center = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shimmer.dispose();
    _center.dispose();
    super.dispose();
  }

  Color get _activeColor {
    if (widget.index < 0 || widget.index >= _items.length) {
      return _items[0].color;
    }
    return _items[widget.index].color;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          S.lg, 0, S.lg, bottomInset > 0 ? bottomInset - 4 : S.md),
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.xxl),
                border: Border.all(
                  color: _activeColor.withOpacity(0.45),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _activeColor.withOpacity(0.35),
                    blurRadius: 34,
                    spreadRadius: -8,
                  ),
                  const BoxShadow(
                    color: Color(0xD9000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.xxl),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                P.surface.withOpacity(0.96),
                                P.bgElevated.withOpacity(0.92),
                                P.surface.withOpacity(0.96),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 1.6,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _shimmer,
                            builder: (_, __) {
                              final dx = -1 + _shimmer.value * 2;
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(dx - 0.5, 0),
                                    end: Alignment(dx + 0.5, 0),
                                    colors: [
                                      Colors.transparent,
                                      _activeColor.withOpacity(0.0),
                                      _activeColor.withOpacity(0.9),
                                      _activeColor.withOpacity(0.0),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _NavSlot(
                              item: _items[0],
                              active: widget.index == 0,
                              onTap: () => widget.onTap(0),
                            ),
                          ),
                          Expanded(
                            child: _NavSlot(
                              item: _items[1],
                              active: widget.index == 1,
                              onTap: () => widget.onTap(1),
                            ),
                          ),
                          const Spacer(),
                          Expanded(
                            child: _NavSlot(
                              item: _items[2],
                              active: widget.index == 2,
                              onTap: () => widget.onTap(2),
                            ),
                          ),
                          Expanded(
                            child: _NavSlot(
                              item: _items[3],
                              active: widget.index == 3,
                              onTap: () => widget.onTap(3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // RAT center button — SAMA PERSIS kayak sebelumnya
            Positioned(
              top: -28,
              child: _CenterButton(
                rotation: _center,
                onTap: widget.onCenterTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const _NItem(this.icon, this.activeIcon, this.label, this.color);
}

class _NavSlot extends StatefulWidget {
  final _NItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavSlot({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavSlot> createState() => _NavSlotState();
}

class _NavSlotState extends State<_NavSlot> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: T.fast,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: T.normal,
              curve: Curves.easeOutCubic,
              padding:
                  const EdgeInsets.symmetric(horizontal: S.md, vertical: 5),
              decoration: BoxDecoration(
                gradient: widget.active
                    ? LinearGradient(
                        colors: [
                          widget.item.color.withOpacity(0.3),
                          widget.item.color.withOpacity(0.08),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Icon(
                widget.active ? widget.item.activeIcon : widget.item.icon,
                size: 22,
                color: widget.active ? widget.item.color : P.text4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.item.label,
              style: TextStyle(
                fontFamily: Cfg.bugFont,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: widget.active ? widget.item.color : P.text5,
                letterSpacing: 1.1,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Center button = RAT (icon remote + hexagon frame + efek — sama persis seperti sebelumnya)
class _CenterButton extends StatelessWidget {
  final Animation<double> rotation;
  final VoidCallback onTap;
  const _CenterButton({required this.rotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: rotation,
          builder: (_, __) {
            final pulse =
                0.5 + 0.5 * math.sin(rotation.value * math.pi * 2);
            return SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 82 + pulse * 10,
                    height: 82 + pulse * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          P.crimson.withOpacity(0.5 * pulse + 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: rotation.value * math.pi * 2,
                    child: CustomPaint(
                      size: const Size(84, 84),
                      painter: _HexFramePainter(P.crimson),
                    ),
                  ),
                  Transform.rotate(
                    angle: -rotation.value * math.pi * 4,
                    child: CustomPaint(
                      size: const Size(68, 68),
                      painter: _HexFramePainter(
                        P.violet.withOpacity(0.55),
                      ),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [P.crimson, P.blood, P.violetDeep],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: P.crimson.withOpacity(0.75 + pulse * 0.2),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: P.bloodBright.withOpacity(0.55),
                          blurRadius: 52,
                          spreadRadius: 5,
                        ),
                        const BoxShadow(
                          color: Color(0xB3000000),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFF2A0A0A), Color(0xFF05030A)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.settings_remote_rounded,
                          color: P.bone,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HexFramePainter extends CustomPainter {
  final Color color;
  _HexFramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i <= 6; i++) {
      final angle = (i / 6) * math.pi * 2 - math.pi / 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi * 2 - math.pi / 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      canvas.drawCircle(
        Offset(x, y),
        2.5,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HexFramePainter old) => old.color != color;
}

// ═════════════════════════════════════════════════════════════════
// ACCENT PICKER SHEET
// ═════════════════════════════════════════════════════════════════

class AccentPickerSheet extends StatelessWidget {
  const AccentPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(S.lg),
        child: Glass(
          radius: R.xxl,
          tint: P.surface.withOpacity(0.97),
          borderColor: P.borderBright.withOpacity(0.6),
          padding: const EdgeInsets.all(S.xl),
          glow: true,
          glowColor: P.violet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_rounded,
                      color: P.violet, size: 22),
                  const SizedBox(width: S.sm),
                  const Text(
                    'WARNA AKSEN',
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<Color>(
                    valueListenable: accentNotifier,
                    builder: (_, current, __) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: current.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(R.pill),
                        border:
                            Border.all(color: current.withOpacity(0.55)),
                      ),
                      child: Text(
                        AccentPresets.labelOf(current),
                        style: TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: current,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: S.lg),
              const Text(
                'Pilih warna aksen untuk seluruh aplikasi.',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 10.5,
                  color: P.text2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: S.xl),
              Row(
                children: AccentPresets.all.entries.map((entry) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _option(context, entry.key, entry.value),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, String label, Color color) {
    return ValueListenableBuilder<Color>(
      valueListenable: accentNotifier,
      builder: (_, current, __) {
        final active = current == color;
        return Tap(
          onTap: () {
            accentNotifier.value = color;
            Navigator.of(context).pop();
          },
          child: AnimatedContainer(
            duration: T.normal,
            padding: const EdgeInsets.symmetric(
                horizontal: S.sm, vertical: S.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: active
                    ? [color.withOpacity(0.35), color.withOpacity(0.1)]
                    : [P.surface, P.bgElevated],
              ),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(
                color: active
                    ? color.withOpacity(0.85)
                    : P.border.withOpacity(0.6),
                width: active ? 1.6 : 1.2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.5)],
                    ),
                  ),
                  child: Icon(
                    AccentPresets.icons[label] ?? Icons.circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: S.sm),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: active ? color : P.text3,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// SETTING SCREEN
// ═════════════════════════════════════════════════════════════════

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _busy = false;
  bool _idCopied = false;

  @override
  void initState() {
    super.initState();
    AppSession.refreshProfile().then((ok) {
      if (!mounted || !ok || AppSession.profile == null) return;
      ProfileStore.save(AppSession.profile!);
    });
  }

  Future<void> _pickAvatar({required bool fromCamera}) async {
    if (_busy) return;
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 720,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final saved = await AvatarStore.saveAvatar(file);
      final profile = ProfileStore.current;
      if (profile != null) {
        await AvatarStore.deleteAvatar(profile.avatarPath);
        final updated = profile.copyWith(avatarPath: saved);
        await ProfileStore.save(updated);
        await AppSession.updateAvatar(saved);
        await ProfileStore.save(updated);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAvatar() async {
    final profile = ProfileStore.current;
    if (profile == null) return;
    setState(() => _busy = true);
    await AvatarStore.deleteAvatar(profile.avatarPath);
    await ProfileStore.save(profile.copyWith(avatarPath: ''));
    await AppSession.updateAvatar('');
    if (mounted) setState(() => _busy = false);
  }

  void _showAvatarOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final hasAvatar =
            (ProfileStore.current?.avatarPath ?? '').isNotEmpty;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(S.lg),
            child: Glass(
              radius: R.xxl,
              tint: P.surface.withOpacity(0.98),
              borderColor: P.violet.withOpacity(0.6),
              padding: const EdgeInsets.all(S.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: P.border,
                      borderRadius: BorderRadius.circular(R.pill),
                    ),
                  ),
                  const SizedBox(height: S.lg),
                  const Text(
                    'FOTO PROFIL',
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: S.lg),
                  _avatarOption(
                    icon: Icons.photo_library_rounded,
                    color: P.violet,
                    label: 'PILIH DARI GALERI',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAvatar(fromCamera: false);
                    },
                  ),
                  const SizedBox(height: S.sm),
                  _avatarOption(
                    icon: Icons.camera_alt_rounded,
                    color: P.cyan,
                    label: 'AMBIL DARI KAMERA',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAvatar(fromCamera: true);
                    },
                  ),
                  if (hasAvatar) ...[
                    const SizedBox(height: S.sm),
                    _avatarOption(
                      icon: Icons.delete_outline_rounded,
                      color: P.crimson,
                      label: 'HAPUS FOTO',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _removeAvatar();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _avatarOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: S.md),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.7), size: 20),
          ],
        ),
      ),
    );
  }

  void _copyId() {
    final profile = ProfileStore.current;
    if (profile == null) return;
    Clipboard.setData(ClipboardData(text: profile.id));
    HapticFeedback.mediumImpact();
    setState(() => _idCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _idCopied = false);
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await _confirm(
      title: 'LOG OUT',
      message:
          'Kamu akan keluar dari sesi ini. Device binding tetap tersimpan di server.',
      confirmText: 'LOG OUT',
      confirmColor: P.crimson,
    );
    if (ok != true) return;
    await AppSession.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await _confirm(
      title: 'HAPUS AKUN',
      message:
          'Akun akan dihapus dari backend beserta sesi dan binding perangkat. Tidak dapat dibatalkan.',
      confirmText: 'HAPUS PERMANEN',
      confirmColor: P.crimson,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final deleted = await AppSession.deleteAccount();
    if (!deleted) {
      if (mounted) setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Akun gagal dihapus dari server. Coba lagi saat online.'),
        ),
      );
      return;
    }
    final profile = ProfileStore.current;
    if (profile != null) await AvatarStore.deleteAvatar(profile.avatarPath);
    await AppSession.clear();
    await ProfileStore.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(S.xl),
          decoration: BoxDecoration(
            color: P.surface,
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(color: confirmColor.withOpacity(0.55)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: confirmColor.withOpacity(0.15),
                  border: Border.all(
                      color: confirmColor.withOpacity(0.55), width: 1.4),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: confirmColor, size: 28),
              ),
              const SizedBox(height: S.lg),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: S.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 11,
                  color: P.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: S.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: P.text2,
                        side: const BorderSide(color: P.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(R.md),
                        ),
                      ),
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(R.md),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: P.bg,
      body: Star(
        child: ValueListenableBuilder<UserProfile?>(
          valueListenable: ProfileStore.notifier,
          builder: (_, profile, __) {
            final p = profile ??
                UserProfile(
                  id: 'NEKO-LOADING',
                  username: 'GUEST USER',
                  avatarPath: '',
                  expired: '--',
                  role: 'basic',
                  email: '',
                  createdAt: DateTime.now(),
                );
            return SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    backgroundColor: P.bg.withOpacity(0.85),
                    surfaceTintColor: Colors.transparent,
                    expandedHeight: 60,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: P.bone),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    title: const Text(
                      'SETTING',
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: P.bone,
                        letterSpacing: 2.4,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(S.lg, S.lg, S.lg, 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _headerCard(p),
                          const SizedBox(height: S.lg),
                          _sectionLabel('INFORMASI AKUN'),
                          const SizedBox(height: S.sm),
                          _infoCard(p),
                          const SizedBox(height: S.lg),
                          _sectionLabel('KEAMANAN & SESI'),
                          const SizedBox(height: S.sm),
                          _actionCard(
                            icon: Icons.logout_rounded,
                            color: P.amber,
                            title: 'Log Out',
                            subtitle: 'Keluar dari sesi aktif',
                            onTap: _confirmLogout,
                          ),
                          const SizedBox(height: S.sm),
                          _actionCard(
                            icon: Icons.delete_forever_rounded,
                            color: P.crimson,
                            title: 'Hapus Akun',
                            subtitle: 'Hapus akun dari server',
                            onTap: _confirmDelete,
                            danger: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [P.crimson, P.violet]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: P.boneSoft,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(UserProfile p) {
    final hasAvatar = p.avatarPath.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.xxl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0B24), Color(0xFF0D0715), Color(0xFF2A0B15)],
        ),
        border: Border.all(color: P.crimson.withOpacity(0.35), width: 1.4),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [P.crimson, P.violet, P.cyan, P.crimson],
                  ),
                ),
              ),
              Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: P.bgDeep,
                ),
                child: ClipOval(
                  child: hasAvatar
                      ? Image.file(
                          File(p.avatarPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _initialAvatar(p.initial),
                        )
                      : _initialAvatar(p.initial),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Tap(
                  onTap: _showAvatarOptions,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [P.crimson, P.violetDeep],
                      ),
                      border: Border.all(color: P.bgDeep, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: S.lg),
          Text(
            p.username.toUpperCase(),
            style: const TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: P.bone,
              letterSpacing: 0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoleChipSimple(role: p.role, fontSize: 9.5),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.expiryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(R.pill),
                  border: Border.all(
                      color: p.expiryColor.withOpacity(0.5), width: 1.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 10, color: p.expiryColor),
                    const SizedBox(width: 5),
                    Text(
                      p.expiryStatus,
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: p.expiryColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: S.lg),
          Tap(
            onTap: _copyId,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.lg, vertical: S.md),
              decoration: BoxDecoration(
                color: P.bgDeep.withOpacity(0.85),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(
                  color:
                      (_idCopied ? P.sick : P.crimson).withOpacity(0.55),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _idCopied
                        ? Icons.check_circle_rounded
                        : Icons.fingerprint_rounded,
                    color: _idCopied ? P.sick : P.crimson,
                    size: 16,
                  ),
                  const SizedBox(width: S.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'USER ID',
                        style: TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: P.text3,
                          letterSpacing: 1.6,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.id,
                        style: TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _idCopied ? P.sick : P.bone,
                          letterSpacing: 2.2,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: S.lg),
                  Icon(
                    _idCopied
                        ? Icons.check_rounded
                        : Icons.content_copy_rounded,
                    color: _idCopied ? P.sick : P.text3,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar(String initial) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [P.crimson, P.violetDeep],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: P.bone,
          ),
        ),
      ),
    );
  }

  Widget _infoCard(UserProfile p) {
    return Glass(
      radius: R.xl,
      tint: P.bgElevated.withOpacity(0.9),
      borderColor: P.border.withOpacity(0.6),
      padding: const EdgeInsets.all(S.lg),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.person_rounded,
            color: P.violet,
            label: 'USERNAME',
            value: p.username,
          ),
          _divider(),
          _infoRow(
            icon: Icons.calendar_today_rounded,
            color: P.amber,
            label: 'TANGGAL EXPIRED',
            value: p.expired.isEmpty ? '--' : p.expired,
            trailingValue: p.daysUntilExpiry != null
                ? '${p.daysUntilExpiry} hari'
                : null,
            valueColor: p.expiryColor,
          ),
          _divider(),
          _infoRow(
            icon: Icons.verified_user_rounded,
            color: P.cyan,
            label: 'STATUS AKUN',
            value: p.daysUntilExpiry != null && p.daysUntilExpiry! >= 0
                ? 'AKTIF'
                : 'EXPIRED',
            valueColor: p.daysUntilExpiry != null && p.daysUntilExpiry! >= 0
                ? P.sick
                : P.crimson,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? trailingValue,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: S.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: P.text3,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? P.bone,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          if (trailingValue != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (valueColor ?? P.violet).withOpacity(0.14),
                borderRadius: BorderRadius.circular(R.xs),
                border: Border.all(
                  color: (valueColor ?? P.violet).withOpacity(0.4),
                ),
              ),
              child: Text(
                trailingValue,
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? P.violet,
                  letterSpacing: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, P.border, Colors.transparent],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(S.md),
        decoration: BoxDecoration(
          color: color.withOpacity(danger ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: color.withOpacity(0.35), width: 1.3),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: color.withOpacity(0.45)),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: S.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 10,
                      color: P.text2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.6), size: 20),
          ],
        ),
      ),
    );
  }
}

class RoleChipSimple extends StatelessWidget {
  final String role;
  final double fontSize;
  const RoleChipSimple({
    super.key,
    required this.role,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    Color color2;
    IconData icon;
    String label;
    switch (role.toLowerCase()) {
      case 'owner':
        color = P.gold;
        color2 = P.rust;
        icon = Icons.workspace_premium_rounded;
        label = 'OWNER';
        break;
      case 'admin':
        color = P.violet;
        color2 = P.violetDeep;
        icon = Icons.shield_rounded;
        label = 'ADMIN';
        break;
      case 'vip':
        color = P.amber;
        color2 = P.rust;
        icon = Icons.star_rounded;
        label = 'VIP';
        break;
      default:
        color = P.crimson;
        color2 = P.bloodDeep;
        icon = Icons.person_rounded;
        label = 'BASIC';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.28), color2.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(R.pill),
        border: Border.all(color: color.withOpacity(0.6), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// TOOLS SCREEN (placeholder)
// ═════════════════════════════════════════════════════════════════

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        elevation: 0,
        title: const Text(
          'TOOLS',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(S.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: P.cyan.withOpacity(0.12),
                  border: Border.all(color: P.cyan.withOpacity(0.5)),
                ),
                child: const Icon(Icons.build_rounded,
                    color: P.cyan, size: 42),
              ),
              const SizedBox(height: S.lg),
              const Text(
                'TOOLS',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: S.sm),
              const Text(
                'Halaman tools akan segera hadir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 12,
                  color: P.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// RAT SCREEN (placeholder — siap diganti ke rat.dart)
// ═════════════════════════════════════════════════════════════════

class RatScreen extends StatelessWidget {
  const RatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        elevation: 0,
        title: const Text(
          'RAT HUB',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(S.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: P.crimson.withOpacity(0.12),
                  border: Border.all(color: P.crimson.withOpacity(0.5)),
                ),
                child: const Icon(Icons.settings_remote_rounded,
                    color: P.crimson, size: 42),
              ),
              const SizedBox(height: S.lg),
              const Text(
                'RAT HUB',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: S.sm),
              const Text(
                'Halaman RAT akan segera hadir.\nSiapkan rat.dart lalu aktifkan import-nya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 11,
                  color: P.text2,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// EXTRA SCREENS
// ═════════════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessageData> _messages = <ChatMessageData>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await LiveServices.fetchChats();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final item = await LiveServices.sendChat(value);
      if (!mounted) return;
      _controller.clear();
      setState(() => _messages.add(item));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat gagal dikirim: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentNotifier.value;
    final currentUser = AppSession.profile?.username ?? '';

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        elevation: 0,
        title: const Text(
          'COMMUNITY CHAT',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(S.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded,
                                  size: 46, color: P.text3),
                              const SizedBox(height: S.md),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: P.text2),
                              ),
                              const SizedBox(height: S.md),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('COBA LAGI'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text('Belum ada pesan.',
                                style: TextStyle(color: P.text3)),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(
                                S.lg, S.md, S.lg, S.lg),
                            itemCount: _messages.length,
                            itemBuilder: (_, index) {
                              final item = _messages[index];
                              final mine = item.sender.toLowerCase() ==
                                  currentUser.toLowerCase();
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 320),
                                  margin:
                                      const EdgeInsets.only(bottom: S.sm),
                                  padding: const EdgeInsets.all(S.md),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? accent.withOpacity(0.16)
                                        : P.surface,
                                    borderRadius:
                                        BorderRadius.circular(R.md),
                                    border: Border.all(
                                      color: mine
                                          ? accent.withOpacity(0.42)
                                          : P.border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.sender,
                                        style: TextStyle(
                                          color: mine ? accent : P.bone,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.message,
                                        style: const TextStyle(
                                            color: P.text, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        filled: true,
                        fillColor: P.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(R.pill),
                          borderSide: const BorderSide(color: P.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: S.sm),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackendStatusScreen extends StatefulWidget {
  const BackendStatusScreen({super.key});

  @override
  State<BackendStatusScreen> createState() => _BackendStatusScreenState();
}

class _BackendStatusScreenState extends State<BackendStatusScreen> {
  Map<String, dynamic>? _status;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await LiveServices.fetchBackendStatus();
      if (!mounted) return;
      setState(() {
        _status = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _num(dynamic value, [String suffix = '']) {
    if (value is num) return '${value.toStringAsFixed(1)}$suffix';
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentNotifier.value;
    final metrics = (_status?['metrics'] as Map?)?.cast<String, dynamic>();
    final heartbeat =
        (_status?['heartbeat'] as Map?)?.cast<String, dynamic>();

    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        elevation: 0,
        title: const Text(
          'BACKEND STATUS',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(S.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 48, color: P.crimson),
                        const SizedBox(height: S.md),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: P.text2)),
                        const SizedBox(height: S.md),
                        ElevatedButton(
                            onPressed: _load, child: const Text('RETRY')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(S.lg),
                  children: [
                    Glass(
                      radius: R.lg,
                      tint: P.surface.withOpacity(0.9),
                      borderColor: accent.withOpacity(0.45),
                      padding: const EdgeInsets.all(S.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Halo(color: P.sick, size: 4),
                              const SizedBox(width: S.sm),
                              Text(
                                '${heartbeat?['status'] ?? 'unknown'}'
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: P.sick,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: S.lg),
                          _row('Uptime',
                              '${heartbeat?['uptime_seconds'] ?? '--'} detik'),
                          _row('Online',
                              '${heartbeat?['online_count'] ?? '--'} device'),
                          _row('Session',
                              '${heartbeat?['sessions'] ?? '--'}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: S.md),
                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                              'CPU', _num(metrics?['cpu'], '%'), accent),
                        ),
                        const SizedBox(width: S.md),
                        Expanded(
                          child: _metric(
                              'RAM', _num(metrics?['ram'], '%'), P.violet),
                        ),
                      ],
                    ),
                    const SizedBox(height: S.md),
                    _metric('DISK', _num(metrics?['disk'], '%'), P.cyan),
                  ],
                ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: P.text3))),
          Text(value,
              style: const TextStyle(
                  color: P.bone, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Glass(
      radius: R.lg,
      tint: P.surface.withOpacity(0.9),
      borderColor: color.withOpacity(0.35),
      padding: const EdgeInsets.all(S.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: P.text3,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: S.sm),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class NewsResearchScreen extends StatefulWidget {
  const NewsResearchScreen({super.key});

  @override
  State<NewsResearchScreen> createState() => _NewsResearchScreenState();
}

class _NewsResearchScreenState extends State<NewsResearchScreen> {
  List<NewsData> _items = <NewsData>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await LiveServices.fetchNews();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _open(NewsData item) async {
    final url = item.linkUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        elevation: 0,
        title: const Text(
          'PUBLIC RESEARCH',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(S.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 48, color: P.crimson),
                        const SizedBox(height: S.md),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: P.text2)),
                        const SizedBox(height: S.md),
                        ElevatedButton(
                            onPressed: _load, child: const Text('RETRY')),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(S.lg),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: S.sm),
                  itemBuilder: (_, index) {
                    final item = _items[index];
                    return Tap(
                      onTap: () => _open(item),
                      child: Glass(
                        radius: R.lg,
                        tint: P.surface.withOpacity(0.92),
                        borderColor: item.c1.withOpacity(0.35),
                        padding: const EdgeInsets.all(S.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.source,
                                    style: TextStyle(
                                      color: item.c1,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Text(item.time,
                                    style: const TextStyle(
                                        color: P.text3, fontSize: 9)),
                              ],
                            ),
                            const SizedBox(height: S.sm),
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: P.bone,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: P.text2,
                                  fontSize: 11,
                                  height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class CodingLabScreen extends StatefulWidget {
  const CodingLabScreen({super.key});

  @override
  State<CodingLabScreen> createState() => _CodingLabScreenState();
}

class _CodingLabScreenState extends State<CodingLabScreen> {
  final _controller = TextEditingController(
    text: '''// NekoVerse Coding Lab
void main() {
  print('Hello, NekoVerse');
}
''',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode disalin ke clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentNotifier.value;
    return Scaffold(
      backgroundColor: P.bg,
      appBar: AppBar(
        backgroundColor: P.bg,
        elevation: 0,
        title: const Text(
          'CODING LAB',
          style: TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        actions: [
          IconButton(onPressed: _copy, icon: const Icon(Icons.copy_rounded)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(S.lg),
        child: TextField(
          controller: _controller,
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: P.bone,
            height: 1.45,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF07070D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.lg),
              borderSide: BorderSide(color: accent.withOpacity(0.35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.lg),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// DASHBOARD
// ═════════════════════════════════════════════════════════════════

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late ScrollController _scrollController;
  int _navIndex = 0;
  double _scrollProgress = 0;
  bool _showScrollTop = false;

  // ─── 2 MENU CAROUSEL ───
  final List<ToolData> _tools = const [
    ToolData(
      code: 'TOOL-01',
      title: 'Community Chat',
      subtitle: 'Pesan komunitas realtime',
      tag: 'LIVE',
      icon: Icons.chat_bubble_rounded,
      colors: [Color(0xFFC21628), Color(0xFF8B0A1A)],
      statLabel: 'MODE',
      statValue: 'ONLINE',
    ),
    ToolData(
      code: 'TOOL-02',
      title: 'Backend Status',
      subtitle: 'CPU, RAM, disk & session',
      tag: 'LIVE',
      icon: Icons.cloud_sync_rounded,
      colors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
      statLabel: 'DATA',
      statValue: 'REALTIME',
      danger: false,
    ),
  ];

  final List<NewsData> _news = <NewsData>[];

  final List<StoryData> _stories = <StoryData>[];

  WeatherData? _weatherData;
  bool _weatherLoading = true;
  String? _weatherError;
  Timer? _weatherTimer;
  Timer? _newsTimer;
  Timer? _storyTimer;
  bool _newsLoading = true;
  String? _newsError;
  String? _storyError;
  String? _selectedOrbitalLabel;
  bool _postingStory = false;

  List<CommandItem> _buildCommands() {
    return [
      CommandItem(
        label: 'Refresh Cuaca',
        description: 'Perbarui data cuaca Jakarta realtime',
        icon: Icons.cloud_sync_rounded,
        color: P.cyan,
        action: () async => _refreshWeather(),
      ),
      CommandItem(
        label: 'Refresh Berita',
        description: 'Ambil feed berita terbaru',
        icon: Icons.newspaper_rounded,
        color: P.rust,
        action: () async => _refreshNews(),
      ),
      CommandItem(
        label: 'Refresh Story',
        description: 'Muat ulang story komunitas',
        icon: Icons.auto_awesome_rounded,
        color: P.crimson,
        action: () async => _refreshStories(),
      ),
      CommandItem(
        label: 'Buat Story Baru',
        description: 'Posting text / gambar / video',
        icon: Icons.add_circle_rounded,
        color: P.violet,
        action: () async => _showCreateStorySheet(),
      ),
      CommandItem(
        label: 'Buka Setting',
        description: 'Akun & pengaturan',
        icon: Icons.settings_rounded,
        color: P.teal,
        action: () async => _openSetting(),
      ),
      CommandItem(
        label: 'Ganti Warna Aksen',
        description: 'Ubah tema warna aplikasi',
        icon: Icons.palette_rounded,
        color: P.amber,
        action: () async {
          await showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const AccentPickerSheet(),
          );
        },
      ),
      CommandItem(
        label: 'Force Sync All',
        description: 'Sync semua data live',
        icon: Icons.sync_rounded,
        color: P.plasma,
        action: () async {
          await Future.wait([
            _refreshWeather(),
            _refreshNews(),
            _refreshStories(),
          ]);
        },
      ),
    ];
  }

  void _showCommandPalette() {
    HapticFeedback.mediumImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Command Palette',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: CommandPalette(commands: _buildCommands()),
      ),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  // ─── NAVIGATION HANDLERS ───
  // index: 0=HOME, 1=MENU, 2=TOOLS, 3=SETTING
  // Center button = RAT
  Future<void> _handleNavTap(int index) async {
    if (index == 0) {
      if (mounted) setState(() => _navIndex = 0);
      return;
    }
    setState(() => _navIndex = index);
    if (index == 1) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const menuui.MenuScreen(),
        ),
      );
    } else if (index == 2) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const ToolsScreen()),
      );
    } else if (index == 3) {
      await _openSetting();
    }
    if (mounted) setState(() => _navIndex = 0);
  }

  Future<void> _openSetting() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingScreen()),
    );
    if (!mounted) return;
    setState(() => _navIndex = 0);
  }

  // Center button = RAT
  Future<void> _openRat() async {
    // TODO: ganti ke ratui.RatScreen() saat rat.dart siap.
    // import 'rat.dart' as ratui;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const RatScreen()),
    );
  }

  Future<void> _handleCarouselTool(String code) async {
    switch (code) {
      case 'TOOL-01':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
        );
        return;
      case 'TOOL-02':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
              builder: (_) => const BackendStatusScreen()),
        );
        return;
    }
  }

  // ─── ORBITAL: MENU — RAT — TOOLS + 3 lain ───
  List<OrbitalItem> get _orbitalItems => [
        OrbitalItem(
          label: 'MENU',
          sub: 'Explore',
          icon: Icons.apps_rounded,
          c1: P.violet,
          c2: P.violetDeep,
          onTap: () => setState(() => _selectedOrbitalLabel = 'MENU'),
        ),
        OrbitalItem(
          label: 'RAT',
          sub: 'Remote',
          icon: Icons.settings_remote_rounded,
          c1: P.crimson,
          c2: P.bloodDeep,
          onTap: () => setState(() => _selectedOrbitalLabel = 'RAT'),
        ),
        OrbitalItem(
          label: 'TOOLS',
          sub: 'Utilities',
          icon: Icons.build_rounded,
          c1: P.cyan,
          c2: P.cyanDeep,
          onTap: () => setState(() => _selectedOrbitalLabel = 'TOOLS'),
        ),
        OrbitalItem(
          label: 'OSINT',
          sub: 'Intel',
          icon: Icons.travel_explore_rounded,
          c1: P.teal,
          c2: P.rot,
          onTap: () => setState(() => _selectedOrbitalLabel = 'OSINT'),
        ),
        OrbitalItem(
          label: 'PAYLOAD',
          sub: 'API Lab',
          icon: Icons.memory_rounded,
          c1: P.pink,
          c2: P.pinkDeep,
          onTap: () => setState(() => _selectedOrbitalLabel = 'PAYLOAD'),
        ),
        OrbitalItem(
          label: 'SHIELD',
          sub: 'Secure',
          icon: Icons.shield_rounded,
          c1: P.sick,
          c2: P.rot,
          onTap: () => setState(() => _selectedOrbitalLabel = 'SHIELD'),
        ),
      ];

  Future<void> _openSelectedTool() async {
    final label = _selectedOrbitalLabel;
    if (label == null) return;
    setState(() => _selectedOrbitalLabel = null);

    switch (label) {
      case 'MENU':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
              builder: (_) => const menuui.MenuScreen()),
        );
        return;
      case 'RAT':
        await _openRat();
        return;
      case 'TOOLS':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const ToolsScreen()),
        );
        return;
      case 'OSINT':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
              builder: (_) => const NewsResearchScreen()),
        );
        return;
      case 'SHIELD':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
              builder: (_) => const BackendStatusScreen()),
        );
        return;
      case 'PAYLOAD':
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: P.surface,
            title: Text(
              label,
              style: const TextStyle(
                color: P.bone,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              'Fitur payload dan kontrol perangkat tidak dijalankan di aplikasi ini.',
              style: TextStyle(color: P.text2, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('TUTUP'),
              ),
            ],
          ),
        );
        return;
    }
  }

  // ─── WEATHER ───
  Future<void> _refreshWeather() async {
    if (mounted) {
      setState(() {
        _weatherLoading = true;
        _weatherError = null;
      });
    }
    try {
      final result = await LiveServices.fetchWeather();
      if (!mounted) return;
      setState(() {
        _weatherData = result;
        _weatherLoading = false;
        _weatherError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherError = _friendlyError(error, 'Cuaca belum bisa dimuat.');
      });
    }
  }

  Future<void> _refreshNews() async {
    if (mounted) {
      setState(() {
        _newsLoading = true;
        _newsError = null;
      });
    }
    try {
      final result = await LiveServices.fetchNews();
      if (!mounted) return;
      setState(() {
        _news
          ..clear()
          ..addAll(result);
        _newsLoading = false;
        _newsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _newsLoading = false;
        _newsError = _friendlyError(error, 'Berita belum bisa dimuat.');
      });
    }
  }

  Future<void> _refreshStories() async {
    try {
      final result = await LiveServices.fetchStories();
      if (!mounted) return;
      setState(() {
        _stories
          ..clear()
          ..addAll(result);
        _storyError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storyError = _friendlyError(
          error,
          'Story online belum terhubung ke database.',
        );
      });
    }
  }

  String _friendlyError(Object error, String fallback) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty || message.contains('SocketException')) {
      return 'Tidak ada koneksi internet. Coba lagi nanti.';
    }
    if (message.contains('403') || message.contains('401')) {
      return 'Akses ditolak server.';
    }
    if (message.length > 100) return fallback;
    return message;
  }

  // ─── POST STORY — Sheet dengan pilihan TEXT / IMAGE / VIDEO ───
  void _showCreateStorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreateStorySheet(onSubmit: _submitStory),
    );
  }

  Future<void> _submitStory({
    required String text,
    String? mediaUrl,
    StoryMediaType mediaType = StoryMediaType.text,
  }) async {
    if (_postingStory) return;
    setState(() => _postingStory = true);
    try {
      final username = ProfileStore.current?.username ?? 'GUEST USER';
      await LiveServices.publishStory(
        username: username,
        text: text,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
      await _refreshStories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story berhasil dipublikasikan.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyError(error, 'Story gagal dikirim.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Story gagal dikirim: $message')),
      );
    } finally {
      if (mounted) setState(() => _postingStory = false);
    }
  }

  void _openStoryViewer(StoryData story) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StoryViewerScreen(story: story),
      ),
    );
  }

  void _onStoryTap(StoryData story) {
    _openStoryViewer(story);
  }

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
    _scrollController = ScrollController()..addListener(_onScroll);

    AppSession.init().then((_) {
      if (AppSession.profile != null) {
        ProfileStore.save(AppSession.profile!);
      } else {
        ProfileStore.loadOrCreate();
      }
    });

    _refreshWeather();
    _refreshNews();
    _refreshStories();
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _refreshWeather(),
    );
    _newsTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _refreshNews(),
    );
    _storyTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshStories(),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final progress = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final showTop = current > 400;
    if ((progress - _scrollProgress).abs() > 0.005 ||
        showTop != _showScrollTop) {
      setState(() {
        _scrollProgress = progress;
        _showScrollTop = showTop;
      });
    }
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _newsTimer?.cancel();
    _storyTimer?.cancel();
    _scrollController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: accentNotifier,
      builder: (_, accent, __) {
        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedOpacity(
                duration: T.normal,
                opacity: _showScrollTop ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showScrollTop,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: S.md),
                    child: Tap(
                      onTap: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: _miniFab(
                          icon: Icons.keyboard_arrow_up_rounded,
                          color: accent),
                    ),
                  ),
                ),
              ),
              Tap(
                onTap: _showCommandPalette,
                child: _mainFab(accent),
              ),
            ],
          ),
          body: Star(
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ListView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            S.lg, S.lg, S.lg, 180),
                        children: [
                          _topBar(accent),
                          const SizedBox(height: S.md),
                          _marquee(),
                          const SizedBox(height: S.xl),
                          _greeting(accent),
                          const SizedBox(height: S.lg),
                          WeatherCard(
                            data: _weatherData,
                            loading: _weatherLoading,
                            error: _weatherError,
                            onRefresh: _refreshWeather,
                          ),
                          const SizedBox(height: S.lg),
                          const PulseStrip(),
                          const SizedBox(height: S.xl),
                          _userPanel(),
                          const SizedBox(height: S.xxl),
                          SectionTitle(
                            title: 'STORY/STATUS',
                            subtitle: 'UPDATE TERBARU KOMUNITAS',
                            icon: Icons.auto_awesome_rounded,
                            accent: accent,
                            trailing: 'SEMUA',
                            onTrailing: _refreshStories,
                          ),
                          const SizedBox(height: S.lg),
                          _storyStrip(),
                          const SizedBox(height: S.xxl),
                          SectionTitle(
                            title: 'NEKOVERSE',
                            subtitle: 'MODUL & FITUR',
                            icon: Icons.warning_rounded,
                            accent: accent,
                            trailing: '${_tools.length} MENU',
                            onTrailing: () {},
                          ),
                          const SizedBox(height: S.lg),
                          ToolCarousel(
                            tools: _tools,
                            onToolTap: _handleCarouselTool,
                          ),
                          const SizedBox(height: S.xxl),
                          SectionTitle(
                            title: 'NEWS',
                            subtitle: 'BERITA TERBARU',
                            icon: Icons.newspaper_rounded,
                            accent: P.rust,
                            trailing: 'REFRESH',
                            onTrailing: _refreshNews,
                          ),
                          const SizedBox(height: S.lg),
                          NewsCarousel(
                            items: _news,
                            loading: _newsLoading,
                            error: _newsError,
                            onRetry: _refreshNews,
                          ),
                          const SizedBox(height: S.xxl),
                          SectionTitle(
                            title: 'TOOLS',
                            subtitle: 'PUSAT KONTROL',
                            icon: Icons.public_rounded,
                            accent: accent,
                            trailing: '${_orbitalItems.length} MENU',
                            onTrailing: () {},
                          ),
                          const SizedBox(height: S.lg),
                          OrbitalMenu(
                            items: _orbitalItems,
                            height: 380,
                          ),
                          const SizedBox(height: S.md),
                          _orbitalHint(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: _scrollProgress.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accent.withOpacity(0.9),
                                  accent.withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavBar(
            index: _navIndex,
            onTap: _handleNavTap,
            onCenterTap: _openRat,
          ),
        );
      },
    );
  }

  Widget _mainFab(Color accent) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, P.bloodDeep, P.violetDeep],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.65),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.terminal_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _miniFab({required IconData icon, required Color color}) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: P.bgElevated.withOpacity(0.95),
        border: Border.all(color: color.withOpacity(0.55), width: 1.4),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _topBar(Color accent) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: ProfileStore.notifier,
      builder: (_, profile, __) {
        final hasAvatar = profile != null && profile.avatarPath.isNotEmpty;
        return Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.lg),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.7),
                    blurRadius: 28,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.lg),
                child: Image.asset(
                  Cfg.logoPage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, P.bloodDeep],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          fontFamily: Cfg.vampireFont,
                          fontSize: 34,
                          color: P.bone,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: S.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NekoVerse',
                    style: TextStyle(
                      fontFamily: Cfg.vampireFont,
                      fontSize: 28,
                      color: P.bone,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      height: 1.0,
                      shadows: [
                        Shadow(color: P.crimson, blurRadius: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      SignalBars(color: accent, height: 12, barCount: 4),
                      const SizedBox(width: 8),
                      Text(
                        (_weatherData != null || _news.isNotEmpty)
                            ? 'LIVE'
                            : 'CONNECTING',
                        style: TextStyle(
                          fontFamily: Cfg.bugFont,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CircleBubble(
              icon: Icons.palette_rounded,
              color: accent,
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const AccentPickerSheet(),
                );
              },
            ),
            const SizedBox(width: S.sm),
            CircleBubble(
              icon: Icons.settings_rounded,
              color: P.violet,
              onTap: _openSetting,
              image: hasAvatar
                  ? Image.file(
                      File(profile.avatarPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _marquee() {
    return const Marquee(
      items: [
        'NekoVerse',
        'New Update',
        'Secure Backend',
        'Live Pulse Monitor',
        'Thank For Buyer',
        'And Seller 👋',
      ],
    );
  }

  Widget _greeting(Color accent) {
    final hour = DateTime.now().hour;
    String greet;
    IconData icon;
    Color color;
    if (hour < 5) {
      greet = 'SELAMAT DINI HARI';
      icon = Icons.visibility_rounded;
      color = P.crimson;
    } else if (hour < 12) {
      greet = 'SELAMAT PAGI';
      icon = Icons.wb_twilight_rounded;
      color = P.amber;
    } else if (hour < 15) {
      greet = 'SELAMAT SIANG';
      icon = Icons.wb_sunny_rounded;
      color = P.orange;
    } else if (hour < 18) {
      greet = 'SELAMAT SORE';
      icon = Icons.wb_twilight_rounded;
      color = P.rust;
    } else {
      greet = 'SELAMAT MALAM';
      icon = Icons.nightlight_round;
      color = P.violet;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.22),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(R.pill),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 11, color: color),
                    const SizedBox(width: 5),
                    Text(
                      greet,
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: S.sm),
              ValueListenableBuilder<UserProfile?>(
                valueListenable: ProfileStore.notifier,
                builder: (_, profile, __) => Text(
                  (profile?.username ?? 'GUEST USER').toUpperCase(),
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: P.bone,
                    letterSpacing: 0.5,
                    height: 1.0,
                    shadows: [
                      Shadow(color: P.crimson, blurRadius: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Support Apk Ini Terus Ya Jink',
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: P.text3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Glass(
          padding:
              const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
          radius: R.md,
          glow: true,
          glowColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Halo(color: accent, size: 5),
                  const SizedBox(width: 6),
                  Text(
                    'ALIVE',
                    style: TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Clock(
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: P.bone,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _userPanel() {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: ProfileStore.notifier,
      builder: (_, profile, __) {
        final p = profile ??
            UserProfile(
              id: 'NEKO-LOADING',
              username: 'GUEST USER',
              avatarPath: '',
              expired: '--',
              role: 'basic',
              email: '',
              createdAt: DateTime.now(),
            );
        final hasAvatar = p.avatarPath.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.xxl),
            border:
                Border.all(color: P.crimson.withOpacity(0.35), width: 1.4),
          ),
          child: SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.xxl),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      Cfg.neko,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [P.bloodDeep, P.violetDeep],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            P.bgDeep.withOpacity(0.78),
                            P.bgDeep.withOpacity(0.85),
                            P.bgDeep.withOpacity(0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(S.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    P.crimson.withOpacity(0.32),
                                    P.bloodDeep.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(R.pill),
                                border: Border.all(
                                    color: P.crimson.withOpacity(0.55)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.remove_red_eye_rounded,
                                      size: 11, color: P.crimson),
                                  SizedBox(width: 5),
                                  Text(
                                    'PROFIL',
                                    style: TextStyle(
                                      fontFamily: Cfg.bugFont,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: P.crimson,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    P.sick.withOpacity(0.25),
                                    P.sick.withOpacity(0.06),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(R.pill),
                                border: Border.all(
                                    color: P.sick.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Halo(color: P.sick, size: 4),
                                  SizedBox(width: 6),
                                  Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      fontFamily: Cfg.bugFont,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: P.sick,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: S.xl),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tap(
                              onTap: _openSetting,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                      colors: [P.crimson, P.bloodDeep]),
                                ),
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: P.bgDeep,
                                  ),
                                  child: ClipOval(
                                    child: hasAvatar
                                        ? Image.file(
                                            File(p.avatarPath),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _initialAvatar(p.initial),
                                          )
                                        : _initialAvatar(p.initial),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: S.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.username.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: Cfg.bugFont,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: P.bone,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      RoleChipSimple(
                                          role: p.role, fontSize: 9.5),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: p.expiryColor
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(R.pill),
                                          border: Border.all(
                                              color: p.expiryColor
                                                  .withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          p.expiryStatus,
                                          style: TextStyle(
                                            fontFamily: Cfg.bugFont,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: p.expiryColor,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: S.md),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: P.bgDeep.withOpacity(0.85),
                                      borderRadius:
                                          BorderRadius.circular(R.sm),
                                      border: Border.all(
                                          color: P.blood.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.fingerprint_rounded,
                                            size: 11,
                                            color: P.crimson),
                                        const SizedBox(width: 5),
                                        Text(
                                          p.id,
                                          style: const TextStyle(
                                            fontFamily: Cfg.bugFont,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: P.crimson,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(S.md),
                          decoration: BoxDecoration(
                            color: P.bgDeep.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(R.md),
                            border: Border.all(
                                color: P.blood.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              _panelStatText('EXPIRED', p.expired, P.amber),
                              _panelDiv(),
                              _panelStat(
                                  'STORY',
                                  _stories.length,
                                  Icons.auto_awesome_rounded,
                                  P.rust),
                              _panelDiv(),
                              _panelStat(
                                  'ROLE',
                                  p.role.toUpperCase() == 'BASIC' ? 1 : 2,
                                  Icons.verified_user_rounded,
                                  P.violet),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _initialAvatar(String initial) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [P.crimson, P.violetDeep],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: Cfg.bugFont,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: P.bone,
          ),
        ),
      ),
    );
  }

  Widget _panelStat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: P.text4,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          NumCounter(
            value: value,
            style: TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelStatText(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 11, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: P.text4,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? '--' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Cfg.bugFont,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelDiv() {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: S.sm),
      color: P.blood.withOpacity(0.3),
    );
  }

  // ─── STORY STRIP — no "+", avatar from user photo ───
  Widget _storyStrip() {
    final allStories = <StoryData>[
      // Placeholder "posting story" card (own)
      StoryData(
        username: ProfileStore.current?.username ?? 'KAMU',
        avatarText:
            (ProfileStore.current?.initial ?? 'K').toUpperCase(),
        avatarPath: ProfileStore.current?.avatarPath ?? '',
        c1: P.violet,
        c2: P.violetDeep,
        isOwn: true,
      ),
      ..._stories,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: allStories.length,
            separatorBuilder: (_, __) => const SizedBox(width: S.md),
            itemBuilder: (_, i) {
              final story = allStories[i];
              if (i == 0) {
                // Slot "BUAT STORY" — no "+" badge, hanya label POSTING
                return StoryCircle(
                  data: story,
                  isPosting: true,
                  onTap: _showCreateStorySheet,
                );
              }
              return StoryCircle(
                data: story,
                onTap: () => _onStoryTap(story),
              );
            },
          ),
        ),
        if (_storyError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 12, color: P.orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'STORY ONLINE: $_storyError',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 8,
                    color: P.text3,
                    height: 1.3,
                  ),
                ),
              ),
              IconButton(
                onPressed: _refreshStories,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded,
                    size: 15, color: P.boneSoft),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _orbitalHint() {
    final selected = _selectedOrbitalLabel;
    return Center(
      child: AnimatedSwitcher(
        duration: T.normal,
        child: GestureDetector(
          key: ValueKey(selected ?? 'no-orbit-selection'),
          onTap: selected == null ? null : _openSelectedTool,
          child: ValueListenableBuilder<Color>(
            valueListenable: accentNotifier,
            builder: (_, accent, __) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: S.lg, vertical: S.md),
              decoration: BoxDecoration(
                color: P.bgElevated.withOpacity(0.88),
                borderRadius: BorderRadius.circular(R.pill),
                border: Border.all(
                  color: (selected == null ? P.blood : accent)
                      .withOpacity(0.65),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected == null
                        ? Icons.touch_app_rounded
                        : Icons.open_in_new_rounded,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    selected == null
                        ? 'PILIH PLANET UNTUK MELANJUTKAN'
                        : 'KLIK UNTUK MEMBUKA',
                    style: const TextStyle(
                      fontFamily: Cfg.bugFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: P.bone,
                      letterSpacing: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// CREATE STORY SHEET — TEXT / IMAGE / VIDEO
// ═════════════════════════════════════════════════════════════════

class _CreateStorySheet extends StatefulWidget {
  final Future<void> Function({
    required String text,
    String? mediaUrl,
    StoryMediaType mediaType,
  }) onSubmit;

  const _CreateStorySheet({required this.onSubmit});

  @override
  State<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends State<_CreateStorySheet> {
  final _textCtrl = TextEditingController();
  StoryMediaType _type = StoryMediaType.text;
  String? _pickedMediaPath;
  bool _submitting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_type == StoryMediaType.text) return;
    final picker = ImagePicker();
    try {
      if (_type == StoryMediaType.image) {
        final f = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1440,
        );
        if (f == null) return;
        setState(() => _pickedMediaPath = f.path);
      } else {
        final f = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );
        if (f == null) return;
        setState(() => _pickedMediaPath = f.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih media: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    final mediaUrl = _pickedMediaPath;

    if (text.isEmpty && mediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis text atau pilih media.')),
      );
      return;
    }

    setState(() => _submitting = true);
    await widget.onSubmit(
      text: text,
      mediaUrl: mediaUrl,
      mediaType: _type,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(S.lg),
          child: Glass(
            radius: R.xxl,
            tint: P.surface.withOpacity(0.98),
            borderColor: P.violet.withOpacity(0.6),
            padding: const EdgeInsets.all(S.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: P.violet, size: 20),
                    const SizedBox(width: S.sm),
                    const Text(
                      'BUAT STORY',
                      style: TextStyle(
                        fontFamily: Cfg.bugFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: P.bone,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: P.text3, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: S.md),
                // Tipe story: TEXT / IMAGE / VIDEO
                Row(
                  children: [
                    _typeChip(
                      label: 'TEXT',
                      icon: Icons.text_fields_rounded,
                      type: StoryMediaType.text,
                      color: P.violet,
                    ),
                    const SizedBox(width: S.sm),
                    _typeChip(
                      label: 'GAMBAR',
                      icon: Icons.image_rounded,
                      type: StoryMediaType.image,
                      color: P.cyan,
                    ),
                    const SizedBox(width: S.sm),
                    _typeChip(
                      label: 'VIDEO',
                      icon: Icons.videocam_rounded,
                      type: StoryMediaType.video,
                      color: P.crimson,
                    ),
                  ],
                ),
                const SizedBox(height: S.lg),
                TextField(
                  controller: _textCtrl,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 200,
                  style: const TextStyle(
                    fontFamily: Cfg.bugFont,
                    fontSize: 13,
                    color: P.bone,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tulis sesuatu...',
                    hintStyle: const TextStyle(color: P.text4),
                    filled: true,
                    fillColor: P.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.md),
                      borderSide: const BorderSide(color: P.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.md),
                      borderSide: const BorderSide(color: P.border),
                    ),
                  ),
                ),
                if (_type != StoryMediaType.text) ...[
                  const SizedBox(height: S.sm),
                  Tap(
                    onTap: _pickMedia,
                    child: Container(
                      padding: const EdgeInsets.all(S.md),
                      decoration: BoxDecoration(
                        color: P.bgDeep.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(
                          color: _pickedMediaPath != null
                              ? P.sick.withOpacity(0.7)
                              : P.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _pickedMediaPath != null
                                ? Icons.check_circle_rounded
                                : (_type == StoryMediaType.image
                                    ? Icons.image_rounded
                                    : Icons.videocam_rounded),
                            color: _pickedMediaPath != null
                                ? P.sick
                                : P.text3,
                            size: 20,
                          ),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Text(
                              _pickedMediaPath == null
                                  ? (_type == StoryMediaType.image
                                      ? 'PILIH GAMBAR'
                                      : 'PILIH VIDEO')
                                  : _pickedMediaPath!.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: Cfg.bugFont,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: P.bone,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (_pickedMediaPath != null)
                            IconButton(
                              onPressed: () =>
                                  setState(() => _pickedMediaPath = null),
                              icon: const Icon(Icons.clear_rounded,
                                  size: 18, color: P.crimson),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: S.lg),
                Tap(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(R.md),
                      gradient: const LinearGradient(
                        colors: [P.violet, P.violetDeep],
                      ),
                    ),
                    child: Center(
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'PUBLIKASIKAN',
                              style: TextStyle(
                                fontFamily: Cfg.bugFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
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

  Widget _typeChip({
    required String label,
    required IconData icon,
    required StoryMediaType type,
    required Color color,
  }) {
    final active = _type == type;
    return Expanded(
      child: Tap(
        onTap: () => setState(() {
          _type = type;
          _pickedMediaPath = null;
        }),
        child: AnimatedContainer(
          duration: T.normal,
          padding: const EdgeInsets.symmetric(vertical: S.md),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.2) : P.bgDeep,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(
              color: active ? color : P.border,
              width: active ? 1.5 : 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? color : P.text3, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Cfg.bugFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: active ? color : P.text3,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
