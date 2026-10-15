import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'chat.dart';
import 'menu.dart';
import 'rat.dart';
import 'overlay_main.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runOverlayApp();
}

final navigatorKey = GlobalKey<NavigatorState>();
final unreadNotifier = ValueNotifier<int>(0);

class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://zyroilegalnew.r-cloud.my.id:3801',
  );
  static const String apiKey = '';
  static const serverBase = apiBase;
  static const assetLogo = 'gallery/logo.jpg';
  static const assetPage = 'gallery/page.png';
  static const assetVideo = 'gallery/neko.mp4';
  static const assetChibiIdle = 'gallery/chibi1.png';
  static const assetChibiDrag = 'gallery/chibi2.png';
  static const fontBug = 'bug';
  static const fontVampire = 'vampire';
  static const timeout = Duration(seconds: 8);
  static const apiTimeout = Duration(seconds: 8);
  static const pollInterval = Duration(seconds: 6);
  static const weatherInterval = Duration(minutes: 15);
  static const prayerInterval = Duration(hours: 6);
  static const heartbeatMaxAge = Duration(seconds: 15);
  static const usersPath = 'api/users';
  static const statusPath = 'api/status';
  static const chatsPath = 'api/chats';
  static const logsPath = 'api/logs';
  static const storiesPath = 'api/chats/stories';
  static const deviceLockPath = 'api/device-lock';
  static const weatherUrl = 'https://api.open-meteo.com/v1/forecast';
  static const prayerUrl = 'https://api.aladhan.com/v1/timingsByCity';
  static const prefBubbleAsked = 'bubble_permission_asked';
  static const prefBubbleEnabled = 'bubble_enabled';
  static const prefOverlayEnabled = 'overlay_enabled';
  static const prefOverlayPanel = 'overlay_panel_enabled';
  static const prefOverlayDashboard = 'overlay_feature_dashboard';
  static const prefOverlayBug = 'overlay_feature_bug';
  static const prefOverlayChat = 'overlay_feature_chat';
  static const prefWeatherCity = 'weather_city_index';
  static const prefPrayerCity = 'prayer_city_index';
}

class Palette {
  static const bg0 = Color(0xFF05030F);
  static const bg1 = Color(0xFF0A0620);
  static const bg2 = Color(0xFF120A2E);
  static const bg3 = Color(0xFF1A1038);
  static const surface = Color(0xFF140F2E);
  static const surfaceAlt = Color(0xFF1B1540);
  static const surfaceSoft = Color(0xFF241C52);
  static const border = Color(0xFF2A2158);
  static const borderSoft = Color(0xFF1E1740);
  static const violet = Color(0xFFA78BFA);
  static const violetDeep = Color(0xFF7C3AED);
  static const pink = Color(0xFFEC4899);
  static const pinkSoft = Color(0xFFF472B6);
  static const cyan = Color(0xFF22D3EE);
  static const cyanDeep = Color(0xFF0891B2);
  static const mint = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const coral = Color(0xFFFB7185);
  static const gold = Color(0xFFFDE047);
  static const blue = Color(0xFF60A5FA);
  static const orange = Color(0xFFF97316);
  static const teal = Color(0xFF2DD4BF);
  static const lime = Color(0xFFA3E635);
  static const danger = Color(0xFFFF2D55);
  static const blood = Color(0xFF8B0000);
  static const plasma = Color(0xFFFF00AA);
  static const toxic = Color(0xFF39FF14);
  static const text = Color(0xFFF8F6FF);
  static const text2 = Color(0xFFB6ADD4);
  static const text3 = Color(0xFF7A6FA6);
  static const text4 = Color(0xFF4E466E);
}

class Spc {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
  static const double xxxl = 40.0;
}

class Radii {
  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 16.0;
  static const double lg = 22.0;
  static const double xl = 28.0;
  static const double xxl = 34.0;
  static const double pill = 999.0;
}

class Timings {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
}

enum BackendState { loading, online, backendOnly, offline }

class AppTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Palette.bg0,
      colorScheme: const ColorScheme.dark(
        primary: Palette.violet,
        secondary: Palette.pink,
        surface: Palette.surface,
        error: Palette.coral,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: AppConfig.fontBug,
        bodyColor: Palette.text,
        displayColor: Palette.text,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _PremiumPageTransitions(),
          TargetPlatform.iOS: _PremiumPageTransitions(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.surfaceAlt,
        contentTextStyle: const TextStyle(
          fontFamily: AppConfig.fontBug,
          color: Palette.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          side: const BorderSide(color: Palette.border),
        ),
      ),
    );
  }
}

class _PremiumPageTransitions extends PageTransitionsBuilder {
  const _PremiumPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.06, 0.04),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }
}

class AppUser {
  final int id;
  final String username;
  final String password;
  final String role;
  final String expired;
  final String createdAt;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.username,
    this.password = '',
    required this.role,
    required this.expired,
    required this.createdAt,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] as String?) ?? 'guest',
        password: (j['password'] as String?) ?? '',
        role: (j['role'] as String?) ?? 'basic',
        expired: (j['expired'] as String?) ?? '-',
        createdAt: (j['created_at'] as String?) ?? '-',
        isActive: (j['is_active'] as bool?) ?? false,
      );

  static AppUser fallback() => const AppUser(
        id: 0,
        username: 'guest',
        password: '',
        role: 'basic',
        expired: '-',
        createdAt: '-',
        isActive: false,
      );

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isVip => role.toLowerCase() == 'vip';
  bool get isAdmin => role.toLowerCase() == 'admin';

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
    if (days == null) return Palette.text3;
    if (days < 0) return Palette.coral;
    if (days <= 7) return Palette.coral;
    if (days <= 30) return Palette.amber;
    return Palette.mint;
  }
}

class DashboardStats {
  final int online;
  final int sessions;
  final int total;
  final int uptimeSeconds;
  final double cpu;
  final double ram;
  final double disk;
  final String status;

  const DashboardStats({
    required this.online,
    required this.sessions,
    required this.total,
    required this.uptimeSeconds,
    required this.cpu,
    required this.ram,
    required this.disk,
    required this.status,
  });

  static DashboardStats empty() => const DashboardStats(
        online: 0,
        sessions: 0,
        total: 0,
        uptimeSeconds: 0,
        cpu: 0,
        ram: 0,
        disk: 0,
        status: 'OFFLINE',
      );
}

class NetworkSnapshot {
  final List<double> history;
  final double incomingBytesPerSecond;
  final double outgoingBytesPerSecond;

  const NetworkSnapshot({
    required this.history,
    required this.incomingBytesPerSecond,
    required this.outgoingBytesPerSecond,
  });

  static NetworkSnapshot empty() => const NetworkSnapshot(
        history: <double>[],
        incomingBytesPerSecond: 0,
        outgoingBytesPerSecond: 0,
      );
}

class ChatMsg {
  final String sender;
  final String message;
  final DateTime time;

  const ChatMsg({
    required this.sender,
    required this.message,
    required this.time,
  });

  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
        sender: (j['sender'] as String?) ?? 'anonymous',
        message: (j['message'] as String?) ?? '',
        time: parseTime(j['timestamp']),
      );

  static DateTime parseTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is num) {
      final n = v.toInt();
      return DateTime.fromMillisecondsSinceEpoch(
        n < 100000000000 ? n * 1000 : n,
      );
    }
    final s = v.toString().trim();
    if (s.isEmpty) return DateTime.now();
    return DateTime.tryParse(s) ?? DateTime.now();
  }
}

class SyamStory {
  final String id;
  final String username;
  final String text;
  final DateTime time;
  final String? mediaUrl;

  const SyamStory({
    required this.id,
    required this.username,
    required this.text,
    required this.time,
    this.mediaUrl,
  });

  factory SyamStory.fromJson(String id, Map<String, dynamic> j) => SyamStory(
        id: id,
        username: (j['username'] as String?) ??
            (j['sender'] as String?) ??
            'anonymous',
        text: (j['text'] as String?) ?? (j['message'] as String?) ?? '',
        time: ChatMsg.parseTime(j['timestamp']),
        mediaUrl: (j['media_url'] as String?) ?? (j['mediaUrl'] as String?),
      );
}

class NotifItem {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const NotifItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

class CarouselSlide {
  final String code;
  final String badge;
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final Color accent;
  final Color accent2;

  const CarouselSlide({
    required this.code,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.accent,
    required this.accent2,
  });
}

class LogEntry {
  final IconData icon;
  final String tag;
  final String title;
  final String detail;
  final String stamp;
  final Color color;

  const LogEntry({
    required this.icon,
    required this.tag,
    required this.title,
    required this.detail,
    required this.stamp,
    required this.color,
  });
}

class WeatherData {
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final String location;
  final DateTime updatedAt;

  const WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.location,
    required this.updatedAt,
  });

  static WeatherData empty() => WeatherData(
        temperature: 0,
        windSpeed: 0,
        weatherCode: 0,
        isDay: true,
        location: '-',
        updatedAt: DateTime.now(),
      );

  String get description {
    switch (weatherCode) {
      case 0:
        return 'CERAH';
      case 1:
        return 'SEBAGIAN CERAH';
      case 2:
        return 'BERAWAN SEBAGIAN';
      case 3:
        return 'MENDUNG';
      case 45:
      case 48:
        return 'BERKABUT';
      case 51:
      case 53:
      case 55:
        return 'GERIMIS';
      case 56:
      case 57:
        return 'GERIMIS BEKU';
      case 61:
      case 63:
      case 65:
        return 'HUJAN';
      case 66:
      case 67:
        return 'HUJAN BEKU';
      case 71:
      case 73:
      case 75:
        return 'SALJU';
      case 77:
        return 'BUTIRAN SALJU';
      case 80:
      case 81:
      case 82:
        return 'HUJAN LEBAT';
      case 85:
      case 86:
        return 'SALJU LEBAT';
      case 95:
        return 'BADAI PETIR';
      case 96:
      case 99:
        return 'BADAI PETIR HAIL';
      default:
        return 'TIDAK DIKETAHUI';
    }
  }

  IconData get icon {
    if (weatherCode == 0) {
      return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }
    if (weatherCode <= 3) {
      return isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
    }
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 57) return Icons.grain_rounded;
    if (weatherCode >= 61 && weatherCode <= 67) {
      return Icons.water_drop_rounded;
    }
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit_rounded;
    if (weatherCode >= 80 && weatherCode <= 82) {
      return Icons.thunderstorm_rounded;
    }
    if (weatherCode >= 85 && weatherCode <= 86) {
      return Icons.ac_unit_rounded;
    }
    if (weatherCode >= 95) return Icons.thunderstorm_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Color get color {
    if (weatherCode == 0) return isDay ? Palette.amber : Palette.blue;
    if (weatherCode <= 3) return isDay ? Palette.cyan : Palette.violet;
    if (weatherCode == 45 || weatherCode == 48) return Palette.text2;
    if (weatherCode >= 51 && weatherCode <= 67) return Palette.blue;
    if (weatherCode >= 71 && weatherCode <= 86) return Palette.cyan;
    if (weatherCode >= 95) return Palette.coral;
    return Palette.text2;
  }
}

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String readableDate;
  final String hijriDate;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.readableDate,
    required this.hijriDate,
  });

  static PrayerTimes empty() => const PrayerTimes(
        fajr: '--:--',
        sunrise: '--:--',
        dhuhr: '--:--',
        asr: '--:--',
        maghrib: '--:--',
        isha: '--:--',
        readableDate: '',
        hijriDate: '',
      );

  List<PrayerEntry> get entries => <PrayerEntry>[
        PrayerEntry('SUBUH', fajr, Icons.nights_stay_rounded, Palette.violet),
        PrayerEntry('DZUHUR', dhuhr, Icons.wb_sunny_rounded, Palette.amber),
        PrayerEntry('ASHAR', asr, Icons.wb_twilight_rounded, Palette.orange),
        PrayerEntry(
            'MAGHRIB', maghrib, Icons.wb_twilight_rounded, Palette.pink),
        PrayerEntry('ISYA', isha, Icons.nightlight_round, Palette.cyan),
      ];

  int get nextPrayerIndex {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final times = <int>[
      _toMinutes(fajr),
      _toMinutes(dhuhr),
      _toMinutes(asr),
      _toMinutes(maghrib),
      _toMinutes(isha),
    ];
    for (int i = 0; i < times.length; i++) {
      if (times[i] > nowMin) return i;
    }
    return 0;
  }

  String get nextPrayerName => entries[nextPrayerIndex].label;

  String get nextPrayerTime => entries[nextPrayerIndex].time;

  Duration get timeUntilNext {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final parts = nextPrayerTime.split(':');
    if (parts.length != 2) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    var targetMin = h * 60 + m;
    if (targetMin <= nowMin) targetMin += 24 * 60;
    return Duration(minutes: targetMin - nowMin) -
        Duration(seconds: now.second);
  }

  static int _toMinutes(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
}

class PrayerEntry {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const PrayerEntry(this.label, this.time, this.icon, this.color);
}

class CityPreset {
  final String name;
  final String country;
  final double lat;
  final double lon;

  const CityPreset(this.name, this.country, this.lat, this.lon);
}

const List<CityPreset> kCityPresets = <CityPreset>[
  CityPreset('Jakarta', 'Indonesia', -6.2088, 106.8456),
  CityPreset('Surabaya', 'Indonesia', -7.2575, 112.7521),
  CityPreset('Bandung', 'Indonesia', -6.9175, 107.6191),
  CityPreset('Medan', 'Indonesia', 3.5952, 98.6722),
  CityPreset('Semarang', 'Indonesia', -6.9932, 110.4203),
  CityPreset('Makassar', 'Indonesia', -5.1477, 119.4327),
  CityPreset('Palembang', 'Indonesia', -2.9761, 104.7754),
  CityPreset('Denpasar', 'Indonesia', -8.6705, 115.2126),
  CityPreset('Yogyakarta', 'Indonesia', -7.7956, 110.3695),
  CityPreset('Balikpapan', 'Indonesia', -1.2379, 116.8529),
  CityPreset('Pontianak', 'Indonesia', -0.0263, 109.3425),
  CityPreset('Manado', 'Indonesia', 1.4748, 124.8421),
  CityPreset('Padang', 'Indonesia', -0.9471, 100.4172),
  CityPreset('Pekanbaru', 'Indonesia', 0.5071, 101.4478),
  CityPreset('Banjarmasin', 'Indonesia', -3.3186, 114.5944),
  CityPreset('Malang', 'Indonesia', -7.9666, 112.6326),
  CityPreset('Solo', 'Indonesia', -7.5755, 110.8243),
  CityPreset('Bogor', 'Indonesia', -6.5971, 106.8060),
  CityPreset('Depok', 'Indonesia', -6.4025, 106.7942),
  CityPreset('Tangerang', 'Indonesia', -6.1781, 106.6300),
];

class BackendSvc {
  static final http.Client _httpClient = http.Client();
  static String? _sessionToken;

  static String? get sessionToken => _sessionToken;
  static void setSessionToken(String? token) =>
      _sessionToken = token?.trim().isEmpty == true ? null : token?.trim();

  Duration? _lastLatency;
  Duration? get lastLatency => _lastLatency;

  Uri _uri(String path) {
    final clean = path.trim().replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('${AppConfig.apiBase}/$clean');
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (AppConfig.apiKey.trim().isNotEmpty &&
          AppConfig.apiKey.trim() != 'CHANGE_ME_API_KEY')
        'X-API-Key': AppConfig.apiKey.trim(),
      if (_sessionToken != null && _sessionToken!.isNotEmpty)
        'Authorization': 'Bearer ${_sessionToken!}',
    };
  }

  Future<dynamic> _get(String path) async {
    final sw = Stopwatch()..start();
    final res = await _httpClient
        .get(_uri(path), headers: _headers())
        .timeout(AppConfig.apiTimeout);
    sw.stop();
    _lastLatency = sw.elapsed;
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    if (res.body.trim().isEmpty || res.body.trim() == 'null') return null;
    return jsonDecode(res.body);
  }

  Future<bool> _request(String method, String path, dynamic body) async {
    try {
      final uri = _uri(path);
      final headers = _headers(json: true);
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response res;
      switch (method) {
        case 'POST':
          res = await _httpClient
              .post(uri, headers: headers, body: encoded)
              .timeout(AppConfig.apiTimeout);
          break;
        case 'PUT':
          res = await _httpClient
              .put(uri, headers: headers, body: encoded)
              .timeout(AppConfig.apiTimeout);
          break;
        case 'DELETE':
          res = await _httpClient
              .delete(uri, headers: headers, body: encoded)
              .timeout(AppConfig.apiTimeout);
          break;
        default:
          throw ArgumentError('Unsupported HTTP method');
      }
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final n = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(
        n < 100000000000 ? n * 1000 : n,
      );
    }
    return DateTime.tryParse('$value');
  }

  Map<String, dynamic> _map(dynamic value) {
    return value is Map
        ? value.map((key, value) => MapEntry('$key', value))
        : <String, dynamic>{};
  }

  bool _fresh(DateTime? seen) {
    if (seen == null) return false;
    return DateTime.now().difference(seen).abs() <= AppConfig.heartbeatMaxAge;
  }

  Future<Map<String, dynamic>> liveStatus() async {
    try {
      final raw = _map(await _get(AppConfig.statusPath));
      final heartbeat = _map(raw['heartbeat'] ?? raw['server'] ?? raw);
      final metrics = _map(raw['metrics']);
      final network = _map(raw['network']);
      final seen = _date(
        heartbeat['timestamp'] ??
            heartbeat['last_heartbeat'] ??
            heartbeat['last_seen'] ??
            heartbeat['updated_at'],
      );
      final onlineFlag = heartbeat['online'] == true ||
          '${heartbeat['status']}'.toLowerCase() == 'online' ||
          heartbeat['running'] == true;
      final fresh = _fresh(seen);
      final online = onlineFlag && fresh;
      final startedAt = _date(heartbeat['started_at'] ?? raw['started_at']);
      var uptime =
          _number(heartbeat['uptime_seconds'] ?? raw['uptime_seconds']);
      if (uptime <= 0 && startedAt != null && online) {
        uptime = DateTime.now()
            .difference(startedAt)
            .inSeconds
            .clamp(0, 1 << 30)
            .toInt();
      }
      double ratio(dynamic value) {
        if (value is! num) return 0;
        final n = value.toDouble();
        return (n > 1 ? n / 100 : n).clamp(0.0, 1.0).toDouble();
      }

      dynamic metricValue(List<String> keys) {
        for (final key in keys) {
          if (metrics[key] != null) return metrics[key];
          if (raw[key] != null) return raw[key];
        }
        return null;
      }

      return {
        'available': true,
        'online': online,
        'fresh': fresh,
        'seen': seen,
        'startedAt': startedAt,
        'uptimeSeconds': online ? uptime : 0,
        'onlineCount': online
            ? _number(raw['online_count'] ?? heartbeat['online_count'])
            : 0,
        'sessions':
            online ? _number(raw['sessions'] ?? heartbeat['sessions']) : 0,
        'cpu': online ? ratio(metricValue(['cpu', 'cpu_usage'])) : 0.0,
        'ram': online
            ? ratio(metricValue(['ram', 'ram_usage', 'memory']))
            : 0.0,
        'disk': online ? ratio(metricValue(['disk', 'disk_usage'])) : 0.0,
        'network': online ? network : <String, dynamic>{},
        'raw': raw,
      };
    } catch (_) {
      return {
        'available': false,
        'online': false,
        'fresh': false,
        'onlineCount': 0,
        'sessions': 0,
        'uptimeSeconds': 0,
        'cpu': 0.0,
        'ram': 0.0,
        'disk': 0.0,
        'network': <String, dynamic>{},
        'raw': <String, dynamic>{},
      };
    }
  }

  Future<List<ChatMsg>> chats() async {
    try {
      final d = await _get(AppConfig.chatsPath);
      if (d is! List) return [];
      final list = <ChatMsg>[];
      for (final value in d) {
        if (value is Map) list.add(ChatMsg.fromJson(_map(value)));
      }
      list.sort((a, b) => b.time.compareTo(a.time));
      return list.take(200).toList();
    } catch (_) {
      return [];
    }
  }

  NetworkSnapshot networkSnapshotFromLive(Map<String, dynamic> live) {
    if (live['online'] != true) return NetworkSnapshot.empty();
    final network = _map(live['network']);
    final raw = <double>[];
    final rx =
        _number(network['rx_bytes_per_sec'] ?? network['rx']).toDouble();
    final tx =
        _number(network['tx_bytes_per_sec'] ?? network['tx']).toDouble();
    if (rx + tx > 0) raw.add(rx + tx);
    if (raw.isEmpty) return NetworkSnapshot.empty();
    final max = raw.reduce(math.max);
    return NetworkSnapshot(
      history: raw
          .map((v) => max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0).toDouble())
          .toList(),
      incomingBytesPerSecond: rx,
      outgoingBytesPerSecond: tx,
    );
  }

  Future<List<LogEntry>> activityLogs() async {
    try {
      final d = await _get(AppConfig.logsPath);
      if (d is! List) return [];
      final list = <LogEntry>[];
      for (final value in d) {
        if (value is! Map) continue;
        final m = _map(value);
        final ok = m['success'] != false;
        list.add(LogEntry(
          icon: ok ? Icons.login_rounded : Icons.block_rounded,
          tag: ok ? 'LOGIN' : 'DENIED',
          title: '${m['username'] ?? 'UNKNOWN'}'.toUpperCase(),
          detail:
              '${m['device'] ?? 'APP'} • ${m['message'] ?? (ok ? 'Session dimulai' : 'Login ditolak')}',
          stamp: '${m['timestamp'] ?? ''}',
          color: ok ? Palette.mint : Palette.coral,
        ));
      }
      list.sort((a, b) => b.stamp.compareTo(a.stamp));
      return list.take(30).toList();
    } catch (_) {
      return [];
    }
  }

  Future<AuthResult?> login({
    required String username,
    required String password,
    String device = 'APP',
  }) async {
    try {
      final uri = _uri('api/auth/login');
      final res = await _httpClient
          .post(
            uri,
            headers: _headers(json: true),
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
              'device': device,
            }),
          )
          .timeout(AppConfig.apiTimeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final token = '${decoded['token'] ?? ''}'.trim();
      final rawUser = decoded['user'];
      if (token.isEmpty || rawUser is! Map) return null;
      final user = AppUser.fromJson(_map(rawUser));
      _sessionToken = token;
      return AuthResult(token: token, user: user);
    } catch (e, st) {
      debugPrint('LOGIN ERROR: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<AppUser?> me() async {
    if (_sessionToken == null || _sessionToken!.isEmpty) return null;
    try {
      final d = await _get('api/auth/me');
      if (d is! Map) return null;
      final rawUser = d['user'];
      if (rawUser is! Map) return null;
      return AppUser.fromJson(_map(rawUser));
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      if (_sessionToken != null && _sessionToken!.isNotEmpty) {
        await _request('POST', 'api/auth/logout', const {});
      }
    } catch (_) {}
    _sessionToken = null;
  }

  Future<bool> writeOverlayEvent({
    required String username,
    required String event,
    Map<String, dynamic>? payload,
  }) async {
    return _request('POST', 'api/overlay/events', {
      'username': username,
      'event': event,
      'payload': payload ?? <String, dynamic>{},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> writeLoginHistory({
    required String username,
    required bool success,
    String device = 'APP',
    String? message,
  }) async {
    return _request('POST', AppConfig.logsPath, {
      'username': username,
      'success': success,
      'device': device,
      'message':
          message ?? (success ? 'Session dimulai' : 'Login ditolak'),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> readDeviceLock() async {
    try {
      final d = await _get(AppConfig.deviceLockPath);
      if (d is Map) {
        return d.map((k, v) => MapEntry('$k', v));
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<bool> writeDeviceLock({
    required bool locked,
    String? username,
    String? reason,
  }) async {
    return _request('POST', AppConfig.deviceLockPath, {
      'locked': locked,
      'username': username,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> writeAccount({
    required String username,
    required String password,
    required String role,
    required String expired,
    required bool active,
  }) async {
    return _request('POST', AppConfig.usersPath, {
      'username': username,
      'password': password,
      'role': role,
      'expired': expired,
      'is_active': active,
    });
  }

  Future<bool> sendChat(String sender, String message) async {
    return _request('POST', AppConfig.chatsPath, {
      'sender': sender,
      'message': message,
    });
  }

  Future<List<SyamStory>> fetchStories() async {
    try {
      final d = await _get(AppConfig.storiesPath);
      if (d is! List) return [];
      final items = <SyamStory>[];
      for (final value in d) {
        if (value is Map) {
          final story = SyamStory.fromJson(
            '${value['id'] ?? DateTime.now().microsecondsSinceEpoch}',
            _map(value),
          );
          final age = DateTime.now().difference(story.time).inHours;
          if (age >= 0 && age < 24) items.add(story);
        }
      }
      items.sort((a, b) => b.time.compareTo(a.time));
      return items.take(30).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createStory({
    required String username,
    required String text,
    String? mediaUrl,
  }) async {
    return _request('POST', AppConfig.storiesPath, {
      'username': username,
      'text': text,
      'media_url': mediaUrl,
      'timestamp': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now()
          .add(const Duration(hours: 24))
          .toIso8601String(),
    });
  }

  Future<bool> deleteStory(String storyId) async {
    if (storyId.trim().isEmpty) return false;
    return _request(
      'DELETE',
      '${AppConfig.storiesPath}/${Uri.encodeComponent(storyId)}',
      null,
    );
  }

  Future<String?> uploadStoryMedia(File file) async {
    try {
      final name = file.path.split(Platform.pathSeparator).last;
      final uri = _uri(
        '${AppConfig.storiesPath}/upload?filename=${Uri.encodeComponent(name)}',
      );
      final bytes = await file.readAsBytes();
      final res = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/octet-stream'},
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['url'] is String) {
        return decoded['url'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class WeatherSvc {
  static final http.Client _httpClient = http.Client();

  Future<WeatherData> fetch({double? lat, double? lon}) async {
    try {
      final latitude = lat ?? -6.2088;
      final longitude = lon ?? 106.8456;
      final uri = Uri.parse(
        '${AppConfig.weatherUrl}?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code,wind_speed_10m,is_day&timezone=auto',
      );
      final res = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return WeatherData.empty();
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return WeatherData.empty();
      final current = decoded['current'];
      if (current is! Map) return WeatherData.empty();
      return WeatherData(
        temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
        windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
        isDay: (current['is_day'] as num?)?.toInt() == 1,
        location: '-',
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return WeatherData.empty();
    }
  }
}

class PrayerSvc {
  static final http.Client _httpClient = http.Client();

  Future<PrayerTimes> fetch({
    required String city,
    required String country,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.prayerUrl}?city=${Uri.encodeComponent(city)}&country=${Uri.encodeComponent(country)}&method=20',
      );
      final res = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return PrayerTimes.empty();
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return PrayerTimes.empty();
      final data = decoded['data'];
      if (data is! Map) return PrayerTimes.empty();
      final timings = data['timings'];
      if (timings is! Map) return PrayerTimes.empty();
      final dateMap = data['date'];
      String readable = '';
      String hijri = '';
      if (dateMap is Map) {
        readable = '${dateMap['readable'] ?? ''}';
        final h = dateMap['hijri'];
        if (h is Map) {
          final day = h['day'] ?? '';
          final monthMap = h['month'];
          final month = monthMap is Map ? (monthMap['en'] ?? '') : '';
          final year = h['year'] ?? '';
          hijri = '$day $month $year';
        }
      }
      return PrayerTimes(
        fajr: _clean('${timings['Fajr']}'),
        sunrise: _clean('${timings['Sunrise']}'),
        dhuhr: _clean('${timings['Dhuhr']}'),
        asr: _clean('${timings['Asr']}'),
        maghrib: _clean('${timings['Maghrib']}'),
        isha: _clean('${timings['Isha']}'),
        readableDate: readable,
        hijriDate: hijri,
      );
    } catch (_) {
      return PrayerTimes.empty();
    }
  }

  String _clean(String s) {
    final part = s.split(' ').first;
    return part.isEmpty ? '--:--' : part;
  }
}

class UserSvc {
  final BackendSvc _api = BackendSvc();

  Future<List<AppUser>> fetchUsers() async {
    try {
      final d = await _api._get(AppConfig.usersPath);
      if (d is! List) return [];
      final users = <AppUser>[];
      for (final value in d) {
        if (value is Map) {
          final user = AppUser.fromJson(_mapPublic(value));
          if (user.username.isNotEmpty && user.username != 'guest') {
            users.add(user);
          }
        }
      }
      users.sort((a, b) => a.username.toLowerCase().compareTo(
            b.username.toLowerCase(),
          ));
      return users;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _mapPublic(dynamic value) => value is Map
      ? value.map((k, v) => MapEntry('$k', v))
      : <String, dynamic>{};
}

class CosmicBackground extends StatefulWidget {
  final Widget child;
  const CosmicBackground({super.key, required this.child});

  @override
  State<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends State<CosmicBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _videoReady = false;
  late AnimationController _aurora;
  late AnimationController _stars;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _stars = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset(AppConfig.assetVideo);
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _video = c;
        _videoReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final v = _video;
    if (v == null || !_videoReady) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        v.pause();
        break;
      case AppLifecycleState.resumed:
        v.play();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aurora.dispose();
    _stars.dispose();
    _pulse.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Palette.bg0,
                  Palette.bg1,
                  Palette.bg2,
                  Palette.bg3,
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
        ),
        if (_videoReady && _video != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video!.value.size.width,
                  height: _video!.value.size.height,
                  child: Opacity(
                    opacity: 0.55,
                    child: VideoPlayer(_video!),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _aurora,
              builder: (_, __) => CustomPaint(
                painter: _AuroraPainter(_aurora.value),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _stars,
              builder: (_, __) => CustomPaint(
                painter: _StarsPainter(_stars.value),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _NebulaPainter(_pulse.value),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Palette.bg0.withValues(alpha: 0.35),
                  Palette.bg0.withValues(alpha: 0.15),
                  Palette.bg0.withValues(alpha: 0.55),
                  Palette.bg0.withValues(alpha: 0.80),
                ],
                stops: const [0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * math.pi * 2;

    final r1 = size.width * 0.85;
    final c1 = Offset(
      size.width * 0.15 + math.sin(angle) * 60,
      size.height * 0.18 + math.cos(angle * 0.7) * 50,
    );
    canvas.drawCircle(
      c1,
      r1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Palette.violet.withValues(alpha: 0.32),
            Palette.violet.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c1, radius: r1)),
    );

    final r2 = size.width * 0.72;
    final c2 = Offset(
      size.width * 0.85 + math.cos(angle * 0.9) * 55,
      size.height * 0.42 + math.sin(angle * 0.8) * 65,
    );
    canvas.drawCircle(
      c2,
      r2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Palette.pink.withValues(alpha: 0.24),
            Palette.pink.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c2, radius: r2)),
    );

    final r3 = size.width * 0.62;
    final c3 = Offset(
      size.width * 0.55 + math.sin(angle * 1.1) * 70,
      size.height * 0.88 + math.cos(angle * 1.3) * 40,
    );
    canvas.drawCircle(
      c3,
      r3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Palette.cyan.withValues(alpha: 0.18),
            Palette.cyan.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c3, radius: r3)),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}

class _StarsPainter extends CustomPainter {
  final double t;
  _StarsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1.2;
    for (int i = 0; i < 80; i++) {
      final seed = i * 137;
      final x = ((seed * 73) % size.width.toInt()).toDouble();
      final baseY = ((seed * 41) % size.height.toInt()).toDouble();
      final y = (baseY - (t * size.height * 0.15)) % size.height;
      final twinkle = (math.sin(t * math.pi * 8 + i) + 1) * 0.5;
      final alpha = 0.15 + twinkle * 0.45;
      paint.color = Palette.text.withValues(alpha: alpha);
      final r = 0.6 + (seed % 3) * 0.5;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.t != t;
}

class _NebulaPainter extends CustomPainter {
  final double t;
  _NebulaPainter(this.t);

  static const List<double> _radii = <double>[60, 85, 70, 92, 78, 68];
  static const List<double> _phaseOffsets = <double>[
    0,
    0.9,
    1.8,
    2.7,
    3.6,
    4.5
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 6; i++) {
      final phase = t * math.pi * 2 + _phaseOffsets[i];
      final x = size.width * (0.15 + (i % 3) * 0.35) + math.sin(phase) * 40;
      final y =
          size.height * (0.2 + (i ~/ 3) * 0.5) + math.cos(phase * 0.7) * 50;
      final r = _radii[i];
      final color = i.isEven ? Palette.violet : Palette.pink;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) => old.t != t;
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final Color? tint;
  final bool glow;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spc.lg),
    this.radius = Radii.lg,
    this.borderColor,
    this.shadows,
    this.tint,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? Palette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Palette.border,
          width: 1.2,
        ),
        boxShadow: shadows ??
            [
              if (glow)
                BoxShadow(
                  color: Palette.violet.withValues(alpha: 0.14),
                  blurRadius: 28,
                  spreadRadius: -6,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: child,
    );
  }
}

class HaloDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const HaloDot({
    super.key,
    this.color = Palette.mint,
    this.size = 8,
    this.animate = true,
  });

  @override
  State<HaloDot> createState() => _HaloDotState();
}

class _HaloDotState extends State<HaloDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.animate) _c.repeat();
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
          painter: _HaloPainter(
            widget.animate ? _c.value : 0.5,
            widget.color,
            widget.size,
          ),
          size: Size(widget.size * 2.6, widget.size * 2.6),
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
      size * 1.3 * t,
      Paint()..color = color.withValues(alpha: (1 - t) * 0.4),
    );
    canvas.drawCircle(
      c,
      size * 0.6,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.t != t;
}

class SkeletonShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = Radii.md,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _c.value * 2, 0),
              end: Alignment(1 + _c.value * 2, 0),
              colors: [
                Palette.surface.withValues(alpha: 0.5),
                Palette.surfaceSoft.withValues(alpha: 0.9),
                Palette.surface.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NumberCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const NumberCounter({
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

class LiveClock extends StatefulWidget {
  final TextStyle? style;
  final Color color;

  const LiveClock({
    super.key,
    this.style,
    this.color = Palette.text,
  });

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  Timer? _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return Text(
      '$h:$m:$s',
      style: widget.style ??
          TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: widget.color,
            letterSpacing: 2.0,
          ),
    );
  }
}

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scale;

  const TapScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: Timings.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class FloatWrap extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  final Duration delay;

  const FloatWrap({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(seconds: 3),
    this.delay = Duration.zero,
  });

  @override
  State<FloatWrap> createState() => _FloatWrapState();
}

class _FloatWrapState extends State<FloatWrap>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
    if (widget.delay == Duration.zero) {
      _c.repeat(reverse: true);
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.repeat(reverse: true);
      });
    }
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
        builder: (_, child) {
          final v = math.sin(_c.value * math.pi * 2) * widget.amplitude;
          return Transform.translate(
            offset: Offset(0, v),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class LiveLineChart extends StatelessWidget {
  final Color color;
  final double height;
  final List<double> values;
  final bool offline;

  const LiveLineChart({
    super.key,
    required this.color,
    this.height = 100,
    this.values = const <double>[],
    this.offline = false,
  });

  @override
  Widget build(BuildContext context) {
    if (offline) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.signal_wifi_off_rounded,
                color: Palette.text3,
                size: 20,
              ),
              SizedBox(height: 6),
              Text(
                'NO SIGNAL — BACKEND OFFLINE',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final data = values.isEmpty
        ? List<double>.filled(40, 0)
        : values.length < 40
            ? [...List<double>.filled(40 - values.length, 0), ...values]
            : values;
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LineChartPainter(data, color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _LineChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final stepX = size.width / (data.length - 1);

    final gridPaint = Paint()
      ..color = Palette.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    for (int i = 1; i < 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - data[i] * (size.height - 12) - 6;
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
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final lastX = (data.length - 1) * stepX;
    final lastY = size.height - data.last * (size.height - 12) - 6;
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}

class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;

  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => CustomPaint(
          painter: _DonutPainter(values, colors, v),
          size: Size(size, size),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double t;

  _DonutPainter(this.values, this.colors, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2 * t;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep - 0.02, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.t != t;
}

class AvatarCircle extends StatelessWidget {
  final AppUser user;
  final double size;
  final bool showRing;

  const AvatarCircle({
    super.key,
    required this.user,
    this.size = 48,
    this.showRing = true,
  });

  @override
  Widget build(BuildContext context) {
    final base = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: user.isOwner
              ? [Palette.pink, Palette.violet]
              : user.isVip
                  ? [Palette.amber, Palette.coral]
                  : [Palette.violet, Palette.cyanDeep],
        ),
      ),
      child: Center(
        child: Text(
          user.initial,
          style: TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (!showRing) return base;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md + 2),
        border: Border.all(
          color: Palette.violet.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: base,
    );
  }
}

class RoleChip extends StatelessWidget {
  final String role;
  final double fontSize;

  const RoleChip({
    super.key,
    required this.role,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final lower = role.toLowerCase();
    final color = lower == 'owner'
        ? Palette.pink
        : lower == 'admin'
            ? Palette.violet
            : lower == 'vip'
                ? Palette.amber
                : Palette.text3;
    final icon = lower == 'owner'
        ? Icons.workspace_premium_rounded
        : lower == 'admin'
            ? Icons.shield_rounded
            : lower == 'vip'
                ? Icons.star_rounded
                : Icons.person_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.42),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 1, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final Color? trailingColor;
  final Widget? trailingWidget;
  final Color accent;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.trailingColor,
    this.trailingWidget,
    this.accent = Palette.violet,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent, accent.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: Spc.sm),
        if (icon != null) ...[
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
        ],
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            color: Palette.text,
          ),
        ),
        const SizedBox(width: Spc.sm),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Palette.border,
                  Palette.border.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Spc.sm),
        if (trailingWidget != null)
          trailingWidget!
        else if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: trailingColor ?? Palette.text3,
            ),
          ),
      ],
    );
  }
}

class SectionTabData {
  final String label;
  final IconData icon;
  final Color color;

  const SectionTabData({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class PremiumTabBar extends StatelessWidget {
  final TabController controller;
  final List<SectionTabData> tabs;

  const PremiumTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return Row(
            children: List<Widget>.generate(tabs.length, (i) {
              final active = controller.index == i;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    controller.animateTo(i);
                  },
                  child: AnimatedContainer(
                    duration: Timings.normal,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: Spc.md),
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                tab.color.withValues(alpha: 0.28),
                                tab.color.withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: active
                          ? Border.all(
                              color: tab.color.withValues(alpha: 0.6),
                              width: 1.2,
                            )
                          : null,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: tab.color.withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: -3,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: active ? 1.15 : 1.0,
                          duration: Timings.normal,
                          curve: Curves.easeOutBack,
                          child: Icon(
                            tab.icon,
                            size: 16,
                            color: active ? tab.color : Palette.text3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label.toUpperCase(),
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: active ? tab.color : Palette.text3,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class FilterChipWidget extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int? count;

  const FilterChipWidget({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Timings.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Spc.md,
          vertical: Spc.sm,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: selected ? null : Palette.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.65) : Palette.border,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: selected ? color : Palette.text3,
                letterSpacing: 1.2,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: (selected ? color : Palette.text3)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: selected ? color : Palette.text3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum UserSort { name, role, status, expiry }

class FullScreenCarousel extends StatefulWidget {
  final List<CarouselSlide> slides;
  final void Function(CarouselSlide slide) onTap;

  const FullScreenCarousel({
    super.key,
    required this.slides,
    required this.onTap,
  });

  @override
  State<FullScreenCarousel> createState() => _FullScreenCarouselState();
}

class _FullScreenCarouselState extends State<FullScreenCarousel> {
  late PageController _controller;
  int _current = 0;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1.0);
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.slides.isEmpty) return;
      final next = (_current + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        FloatWrap(
          amplitude: 5,
          period: const Duration(seconds: 5),
          child: SizedBox(
            height: 215,
            child: PageView.builder(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.slides.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final slide = widget.slides[i];
                return _CarouselSlideView(
                  slide: slide,
                  onTap: () => widget.onTap(slide),
                  isActive: i == _current,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: Spc.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(widget.slides.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: Timings.normal,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              width: active ? 30 : 8,
              decoration: BoxDecoration(
                color:
                    active ? Palette.violet : Palette.text3.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(Radii.pill),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Palette.violet.withValues(alpha: 0.7),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CarouselSlideView extends StatelessWidget {
  final CarouselSlide slide;
  final VoidCallback onTap;
  final bool isActive;

  const _CarouselSlideView({
    required this.slide,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedScale(
        scale: isActive ? 1.0 : 0.94,
        duration: Timings.normal,
        curve: Curves.easeOut,
        child: TapScale(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: slide.accent, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: slide.accent.withValues(alpha: 0.45),
                  blurRadius: 26,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xl - 1),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      AppConfig.assetPage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Palette.surface, slide.accent2],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Palette.bg0.withValues(alpha: 0.35),
                            Palette.bg0.withValues(alpha: 0.60),
                            slide.accent.withValues(alpha: 0.35),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.bg0.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(Radii.xs),
                        border: Border.all(color: slide.accent, width: 1),
                      ),
                      child: Text(
                        slide.code,
                        style: TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: slide.accent,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: slide.accent.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(Radii.xs),
                        border: Border.all(
                          color: slide.accent.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        slide.badge,
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -26,
                    bottom: -22,
                    child: Icon(
                      slide.icon,
                      size: 150,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Spc.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.6,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          slide.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.4,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: Spc.md),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: slide.accent,
                                borderRadius:
                                    BorderRadius.circular(Radii.pill),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        slide.accent.withValues(alpha: 0.6),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    slide.cta,
                                    style: const TextStyle(
                                      fontFamily: AppConfig.fontBug,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Palette.bg0.withValues(alpha: 0.6),
                                borderRadius:
                                    BorderRadius.circular(Radii.sm),
                                border: Border.all(
                                  color:
                                      slide.accent.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Icon(
                                slide.icon,
                                size: 18,
                                color: slide.accent,
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
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData active;
  final String label;
  final Color color;

  const NavItem({
    required this.icon,
    required this.active,
    required this.label,
    this.color = Palette.violet,
  });
}

// ═════════════════════════════════════════════════════════════════
// SPECTRAL COMMAND BAR — REBUILT PREMIUM NAVIGATION
// Layers:
// 1. Ambient underglow (color shifts with active index)
// 2. Glass backdrop with gradient surface
// 3. Hex pattern overlay (drift animation)
// 4. Top energy beam (scan + color pulse)
// 5. Active orb + rotating ring
// 6. Center hex orb (rotating frame + bolt pulse)
// 7. Particle burst + shockwave on tap
// ═════════════════════════════════════════════════════════════════
class FloatingGlassNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  final VoidCallback onCenterTap;

  const FloatingGlassNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
    required this.onCenterTap,
  });

  @override
  State<FloatingGlassNavBar> createState() => _FloatingGlassNavBarState();
}

class _TapBurst {
  final int index;
  final Color color;
  _TapBurst(this.index, this.color);
}

class _FloatingGlassNavBarState extends State<FloatingGlassNavBar>
    with TickerProviderStateMixin {
  late AnimationController _bubbleCtrl;
  late Animation<double> _bubble;
  late AnimationController _haloCtrl;
  late AnimationController _ambientCtrl;
  late AnimationController _hexCtrl;
  late AnimationController _beamCtrl;
  late AnimationController _orbCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _shockCtrl;

  final List<_TapBurst> _bursts = [];
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.index;

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      value: 1,
    );
    _bubble = CurvedAnimation(parent: _bubbleCtrl, curve: Curves.easeOutBack);

    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _hexCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _beamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _shockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingGlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _lastIndex = old.index;
      _bubbleCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bubbleCtrl.dispose();
    _haloCtrl.dispose();
    _ambientCtrl.dispose();
    _hexCtrl.dispose();
    _beamCtrl.dispose();
    _orbCtrl.dispose();
    _burstCtrl.dispose();
    _shockCtrl.dispose();
    super.dispose();
  }

  Color get _activeColor {
    if (widget.items.isEmpty) return Palette.violet;
    final idx = widget.index.clamp(0, widget.items.length - 1);
    return widget.items[idx].color;
  }

  void _triggerBurst(int index) {
    if (widget.items.isEmpty) return;
    final color = widget.items[index.clamp(0, widget.items.length - 1)].color;
    setState(() {
      _bursts.add(_TapBurst(index, color));
    });
    _burstCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        if (_bursts.isNotEmpty) _bursts.removeAt(0);
      });
    });
    _shockCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final activeColor = _activeColor;
    final itemCount = widget.items.length;
    if (itemCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spc.lg,
        0,
        Spc.lg,
        inset > 0 ? inset - 4 : Spc.md,
      ),
      child: SizedBox(
        height: 116,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Layer 1: Ambient underglow
            Positioned(
              bottom: -22,
              left: -22,
              right: -22,
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_ambientCtrl, _haloCtrl]),
                    builder: (_, __) {
                      final pulse =
                          0.5 + 0.5 * math.sin(_ambientCtrl.value * math.pi * 2);
                      final ripple =
                          0.5 + 0.5 * math.sin(_haloCtrl.value * math.pi * 2);
                      return Container(
                        height: 108,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              activeColor.withValues(
                                alpha: 0.22 + pulse * 0.14,
                              ),
                              activeColor.withValues(
                                alpha: 0.08 + ripple * 0.06,
                              ),
                              Colors.transparent,
                            ],
                            radius: 1.05,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Layer 2 + 3 + 4: Glass container
            Container(
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.32),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.26),
                    blurRadius: 38,
                    spreadRadius: -8,
                  ),
                  BoxShadow(
                    color: Palette.bg0.withValues(alpha: 0.85),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xl),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Stack(
                    children: [
                      // Glass surface
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Palette.surface.withValues(alpha: 0.86),
                                Palette.surfaceAlt.withValues(alpha: 0.72),
                                Palette.surface.withValues(alpha: 0.9),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Hex pattern drift
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _hexCtrl,
                              builder: (_, __) => CustomPaint(
                                painter: _HexPatternPainter(
                                  _hexCtrl.value,
                                  activeColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Top energy beam
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 2,
                        child: AnimatedBuilder(
                          animation: _beamCtrl,
                          builder: (_, __) {
                            final t = _beamCtrl.value;
                            final dx = -1.0 + t * 2.0;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(dx - 0.5, 0),
                                  end: Alignment(dx + 0.5, 0),
                                  colors: [
                                    Colors.transparent,
                                    activeColor.withValues(alpha: 0.0),
                                    activeColor,
                                    activeColor.withValues(alpha: 0.0),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom scanline
                      Positioned(
                        bottom: 0,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                activeColor.withValues(alpha: 0.5),
                                activeColor.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Nav items row
                      LayoutBuilder(
                        builder: (context, cons) {
                          final gap = 76.0;
                          final itemW = (cons.maxWidth - gap) / itemCount;
                          return Stack(
                            children: [
                              // Active bubble
                              AnimatedPositioned(
                                duration:
                                    const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                                left: widget.index < itemCount / 2
                                    ? widget.index * itemW
                                    : gap + widget.index * itemW,
                                top: 0,
                                bottom: 0,
                                width: itemW,
                                child: Center(
                                  child: ScaleTransition(
                                    scale: _bubble,
                                    child: _ActiveOrb(
                                      color: activeColor,
                                      progress: _bubbleCtrl,
                                    ),
                                  ),
                                ),
                              ),

                              // Nav slots
                              Row(
                                children: List.generate(
                                  itemCount,
                                  (i) {
                                    final it = widget.items[i];
                                    final sel = i == widget.index;
                                    return Expanded(
                                      child: _NavSlot(
                                        item: it,
                                        selected: sel,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _triggerBurst(i);
                                          widget.onTap(i);
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Particle burst overlay
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _burstCtrl,
                                    builder: (_, __) {
                                      if (_bursts.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final burst = _bursts.first;
                                      final localLeft =
                                          burst.index < itemCount / 2
                                              ? burst.index * itemW +
                                                  itemW / 2
                                              : gap +
                                                  burst.index * itemW +
                                                  itemW / 2;
                                      return Stack(
                                        children: [
                                          Positioned(
                                            left: localLeft - 60,
                                            top: 20,
                                            width: 120,
                                            height: 60,
                                            child: CustomPaint(
                                              painter: _BurstPainter(
                                                _burstCtrl.value,
                                                burst.color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Center gap placeholder
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: Center(
                                    child: SizedBox(width: gap),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 6: Center hex orb
            Positioned(
              top: -28,
              child: _CenterHexOrb(
                color: activeColor,
                rotation: _orbCtrl,
                shock: _shockCtrl,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _triggerBurst(0);
                  widget.onCenterTap();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active orb with rotating ring + 3 shadow layers ───────────────
class _ActiveOrb extends StatelessWidget {
  final Color color;
  final Animation<double> progress;

  const _ActiveOrb({required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Rotating dashed ring
              Transform.rotate(
                angle: progress.value * math.pi * 2,
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _DashedRingPainter(color),
                ),
              ),
              // Solid core
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.lerp(color, Palette.violetDeep, 0.55)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.75),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.42),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              // Inner highlight
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const segments = 12;
    for (int i = 0; i < segments; i++) {
      final startAngle = (i / segments) * math.pi * 2;
      final sweep = (math.pi * 2 / segments) * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) =>
      old.color != color;
}

// ─── Nav slot with multi-layer effects ─────────────────────────────
class _NavSlot extends StatefulWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavSlot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavSlot> createState() => _NavSlotState();
}

class _NavSlotState extends State<_NavSlot> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final color = widget.item.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: Timings.fast,
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: FadeTransition(opacity: anim, child: child),
                      );
                    },
                    child: Icon(
                      sel ? widget.item.active : widget.item.icon,
                      key: ValueKey('${widget.item.label}-$sel'),
                      size: 22,
                      color: sel ? Colors.white : Palette.text3,
                    ),
                  ),
                  if (sel)
                    Positioned(
                      bottom: -1,
                      child: Container(
                        width: 22,
                        height: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.9),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: sel ? 9.5 : 9,
                fontWeight: FontWeight.w900,
                color: sel ? Colors.white : Palette.text3,
                letterSpacing: 1.1,
              ),
              child: Text(widget.item.label.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Center hex orb with rotating frame ────────────────────────────
class _CenterHexOrb extends StatelessWidget {
  final Color color;
  final Animation<double> rotation;
  final Animation<double> shock;
  final VoidCallback onTap;

  const _CenterHexOrb({
    required this.color,
    required this.rotation,
    required this.shock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([rotation, shock]),
          builder: (_, __) {
            final pulse = 0.5 + 0.5 * math.sin(rotation.value * math.pi * 2);
            final shockScale = 1.0 + shock.value * 0.7;
            final shockAlpha = (1.0 - shock.value) * 0.5;

            return SizedBox(
              width: 118,
              height: 118,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shockwave ring on tap
                  if (shock.value > 0)
                    Container(
                      width: 76 * shockScale,
                      height: 76 * shockScale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: shockAlpha),
                          width: 2.5,
                        ),
                      ),
                    ),
                  // Ambient halo
                  Container(
                    width: 82 + pulse * 10,
                    height: 82 + pulse * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.42 * pulse + 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Rotating hex frame
                  Transform.rotate(
                    angle: rotation.value * math.pi * 2,
                    child: CustomPaint(
                      size: const Size(84, 84),
                      painter: _HexFramePainter(color),
                    ),
                  ),
                  // Inner rotating counter
                  Transform.rotate(
                    angle: -rotation.value * math.pi * 4,
                    child: CustomPaint(
                      size: const Size(66, 66),
                      painter: _HexFramePainter(
                        color.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  // Core orb
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Palette.cyan,
                          Palette.violet,
                          Palette.plasma,
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.cyan.withValues(
                            alpha: 0.65 + pulse * 0.2,
                          ),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Palette.plasma.withValues(alpha: 0.55),
                          blurRadius: 44,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFF2A1A5A),
                            Color(0xFF0A0520),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
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

    // Corner glow dots
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

// ─── Hex pattern painter (nav background drift) ────────────────────
class _HexPatternPainter extends CustomPainter {
  final double t;
  final Color color;
  _HexPatternPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const hexSize = 14.0;
    final driftX = (t * 30) % (hexSize * 3);
    final driftY = (t * 20) % (hexSize * 1.75);

    for (double y = -hexSize; y < size.height + hexSize; y += hexSize * 1.75) {
      for (double x = -hexSize; x < size.width + hexSize; x += hexSize * 3) {
        final offsetX = ((y / (hexSize * 1.75)).round().isEven)
            ? 0
            : hexSize * 1.5;
        final cx = x + offsetX + driftX;
        final cy = y + driftY;
        _drawHex(canvas, Offset(cx, cy), hexSize, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i <= 6; i++) {
      final angle = (i / 6) * math.pi * 2;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexPatternPainter old) =>
      old.t != t || old.color != color;
}

// ─── Tap burst particles ───────────────────────────────────────────
class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;
  _BurstPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2;
      final dist = t * 48 + 4;
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;
      final alpha = (1 - t).clamp(0.0, 1.0);
      final r = (1 - t) * 2.4 + 0.8;
      paint.color = color.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.t != t || old.color != color;
}

// ═════════════════════════════════════════════════════════════════
// CHIBI COMPANION
// ═════════════════════════════════════════════════════════════════
enum ChibiMood { happy, sleepy, excited, focused, curious }
enum ChibiState { idle, dragging, dismissed }

class ChibiCompanion extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Offset initialPosition;
  final Size screenSize;
  final bool isDay;
  final bool isOnline;

  const ChibiCompanion({
    super.key,
    required this.onTap,
    required this.initialPosition,
    required this.screenSize,
    this.onLongPress,
    this.isDay = true,
    this.isOnline = true,
  });

  @override
  State<ChibiCompanion> createState() => _ChibiCompanionState();
}

class _ChibiCompanionState extends State<ChibiCompanion>
    with TickerProviderStateMixin {
  ChibiState _state = ChibiState.idle;
  ChibiMood _mood = ChibiMood.happy;
  late Offset _position;
  late Offset _dragStart;
  late Offset _positionAtDragStart;
  Timer? _speechTimer;
  Timer? _moodTimer;
  String? _speech;
  bool _speechVisible = false;

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _snapController;
  late AnimationController _speechController;
  late AnimationController _particleController;
  late Animation<double> _speechAnim;
  late Animation<Offset> _snapAnimation;

  static const double _chibiSize = 100;
  static const double _dropZoneRadius = 56;

  static const _speechHappy = <String>[
    'HALO! KETUK AKU YA',
    'MAU NGAPAIN HARI INI?',
    'SEMANGAT YA!',
    'AKU DI SINI KALAU BUTUH',
    'JANGAN LUPA ISTIRAHAT',
    'MINUM AIR DULU YUK',
  ];
  static const _speechSleepy = <String>[
    'HMM... NGANTUK NIH',
    'Zzz... jangan ganggu',
    'MALEM INI DINGIN YA',
    'AKU TIDUR SEBENTAR',
  ];
  static const _speechExcited = <String>[
    'WOW KEREN!',
    'AYO MULAI!',
    'AKU SIAP MEMBANTU!',
    'GAS GAS GAS!',
  ];
  static const _speechFocused = <String>[
    'SEDANG FOKUS...',
    'MOHON JANGAN DIGANGGU',
    'LAGI MIKIR NIH',
  ];
  static const _speechCurious = <String>[
    'ITU APA?',
    'HMM MENARIK...',
    'COBA KLIK AKU',
    'ADA YANG BARU?',
  ];

  bool get _isDismissed => _state == ChibiState.dismissed;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _dragStart = Offset.zero;
    _positionAtDragStart = _position;
    _mood = widget.isDay ? ChibiMood.happy : ChibiMood.sleepy;

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1,
    );

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: _position,
    ).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutBack,
      ),
    );
    _snapController.addListener(_snapListener);

    _speechController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _speechAnim = CurvedAnimation(
      parent: _speechController,
      curve: Curves.easeOutBack,
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _scheduleSpeech();
    _scheduleMoodChange();
  }

  void _scheduleSpeech() {
    _speechTimer?.cancel();
    _speechTimer = Timer.periodic(const Duration(seconds: 14), (_) {
      if (!mounted || _isDismissed || _state == ChibiState.dragging) return;
      _showRandomSpeech();
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_isDismissed) _showRandomSpeech();
    });
  }

  void _scheduleMoodChange() {
    _moodTimer?.cancel();
    _moodTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted || _isDismissed) return;
      _autoMood();
    });
  }

  void _autoMood() {
    if (!widget.isOnline) {
      setState(() => _mood = ChibiMood.sleepy);
      return;
    }
    if (!widget.isDay) {
      setState(() => _mood = ChibiMood.sleepy);
      return;
    }
    final r = math.Random().nextInt(4);
    setState(() {
      _mood = ChibiMood.values[r == 0 ? 0 : r == 1 ? 2 : r == 2 ? 3 : 4];
    });
  }

  void _showRandomSpeech() {
    final list = switch (_mood) {
      ChibiMood.happy => _speechHappy,
      ChibiMood.sleepy => _speechSleepy,
      ChibiMood.excited => _speechExcited,
      ChibiMood.focused => _speechFocused,
      ChibiMood.curious => _speechCurious,
    };
    final text = list[math.Random().nextInt(list.length)];
    setState(() {
      _speech = text;
      _speechVisible = true;
    });
    _speechController.forward(from: 0);
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      _speechController.reverse().then((_) {
        if (mounted) setState(() => _speechVisible = false);
      });
    });
  }

  @override
  void dispose() {
    _speechTimer?.cancel();
    _moodTimer?.cancel();
    _snapController.removeListener(_snapListener);
    _floatController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _snapController.dispose();
    _speechController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Offset get _dropZoneCenter => Offset(
        widget.screenSize.width / 2,
        widget.screenSize.height - 200,
      );

  bool _isOverDropZone(Offset pos) {
    final centerOfChibi =
        pos + const Offset(_chibiSize / 2, _chibiSize / 2);
    final dist = (centerOfChibi - _dropZoneCenter).distance;
    return dist < _dropZoneRadius + 30;
  }

  void _onPanStart(DragStartDetails d) {
    if (_isDismissed) return;
    HapticFeedback.selectionClick();
    setState(() {
      _state = ChibiState.dragging;
      _dragStart = d.globalPosition;
      _positionAtDragStart = _position;
    });
    _floatController.stop();
    if (_speechVisible) {
      _speechController.reverse();
      setState(() => _speechVisible = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isDismissed) return;
    final delta = d.globalPosition - _dragStart;
    var newPos = _positionAtDragStart + delta;
    newPos = Offset(
      newPos.dx.clamp(0, widget.screenSize.width - _chibiSize),
      newPos.dy.clamp(0, widget.screenSize.height - _chibiSize),
    );
    setState(() => _position = newPos);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isDismissed) return;
    if (_isOverDropZone(_position)) {
      _dismiss();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_snapController.isAnimating) return;
    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: widget.initialPosition,
    ).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutBack,
      ),
    );
    _snapController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _position = widget.initialPosition;
        _state = ChibiState.idle;
      });
      _floatController.repeat(reverse: true);
    });
  }

  void _snapListener() {
    if (!mounted) return;
    if (!_snapController.isAnimating) return;
    setState(() => _position = _snapAnimation.value);
  }

  void _dismiss() {
    HapticFeedback.mediumImpact();
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _state = ChibiState.dismissed);
    });
  }

  void _handleTap() {
    if (_isDismissed || _state == ChibiState.dragging) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mood = ChibiMood.excited;
    });
    widget.onTap();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _autoMood();
    });
  }

  void _handleDoubleTap() {
    if (_isDismissed || _state == ChibiState.dragging) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _mood =
          ChibiMood.values[math.Random().nextInt(ChibiMood.values.length)];
    });
    _showRandomSpeech();
  }

  void _handleLongPress() {
    if (_isDismissed || _state == ChibiState.dragging) return;
    HapticFeedback.heavyImpact();
    widget.onLongPress?.call();
  }

  Color get _moodColor {
    switch (_mood) {
      case ChibiMood.happy:
        return Palette.mint;
      case ChibiMood.sleepy:
        return Palette.violet;
      case ChibiMood.excited:
        return Palette.amber;
      case ChibiMood.focused:
        return Palette.cyan;
      case ChibiMood.curious:
        return Palette.pink;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final isDragging = _state == ChibiState.dragging;
    final overDrop = isDragging && _isOverDropZone(_position);

    return Stack(
      children: [
        if (isDragging)
          Positioned(
            left: _dropZoneCenter.dx - _dropZoneRadius,
            top: _dropZoneCenter.dy - _dropZoneRadius,
            child: _DropZone(active: overDrop, radius: _dropZoneRadius),
          ),
        AnimatedBuilder(
          animation: Listenable.merge([
            _floatController,
            _snapController,
            _fadeController,
            _pulseController,
            _particleController,
          ]),
          builder: (_, __) {
            double floatOffset = 0;
            if (_state == ChibiState.idle) {
              floatOffset =
                  math.sin(_floatController.value * math.pi * 2) * 6;
            }

            return Positioned(
              left: _position.dx,
              top: _position.dy + floatOffset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                onDoubleTap: _handleDoubleTap,
                onLongPress: _handleLongPress,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_speechVisible && _speech != null)
                        ScaleTransition(
                          scale: _speechAnim,
                          alignment: Alignment.bottomCenter,
                          child: _SpeechBubble(text: _speech!),
                        ),
                      const SizedBox(height: 4),
                      _ChibiBody(
                        isDragging: isDragging,
                        overDrop: overDrop,
                        pulse: _pulseController.value,
                        size: _chibiSize,
                        moodColor: _moodColor,
                        particles: _particleController.value,
                        mood: _mood,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Palette.cyan.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.cyan.withValues(alpha: 0.3),
            blurRadius: 18,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppConfig.fontBug,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Palette.text,
          letterSpacing: 1.0,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ChibiBody extends StatelessWidget {
  final bool isDragging;
  final bool overDrop;
  final double pulse;
  final double size;
  final Color moodColor;
  final double particles;
  final ChibiMood mood;

  const _ChibiBody({
    required this.isDragging,
    required this.overDrop,
    required this.pulse,
    required this.size,
    required this.moodColor,
    required this.particles,
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    final asset =
        isDragging ? AppConfig.assetChibiDrag : AppConfig.assetChibiIdle;
    final label = isDragging ? 'LEPAS DI X' : 'TAP AKU';
    final labelColor = overDrop
        ? Palette.coral
        : isDragging
            ? Palette.amber
            : moodColor;

    final glowAmount = 0.35 + math.sin(pulse * math.pi * 2) * 0.2;
    final glowColor = overDrop ? Palette.coral : moodColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Palette.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: labelColor, width: 1.3),
            boxShadow: [
              BoxShadow(
                color: labelColor.withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: labelColor,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size + 20,
          height: size + 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ChibiParticlesPainter(particles, moodColor),
                ),
              ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: glowAmount),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ChibiRingPainter(
                          pulse,
                          glowColor,
                          isDragging,
                        ),
                      ),
                    ),
                    Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _ChibiFallback(
                        isDragging: isDragging,
                        color: glowColor,
                        mood: mood,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChibiParticlesPainter extends CustomPainter {
  final double t;
  final Color color;
  _ChibiParticlesPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    for (int i = 0; i < 6; i++) {
      final phase = (t + i / 6.0) % 1.0;
      final angle = i * math.pi / 3 + t * math.pi * 2;
      final r = size.width * 0.42 + math.sin(phase * math.pi * 2) * 6;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      final alpha = (1 - phase) * 0.55;
      final radius = 1.5 + math.sin(phase * math.pi) * 1.5;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChibiParticlesPainter old) =>
      old.t != t || old.color != color;
}

class _ChibiFallback extends StatelessWidget {
  final bool isDragging;
  final Color color;
  final ChibiMood mood;

  const _ChibiFallback({
    required this.isDragging,
    required this.color,
    required this.mood,
  });

  IconData get _moodIcon {
    if (isDragging) return Icons.pets_rounded;
    switch (mood) {
      case ChibiMood.happy:
        return Icons.sentiment_very_satisfied_rounded;
      case ChibiMood.sleepy:
        return Icons.bedtime_rounded;
      case ChibiMood.excited:
        return Icons.emoji_emotions_rounded;
      case ChibiMood.focused:
        return Icons.psychology_rounded;
      case ChibiMood.curious:
        return Icons.help_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.6),
            color.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Center(
        child: Icon(_moodIcon, size: 44, color: Colors.white),
      ),
    );
  }
}

class _ChibiRingPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool isDragging;

  _ChibiRingPainter(this.t, this.color, this.isDragging);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;

    for (int i = 0; i < 2; i++) {
      final local = (t + i * 0.5) % 1.0;
      final r = baseR - 4 + local * 12;
      final alpha = (1 - local) * (isDragging ? 0.7 : 0.45);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawCircle(
      center,
      baseR - 6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.18),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: baseR)),
    );
  }

  @override
  bool shouldRepaint(covariant _ChibiRingPainter old) =>
      old.t != t || old.color != color || old.isDragging != isDragging;
}

class _DropZone extends StatefulWidget {
  final bool active;
  final double radius;

  const _DropZone({required this.active, required this.radius});

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Palette.coral : Palette.text3;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final pulse = widget.active ? _c.value : 0.0;
          return SizedBox(
            width: widget.radius * 2,
            height: widget.radius * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.radius * 2 * (0.9 + pulse * 0.15),
                  height: widget.radius * 2 * (0.9 + pulse * 0.15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.10),
                    border: Border.all(
                      color: color.withValues(alpha: 0.6),
                      width: 1.6,
                    ),
                    boxShadow: widget.active
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 24,
                            ),
                          ]
                        : null,
                  ),
                ),
                Icon(Icons.close_rounded, color: color, size: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}

class UserInfoPanel extends StatelessWidget {
  final AppUser user;
  final String status;

  const UserInfoPanel({
    super.key,
    required this.user,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final days = user.daysUntilExpiry;
    final expiryColor = user.expiryColor;
    final roleColor = user.isOwner
        ? Palette.pink
        : user.isAdmin
            ? Palette.violet
            : user.isVip
                ? Palette.amber
                : Palette.text3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xl),
      child: SizedBox(
        height: 340,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                AppConfig.assetPage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Palette.violetDeep.withValues(alpha: 0.6),
                        Palette.pink.withValues(alpha: 0.4),
                        Palette.bg2,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Palette.bg0.withValues(alpha: 0.55),
                      Palette.bg0.withValues(alpha: 0.75),
                      Palette.bg0.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _UserPanelDecorPainter(roleColor),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spc.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.bg0.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(Radii.xs),
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              color: roleColor,
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PROFIL PENGGUNA',
                              style: TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: roleColor,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.bg0.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(Radii.xs),
                          border: Border.all(
                            color: (status == 'ONLINE'
                                    ? Palette.mint
                                    : Palette.coral)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HaloDot(
                              color: status == 'ONLINE'
                                  ? Palette.mint
                                  : Palette.coral,
                              size: 3,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              status,
                              style: TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: status == 'ONLINE'
                                    ? Palette.mint
                                    : Palette.coral,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spc.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [roleColor, Palette.bg0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: roleColor.withValues(alpha: 0.6),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Palette.surface,
                              ),
                              child: Center(
                                child: Text(
                                  user.initial,
                                  style: TextStyle(
                                    fontFamily: AppConfig.fontBug,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: roleColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: user.isActive
                                    ? Palette.mint
                                    : Palette.coral,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Palette.bg0,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: Spc.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Palette.text,
                                letterSpacing: 0.4,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                RoleChip(role: user.role, fontSize: 9.5),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Palette.bg0.withValues(alpha: 0.6),
                                    borderRadius:
                                        BorderRadius.circular(Radii.pill),
                                    border: Border.all(
                                      color: Palette.borderSoft,
                                    ),
                                  ),
                                  child: Text(
                                    'ID #${user.id}',
                                    style: const TextStyle(
                                      fontFamily: AppConfig.fontBug,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: Palette.text2,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Spc.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spc.md,
                                vertical: Spc.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Palette.bg0.withValues(alpha: 0.55),
                                borderRadius:
                                    BorderRadius.circular(Radii.sm),
                                border: Border.all(
                                  color: Palette.borderSoft,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    color: Palette.text3,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'DIBUAT',
                                    style: TextStyle(
                                      fontFamily: AppConfig.fontBug,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Palette.text3,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    user.createdAt,
                                    style: const TextStyle(
                                      fontFamily: AppConfig.fontBug,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Palette.text,
                                      letterSpacing: 0.6,
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
                    padding: const EdgeInsets.all(Spc.md),
                    decoration: BoxDecoration(
                      color: Palette.bg0.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        color: expiryColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: expiryColor.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: expiryColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                              color: expiryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.event_available_rounded,
                            color: expiryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: Spc.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'EXPIRED PADA',
                                    style: TextStyle(
                                      fontFamily: AppConfig.fontBug,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: Palette.text3,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Palette.borderSoft,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    user.expired,
                                    style: TextStyle(
                                      fontFamily: AppConfig.fontBug,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: expiryColor,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: Spc.sm),
                                  if (days != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: expiryColor
                                            .withValues(alpha: 0.16),
                                        borderRadius:
                                            BorderRadius.circular(Radii.xs),
                                        border: Border.all(
                                          color: expiryColor
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        days < 0 ? 'LEWAT' : '$days HARI',
                                        style: TextStyle(
                                          fontFamily: AppConfig.fontBug,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: expiryColor,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user.expiryStatus,
                                style: const TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Palette.text3,
                                  letterSpacing: 1.0,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _UserPanelDecorPainter extends CustomPainter {
  final Color accent;
  _UserPanelDecorPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 60, paint);
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.1),
      90,
      paint..color = accent.withValues(alpha: 0.05),
    );

    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.95),
      50,
      paint..color = accent.withValues(alpha: 0.06),
    );

    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.04)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UserPanelDecorPainter old) =>
      old.accent != accent;
}

class WeatherWidget extends StatelessWidget {
  final WeatherData weather;
  final bool loading;
  final String city;
  final VoidCallback onSettings;

  const WeatherWidget({
    super.key,
    required this.weather,
    this.loading = false,
    this.city = '-',
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return GlassPanel(
        padding: const EdgeInsets.all(Spc.lg),
        child: Row(
          children: const [
            SkeletonShimmer(width: 52, height: 52, radius: 14),
            SizedBox(width: Spc.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonShimmer(width: 100, height: 12),
                  SizedBox(height: Spc.sm),
                  SkeletonShimmer(width: 140, height: 10),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final color = weather.color;

    return GlassPanel(
      padding: const EdgeInsets.all(Spc.lg),
      borderColor: color.withValues(alpha: 0.35),
      tint: color.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.4),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(weather.icon, color: color, size: 28),
          ),
          const SizedBox(width: Spc.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${weather.temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.4,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: Spc.sm),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(Radii.xs),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          city.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: color,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      weather.description,
                      style: const TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Palette.text2,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: Spc.sm),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.text3,
                      ),
                    ),
                    const SizedBox(width: Spc.sm),
                    const Icon(
                      Icons.air_rounded,
                      color: Palette.text3,
                      size: 10,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${weather.windSpeed.toStringAsFixed(1)} km/j',
                      style: const TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Palette.text3,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSettings();
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Palette.surfaceAlt.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: Palette.border),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Palette.text2,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrayerTimesWidget extends StatefulWidget {
  final PrayerTimes prayer;
  final bool loading;
  final String city;
  final VoidCallback onSettings;

  const PrayerTimesWidget({
    super.key,
    required this.prayer,
    required this.loading,
    required this.city,
    required this.onSettings,
  });

  @override
  State<PrayerTimesWidget> createState() => _PrayerTimesWidgetState();
}

class _PrayerTimesWidgetState extends State<PrayerTimesWidget> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmtCountdown(Duration d) {
    if (d.isNegative) return '--:--:--';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return GlassPanel(
        padding: const EdgeInsets.all(Spc.lg),
        child: Row(
          children: const [
            SkeletonShimmer(width: 44, height: 44, radius: 12),
            SizedBox(width: Spc.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonShimmer(width: 140, height: 12),
                  SizedBox(height: Spc.sm),
                  SkeletonShimmer(width: 200, height: 10),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final prayer = widget.prayer;
    final entries = prayer.entries;
    final nextIdx = prayer.nextPrayerIndex;
    final countdown = prayer.timeUntilNext;

    return GlassPanel(
      padding: const EdgeInsets.all(Spc.lg),
      borderColor: Palette.mint.withValues(alpha: 0.35),
      tint: Palette.mint.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Palette.mint, Palette.teal],
                  ),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.mint.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: Spc.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WAKTU SHOLAT',
                      style: TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Palette.mint,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city_rounded,
                          color: Palette.text3,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.city.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppConfig.fontBug,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Palette.text2,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (prayer.hijriDate.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Palette.text3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              prayer.hijriDate.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Palette.text3,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSettings();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Palette.surfaceAlt.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: Palette.border),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Palette.text2,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spc.lg),
          Row(
            children: List.generate(entries.length, (i) {
              final e = entries[i];
              final active = i == nextIdx;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == entries.length - 1 ? 0 : 4,
                  ),
                  child: AnimatedContainer(
                    duration: Timings.normal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                e.color.withValues(alpha: 0.30),
                                e.color.withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                      color: active
                          ? null
                          : Palette.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(
                        color: active
                            ? e.color.withValues(alpha: 0.7)
                            : Palette.borderSoft,
                        width: active ? 1.3 : 1,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: e.color.withValues(alpha: 0.35),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          e.icon,
                          size: 14,
                          color: active ? e.color : Palette.text3,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          e.label,
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: active ? e.color : Palette.text3,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          e.time,
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: active ? e.color : Palette.text2,
                            letterSpacing: 0.4,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: Spc.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spc.md,
              vertical: Spc.sm,
            ),
            decoration: BoxDecoration(
              color: Palette.bg0.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(
                color: Palette.mint.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const HaloDot(color: Palette.mint, size: 4),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${prayer.nextPrayerName} • ${prayer.nextPrayerTime}',
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Palette.text,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Text(
                  _fmtCountdown(countdown),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Palette.mint,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationSettingsSheet extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const LocationSettingsSheet({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(
          color: Palette.violet.withValues(alpha: 0.42),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.violet.withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Palette.border,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Palette.cyan, Palette.violet],
                    ),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Palette.text,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'PILIH KOTA / WILAYAH',
                        style: TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Palette.text3,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: kCityPresets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final city = kCityPresets[i];
                  final selected = i == selectedIndex;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(i);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: Timings.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Palette.violet.withValues(alpha: 0.16)
                              : Palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Palette.violet.withValues(alpha: 0.6)
                                : Palette.border,
                            width: selected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_rounded,
                              size: 16,
                              color:
                                  selected ? Palette.violet : Palette.text3,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                city.name.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: selected
                                      ? Palette.violet
                                      : Palette.text,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Text(
                              city.country.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Palette.text4,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Palette.violet,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult({required this.token, required this.user});
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen();
  }
}

class LoginScreen extends StatefulWidget {
  final ValueChanged<AppUser>? onLoggedIn;
  const LoginScreen({super.key, this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _api = BackendSvc();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.login(
      username: _username.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = 'USERNAME / PASSWORD SALAH ATAU SERVER TIDAK TERHUBUNG';
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', result.token);
    await prefs.setString('session_username', result.user.username);
    await prefs.setString('session_role', result.user.role);
    await prefs.setString('session_expired', result.user.expired);
    setState(() => _loading = false);
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(jsonEncode({
          'type': 'settings',
          'username': result.user.username,
          'role': result.user.role,
          'expired': result.user.expired,
        }));
      }
    } catch (_) {}
    widget.onLoggedIn?.call(result.user);
    if (widget.onLoggedIn == null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Palette.surface, Palette.surfaceAlt],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Palette.border),
              boxShadow: [
                BoxShadow(
                  color: Palette.violet.withValues(alpha: 0.18),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipOval(
                    child: Image.asset(
                      AppConfig.assetLogo,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const CircleAvatar(
                        radius: 39,
                        backgroundColor: Palette.surfaceSoft,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Palette.cyan,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'NEKO ASSIST',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'LOGIN DARI AKUN SERVER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 9,
                    color: Palette.text3,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  onSubmitted: (_) => _loading ? null : _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Palette.coral,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _loading ? null : _login,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(_loading ? 'MENYAMBUNG...' : 'MASUK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _fb = BackendSvc();
  final _usersSvc = UserSvc();
  final _weatherSvc = WeatherSvc();
  final _prayerSvc = PrayerSvc();

  AppUser _user = AppUser.fallback();
  DashboardStats _stats = DashboardStats.empty();
  List<ChatMsg> _chats = [];
  List<AppUser> _allUsers = [];
  List<AppUser> _backendUsers = [];
  List<SyamStory> _stories = [];
  List<NotifItem> _notifs = [];
  List<LogEntry> _logs = [];
  NetworkSnapshot _network = NetworkSnapshot.empty();
  WeatherData _weather = WeatherData.empty();
  PrayerTimes _prayer = PrayerTimes.empty();

  int _weatherCityIndex = 0;
  int _prayerCityIndex = 0;

  BackendState _backend = BackendState.loading;
  bool _backendAvailable = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _loginLogged = false;
  bool _weatherLoading = true;
  bool _prayerLoading = true;
  String _status = 'CHECKING';
  DateTime _lastUpdate = DateTime.now();

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';
  UserSort _sortMode = UserSort.name;

  Timer? _poll;
  Timer? _weatherTimer;
  Timer? _prayerTimer;
  late AnimationController _entrance;
  late Animation<double> _fade;
  late TabController _tabController;
  late List<CarouselSlide> _slides;
  late Size _screenSize;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entrance.forward();
    _tabController = TabController(length: 5, vsync: this);
    _buildSlides();
    _loadPrefsThenLoad();
    _startPolling();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  Future<void> _loadPrefsThenLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _weatherCityIndex = (prefs.getInt(AppConfig.prefWeatherCity) ?? 0)
        .clamp(0, kCityPresets.length - 1);
    _prayerCityIndex = (prefs.getInt(AppConfig.prefPrayerCity) ?? 0)
        .clamp(0, kCityPresets.length - 1);
    if (!mounted) return;
    setState(() {});
    await _load();
    _loadWeather();
    _loadPrayer();
  }

  void _buildSlides() {
    _slides = const <CarouselSlide>[
      CarouselSlide(
        code: 'ACT-01',
        badge: 'FEATURED',
        title: 'NEKOCRASH PRO',
        subtitle:
            'Buka semua modul premium dalam satu dashboard yang powerful.',
        cta: 'JELAJAHI',
        icon: Icons.workspace_premium_rounded,
        accent: Palette.pink,
        accent2: Palette.violetDeep,
      ),
      CarouselSlide(
        code: 'ACT-02',
        badge: 'TERMINAL',
        title: 'GUIDE TERMUX',
        subtitle: 'Panduan lengkap setup termux dari nol sampai siap pakai.',
        cta: 'BUKA',
        icon: Icons.terminal_rounded,
        accent: Palette.cyan,
        accent2: Palette.cyanDeep,
      ),
      CarouselSlide(
        code: 'ACT-03',
        badge: 'SERVER',
        title: 'GUIDE VPS',
        subtitle: 'Deploy server produksi dengan aman, cepat, dan stabil.',
        cta: 'MULAI',
        icon: Icons.cloud_rounded,
        accent: Palette.coral,
        accent2: Palette.pink,
      ),
      CarouselSlide(
        code: 'ACT-04',
        badge: 'KOMUNITAS',
        title: 'SYAMGRAM HUB',
        subtitle:
            'Terhubung dengan pengguna aktif lainnya di seluruh jaringan.',
        cta: 'GABUNG',
        icon: Icons.hub_rounded,
        accent: Palette.mint,
        accent2: Palette.cyanDeep,
      ),
      CarouselSlide(
        code: 'ACT-05',
        badge: 'UPDATE',
        title: 'VERSI 2.5',
        subtitle:
            'UI baru, performa lebih cepat, dan fitur-fitur baru telah hadir.',
        cta: 'LIHAT',
        icon: Icons.auto_awesome_rounded,
        accent: Palette.amber,
        accent2: Palette.violet,
      ),
    ];
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(AppConfig.pollInterval, (_) {
      _refreshRealtime();
    });
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(AppConfig.weatherInterval, (_) {
      _loadWeather();
    });
    _prayerTimer?.cancel();
    _prayerTimer = Timer.periodic(AppConfig.prayerInterval, (_) {
      _loadPrayer();
    });
  }

  Future<void> _loadWeather() async {
    if (mounted) setState(() => _weatherLoading = true);
    final city = kCityPresets[_weatherCityIndex];
    final data = await _weatherSvc.fetch(lat: city.lat, lon: city.lon);
    if (!mounted) return;
    setState(() {
      _weather = WeatherData(
        temperature: data.temperature,
        windSpeed: data.windSpeed,
        weatherCode: data.weatherCode,
        isDay: data.isDay,
        location: city.name,
        updatedAt: data.updatedAt,
      );
      _weatherLoading = false;
    });
  }

  Future<void> _loadPrayer() async {
    if (mounted) setState(() => _prayerLoading = true);
    final city = kCityPresets[_prayerCityIndex];
    final data = await _prayerSvc.fetch(city: city.name, country: city.country);
    if (!mounted) return;
    setState(() {
      _prayer = data;
      _prayerLoading = false;
    });
  }

  Future<void> _changeWeatherCity(int index) async {
    if (index < 0 || index >= kCityPresets.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.prefWeatherCity, index);
    if (!mounted) return;
    setState(() => _weatherCityIndex = index);
    await _loadWeather();
  }

  Future<void> _changePrayerCity(int index) async {
    if (index < 0 || index >= kCityPresets.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.prefPrayerCity, index);
    if (!mounted) return;
    setState(() => _prayerCityIndex = index);
    await _loadPrayer();
  }

  Future<void> _showWeatherCityPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LocationSettingsSheet(
        title: 'UBAH LOKASI CUACA',
        selectedIndex: _weatherCityIndex,
        onSelect: (i) async {
          Navigator.pop(context);
          await _changeWeatherCity(i);
        },
      ),
    );
  }

  Future<void> _showPrayerCityPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LocationSettingsSheet(
        title: 'UBAH WILAYAH SHOLAT',
        selectedIndex: _prayerCityIndex,
        onSelect: (i) async {
          Navigator.pop(context);
          await _changePrayerCity(i);
        },
      ),
    );
  }

  Future<void> _refreshRealtime({bool reloadUsers = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      if (reloadUsers || _backendUsers.isEmpty) {
        final users = await _usersSvc.fetchUsers();
        if (!mounted) return;
        if (users.isNotEmpty) {
          setState(() {
            _backendUsers = users;
            _backendAvailable = true;
          });
        }
      }

      final live = await _fb.liveStatus();
      final liveAvailable = live['available'] == true;
      final liveOnline = live['online'] == true;
      if (!mounted) return;

      _backendAvailable = liveAvailable;

      if (!liveAvailable) {
        setState(() {
          _backend = _backendAvailable
              ? BackendState.backendOnly
              : BackendState.offline;
          _status = _backendAvailable ? 'BACKEND' : 'OFFLINE';
          _stats = DashboardStats(
            online: _backendUsers.where((u) => u.isActive).length,
            sessions: 0,
            total: _backendUsers.length,
            uptimeSeconds: 0,
            cpu: 0,
            ram: 0,
            disk: 0,
            status: 'BACKEND',
          );
          _network = NetworkSnapshot.empty();
          _lastUpdate = DateTime.now();
        });
        return;
      }

      final social = await Future.wait<dynamic>([
        _fb.chats(),
        _fb.fetchStories(),
        _fb.activityLogs(),
      ]);
      if (!mounted) return;

      final chats = social[0] as List<ChatMsg>;
      final stories = social[1] as List<SyamStory>;
      final logs = social[2] as List<LogEntry>;

      final notifs = chats
          .take(30)
          .map((c) => NotifItem(
                icon: Icons.chat_bubble_rounded,
                title: c.sender.toUpperCase(),
                body: c.message,
                color: Palette.violet,
              ))
          .toList();

      unreadNotifier.value = notifs.length;

      if (!liveOnline) {
        setState(() {
          _backend = BackendState.backendOnly;
          _status = _backendAvailable ? 'BACKEND' : 'OFFLINE';
          _stats = DashboardStats(
            online: _backendUsers.where((u) => u.isActive).length,
            sessions: 0,
            total: _backendUsers.length,
            uptimeSeconds: 0,
            cpu: 0,
            ram: 0,
            disk: 0,
            status: 'BACKEND',
          );
          _chats = chats;
          _stories = stories;
          _logs = logs;
          _notifs = notifs;
          _network = NetworkSnapshot.empty();
          _lastUpdate = DateTime.now();
        });
        return;
      }

      final online = (live['onlineCount'] as int?) ?? 0;
      final sessions = (live['sessions'] as int?) ?? 0;
      final uptime = (live['uptimeSeconds'] as int?) ?? 0;

      setState(() {
        _backend = BackendState.online;
        _status = 'ONLINE';
        _stats = DashboardStats(
          online: online,
          sessions: sessions,
          total: online + sessions,
          uptimeSeconds: uptime,
          cpu: (live['cpu'] as double?) ?? 0,
          ram: (live['ram'] as double?) ?? 0,
          disk: (live['disk'] as double?) ?? 0,
          status: 'ONLINE',
        );
        _chats = chats;
        _stories = stories;
        _logs = logs;
        _notifs = notifs;
        _network = _fb.networkSnapshotFromLive(live);
        _lastUpdate = DateTime.now();
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final users = await _usersSvc.fetchUsers();
    if (!mounted) return;

    final currentUser = await _fb.me();
    if (!mounted) return;

    setState(() {
      _backendUsers = users;
      _backendAvailable = users.isNotEmpty;
      _user = (currentUser != null && currentUser.isActive)
          ? currentUser
          : _user;
      _loading = false;
      if (users.isNotEmpty) {
        _backend = BackendState.backendOnly;
        _status = 'BACKEND';
        _stats = DashboardStats(
          online: users.where((u) => u.isActive).length,
          sessions: 0,
          total: users.length,
          uptimeSeconds: 0,
          cpu: 0,
          ram: 0,
          disk: 0,
          status: 'BACKEND',
        );
      }
    });

    if (users.isNotEmpty) {
      final merged = <String, AppUser>{};
      for (final u in users) {
        merged[u.username.toLowerCase()] = u;
      }
      final result = merged.values.toList()
        ..sort((a, b) =>
            a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      setState(() => _allUsers = result);
    } else {
      setState(() => _allUsers = _backendUsers);
    }

    await _refreshRealtime();

    if (!_loginLogged && _user.username != 'guest' && _backendAvailable) {
      _loginLogged = true;
      await _fb.writeLoginHistory(
        username: _user.username,
        success: true,
      );
    }
  }

  List<AppUser> get _filteredUsers {
    final source = _backendUsers.isNotEmpty ? _backendUsers : _allUsers;
    var list = source.where((u) {
      if (_roleFilter != 'all' && u.role.toLowerCase() != _roleFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !u.username.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortMode) {
      case UserSort.name:
        list.sort((a, b) => a.username.compareTo(b.username));
        break;
      case UserSort.role:
        list.sort((a, b) => a.role.compareTo(b.role));
        break;
      case UserSort.status:
        list.sort((a, b) =>
            (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0));
        break;
      case UserSort.expiry:
        list.sort((a, b) => a.expired.compareTo(b.expired));
        break;
    }
    return list;
  }

  void _openMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MenuScreen()),
    );
  }

  void _openRat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RatScreen()),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _openRoomChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RoomChatScreen()),
    );
  }

  void _openTools() => _showGuideChooser();

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.sizeOf(context);

    final items = <NavItem>[
      const NavItem(
        icon: Icons.home_outlined,
        active: Icons.home_rounded,
        label: 'HOME',
        color: Palette.violet,
      ),
      const NavItem(
        icon: Icons.grid_view_outlined,
        active: Icons.grid_view_rounded,
        label: 'MENU',
        color: Palette.pink,
      ),
      const NavItem(
        icon: Icons.forum_outlined,
        active: Icons.forum_rounded,
        label: 'ROOM',
        color: Palette.cyan,
      ),
      const NavItem(
        icon: Icons.build_outlined,
        active: Icons.build_rounded,
        label: 'TOOLS',
        color: Palette.mint,
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Palette.bg0,
      body: CosmicBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              FadeTransition(
                opacity: _fade,
                child: _buildDashboard(),
              ),
              ChibiCompanion(
                screenSize: _screenSize,
                isDay: _weather.isDay,
                isOnline: _backend == BackendState.online,
                initialPosition: Offset(
                  _screenSize.width - 140,
                  _screenSize.height * 0.52,
                ),
                onTap: _openChat,
                onLongPress: () => _showChibiMenu(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FloatingGlassNavBar(
        index: 0,
        items: items,
        onTap: (i) {
          switch (i) {
            case 0:
              return;
            case 1:
              _openMenu();
              return;
            case 2:
              _openRoomChat();
              return;
            case 3:
              _openTools();
              return;
          }
        },
        onCenterTap: _openRat,
      ),
    );
  }

  void _showChibiMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(Spc.lg),
        padding: const EdgeInsets.all(Spc.xl),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: Palette.cyan.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.cyan.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: -6,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Palette.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: Spc.lg),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Palette.cyan, Palette.violet],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.cyan.withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: Spc.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHIBI ASSIST',
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Palette.text,
                            letterSpacing: 1.6,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'PILIH AKSI CEPAT',
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Palette.text3,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spc.lg),
              Row(
                children: [
                  Expanded(
                    child: _chibiAction(
                      icon: Icons.auto_awesome_rounded,
                      label: 'CHAT',
                      color: Palette.cyan,
                      onTap: () {
                        Navigator.pop(context);
                        _openChat();
                      },
                    ),
                  ),
                  const SizedBox(width: Spc.sm),
                  Expanded(
                    child: _chibiAction(
                      icon: Icons.bolt_rounded,
                      label: 'RAT HUB',
                      color: Palette.coral,
                      onTap: () {
                        Navigator.pop(context);
                        _openRat();
                      },
                    ),
                  ),
                  const SizedBox(width: Spc.sm),
                  Expanded(
                    child: _chibiAction(
                      icon: Icons.forum_rounded,
                      label: 'ROOM',
                      color: Palette.amber,
                      onTap: () {
                        Navigator.pop(context);
                        _openRoomChat();
                      },
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

  Widget _chibiAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Spc.md,
          horizontal: Spc.sm,
        ),
        decoration: BoxDecoration(
          color: Palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _load,
      color: Palette.violet,
      backgroundColor: Palette.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(Spc.lg, Spc.lg, Spc.lg, 200),
        children: [
          _topBar(),
          const SizedBox(height: Spc.lg),
          _greetingHeader(),
          const SizedBox(height: Spc.lg),
          WeatherWidget(
            weather: _weather,
            loading: _weatherLoading,
            city: kCityPresets[_weatherCityIndex].name,
            onSettings: _showWeatherCityPicker,
          ),
          const SizedBox(height: Spc.md),
          PrayerTimesWidget(
            prayer: _prayer,
            loading: _prayerLoading,
            city: kCityPresets[_prayerCityIndex].name,
            onSettings: _showPrayerCityPicker,
          ),
          const SizedBox(height: Spc.lg),
          _searchBar(),
          const SizedBox(height: Spc.lg),
          _monitorStrip(),
          const SizedBox(height: Spc.md),
          _overlayMenuButton(),
          const SizedBox(height: Spc.lg),
          if (_backend != BackendState.online) ...[
            _backendBanner(),
            const SizedBox(height: Spc.lg),
          ],
          if (_loading)
            _skeleton()
          else ...[
            FullScreenCarousel(
              slides: _slides,
              onTap: _handleCarouselTap,
            ),
            const SizedBox(height: Spc.xl),
            SectionHeader(
              title: 'AKSES MODUL',
              accent: Palette.plasma,
              icon: Icons.security_rounded,
              trailing: 'SECURE',
              trailingColor: Palette.plasma,
            ),
            const SizedBox(height: Spc.md),
            _modulesGrid(),
            const SizedBox(height: Spc.xl),
            SectionHeader(
              title: 'INFORMASI PENGGUNA',
              accent: Palette.pink,
              trailing: _user.isActive ? 'AKTIF' : 'NONAKTIF',
              trailingColor: _user.isActive ? Palette.mint : Palette.coral,
            ),
            const SizedBox(height: Spc.md),
            UserInfoPanel(user: _user, status: _status),
            const SizedBox(height: Spc.xl),
            PremiumTabBar(
              controller: _tabController,
              tabs: const [
                SectionTabData(
                  label: 'MENU',
                  icon: Icons.dashboard_rounded,
                  color: Palette.violet,
                ),
                SectionTabData(
                  label: 'SYAMGRAM',
                  icon: Icons.camera_rounded,
                  color: Palette.pink,
                ),
                SectionTabData(
                  label: 'CREATE',
                  icon: Icons.people_alt_rounded,
                  color: Palette.cyan,
                ),
                SectionTabData(
                  label: 'NOTIF',
                  icon: Icons.notifications_rounded,
                  color: Palette.mint,
                ),
                SectionTabData(
                  label: 'AKTIVITAS',
                  icon: Icons.receipt_long_rounded,
                  color: Palette.amber,
                ),
              ],
            ),
            const SizedBox(height: Spc.lg),
            AnimatedBuilder(
              animation: _tabController,
              builder: (_, __) {
                switch (_tabController.index) {
                  case 0:
                    return _overviewTab();
                  case 1:
                    return _syamgramTab();
                  case 2:
                    return _usersTab();
                  case 3:
                    return _transmissionTab();
                  case 4:
                    return _logsTab();
                  default:
                    return _overviewTab();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _modulesGrid() {
    final modules = <_ModuleData>[
      _ModuleData(
        'RAT HUB',
        'Remote Access Toolkit',
        Icons.bolt_rounded,
        Palette.coral,
        Palette.blood,
        onTap: _openRat,
      ),
      _ModuleData(
        'BUG PANEL',
        'Exploit & Payload',
        Icons.bug_report_rounded,
        Palette.danger,
        Palette.plasma,
        onTap: _openRat,
      ),
      _ModuleData(
        'TOOLS',
        'Utility & Recon',
        Icons.build_rounded,
        Palette.violet,
        Palette.violetDeep,
        onTap: _openTools,
      ),
      _ModuleData(
        'SESSION',
        'Active Monitor',
        Icons.sensors_rounded,
        Palette.mint,
        Palette.teal,
        onTap: _openRat,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _moduleCard(modules[0])),
            const SizedBox(width: Spc.md),
            Expanded(child: _moduleCard(modules[1])),
          ],
        ),
        const SizedBox(height: Spc.md),
        Row(
          children: [
            Expanded(child: _moduleCard(modules[2])),
            const SizedBox(width: Spc.md),
            Expanded(child: _moduleCard(modules[3])),
          ],
        ),
      ],
    );
  }

  Widget _moduleCard(_ModuleData data) {
    return TapScale(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(Spc.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              data.color.withValues(alpha: 0.24),
              data.color2.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: data.color.withValues(alpha: 0.42),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: 0.22),
              blurRadius: 20,
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [data.color, data.color2],
                ),
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: [
                  BoxShadow(
                    color: data.color.withValues(alpha: 0.6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(data.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: Spc.md),
            Text(
              data.title,
              style: const TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Palette.text,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Palette.text3,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backendBanner() {
    final onlyBackend = _backend == BackendState.backendOnly;
    final color = onlyBackend ? Palette.amber : Palette.coral;
    final icon =
        onlyBackend ? Icons.cloud_off_rounded : Icons.wifi_off_rounded;
    final title =
        onlyBackend ? 'BACKEND OFFLINE — MODE BACKEND' : 'TIDAK ADA KONEKSI';
    final subtitle = onlyBackend
        ? 'Data pengguna aktif dari Backend. Fitur realtime dinonaktifkan sementara.'
        : 'Cek koneksi internet kamu. Beberapa fitur butuh jaringan.';

    return GlassPanel(
      padding: const EdgeInsets.all(Spc.md),
      borderColor: color.withValues(alpha: 0.4),
      tint: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: Spc.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 8.5,
                    color: Palette.text2,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleCarouselTap(CarouselSlide slide) {
    switch (slide.title) {
      case 'GUIDE TERMUX':
        _showGuide(
          title: 'GUIDE TERMUX',
          accent: Palette.cyan,
          steps: const [
            'Update package manager dan cek versi Termux.',
            'Pasang runtime/tool yang dibutuhkan project.',
            'Clone atau salin project ke folder kerja.',
            'Jalankan dependency install lalu start project.',
          ],
        );
        break;
      case 'GUIDE VPS':
        _showGuide(
          title: 'GUIDE VPS',
          accent: Palette.coral,
          steps: const [
            'Siapkan VPS dan user kerja non-root.',
            'Install runtime sesuai stack aplikasi.',
            'Jalankan service menggunakan process manager.',
            'Hubungkan heartbeat status dan monitoring backend.',
          ],
        );
        break;
      case 'SYAMGRAM HUB':
        _tabController.animateTo(1);
        break;
      default:
        _showSnack('${slide.title} SIAP DIGUNAKAN');
    }
  }

  Future<Map<String, dynamic>> _readOverlayConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return <String, dynamic>{
      'overlay_enabled': prefs.getBool(AppConfig.prefOverlayEnabled) ?? true,
      'panel_enabled': prefs.getBool(AppConfig.prefOverlayPanel) ?? true,
      'dashboard_enabled':
          prefs.getBool(AppConfig.prefOverlayDashboard) ?? true,
      'bug_enabled': prefs.getBool(AppConfig.prefOverlayBug) ?? true,
      'chat_enabled': prefs.getBool(AppConfig.prefOverlayChat) ?? true,
      'scale': (prefs.getDouble('overlay_scale') ?? 1.0).clamp(0.75, 1.35),
    };
  }

  Future<void> _pushOverlayConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      AppConfig.prefOverlayEnabled,
      config['overlay_enabled'] == true,
    );
    await prefs.setBool(
      AppConfig.prefOverlayPanel,
      config['panel_enabled'] == true,
    );
    await prefs.setBool(
      AppConfig.prefOverlayDashboard,
      config['dashboard_enabled'] == true,
    );
    await prefs.setBool(
      AppConfig.prefOverlayBug,
      config['bug_enabled'] == true,
    );
    await prefs.setBool(
      AppConfig.prefOverlayChat,
      config['chat_enabled'] == true,
    );
    if (config['scale'] is num) {
      await prefs.setDouble(
        'overlay_scale',
        (config['scale'] as num).toDouble().clamp(0.75, 1.35),
      );
    }

    final enabled = config['overlay_enabled'] == true;
    if (!enabled) {
      try {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
      } catch (e) {
        debugPrint('OVERLAY OFF ERROR: $e');
      }
      return;
    }

    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (granted != true) {
        final result = await FlutterOverlayWindow.requestPermission();
        if (result != true) {
          return;
        }
      }

      final active = await FlutterOverlayWindow.isActive();
      if (!active) {
        await FlutterOverlayWindow.showOverlay(
          height: 64,
          width: 64,
          alignment: OverlayAlignment.centerRight,
          visibility: NotificationVisibility.visibilitySecret,
          positionGravity: PositionGravity.none,
          enableDrag: false,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: 'Neko Assist',
          overlayContent: 'Bubble aktif',
        );
      }

      final sessionUser =
          prefs.getString('session_username') ?? _user.username;
      final sessionRole = prefs.getString('session_role') ?? _user.role;
      final sessionExpired =
          prefs.getString('session_expired') ?? _user.expired;

      await FlutterOverlayWindow.shareData(jsonEncode({
        'type': 'settings',
        'overlay_enabled': true,
        'username': sessionUser,
        'role': sessionRole,
        'expired': sessionExpired,
        ...config,
      }));
    } catch (e, st) {
      debugPrint('OVERLAY APPLY ERROR: $e');
      debugPrint('$st');
    }
  }

  Future<void> _showOverlayMenu() async {
    HapticFeedback.mediumImpact();
    final initial = await _readOverlayConfig();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        bool overlayEnabled = initial['overlay_enabled'] == true;
        bool panelEnabled = initial['panel_enabled'] == true;
        bool dashboardEnabled = initial['dashboard_enabled'] == true;
        bool bugEnabled = initial['bug_enabled'] == true;
        bool chatEnabled = initial['chat_enabled'] == true;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> update({
              bool? overlay,
              bool? panel,
              bool? dashboard,
              bool? bug,
              bool? chat,
            }) async {
              setSheetState(() {
                if (overlay != null) overlayEnabled = overlay;
                if (panel != null) panelEnabled = panel;
                if (dashboard != null) dashboardEnabled = dashboard;
                if (bug != null) bugEnabled = bug;
                if (chat != null) chatEnabled = chat;
              });

              await _pushOverlayConfig({
                'overlay_enabled': overlayEnabled,
                'panel_enabled': panelEnabled,
                'dashboard_enabled': dashboardEnabled,
                'bug_enabled': bugEnabled,
                'chat_enabled': chatEnabled,
                'scale': initial['scale'],
              });
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(
                    color: Palette.violet.withValues(alpha: 0.42),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.violet.withValues(alpha: 0.18),
                      blurRadius: 30,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Palette.border,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Palette.cyan, Palette.violet],
                            ),
                            borderRadius: BorderRadius.circular(Radii.md),
                            boxShadow: [
                              BoxShadow(
                                color: Palette.cyan.withValues(alpha: 0.28),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OVERLAY MENU',
                                style: TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.text,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'KONTROL BUBBLE DAN FITUR OVERLAY',
                                style: TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Palette.text3,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _overlaySwitchTile(
                      icon: Icons.power_settings_new_rounded,
                      title: 'OVERLAY',
                      subtitle: 'Tampilkan atau sembunyikan bubble',
                      color: Palette.mint,
                      value: overlayEnabled,
                      onChanged: (v) => update(overlay: v),
                      emphasized: true,
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'FITUR OVERLAY',
                        style: TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Palette.text3,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    _overlaySwitchTile(
                      icon: Icons.tune_rounded,
                      title: 'PANEL',
                      subtitle: 'Tampilkan Tools Panel pada bubble',
                      color: Palette.pink,
                      value: panelEnabled,
                      enabled: overlayEnabled,
                      onChanged: (v) => update(panel: v),
                    ),
                    const SizedBox(height: 6),
                    _overlaySwitchTile(
                      icon: Icons.home_rounded,
                      title: 'DASHBOARD',
                      subtitle: 'Akses dashboard dari overlay',
                      color: Palette.cyan,
                      value: dashboardEnabled,
                      enabled: overlayEnabled,
                      onChanged: (v) => update(dashboard: v),
                    ),
                    const SizedBox(height: 6),
                    _overlaySwitchTile(
                      icon: Icons.bug_report_rounded,
                      title: 'BUG PANEL',
                      subtitle: 'Tampilkan menu Bug Panel',
                      color: Palette.coral,
                      value: bugEnabled,
                      enabled: overlayEnabled,
                      onChanged: (v) => update(bug: v),
                    ),
                    const SizedBox(height: 6),
                    _overlaySwitchTile(
                      icon: Icons.build_circle_rounded,
                      title: 'TOOLS PANEL',
                      subtitle: 'Tampilkan menu Tools Panel',
                      color: Palette.violet,
                      value: panelEnabled,
                      enabled: overlayEnabled,
                      onChanged: (v) => update(panel: v),
                    ),
                    const SizedBox(height: 6),
                    _overlaySwitchTile(
                      icon: Icons.auto_awesome_rounded,
                      title: 'CHAT',
                      subtitle: 'Tampilkan akses Chat',
                      color: Palette.amber,
                      value: chatEnabled,
                      enabled: overlayEnabled,
                      onChanged: (v) => update(chat: v),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _overlaySwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    bool emphasized = false,
  }) {
    return AnimatedOpacity(
      duration: Timings.fast,
      opacity: enabled ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: emphasized ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Palette.text,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 7.5,
                      color: Palette.text3,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final online = _status == 'ONLINE';
    final backend = _status == 'BACKEND';
    final checking = _status == 'CHECKING';
    final color = checking
        ? Palette.amber
        : online
            ? Palette.mint
            : backend
                ? Palette.cyan
                : Palette.coral;
    return Row(
      children: [
        AvatarCircle(user: _user, size: 46),
        const SizedBox(width: Spc.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _user.username.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Palette.text,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_user.isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Radii.xs),
                        border: Border.all(
                          color: Palette.gold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        'OWNER',
                        style: TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Palette.gold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  HaloDot(color: color, size: 4),
                  const SizedBox(width: 6),
                  Text(
                    checking
                        ? 'CHECKING'
                        : online
                            ? 'ONLINE'
                            : backend
                                ? 'BACKEND ONLY'
                                : 'OFFLINE',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: Spc.sm),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.text3,
                    ),
                  ),
                  const SizedBox(width: Spc.sm),
                  const LiveClock(
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Palette.text3,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _notifButton(),
        const SizedBox(width: Spc.sm),
        _profileButton(),
      ],
    );
  }

  Widget _notifButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showNotifs();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: Palette.border, width: 1),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Palette.text,
              size: 19,
            ),
          ),
          if (_notifs.isNotEmpty)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: Palette.coral,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: Palette.bg0, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _notifs.length > 99 ? '99+' : '${_notifs.length}',
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9.5,
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

  Widget _profileButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showSnack('PROFILE SEGERA HADIR');
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: Palette.violet.withValues(alpha: 0.55),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _user.isOwner
                ? [Palette.pink, Palette.violet]
                : _user.isVip
                    ? [Palette.amber, Palette.coral]
                    : [Palette.violet, Palette.cyanDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.violet.withValues(alpha: 0.35),
              blurRadius: 12,
            ),
          ],
        ),
        child: Center(
          child: Text(
            _user.initial,
            style: const TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _greetingHeader() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'SELAMAT PAGI'
        : hour < 15
            ? 'SELAMAT SIANG'
            : hour < 18
                ? 'SELAMAT SORE'
                : 'SELAMAT MALAM';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Palette.violet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.xs),
                  border: Border.all(
                    color: Palette.violet.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wb_twilight_rounded,
                      size: 10,
                      color: Palette.violet,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Palette.violet,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spc.sm),
              Text(
                'HAI, ${_user.username.toUpperCase()}',
                style: const TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Palette.text,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 10,
                    color: Palette.text3,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'UPDATE ${_fmtTime(_lastUpdate)}',
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Palette.text3,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TapScale(
          onTap: _loadWeather,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _weather.isDay
                    ? [Palette.amber, Palette.orange]
                    : [Palette.violet, Palette.blue],
              ),
              borderRadius: BorderRadius.circular(Radii.sm),
              boxShadow: [
                BoxShadow(
                  color: (_weather.isDay ? Palette.amber : Palette.violet)
                      .withValues(alpha: 0.4),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(_weather.icon, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Palette.border, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: Spc.md),
          const Icon(Icons.search_rounded, color: Palette.text3, size: 20),
          const SizedBox(width: Spc.sm),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Palette.text,
              ),
              decoration: const InputDecoration(
                hintText: 'CARI USER, ROLE, ATAU FITUR...',
                hintStyle: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.4,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => _searchController.clear(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: Spc.md),
                child: Icon(
                  Icons.close_rounded,
                  color: Palette.text3,
                  size: 18,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(
              horizontal: Spc.md,
              vertical: Spc.sm,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Palette.violet, Palette.pink],
              ),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: const Text(
              'CARI',
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayMenuButton() {
    return GestureDetector(
      onTap: _showOverlayMenu,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Palette.surfaceAlt, Palette.surface],
          ),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: Palette.cyan.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.cyan.withValues(alpha: 0.10),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Palette.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(
                  color: Palette.cyan.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.layers_rounded,
                color: Palette.cyan,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVERLAY MENU',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Palette.text,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'BUBBLE / PANEL / FITUR',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: Palette.text3,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Palette.text3,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _monitorStrip() {
    return GlassPanel(
      padding: const EdgeInsets.all(Spc.sm),
      child: Row(
        children: [
          Expanded(
            child: _monitorCell(
              'ONLINE',
              _stats.online,
              Icons.visibility_rounded,
              Palette.mint,
            ),
          ),
          _cellDivider(),
          Expanded(
            child: _monitorCell(
              'SESSIONS',
              _stats.sessions,
              Icons.sensors_rounded,
              Palette.violet,
            ),
          ),
          _cellDivider(),
          Expanded(
            child: _monitorCell(
              'ACCOUNTS',
              _backendUsers.length,
              Icons.people_alt_rounded,
              Palette.pink,
            ),
          ),
          _cellDivider(),
          Expanded(
            child: _monitorTextCell(
              'UPTIME',
              _stats.uptimeSeconds > 0
                  ? _formatUptime(_stats.uptimeSeconds)
                  : '-',
              Icons.speed_rounded,
              Palette.cyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellDivider() =>
      Container(width: 1, height: 38, color: Palette.borderSoft);

  Widget _monitorCell(String label, int value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        NumberCounter(
          value: value,
          style: TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.4,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _monitorTextCell(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return '0s';
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  Widget _overviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'JUMLAH ROLE USER',
          accent: Palette.pink,
          trailing: '${_backendUsers.length} BACKEND',
          trailingColor: Palette.pink,
        ),
        const SizedBox(height: Spc.md),
        GlassPanel(
          padding: const EdgeInsets.all(Spc.lg),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DonutChart(
                      values: [
                        _backendUsers
                            .where((u) => u.role.toLowerCase() == 'owner')
                            .length
                            .toDouble(),
                        _backendUsers
                            .where((u) => u.isAdmin)
                            .length
                            .toDouble(),
                        _backendUsers.where((u) => u.isVip).length.toDouble(),
                        _backendUsers
                            .where((u) =>
                                !u.isOwner && !u.isAdmin && !u.isVip)
                            .length
                            .toDouble(),
                      ],
                      colors: const [
                        Palette.pink,
                        Palette.violet,
                        Palette.amber,
                        Palette.text3,
                      ],
                      size: 110,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_backendUsers.length}',
                          style: const TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Palette.text,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Palette.text3,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spc.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(
                      'OWNER',
                      _backendUsers.where((u) => u.isOwner).length,
                      Palette.pink,
                    ),
                    const SizedBox(height: Spc.sm),
                    _legendRow(
                      'ADMIN',
                      _backendUsers.where((u) => u.isAdmin).length,
                      Palette.violet,
                    ),
                    const SizedBox(height: Spc.sm),
                    _legendRow(
                      'VIP',
                      _backendUsers.where((u) => u.isVip).length,
                      Palette.amber,
                    ),
                    const SizedBox(height: Spc.sm),
                    _legendRow(
                      'BASIC',
                      _backendUsers
                          .where((u) =>
                              !u.isOwner && !u.isAdmin && !u.isVip)
                          .length,
                      Palette.text3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spc.lg),
        SectionHeader(
          title: 'TOP USERS',
          accent: Palette.amber,
          trailing: 'RANKING',
          trailingColor: Palette.amber,
        ),
        const SizedBox(height: Spc.md),
        ..._topUsers().map(_topUserRow),
      ],
    );
  }

  List<AppUser> _topUsers() {
    final list = List<AppUser>.from(_backendUsers);
    list.sort((a, b) {
      final aScore = (a.isOwner ? 100 : 0) +
          (a.isAdmin ? 50 : 0) +
          (a.isVip ? 25 : 0) +
          (a.isActive ? 10 : 0);
      final bScore = (b.isOwner ? 100 : 0) +
          (b.isAdmin ? 50 : 0) +
          (b.isVip ? 25 : 0) +
          (b.isActive ? 10 : 0);
      return bScore.compareTo(aScore);
    });
    return list.take(3).toList();
  }

  Widget _topUserRow(AppUser u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spc.sm),
      child: GlassPanel(
        padding: const EdgeInsets.all(Spc.md),
        child: Row(
          children: [
            AvatarCircle(user: u, size: 40, showRing: false),
            const SizedBox(width: Spc.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.username.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Palette.text,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RoleChip(role: u.role),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Palette.coral,
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  u.isActive ? 'AKTIF' : 'OFF',
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: u.isActive ? Palette.mint : Palette.text3,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: Spc.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Palette.text2,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateAccount() async {
    if (!_backendAvailable) {
      _showSnack('BACKEND OFFLINE — TIDAK BISA SIMPAN AKUN');
      return;
    }
    final username = TextEditingController();
    final password = TextEditingController();
    final expiry = TextEditingController();
    String role = 'basic';
    bool obscure = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: const BorderSide(color: Palette.border),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Palette.cyan, Palette.violet],
                  ),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: Spc.md),
              const Text(
                'CREATE AKUN',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontWeight: FontWeight.w900,
                  color: Palette.text,
                  letterSpacing: 1.2,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  controller: username,
                  label: 'USERNAME',
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: Spc.md),
                _dialogField(
                  controller: password,
                  label: 'PASSWORD',
                  icon: Icons.lock_rounded,
                  obscure: obscure,
                  suffix: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Palette.text3,
                      size: 18,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
                const SizedBox(height: Spc.md),
                _dialogField(
                  controller: expiry,
                  label: 'EXPIRED (YYYY-MM-DD)',
                  icon: Icons.event_available_rounded,
                ),
                const SizedBox(height: Spc.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spc.md),
                  decoration: BoxDecoration(
                    color: Palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: Palette.border),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: role,
                    dropdownColor: Palette.surfaceAlt,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      color: Palette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'ROLE',
                      labelStyle: TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Palette.text3,
                        letterSpacing: 1.2,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'basic', child: Text('BASIC')),
                      DropdownMenuItem(value: 'vip', child: Text('VIP')),
                      DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
                      DropdownMenuItem(value: 'owner', child: Text('OWNER')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => role = v ?? 'basic'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'BATAL',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            FilledButton(
              onPressed: () async {
                final name = username.text.trim();
                final pass = password.text.trim();
                final exp = expiry.text.trim();
                if (name.isEmpty || pass.isEmpty) return;
                final parsed = DateTime.tryParse(exp) ??
                    (() {
                      final parts = exp.split('/');
                      if (parts.length != 3) return null;
                      return DateTime.tryParse(
                        '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
                      );
                    })();
                if (parsed == null) return;
                try {
                  final ok = await _fb.writeAccount(
                    username: name,
                    password: pass,
                    role: role,
                    expired: exp,
                    active: true,
                  );
                  if (context.mounted) Navigator.pop(context, ok);
                } catch (_) {
                  if (context.mounted) Navigator.pop(context, false);
                }
              },
              child: const Text(
                'SIMPAN',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    username.dispose();
    password.dispose();
    expiry.dispose();
    if (!mounted) return;
    if (created == true) {
      _showSnack('AKUN TERSIMPAN KE SERVER');
      await _load();
    } else if (created == false) {
      _showSnack('GAGAL MENYIMPAN AKUN');
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spc.md),
      decoration: BoxDecoration(
        color: Palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: Palette.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          fontFamily: AppConfig.fontBug,
          color: Palette.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, color: Palette.text3, size: 16),
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Palette.text3,
            letterSpacing: 1.2,
          ),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  Widget _syamgramTab() {
    final offline = _backend != BackendState.online;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'SYAMGRAM',
          accent: Palette.pink,
          trailing:
              _stories.isEmpty ? 'NO STORY' : '${_stories.length} STORY',
          trailingColor: Palette.pink,
        ),
        const SizedBox(height: Spc.md),
        if (offline)
          GlassPanel(
            padding: const EdgeInsets.all(Spc.md),
            borderColor: Palette.coral.withValues(alpha: 0.35),
            tint: Palette.coral.withValues(alpha: 0.06),
            child: Row(
              children: const [
                Icon(
                  Icons.cloud_off_rounded,
                  color: Palette.coral,
                  size: 18,
                ),
                SizedBox(width: Spc.md),
                Expanded(
                  child: Text(
                    'SYAMGRAM BUTUH SERVER. Fitur tidak tersedia saat backend offline.',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      color: Palette.text2,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!offline) ...[
          GlassPanel(
            padding: const EdgeInsets.all(Spc.md),
            child: SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _stories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: Spc.md),
                itemBuilder: (_, i) {
                  if (i == 0) return _storyCircle(create: true);
                  return _storyCircle(story: _stories[i - 1], index: i - 1);
                },
              ),
            ),
          ),
          const SizedBox(height: Spc.lg),
          if (_stories.isEmpty)
            GlassPanel(
              padding: const EdgeInsets.all(Spc.xl),
              child: Column(
                children: const [
                  Icon(
                    Icons.photo_camera_back_rounded,
                    size: 30,
                    color: Palette.text3,
                  ),
                  SizedBox(height: Spc.md),
                  Text(
                    'BELUM ADA STORY',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Palette.text2,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._stories.map(_storyFeedCard),
        ],
      ],
    );
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('format=jpg') ||
        lower.contains('format=png');
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8');
  }

  bool _isLocalMedia(String url) {
    if (url.isEmpty) return false;
    if (url.startsWith('http://') || url.startsWith('https://')) return false;
    if (url.startsWith('content://')) return true;
    if (url.startsWith('/')) return true;
    if (url.length > 2 && url[1] == ':' && (url[2] == '\\' || url[2] == '/')) {
      return true;
    }
    return false;
  }

  Widget _storyMedia(String url, {BoxFit fit = BoxFit.cover}) {
    if (_isLocalMedia(url)) {
      return Image.file(
        File(url),
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Palette.surfaceAlt,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Palette.violet),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _storyCircle({
    SyamStory? story,
    bool create = false,
    int index = 0,
  }) {
    final color = create ? Palette.pink : Palette.violet;
    return GestureDetector(
      onTap: () {
        if (create) {
          _showCreateStory();
        } else {
          _openStoryViewer(index);
        }
      },
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.25)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.surface,
                ),
                child: ClipOval(
                  child: _storyThumb(story, create),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              create ? 'BUAT' : story!.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: create ? Palette.pink : Palette.text2,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storyThumb(SyamStory? story, bool create) {
    if (create) {
      return const Icon(Icons.add_rounded, color: Palette.text, size: 25);
    }
    final url = story!.mediaUrl?.trim() ?? '';
    if (url.isEmpty) {
      return Center(
        child: Text(
          story.username.isEmpty ? '?' : story.username[0].toUpperCase(),
          style: const TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Palette.text,
          ),
        ),
      );
    }
    if (_isImageUrl(url) || _isLocalMedia(url)) {
      return _storyMedia(url);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E1065),
                Color(0xFF7C3AED),
                Color(0xFFEC4899),
              ],
            ),
          ),
        ),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ],
    );
  }

  void _openStoryViewer(int initialIndex) {
    if (_stories.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => StoryViewer(
          stories: _stories,
          initialIndex: initialIndex,
          currentUser: _user.username,
          onReply: (story, text) async {
            await _fb.sendChat(_user.username, '@${story.username}: $text');
          },
          onDelete: (story) => _confirmDeleteStory(story),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _storyFeedCard(SyamStory story) {
    final stamp =
        '${story.time.hour.toString().padLeft(2, '0')}:${story.time.minute.toString().padLeft(2, '0')}';
    final url = story.mediaUrl?.trim() ?? '';
    final hasMedia = url.isNotEmpty;
    final isImage = hasMedia && (_isImageUrl(url) || _isLocalMedia(url));
    final isVideo = hasMedia && _isVideoUrl(url);
    final isOwn =
        story.username.toLowerCase() == _user.username.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: Spc.md),
      child: GlassPanel(
        padding: const EdgeInsets.all(Spc.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.pink.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Palette.pink.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      story.username.isEmpty
                          ? '?'
                          : story.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontWeight: FontWeight.w900,
                        color: Palette.pink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spc.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              story.username.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Palette.text,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          if (isOwn) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Palette.violet.withValues(alpha: 0.18),
                                borderRadius:
                                    BorderRadius.circular(Radii.xs),
                                border: Border.all(
                                  color: Palette.violet
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Text(
                                'KAMU',
                                style: TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.violet,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stamp,
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8,
                          color: Palette.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwn)
                  GestureDetector(
                    onTap: () => _confirmDeleteStory(story),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Palette.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.xs),
                        border: Border.all(
                          color: Palette.coral.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Palette.coral,
                        size: 16,
                      ),
                    ),
                  )
                else
                  HaloDot(color: Palette.mint, size: 4),
              ],
            ),
            if (isImage) ...[
              const SizedBox(height: Spc.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: _storyMedia(url),
              ),
            ],
            if (isVideo) ...[
              const SizedBox(height: Spc.md),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: Palette.borderSoft),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: Palette.violet,
                    size: 42,
                  ),
                ),
              ),
            ],
            if (story.text.isNotEmpty) ...[
              const SizedBox(height: Spc.md),
              Text(
                story.text,
                style: const TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Palette.text2,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStory(SyamStory story) async {
    final preview =
        story.text.length > 60 ? '${story.text.substring(0, 60)}...' : story.text;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: const BorderSide(color: Palette.border),
        ),
        title: const Text(
          'HAPUS STORY',
          style: TextStyle(
            fontFamily: AppConfig.fontBug,
            fontWeight: FontWeight.w900,
            color: Palette.text,
            letterSpacing: 1.2,
            fontSize: 13,
          ),
        ),
        content: Text(
          'Yakin mau hapus story ini?\n\n$preview',
          style: const TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 10,
            color: Palette.text2,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'BATAL',
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontWeight: FontWeight.w900,
                color: Palette.text3,
                letterSpacing: 1.4,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'HAPUS',
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await _fb.deleteStory(story.id);
    if (!mounted) return;
    if (success) {
      setState(() => _stories.removeWhere((s) => s.id == story.id));
      _showSnack('STORY DIHAPUS');
      await _refreshRealtime();
    } else {
      _showSnack('GAGAL MENGHAPUS STORY');
    }
  }

  Future<void> _showCreateStory() async {
    if (!_backendAvailable) {
      _showSnack('BACKEND OFFLINE — STORY BUTUH BACKEND');
      return;
    }
    final textController = TextEditingController();
    final mediaController = TextEditingController();
    final picker = ImagePicker();
    String mediaMode = 'url';
    XFile? pickedFile;
    bool uploading = false;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            side: const BorderSide(color: Palette.border),
          ),
          title: const Text(
            'BUAT SYAMGRAM STORY',
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontWeight: FontWeight.w900,
              color: Palette.text,
              letterSpacing: 1.2,
              fontSize: 13,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 4,
                  style: const TextStyle(color: Palette.text),
                  decoration: const InputDecoration(
                    labelText: 'Isi story',
                    hintText: 'Tulis apa yang sedang kamu bagikan...',
                  ),
                ),
                const SizedBox(height: Spc.md),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => mediaMode = 'url'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: Spc.sm,
                          ),
                          decoration: BoxDecoration(
                            color: mediaMode == 'url'
                                ? Palette.violet.withValues(alpha: 0.18)
                                : Palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                              color: mediaMode == 'url'
                                  ? Palette.violet.withValues(alpha: 0.55)
                                  : Palette.border,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'LINK URL',
                              style: TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Palette.text,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spc.sm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => mediaMode = 'gallery'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: Spc.sm,
                          ),
                          decoration: BoxDecoration(
                            color: mediaMode == 'gallery'
                                ? Palette.pink.withValues(alpha: 0.18)
                                : Palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                              color: mediaMode == 'gallery'
                                  ? Palette.pink.withValues(alpha: 0.55)
                                  : Palette.border,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'GALERI',
                              style: TextStyle(
                                fontFamily: AppConfig.fontBug,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Palette.text,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spc.md),
                if (mediaMode == 'url')
                  TextField(
                    controller: mediaController,
                    style: const TextStyle(color: Palette.text),
                    decoration: const InputDecoration(
                      labelText: 'Media URL (opsional)',
                      hintText: 'https://... .jpg / .mp4',
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: uploading
                            ? null
                            : () async {
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (file != null) {
                                  setDialogState(() => pickedFile = file);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.all(Spc.md),
                          decoration: BoxDecoration(
                            color: Palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                              color: pickedFile != null
                                  ? Palette.mint.withValues(alpha: 0.55)
                                  : Palette.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                pickedFile != null
                                    ? Icons.image_rounded
                                    : Icons.image_outlined,
                                color: pickedFile != null
                                    ? Palette.mint
                                    : Palette.text3,
                                size: 18,
                              ),
                              const SizedBox(width: Spc.sm),
                              Expanded(
                                child: Text(
                                  pickedFile == null
                                      ? 'PILIH DARI GALERI'
                                      : pickedFile!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppConfig.fontBug,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: pickedFile != null
                                        ? Palette.mint
                                        : Palette.text3,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              if (pickedFile != null)
                                GestureDetector(
                                  onTap: () => setDialogState(
                                      () => pickedFile = null),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Palette.text3,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (pickedFile != null) ...[
                        const SizedBox(height: Spc.md),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          child: Image.file(
                            File(pickedFile!.path),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(height: 0),
                          ),
                        ),
                      ],
                      if (uploading) ...[
                        const SizedBox(height: Spc.md),
                        const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Palette.violet),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(context),
              child: const Text(
                'BATAL',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            FilledButton(
              onPressed: uploading
                  ? null
                  : () async {
                      final text = textController.text.trim();
                      if (text.isEmpty) return;
                      String? mediaUrl;
                      if (mediaMode == 'url') {
                        final u = mediaController.text.trim();
                        mediaUrl = u.isEmpty ? null : u;
                      } else if (pickedFile != null) {
                        setDialogState(() => uploading = true);
                        final uploaded = await _fb.uploadStoryMedia(
                          File(pickedFile!.path),
                        );
                        if (!context.mounted) return;
                        setDialogState(() => uploading = false);
                        if (uploaded != null) {
                          mediaUrl = uploaded;
                        } else {
                          mediaUrl = pickedFile!.path;
                        }
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context, {
                        'text': text,
                        'media': mediaUrl ?? '',
                      });
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'POSTING',
                      style: TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
    mediaController.dispose();
    if (!mounted || result == null) return;
    final ok = await _fb.createStory(
      username: _user.username,
      text: result['text'] ?? '',
      mediaUrl: (result['media'] ?? '').isEmpty ? null : result['media'],
    );
    if (!mounted) return;
    _showSnack(ok ? 'STORY TERSIMPAN KE SERVER' : 'GAGAL MEMBUAT STORY');
    if (ok) await _refreshRealtime();
  }

  Widget _transmissionTab() {
    final offline = _backend != BackendState.online;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'TRANSMISSION',
          accent: Palette.mint,
          trailing: offline ? 'OFFLINE' : '${_chats.length} MSG',
          trailingColor: offline ? Palette.coral : Palette.mint,
          icon: Icons.notifications_rounded,
        ),
        const SizedBox(height: Spc.md),
        if (offline)
          GlassPanel(
            padding: const EdgeInsets.all(Spc.md),
            borderColor: Palette.coral.withValues(alpha: 0.35),
            tint: Palette.coral.withValues(alpha: 0.06),
            child: Row(
              children: const [
                Icon(
                  Icons.cloud_off_rounded,
                  color: Palette.coral,
                  size: 18,
                ),
                SizedBox(width: Spc.md),
                Expanded(
                  child: Text(
                    'TRANSMISSION BUTUH SERVER. Notifikasi akan tampil saat backend online.',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      color: Palette.text2,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_chats.isEmpty)
          _emptyTransmission()
        else
          ..._chats.take(20).map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: Spc.sm),
                  child: _transmissionCard(c),
                ),
              ),
      ],
    );
  }

  Widget _emptyTransmission() {
    return GlassPanel(
      padding: const EdgeInsets.all(Spc.xl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.surfaceAlt,
              border: Border.all(color: Palette.border),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 26,
              color: Palette.text3,
            ),
          ),
          const SizedBox(height: Spc.md),
          const Text(
            'BELUM ADA NOTIFIKASI',
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Palette.text2,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transmissionCard(ChatMsg c) {
    return Container(
      padding: const EdgeInsets.all(Spc.md),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Palette.violet, Palette.pink],
                  ),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Center(
                  child: Text(
                    c.sender.isNotEmpty ? c.sender[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: HaloDot(color: Palette.mint, size: 4),
              ),
            ],
          ),
          const SizedBox(width: Spc.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.sender.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Palette.text,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  c.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 10,
                    color: Palette.text2,
                    letterSpacing: 0.3,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spc.sm),
          Text(
            _fmtTime(c.time),
            style: const TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 9,
              color: Palette.violet,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersTab() {
    final filtered = _filteredUsers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TapScale(
            onTap: _showCreateAccount,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spc.md,
                vertical: Spc.sm,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.cyan, Palette.violet],
                ),
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: [
                  BoxShadow(
                    color: Palette.cyan.withValues(alpha: 0.3),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'CREATE AKUN',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spc.md),
        SectionHeader(
          title: 'FILTER ROLE',
          accent: Palette.cyan,
          trailing: '${filtered.length} HASIL',
          trailingColor: Palette.cyan,
        ),
        const SizedBox(height: Spc.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              FilterChipWidget(
                label: 'semua',
                selected: _roleFilter == 'all',
                color: Palette.violet,
                count: _backendUsers.length,
                onTap: () => setState(() => _roleFilter = 'all'),
              ),
              const SizedBox(width: Spc.sm),
              FilterChipWidget(
                label: 'owner',
                selected: _roleFilter == 'owner',
                color: Palette.pink,
                count: _backendUsers.where((u) => u.isOwner).length,
                onTap: () => setState(() => _roleFilter = 'owner'),
              ),
              const SizedBox(width: Spc.sm),
              FilterChipWidget(
                label: 'admin',
                selected: _roleFilter == 'admin',
                color: Palette.violet,
                count: _backendUsers.where((u) => u.isAdmin).length,
                onTap: () => setState(() => _roleFilter = 'admin'),
              ),
              const SizedBox(width: Spc.sm),
              FilterChipWidget(
                label: 'vip',
                selected: _roleFilter == 'vip',
                color: Palette.amber,
                count: _backendUsers.where((u) => u.isVip).length,
                onTap: () => setState(() => _roleFilter = 'vip'),
              ),
              const SizedBox(width: Spc.sm),
              FilterChipWidget(
                label: 'basic',
                selected: _roleFilter == 'basic',
                color: Palette.text3,
                count: _backendUsers
                    .where((u) => !u.isOwner && !u.isAdmin && !u.isVip)
                    .length,
                onTap: () => setState(() => _roleFilter = 'basic'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spc.lg),
        SectionHeader(
          title: 'URUTKAN',
          accent: Palette.amber,
          trailingWidget: PopupMenuButton<UserSort>(
            color: Palette.surfaceAlt,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.sm),
              side: const BorderSide(color: Palette.border),
            ),
            onSelected: (s) => setState(() => _sortMode = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: UserSort.name, child: Text('NAMA')),
              PopupMenuItem(value: UserSort.role, child: Text('ROLE')),
              PopupMenuItem(value: UserSort.status, child: Text('STATUS')),
              PopupMenuItem(value: UserSort.expiry, child: Text('EXPIRED')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spc.md,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Palette.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: Palette.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sortMode.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Palette.text2,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Palette.text2,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spc.md),
        if (filtered.isEmpty)
          _emptyUsers()
        else
          ...filtered.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: Spc.sm),
                child: _userCard(u),
              )),
      ],
    );
  }

  Widget _emptyUsers() {
    return GlassPanel(
      padding: const EdgeInsets.all(Spc.xl),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.surfaceAlt,
              border: Border.all(color: Palette.border),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 26,
              color: Palette.text3,
            ),
          ),
          const SizedBox(height: Spc.md),
          const Text(
            'TIDAK ADA HASIL',
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Palette.text2,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(AppUser u) {
    final active = u.isActive;
    final color = active ? Palette.mint : Palette.coral;
    return TapScale(
      onTap: () => _showUserDetail(u),
      child: GlassPanel(
        padding: const EdgeInsets.all(Spc.md),
        child: Row(
          children: [
            AvatarCircle(user: u, size: 44, showRing: false),
            const SizedBox(width: Spc.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.username.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Palette.text,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (u.isOwner)
                        const Icon(
                          Icons.verified_rounded,
                          color: Palette.gold,
                          size: 12,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RoleChip(role: u.role, fontSize: 8),
                      const SizedBox(width: 5),
                      Text(
                        'EXP ${u.expired}',
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8.5,
                          color: Palette.text4,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    active ? 'AKTIF' : 'MATI',
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Palette.text3,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _logsTab() {
    final offline = _backend != BackendState.online;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'EVENT TIMELINE',
          accent: Palette.amber,
          trailing: offline ? 'OFFLINE' : '${_logs.length} ENTRIES',
          trailingColor: offline ? Palette.coral : Palette.amber,
        ),
        const SizedBox(height: Spc.md),
        if (offline)
          GlassPanel(
            padding: const EdgeInsets.all(Spc.xl),
            child: Column(
              children: const [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 30,
                  color: Palette.text3,
                ),
                SizedBox(height: Spc.md),
                Text(
                  'EVENT LOG BUTUH BACKEND',
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Palette.text2,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          )
        else if (_logs.isEmpty)
          GlassPanel(
            padding: const EdgeInsets.all(Spc.xl),
            child: const Text(
              'BELUM ADA AKTIVITAS',
              style: TextStyle(
                fontFamily: AppConfig.fontBug,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Palette.text3,
                letterSpacing: 1.4,
              ),
            ),
          )
        else
          ...List<Widget>.generate(_logs.length, (i) {
            final log = _logs[i];
            final isFirst = i == 0;
            final isLast = i == _logs.length - 1;
            return _logRow(log, isFirst: isFirst, isLast: isLast);
          }),
      ],
    );
  }

  Widget _logRow(LogEntry log,
      {required bool isFirst, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              if (!isFirst)
                Container(width: 2, height: 12, color: Palette.border),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: log.color.withValues(alpha: 0.16),
                  border: Border.all(
                    color: log.color.withValues(alpha: 0.5),
                    width: 1.4,
                  ),
                ),
                child: Icon(log.icon, color: log.color, size: 14),
              ),
              if (!isLast)
                Container(width: 2, height: 46, color: Palette.border),
            ],
          ),
        ),
        const SizedBox(width: Spc.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: isFirst ? 0 : 6,
              bottom: Spc.md,
            ),
            child: GlassPanel(
              padding: const EdgeInsets.all(Spc.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: log.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(Radii.xs),
                          border: Border.all(
                            color: log.color.withValues(alpha: 0.42),
                          ),
                        ),
                        child: Text(
                          log.tag,
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: log.color,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        log.stamp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8,
                          color: Palette.text4,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spc.sm),
                  Text(
                    log.title,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Palette.text,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.detail,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9.5,
                      color: Palette.text2,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SkeletonShimmer(width: double.infinity, height: 215),
        SizedBox(height: Spc.lg),
        SkeletonShimmer(width: double.infinity, height: 340),
        SizedBox(height: Spc.lg),
        SkeletonShimmer(width: double.infinity, height: 60),
        SizedBox(height: Spc.lg),
        SkeletonShimmer(width: double.infinity, height: 300),
      ],
    );
  }

  void _showUserDetail(AppUser u) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserDetailSheet(user: u),
    );
  }

  void _showNotifs() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotifSheet(items: _notifs),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(msg),
        ),
      );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'BARU';
    if (diff.inHours < 1) return '${diff.inMinutes}M';
    if (diff.inDays < 1) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${diff.inDays}H';
  }

  @override
  void dispose() {
    _poll?.cancel();
    _weatherTimer?.cancel();
    _prayerTimer?.cancel();
    _searchController.dispose();
    _entrance.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

class _ModuleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color color2;
  final VoidCallback onTap;

  const _ModuleData(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.color2,
    {required this.onTap}
  );
}

class RoomChatScreen extends StatefulWidget {
  const RoomChatScreen({super.key});

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen>
    with TickerProviderStateMixin {
  final _fb = BackendSvc();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<ChatMsg> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;
  late AnimationController _entrance;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entrance.forward();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final all = await _fb.chats();
      if (!mounted) return;
      setState(() {
        _messages = all.reversed.toList();
        _loading = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();

    final optimistic = ChatMsg(
      sender: 'KAMU',
      message: text,
      time: DateTime.now(),
    );
    setState(() => _messages.add(optimistic));
    _scrollToEnd();

    final ok = await _fb.sendChat('guest', text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _load(silent: true);
    } else {
      setState(() => _messages.remove(optimistic));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GAGAL KIRIM PESAN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: CosmicBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessages()),
                _buildInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(Spc.lg, Spc.md, Spc.lg, Spc.md),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.72),
        border: Border(
          bottom: BorderSide(color: Palette.borderSoft),
        ),
      ),
      child: Row(
        children: [
          TapScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Palette.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: Palette.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Palette.text,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: Spc.md),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Palette.amber, Palette.orange],
              ),
              borderRadius: BorderRadius.circular(Radii.sm),
              boxShadow: [
                BoxShadow(
                  color: Palette.amber.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: Spc.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROOM CHAT',
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Palette.text,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const HaloDot(color: Palette.mint, size: 3),
                    const SizedBox(width: 5),
                    Text(
                      '${_messages.length} PESAN',
                      style: const TextStyle(
                        fontFamily: AppConfig.fontBug,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Palette.text3,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TapScale(
            onTap: _load,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.violet, Palette.pink],
                ),
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: [
                  BoxShadow(
                    color: Palette.violet.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Palette.violet),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: GlassPanel(
          padding: const EdgeInsets.all(Spc.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.forum_outlined,
                size: 48,
                color: Palette.text3,
              ),
              SizedBox(height: Spc.md),
              Text(
                'BELUM ADA PESAN',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'mulai percakapan dengan kirim pesan pertama',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 9,
                  color: Palette.text4,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(Spc.lg),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        final mine = m.sender.toUpperCase() == 'KAMU';
        return _messageBubble(m, mine);
      },
    );
  }

  Widget _messageBubble(ChatMsg m, bool mine) {
    final time =
        '${m.time.hour.toString().padLeft(2, '0')}:${m.time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Spc.md),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.violet, Palette.pink],
                ),
                borderRadius: BorderRadius.circular(Radii.xs),
              ),
              child: Center(
                child: Text(
                  m.sender.isEmpty ? '?' : m.sender[0].toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spc.sm),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Spc.md,
                vertical: Spc.sm,
              ),
              decoration: BoxDecoration(
                gradient: mine
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Palette.violet, Palette.violetDeep],
                      )
                    : null,
                color: mine ? null : Palette.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(Radii.md),
                  topRight: const Radius.circular(Radii.md),
                  bottomLeft: Radius.circular(mine ? Radii.md : Radii.xs),
                  bottomRight: Radius.circular(mine ? Radii.xs : Radii.md),
                ),
                border: mine ? null : Border.all(color: Palette.border),
                boxShadow: [
                  BoxShadow(
                    color: (mine ? Palette.violet : Colors.black)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        m.sender.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Palette.violet,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  Text(
                    m.message,
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 11.5,
                      color: Palette.text,
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 8,
                      color:
                          Palette.text.withValues(alpha: mine ? 0.7 : 0.4),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mine) const SizedBox(width: Spc.sm),
        ],
      ),
    );
  }

  Widget _buildInput() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Spc.lg,
        Spc.md,
        Spc.lg,
        bottomInset > 0 ? bottomInset : Spc.md,
      ),
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Palette.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Spc.md),
              decoration: BoxDecoration(
                color: Palette.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: Palette.border),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 12,
                  color: Palette.text,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan...',
                  hintStyle: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 11.5,
                    color: Palette.text3,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spc.sm),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.amber, Palette.orange],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Palette.amber.withValues(alpha: 0.5),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoryViewer extends StatefulWidget {
  final List<SyamStory> stories;
  final int initialIndex;
  final String currentUser;
  final Future<void> Function(SyamStory story, String text) onReply;
  final Future<void> Function(SyamStory story)? onDelete;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.currentUser,
    required this.onReply,
    this.onDelete,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;
  static const Duration _storyDuration = Duration(seconds: 5);
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  bool get _isOwnStory {
    if (widget.stories.isEmpty) return false;
    return widget.stories[_currentIndex].username.toLowerCase() ==
        widget.currentUser.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex >= widget.stories.length - 1) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentIndex++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _progressController.forward(from: 0);
  }

  void _prevStory() {
    if (_currentIndex <= 0) {
      _progressController.forward(from: 0);
      return;
    }
    setState(() => _currentIndex--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _progressController.forward(from: 0);
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('format=jpg') ||
        lower.contains('format=png');
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m3u8');
  }

  bool _isLocalMedia(String url) {
    if (url.isEmpty) return false;
    if (url.startsWith('http://') || url.startsWith('https://')) return false;
    if (url.startsWith('content://')) return true;
    if (url.startsWith('/')) return true;
    if (url.length > 2 && url[1] == ':' && (url[2] == '\\' || url[2] == '/')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 8) Navigator.pop(context);
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) => _buildStory(widget.stories[i]),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _prevStory,
                      behavior: HitTestBehavior.opaque,
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: GestureDetector(
                      onTap: _nextStory,
                      behavior: HitTestBehavior.opaque,
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildProgressBar(),
                  _buildProfileRow(),
                ],
              ),
            ),
            if (!_isOwnStory)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(child: _buildReplyBar()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStory(SyamStory story) {
    final mediaUrl = story.mediaUrl?.trim() ?? '';
    final hasMedia = mediaUrl.isNotEmpty;
    final isImage =
        hasMedia && (_isImageUrl(mediaUrl) || _isLocalMedia(mediaUrl));
    final isVideo = hasMedia && _isVideoUrl(mediaUrl);
    final isTextOnly = !hasMedia || (!isImage && !isVideo);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (isImage)
          _isLocalMedia(mediaUrl)
              ? Image.file(
                  File(mediaUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _gradientBg(),
                )
              : Image.network(
                  mediaUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _gradientBg(),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _gradientBg(),
                        Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            valueColor: const AlwaysStoppedAnimation(
                              Palette.violet,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
        else if (isVideo)
          _StoryVideoPlayer(url: mediaUrl)
        else
          _gradientBg(),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.25, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 140,
              bottom: 120,
              left: 28,
              right: 28,
            ),
            child: Center(
              child: isTextOnly
                  ? _buildTextStory(story)
                  : _buildMediaCaption(story),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E1065),
            Color(0xFF7C3AED),
            Color(0xFFEC4899),
            Color(0xFFFB7185),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildTextStory(SyamStory story) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.4,
        ),
      ),
      child: Text(
        story.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppConfig.fontBug,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.4,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildMediaCaption(SyamStory story) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          story.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppConfig.fontBug,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.4,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: List.generate(widget.stories.length, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _progressSegment(i),
            ),
          );
        }),
      ),
    );
  }

  Widget _progressSegment(int index) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (_, __) {
        double value;
        if (index < _currentIndex) {
          value = 1.0;
        } else if (index > _currentIndex) {
          value = 0.0;
        } else {
          value = _progressController.value;
        }
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow() {
    final story = widget.stories[_currentIndex];
    final stamp =
        '${story.time.hour.toString().padLeft(2, '0')}:${story.time.minute.toString().padLeft(2, '0')}';
    final isOwn =
        story.username.toLowerCase() == widget.currentUser.toLowerCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Palette.pink, Palette.violet],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              child: Center(
                child: Text(
                  story.username.isEmpty
                      ? '?'
                      : story.username[0].toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        story.username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.violet.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Palette.violet.withValues(alpha: 0.7),
                          ),
                        ),
                        child: const Text(
                          'KAMU',
                          style: TextStyle(
                            fontFamily: AppConfig.fontBug,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$stamp  •  ${_currentIndex + 1}/${widget.stories.length}',
                  style: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          if (isOwn && widget.onDelete != null)
            GestureDetector(
              onTap: () async {
                await widget.onDelete!(story);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Palette.coral.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Palette.coral.withValues(alpha: 0.55),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Palette.coral,
                  size: 18,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocus,
                style: const TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 12,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: 'Balas story...',
                  hintStyle: TextStyle(
                    fontFamily: AppConfig.fontBug,
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _sendReply(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendReply,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Palette.pink, Palette.violet],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final story = widget.stories[_currentIndex];
    _replyController.clear();
    _replyFocus.unfocus();
    await widget.onReply(story, text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('Balasan terkirim ke ${story.username}'),
      ),
    );
  }
}

class _StoryVideoPlayer extends StatefulWidget {
  final String url;
  const _StoryVideoPlayer({required this.url});

  @override
  State<_StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<_StoryVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final isLocal = !widget.url.startsWith('http');
      final c = isLocal
          ? VideoPlayerController.file(File(widget.url))
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E1065),
              Color(0xFF7C3AED),
              Color(0xFFEC4899),
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Palette.violet),
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  final AppUser user;

  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final expiryColor = user.expiryColor;
    return Container(
      margin: const EdgeInsets.all(Spc.lg),
      padding: const EdgeInsets.all(Spc.xl),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: Palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Palette.violet.withValues(alpha: 0.22),
            blurRadius: 30,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Palette.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: Spc.xl),
          AvatarCircle(user: user, size: 76),
          const SizedBox(height: Spc.lg),
          Text(
            user.username.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Palette.text,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          RoleChip(role: user.role),
          const SizedBox(height: Spc.xl),
          _row('USER ID', '#${user.id}'),
          _row('STATUS', user.isActive ? 'AKTIF' : 'NONAKTIF'),
          _row('EXPIRED', user.expired, valueColor: expiryColor),
          _row('DIBUAT', user.createdAt),
          const SizedBox(height: Spc.lg),
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: user.username));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('USERNAME DISALIN'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Spc.md),
                    decoration: BoxDecoration(
                      color: Palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: Palette.border),
                    ),
                    child: const Center(
                      child: Text(
                        'SALIN',
                        style: TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Palette.text2,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spc.sm),
              Expanded(
                child: TapScale(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Spc.md),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.violet, Palette.pink],
                      ),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: const Center(
                      child: Text(
                        'TUTUP',
                        style: TextStyle(
                          fontFamily: AppConfig.fontBug,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spc.md),
      child: Row(
        children: [
          Text(
            k,
            style: const TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Palette.text3,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Text(
            v,
            style: TextStyle(
              fontFamily: AppConfig.fontBug,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: valueColor ?? Palette.text,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifSheet extends StatelessWidget {
  final List<NotifItem> items;

  const _NotifSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Spc.lg),
      padding: const EdgeInsets.all(Spc.lg),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: Palette.border, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Palette.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: Spc.lg),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Palette.violet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(
                    color: Palette.violet.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: Palette.violet,
                  size: 16,
                ),
              ),
              const SizedBox(width: Spc.md),
              const Text(
                'NOTIFIKASI',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Palette.text,
                  letterSpacing: 2.4,
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.coral.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                      color: Palette.coral.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontFamily: AppConfig.fontBug,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Palette.coral,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spc.md),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Spc.xl),
              child: Text(
                'TIDAK ADA NOTIFIKASI',
                style: TextStyle(
                  fontFamily: AppConfig.fontBug,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Palette.text3,
                  letterSpacing: 1.4,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: Spc.sm),
                itemBuilder: (_, i) {
                  final n = items[i];
                  return Container(
                    padding: const EdgeInsets.all(Spc.md),
                    decoration: BoxDecoration(
                      color: Palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: Palette.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: n.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(Radii.xs),
                            border: Border.all(
                              color: n.color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(n.icon, color: n.color, size: 16),
                        ),
                        const SizedBox(width: Spc.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.text,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppConfig.fontBug,
                                  fontSize: 9.5,
                                  color: Palette.text2,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('STACK: ${details.stack}');
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('UNCAUGHT: $error');
    debugPrint('STACK: $stack');
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const NekoApp());
}

class NekoApp extends StatefulWidget {
  const NekoApp({super.key});

  @override
  State<NekoApp> createState() => _NekoAppState();
}

class _NekoAppState extends State<NekoApp> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _overlaySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapOverlay();
      _listenOverlay();
    });
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckOverlay();
    }
  }

  Future<void> _bootstrapOverlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(AppConfig.prefOverlayEnabled) ?? true;
      if (!enabled) {
        debugPrint('BOOTSTRAP OVERLAY DISABLED BY USER');
        return;
      }
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      debugPrint('BOOTSTRAP GRANTED: $granted');

      if (granted == true) {
        await _ensureOverlayRunning();
        return;
      }

      await FlutterOverlayWindow.requestPermission();
    } catch (e, st) {
      debugPrint('OVERLAY BOOTSTRAP ERROR: $e');
      debugPrint('$st');
    }
  }

  void _listenOverlay() {
    _overlaySub?.cancel();
    _overlaySub = FlutterOverlayWindow.overlayListener.listen(
      (dynamic data) async {
        if (!mounted) return;
        Map<String, dynamic>? payload;
        if (data is Map) {
          payload = data.map((k, v) => MapEntry('$k', v));
        } else if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              payload = decoded.map((k, v) => MapEntry('$k', v));
            }
          } catch (_) {}
        }
        final type = '${payload?['type'] ?? ''}';
        final command = '${payload?['command'] ?? data ?? ''}'.trim();
        debugPrint('OVERLAY EVENT: type=$type command=$command');

        switch (command) {
          case 'chat_ai':
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
            break;
          case 'menu':
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const MenuScreen()),
            );
            break;
          case 'rat':
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const RatScreen()),
            );
            break;
          case 'dashboard':
            navigatorKey.currentState?.popUntil((r) => r.isFirst);
            break;
        }
      },
    );
  }

  Future<void> _recheckOverlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(AppConfig.prefOverlayEnabled) ?? true;
      if (!enabled) return;
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      debugPrint('RECHECK GRANTED: $granted');
      if (granted != true) return;
      final active = await FlutterOverlayWindow.isActive();
      debugPrint('RECHECK ACTIVE: $active');
      if (active == true) return;
      await _ensureOverlayRunning();
    } catch (e) {
      debugPrint('RECHECK ERROR: $e');
    }
  }

  Future<void> _ensureOverlayRunning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(AppConfig.prefOverlayEnabled) ?? true;
      if (!enabled) return;
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (granted != true) {
        await FlutterOverlayWindow.requestPermission();
        return;
      }
      final active = await FlutterOverlayWindow.isActive();
      if (active == true) return;

      await FlutterOverlayWindow.showOverlay(
        height: 64,
        width: 64,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.none,
        enableDrag: false,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Neko Assist',
        overlayContent: 'Bubble aktif',
      );

      final panelEnabled = prefs.getBool(AppConfig.prefOverlayPanel) ?? true;
      final dashboardEnabled =
          prefs.getBool(AppConfig.prefOverlayDashboard) ?? true;
      final bugEnabled = prefs.getBool(AppConfig.prefOverlayBug) ?? true;
      final chatEnabled = prefs.getBool(AppConfig.prefOverlayChat) ?? true;
      final scale =
          (prefs.getDouble('overlay_scale') ?? 1.0).clamp(0.75, 1.35);
      final username = prefs.getString('session_username') ?? 'guest';
      final role = prefs.getString('session_role') ?? 'basic';
      final expired = prefs.getString('session_expired') ?? '-';

      try {
        await FlutterOverlayWindow.shareData(jsonEncode({
          'type': 'settings',
          'overlay_enabled': true,
          'username': username,
          'role': role,
          'expired': expired,
          'panel_enabled': panelEnabled,
          'dashboard_enabled': dashboardEnabled,
          'bug_enabled': bugEnabled,
          'chat_enabled': chatEnabled,
          'scale': scale,
        }));
      } catch (_) {}

      debugPrint('SHOW OVERLAY CALLED');
    } catch (e, st) {
      debugPrint('ENSURE OVERLAY ERROR: $e');
      debugPrint('$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NekoVerse',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.build(),
      home: const SessionGate(),
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}