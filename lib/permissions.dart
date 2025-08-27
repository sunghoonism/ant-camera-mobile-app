import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  // 권한 확인 및 요청
  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    print('권한 확인 시작');
    final cameraStatus = await Permission.camera.status;
    print('카메라 권한 상태: $cameraStatus');
    final androidInfo = Platform.isAndroid ? await DeviceInfoPlugin().androidInfo : null;
    final sdkInt = androidInfo?.version.sdkInt ?? 0;
    
    bool storageGranted = false;
    
    if (Platform.isAndroid && sdkInt >= 33) {
      // Android 13 이상에서는 개별 미디어 권한 확인
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      final mediaLibraryStatus = await Permission.mediaLibrary.status;
      
      storageGranted = photosStatus.isGranted && 
                       videosStatus.isGranted && 
                       mediaLibraryStatus.isGranted;
    } else {
      // Android 13 미만이거나 다른 플랫폼
      final storageStatus = await Permission.storage.status;
      storageGranted = storageStatus.isGranted;
    }
        
    if (cameraStatus.isGranted && storageGranted) {
      return true;
    } else {
      final result = await _requestPermissions();
      
      // 권한이 거부된 경우 알림
      if (!result && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and storage permissions are required. Please allow permissions in settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      
      return result;
    }
  }

  // 필요한 권한 요청
  static Future<bool> _requestPermissions() async {
    // 안드로이드 13(API 33) 이상
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      Map<Permission, PermissionStatus> statuses;
      if (sdkInt >= 33) {
        statuses = await [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
          Permission.videos,
          Permission.mediaLibrary,  // 미디어 라이브러리 권한 추가
          Permission.location,
        ].request();
      } else {
        // 안드로이드 13 미만
        statuses = await [
          Permission.camera,
          Permission.microphone,
          Permission.storage,
          Permission.location,
        ].request();
      }
      
      // 카메라와 저장소 권한이 모두 허용되었는지 확인
      final bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final bool storageGranted = sdkInt >= 33
          ? (statuses[Permission.photos]?.isGranted ?? false) && 
            (statuses[Permission.videos]?.isGranted ?? false) && 
            (statuses[Permission.mediaLibrary]?.isGranted ?? false)
          : (statuses[Permission.storage]?.isGranted ?? false);
          
      return cameraGranted && storageGranted;
    } else if (Platform.isIOS) {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
        Permission.photos,
        Permission.location,
      ].request();
      
      return (statuses[Permission.camera]?.isGranted ?? false) && 
             (statuses[Permission.photos]?.isGranted ?? false);
    }
    
    return false;
  }

  // 권한 상태만 확인 (요청하지 않음)
  static Future<bool> checkPermissionsStatus() async {
    final cameraStatus = await Permission.camera.status;
    final androidInfo = Platform.isAndroid ? await DeviceInfoPlugin().androidInfo : null;
    final sdkInt = androidInfo?.version.sdkInt ?? 0;
    
    bool storageGranted = false;
    
    if (Platform.isAndroid && sdkInt >= 33) {
      // Android 13 이상에서는 개별 미디어 권한 확인
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      final mediaLibraryStatus = await Permission.mediaLibrary.status;
      
      storageGranted = photosStatus.isGranted && 
                       videosStatus.isGranted && 
                       mediaLibraryStatus.isGranted;
    } else {
      // Android 13 미만이거나 다른 플랫폼
      final storageStatus = await Permission.storage.status;
      storageGranted = storageStatus.isGranted;
    }
    
    return cameraStatus.isGranted && storageGranted;
  }
}
