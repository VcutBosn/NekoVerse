import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const SyamApp());

class SyamApp extends StatelessWidget {
  const SyamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF03060D),
        fontFamily: 'SyamAstra',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      home: const DoorIntroScreen(),
    );
  }
}

class DoorIntroScreen extends StatefulWidget {
  const DoorIntroScreen({super.key});
  @override
  State<DoorIntroScreen> createState() => _DoorIntroScreenState();
}

class _DoorIntroScreenState extends State<DoorIntroScreen> {
  VideoPlayerController? _c;
  bool _ended = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = VideoPlayerController.asset('gallery/videos/door_intro.mp4');
      _c = c;
      await c.initialize();
      c.play();
      c.addListener(() {
        if (c.value.isInitialized &&
            c.value.position >= c.value.duration &&
            !_ended) {
          setState(() => _ended = true);
        }
      });
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _tap() {
    _c?.pause();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const WelcomeNoteScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 750),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: SizedBox.expand(
          child: (_ready && _c != null)
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _c!.value.size.width,
                    height: _c!.value.size.height,
                    child: VideoPlayer(_c!),
                  ),
                )
              : const ColoredBox(color: Colors.black),
        ),
      ),
    );
  }
}

class WelcomeNoteScreen extends StatefulWidget {
  const WelcomeNoteScreen({super.key});
  @override
  State<WelcomeNoteScreen> createState() => _WelcomeNoteScreenState();
}

class _WelcomeNoteScreenState extends State<WelcomeNoteScreen>
    with TickerProviderStateMixin {
  late final AnimationController _paperCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _stampCtrl;
  late final AnimationController _buttonCtrl;
  late final AnimationController _skipCtrl;

  @override
  void initState() {
    super.initState();
    _paperCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1150));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200));
    _stampCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _buttonCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _skipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _paperCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _contentCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _stampCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2750), () {
      if (mounted) _buttonCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 3100), () {
      if (mounted) _skipCtrl.forward();
    });
  }

  @override
  void dispose() {
    _paperCtrl.dispose();
    _contentCtrl.dispose();
    _stampCtrl.dispose();
    _buttonCtrl.dispose();
    _skipCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = size.width * 0.965;
    final maxH = size.height * 0.855;
    double paperW = maxW;
    double paperH = paperW * 1.42;
    if (paperH > maxH) {
      paperH = maxH;
      paperW = paperH / 1.42;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF03060D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _paperCtrl,
                  builder: (context, child) {
                    final v = CurvedAnimation(
                      parent: _paperCtrl,
                      curve: Curves.easeOutCubic,
                    ).value;
                    return Transform.translate(
                      offset: Offset(0, 200 * (1 - v)),
                      child: Opacity(
                        opacity: v,
                        child: Transform.rotate(
                          angle: -0.012 * (1 - v),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: paperW,
                    height: paperH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'gallery/images/paper.png',
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8D9B0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _contentCtrl,
                            builder: (context, child) => Opacity(
                              opacity: _contentCtrl.value,
                              child: child,
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                paperW * 0.095,
                                paperH * 0.062,
                                paperW * 0.095,
                                paperH * 0.052,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: const Color(
                                                  0xFF9C8768),
                                              width: 0.9),
                                        ),
                                        child: const Text(
                                          'CATATAN PEMBUKA',
                                          style: TextStyle(
                                            color:
                                                Color(0xFF7A6647),
                                            fontSize: 7,
                                            letterSpacing: 1.6,
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        'SYAM',
                                        style: TextStyle(
                                          color:
                                              Color(0xFFC9A961),
                                          fontSize: 9.5,
                                          letterSpacing: 3.5,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: paperH * 0.030),
                                  const Text(
                                    'APK SYAM',
                                    style: TextStyle(
                                      color: Color(0xFF0D0D0D),
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'berbeda dari project lama',
                                    style: TextStyle(
                                      color: Color(0xFF0D0D0D),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                                  ),
                                  SizedBox(height: paperH * 0.016),
                                  Container(
                                    height: 2.4,
                                    width: 46,
                                    color: const Color(0xFFC9A227),
                                  ),
                                  SizedBox(height: paperH * 0.024),
                                  const Text(
                                    'Karena Pengalaman yang dahulu mengurus vps sendiri Pembelian banyak vps yang tidak menghasilkan pencapaian maksimal Yang Ada buang duit dan member terus mengeluh.',
                                    style: TextStyle(
                                      color: Color(0xFF212121),
                                      fontSize: 10.6,
                                      height: 1.58,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: paperH * 0.020),
                                  const Text(
                                    'Dan Sekarang SYAM dibangun dengan metode khusus - biar server tetap bisa jalan di Termux, tanpa nuntut VPS yang terus nggak stabil dan ada masalah.',
                                    style: TextStyle(
                                      color: Color(0xFF212121),
                                      fontSize: 10.6,
                                      height: 1.58,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: paperH * 0.024),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: paperW * 0.032,
                                      vertical: paperH * 0.015,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFE4C8)
                                          .withOpacity(0.55),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                      border: Border.all(
                                          color: const Color(
                                              0xFFDDCBA0),
                                          width: 0.8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 13,
                                          height: 19,
                                          margin:
                                              const EdgeInsets.only(
                                                  top: 1, right: 10),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: const Color(
                                                    0xFF8B7355),
                                                width: 1.1),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    2),
                                          ),
                                        ),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                'Dulu: proxy VPS - ribet + sia sia.',
                                                style: TextStyle(
                                                  color: Color(
                                                      0xFF2A2A2A),
                                                  fontSize: 10,
                                                  height: 1.55,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Sekarang: jalan di Termux / VPS sendiri.',
                                                style: TextStyle(
                                                  color: Color(
                                                      0xFF2A2A2A),
                                                  fontSize: 10,
                                                  height: 1.55,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                'Meminimalisir Ketidakstabilan.',
                                                style: TextStyle(
                                                  color: Color(
                                                      0xFF2A2A2A),
                                                  fontSize: 10,
                                                  height: 1.55,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: paperH * 0.024),
                                  const Text(
                                    'Syam bakal terus disempurnakan - menambah fitur dan benefit biar project SYAM ini makin nyaman dipake oleh kalian.',
                                    style: TextStyle(
                                      color: Color(0xFF212121),
                                      fontSize: 10.6,
                                      height: 1.58,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: paperH * 0.026),
                                  const Text(
                                    '- SYAM',
                                    style: TextStyle(
                                      color: Color(0xFF212121),
                                      fontSize: 10.6,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  const Text(
                                    '@Otapengenkawin',
                                    style: TextStyle(
                                      color: Color(0xFF7A6647),
                                      fontSize: 8.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  AnimatedBuilder(
                                    animation: _buttonCtrl,
                                    builder: (context, child) {
                                      final v = CurvedAnimation(
                                        parent: _buttonCtrl,
                                        curve: Curves.easeOutCubic,
                                      ).value;
                                      return Transform.translate(
                                        offset: Offset(0, 24 * (1 - v)),
                                        child: Opacity(
                                            opacity: v, child: child),
                                      );
                                    },
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 41,
                                      child: ElevatedButton(
                                        onPressed: _goNext,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF141414),
                                          foregroundColor:
                                              Colors.white,
                                          elevation: 0,
                                          padding:
                                              EdgeInsets.zero,
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    3),
                                          ),
                                        ),
                                        child: const Text(
                                          'OKE, LANJUT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            letterSpacing: 3,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
                        Positioned(
                          right: paperW * 0.095,
                          bottom: paperH * 0.148,
                          child: AnimatedBuilder(
                            animation: _stampCtrl,
                            builder: (context, child) {
                              final v = CurvedAnimation(
                                parent: _stampCtrl,
                                curve: Curves.elasticOut,
                              ).value;
                              return Transform.scale(
                                scale: v,
                                child: Opacity(
                                  opacity: v.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [
                                    Color(0xFFFBE58A),
                                    Color(0xFFD9AE2E),
                                    Color(0xFF6E4F08),
                                  ],
                                  stops: [0.0, 0.6, 1.0],
                                  center: Alignment(-0.35, -0.35),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                    color: const Color(0xFF8A6A12),
                                    width: 0.6),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'S',
                                style: TextStyle(
                                  color: Color(0xFF3E2A00),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
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
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _skipCtrl,
              builder: (context, child) => Opacity(
                opacity: _skipCtrl.value * 0.75,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - _skipCtrl.value)),
                  child: child,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Lewati catatan',
                  style: TextStyle(
                    color: Color(0xFF6A7688),
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _bg;
  late AnimationController _fade;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _loadBg();
  }

  Future<void> _loadBg() async {
    try {
      final c = VideoPlayerController.asset(
          'gallery/videos/post_login_splash.mp4');
      _bg = c;
      await c.initialize();
      c.setLooping(true);
      c.setVolume(0);
      c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
    _fade.forward();
  }

  @override
  void dispose() {
    _bg?.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03060D),
      body: Stack(
        children: [
          Positioned.fill(
            child: (_ready && _bg != null)
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _bg!.value.size.width,
                      height: _bg!.value.size.height,
                      child: VideoPlayer(_bg!),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF071533),
                          Color(0xFF03060D)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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
                    const Color(0xFF03060D).withOpacity(0.30),
                    const Color(0xFF03060D).withOpacity(0.15),
                    const Color(0xFF03060D).withOpacity(0.72),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -8),
                      child: Image.asset(
                        'gallery/images/syam_logo_header.png',
                        height: 158,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(
                            height: 158,
                            child: Center(
                              child: Text('SYAM',
                                  style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 64,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4)),
                            )),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'APK SYAM  ·  FOR YOU',
                      style: TextStyle(
                        color: Color(0xFFE2ECF8),
                        fontSize: 13,
                        letterSpacing: 4.6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'APK Terbaru dengan fitur lengkap',
                      style: TextStyle(
                        color: Color(0xFF97AAC2),
                        fontSize: 10.6,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _featureCard(
                          Icons.smartphone,
                          'TERMUX',
                          'install di HP\nlangsung jalan',
                        ),
                        const SizedBox(width: 8),
                        _featureCard(
                          Icons.dns_outlined,
                          'VPS',
                          'Server 24/7\nstabil',
                        ),
                        const SizedBox(width: 8),
                        _featureCard(
                          Icons.send_outlined,
                          'UBOT',
                          'Bot per\nuser',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding:
                          const EdgeInsets.fromLTRB(13, 13, 13, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1730)
                            .withOpacity(0.48),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.anchor,
                                  color: Color(0xFFB9C7D6),
                                  size: 13),
                              SizedBox(width: 8),
                              Text(
                                'KENAPA PILIH SYAM?',
                                style: TextStyle(
                                  color: Color(0xFFE2ECF8),
                                  fontSize: 11.2,
                                  letterSpacing: 2.3,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'integrasi server cerdas dengan beberapa fitur serta benefit.\nSYAM For you and Always For You.',
                            style: TextStyle(
                              color: Color(0xFFB3C1D4),
                              fontSize: 10.4,
                              height: 1.58,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _tag('OTA'),
                              const SizedBox(width: 6),
                              _tag('AYUN'),
                              const SizedBox(width: 6),
                              _tag('SYAM'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding:
                          const EdgeInsets.fromLTRB(13, 13, 13, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1730)
                            .withOpacity(0.48),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.palette_outlined,
                                  color: Color(0xFFB9C7D6),
                                  size: 13),
                              SizedBox(width: 8),
                              Text(
                                'PILIH TEMA',
                                style: TextStyle(
                                  color: Color(0xFFE2ECF8),
                                  fontSize: 11.2,
                                  letterSpacing: 2.3,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Tampilan aplikasi - tersimpan permanen di HP',
                            style: TextStyle(
                              color: Color(0xFF8899AE),
                              fontSize: 9.9,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                      11, 10, 11, 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E64D8)
                                        .withOpacity(0.12),
                                    borderRadius:
                                        BorderRadius.circular(9),
                                    border: Border.all(
                                      color: const Color(0xFF3B82F6),
                                      width: 1.3,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFF3B82F6),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      2),
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 7,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFF3B82F6),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      3),
                                            ),
                                            child: const Text(
                                              'AKTIF',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 7,
                                                letterSpacing: 1.2,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'SYAM Original',
                                        style: TextStyle(
                                          color: Color(0xFFE2ECF8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Palet warna bebas',
                                        style: TextStyle(
                                          color: Color(0xFF97AAC2),
                                          fontSize: 9.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                      11, 10, 11, 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.025),
                                    borderRadius:
                                        BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.14),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.auto_awesome,
                                              color: Color(0xFF3B82F6),
                                              size: 13),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      3),
                                            ),
                                            child: const Text(
                                              'SOON',
                                              style: TextStyle(
                                                color:
                                                    Color(0xFF97AAC2),
                                                fontSize: 7,
                                                letterSpacing: 1.2,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'SYAM 3D Comic',
                                        style: TextStyle(
                                          color: Color(0xFFE2ECF8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Kertas & tema 3D',
                                        style: TextStyle(
                                          color: Color(0xFF8899AE),
                                          fontSize: 9.3,
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2478F0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.login, size: 15),
                            SizedBox(width: 10),
                            Text(
                              'MASUK',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 4.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _outlineButton(Icons.lock_outline, 'BELI AKSES'),
                    const SizedBox(height: 10),
                    _outlineButton(
                        Icons.headset_mic_outlined,
                        'HUBUNGI SUPPORT'),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _circleIcon(Icons.telegram),
                        const SizedBox(width: 42),
                        _circleIcon(Icons.music_note),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 70,
                          child: Text(
                            'Telegram',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF8899AE),
                                fontSize: 9.5),
                          ),
                        ),
                        SizedBox(width: 42),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'TikTok',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF8899AE),
                                fontSize: 9.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '© 2026 SYAM',
                      style: TextStyle(
                        color: Color(0xFF5E6E82),
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String sub) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1730).withOpacity(0.48),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE2ECF8), size: 20),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFE2ECF8),
                fontSize: 10,
                letterSpacing: 2.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF97AAC2),
                fontSize: 8.6,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
          width: 0.7,
        ),
      ),
      child: Text(
        t,
        style: const TextStyle(
          color: Color(0xFFB3C1D4),
          fontSize: 9,
          letterSpacing: 2.6,
        ),
      ),
    );
  }

  Widget _outlineButton(IconData icon, String label) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: Colors.white.withOpacity(0.18),
            width: 0.9,
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFB3C1D4)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.2,
                letterSpacing: 3.6,
                color: Color(0xFFE2ECF8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.16),
          width: 0.9,
        ),
      ),
      child: Icon(icon, color: const Color(0xFFE2ECF8), size: 20),
    );
  }
}