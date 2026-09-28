import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int latestBuild;
  final String minimumVersion;
  final int minimumBuild;
  final bool forceUpdate;
  final String releaseNotes;
  final Map<String, String> apkUrls;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumVersion,
    required this.minimumBuild,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.apkUrls,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['apkUrls'];

    final Map<String, String> urls = {};

    if (rawUrls is Map) {
      rawUrls.forEach((key, value) {
        if (value != null && value.toString().trim().isNotEmpty) {
          urls[key.toString()] = value.toString();
        }
      });
    }

    return AppUpdateInfo(
      latestVersion: json['latestVersion']?.toString() ?? '0.0.0',
      latestBuild: int.tryParse(json['latestBuild']?.toString() ?? '0') ?? 0,
      minimumVersion: json['minimumVersion']?.toString() ?? '0.0.0',
      minimumBuild: int.tryParse(json['minimumBuild']?.toString() ?? '0') ?? 0,
      forceUpdate: json['forceUpdate'] == true,
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      apkUrls: urls,
    );
  }
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String versionUrl =
      'https://hostel-management-vorh.vercel.app/api/app-version';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 15),

      responseType: ResponseType.bytes,

      followRedirects: true,
      maxRedirects: 10,

      validateStatus: (status) {
        return status != null && status >= 200 && status < 500;
      },

      headers: {
        'Accept': '*/*',
        'User-Agent': 'HostelMess-App/2.0.0',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    ),
  );

  // ============================================================
  // INSTALLED APP INFORMATION
  // ============================================================

  Future<PackageInfo> getInstalledPackageInfo() async {
    return PackageInfo.fromPlatform();
  }

  Future<String> getInstalledVersion() async {
    final packageInfo = await getInstalledPackageInfo();

    return packageInfo.version;
  }

  Future<int> getInstalledBuild() async {
    final packageInfo = await getInstalledPackageInfo();

    return int.tryParse(packageInfo.buildNumber) ?? 0;
  }

  // ============================================================
  // VERSION CHECK
  // ============================================================

  Future<AppUpdateInfo?> checkForUpdate() async {
    HttpClient? client;

    try {
      final packageInfo = await getInstalledPackageInfo();

      final installedVersion = packageInfo.version;

      final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('========================================');
      debugPrint('APP UPDATE CHECK');
      debugPrint('Installed version: $installedVersion');
      debugPrint('Installed build: $installedBuild');
      debugPrint('Base URL: $versionUrl');

      client = HttpClient();

      client.connectionTimeout = const Duration(seconds: 15);

      client.idleTimeout = const Duration(seconds: 15);

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final urls = <String>[
        '$versionUrl?v=$timestamp',
        '$versionUrl/?v=$timestamp',
      ];

      HttpClientResponse? successfulResponse;
      String successfulUrl = '';
      String responseBody = '';

      for (final url in urls) {
        try {
          debugPrint('Trying update URL: $url');

          final uri = Uri.parse(url);

          final request = await client.getUrl(uri);

          request.headers.set(HttpHeaders.acceptHeader, 'application/json');

          request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

          request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');

          request.headers.set(
            HttpHeaders.userAgentHeader,
            'HostelMess-App/2.0.0',
          );

          final response = await request.close();

          final body = await response.transform(utf8.decoder).join();

          debugPrint('Response status: ${response.statusCode}');

          debugPrint(
            'Response content-type: '
            '${response.headers.contentType}',
          );

          debugPrint('Response body: $body');

          if (response.statusCode == 200) {
            successfulResponse = response;
            successfulUrl = url;
            responseBody = body;
            break;
          }

          debugPrint(
            'Update URL failed: '
            'HTTP ${response.statusCode}',
          );
        } catch (e) {
          debugPrint('Update URL request failed: $e');
        }
      }

      if (successfulResponse == null) {
        debugPrint(
          'UPDATE CHECK FAILED: '
          'all version URLs returned an error.',
        );

        debugPrint('========================================');

        return null;
      }

      debugPrint('SUCCESSFUL UPDATE URL: $successfulUrl');

      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        debugPrint('UPDATE CHECK FAILED: Invalid JSON.');

        return null;
      }

      if (decoded['success'] != true) {
        debugPrint('UPDATE CHECK FAILED: success != true');

        return null;
      }

      final updateInfo = AppUpdateInfo.fromJson(decoded);

      debugPrint(
        'Latest version: '
        '${updateInfo.latestVersion}',
      );

      debugPrint(
        'Latest build: '
        '${updateInfo.latestBuild}',
      );

      debugPrint(
        'Minimum version: '
        '${updateInfo.minimumVersion}',
      );

      debugPrint(
        'Minimum build: '
        '${updateInfo.minimumBuild}',
      );

      debugPrint(
        'Force update: '
        '${updateInfo.forceUpdate}',
      );

      debugPrint(
        'APK URLs: '
        '${updateInfo.apkUrls}',
      );

      final bool updateRequired = installedBuild < updateInfo.minimumBuild;

      final bool updateAvailable = installedBuild < updateInfo.latestBuild;

      debugPrint('Update required: $updateRequired');

      debugPrint('Update available: $updateAvailable');

      if (!updateRequired && !updateAvailable) {
        debugPrint('APP IS UP TO DATE');

        debugPrint('========================================');

        return null;
      }

      debugPrint('UPDATE AVAILABLE / REQUIRED');

      debugPrint('========================================');

      return updateInfo;
    } catch (e, stackTrace) {
      debugPrint('========================================');

      debugPrint('APP UPDATE CHECK ERROR');

      debugPrint('$e');

      debugPrint('$stackTrace');

      debugPrint('========================================');

      return null;
    } finally {
      client?.close(force: true);
    }
  }

  // ============================================================
  // DEVICE ABI
  // ============================================================

  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) {
      return [];
    }

    final deviceInfo = DeviceInfoPlugin();

    final androidInfo = await deviceInfo.androidInfo;

    debugPrint('========================================');
    debugPrint('ANDROID DEVICE INFORMATION');

    debugPrint('Model: ${androidInfo.model}');

    debugPrint('Manufacturer: ${androidInfo.manufacturer}');

    debugPrint(
      'Android version: '
      '${androidInfo.version.release}',
    );

    debugPrint('SDK: ${androidInfo.version.sdkInt}');

    debugPrint(
      'Supported ABIs: '
      '${androidInfo.supportedAbis}',
    );

    debugPrint('========================================');

    return androidInfo.supportedAbis;
  }

  // ============================================================
  // APK ABI SELECTION
  // ============================================================

  String getApkUrlForAbi(AppUpdateInfo updateInfo, List<String> supportedAbis) {
    debugPrint('========================================');
    debugPrint('APK ABI SELECTION');

    debugPrint('Device ABIs: $supportedAbis');

    debugPrint(
      'Available APKs: '
      '${updateInfo.apkUrls.keys.toList()}',
    );

    // ----------------------------------------------------------
    // ARM64
    // ----------------------------------------------------------

    if (supportedAbis.contains('arm64-v8a')) {
      final url = updateInfo.apkUrls['arm64-v8a'] ?? '';

      if (url.trim().isNotEmpty) {
        debugPrint('SELECTED APK: arm64-v8a');

        debugPrint('APK URL: $url');

        debugPrint('========================================');

        return url;
      }
    }

    // ----------------------------------------------------------
    // ARM32
    // ----------------------------------------------------------

    if (supportedAbis.contains('armeabi-v7a')) {
      final url = updateInfo.apkUrls['armeabi-v7a'] ?? '';

      if (url.trim().isNotEmpty) {
        debugPrint('SELECTED APK: armeabi-v7a');

        debugPrint('APK URL: $url');

        debugPrint('========================================');

        return url;
      }
    }

    // ----------------------------------------------------------
    // x86_64
    // ----------------------------------------------------------

    if (supportedAbis.contains('x86_64')) {
      final url = updateInfo.apkUrls['x86_64'] ?? '';

      if (url.trim().isNotEmpty) {
        debugPrint('SELECTED APK: x86_64');

        debugPrint('APK URL: $url');

        debugPrint('========================================');

        return url;
      }
    }

    debugPrint('NO COMPATIBLE APK FOUND');

    debugPrint('========================================');

    return '';
  }

  // ============================================================
  // APK DOWNLOAD
  // ============================================================

  Future<File> downloadApk({
    required String apkUrl,
    required void Function(double progress) onProgress,
  }) async {
    if (apkUrl.trim().isEmpty) {
      throw Exception('APK download URL is empty.');
    }

    debugPrint('========================================');
    debugPrint('APK DOWNLOAD START');

    debugPrint('URL: $apkUrl');

    final directory = await getTemporaryDirectory();

    final apkFile = File('${directory.path}/hostelmess_update.apk');

    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    try {
      final response = await _dio.download(
        apkUrl,
        apkFile.path,

        deleteOnError: true,

        onReceiveProgress: (received, total) {
          if (total <= 0) {
            onProgress(0);
            return;
          }

          final progress = received / total;

          debugPrint(
            'Download: '
            '${(progress * 100).toStringAsFixed(1)}%',
          );

          onProgress(progress.clamp(0.0, 1.0));
        },
      );

      debugPrint(
        'Download status: '
        '${response.statusCode}',
      );

      debugPrint(
        'Download headers: '
        '${response.headers}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'APK server returned HTTP '
          '${response.statusCode}.',
        );
      }

      if (!await apkFile.exists()) {
        throw Exception('APK download failed.');
      }

      final fileSize = await apkFile.length();

      debugPrint(
        'Downloaded file: '
        '${apkFile.path}',
      );

      debugPrint(
        'Downloaded size: '
        '$fileSize bytes',
      );

      if (fileSize <= 0) {
        throw Exception('Downloaded APK is empty.');
      }

      // --------------------------------------------------------
      // Verify APK ZIP signature
      // --------------------------------------------------------

      final bytes = await apkFile.openRead(0, 4).fold<List<int>>(<int>[], (
        previous,
        element,
      ) {
        final result = <int>[...previous, ...element];

        if (result.length > 4) {
          return result.sublist(0, 4);
        }

        return result;
      });

      final bool isZipBasedApk =
          bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

      debugPrint('First bytes: $bytes');

      debugPrint(
        'APK ZIP signature valid: '
        '$isZipBasedApk',
      );

      debugPrint('========================================');

      if (!isZipBasedApk) {
        // Read a small portion to identify
        // what the server actually returned.
        String preview = '';

        try {
          final previewBytes = await apkFile
              .openRead(0, fileSize > 300 ? 300 : fileSize)
              .fold<List<int>>(<int>[], (previous, element) {
                return [...previous, ...element];
              });

          preview = utf8.decode(previewBytes, allowMalformed: true);
        } catch (_) {}

        debugPrint('INVALID APK RESPONSE PREVIEW:');

        debugPrint(preview);

        throw Exception(
          'Downloaded file is not a valid APK. '
          'The hosting server may be returning '
          'a webpage, login page, redirect page, '
          'or authorization error.',
        );
      }

      return apkFile;
    } on DioException catch (e) {
      debugPrint('APK DOWNLOAD DIO ERROR');

      debugPrint('Type: ${e.type}');

      debugPrint('Message: ${e.message}');

      debugPrint('Status: ${e.response?.statusCode}');

      debugPrint('Headers: ${e.response?.headers}');

      throw Exception(
        'APK download failed: '
        '${e.message ?? 'Unknown network error'}',
      );
    }
  }

  // ============================================================
  // APK INSTALLATION
  // ============================================================

  Future<bool> installApk(File apkFile) async {
    if (!await apkFile.exists()) {
      return false;
    }

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    debugPrint(
      'APK installer result: '
      '${result.type}',
    );

    debugPrint(
      'APK installer message: '
      '${result.message}',
    );

    return result.type == ResultType.done;
  }

  // ============================================================
  // COMPLETE UPDATE FLOW
  // ============================================================

  Future<File> downloadUpdate({
    required AppUpdateInfo updateInfo,
    required void Function(double progress) onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception(
        'Automatic APK updates are supported '
        'on Android only.',
      );
    }

    final supportedAbis = await getSupportedAbis();

    if (supportedAbis.isEmpty) {
      throw Exception('Unable to determine this device architecture.');
    }

    final apkUrl = getApkUrlForAbi(updateInfo, supportedAbis);

    if (apkUrl.isEmpty) {
      throw Exception(
        'No compatible APK is available '
        'for this device.',
      );
    }

    return downloadApk(apkUrl: apkUrl, onProgress: onProgress);
  }

  // ============================================================
  // DOWNLOAD + INSTALL
  // ============================================================

  Future<bool> downloadAndInstallUpdate({
    required AppUpdateInfo updateInfo,
    required void Function(double progress) onProgress,
  }) async {
    final apkFile = await downloadUpdate(
      updateInfo: updateInfo,
      onProgress: onProgress,
    );

    return installApk(apkFile);
  }
}
