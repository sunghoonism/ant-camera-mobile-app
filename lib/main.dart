import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ant Camera',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
        useMaterial3: true,
      ),
      home: const AntCameraScreen(),
    );
  }
}
class AntCameraScreen extends StatefulWidget {
  const AntCameraScreen({super.key});

  @override
  State<AntCameraScreen> createState() => _AntCameraScreenState();
}

class _AntCameraScreenState extends State<AntCameraScreen> {
  final List<String> defaultTags = ['my', 'home', 'company', 'school', 'etc'];
  List<String> tags = [];
  String? selectedTag = "etc";
  bool _isCustomPath = false;
  final TextEditingController _tagController = TextEditingController();
  
  // 사진 저장 위치 관련 변수
  String? _photoSavePath;
  final TextEditingController _pathController = TextEditingController();

  // 위치 정보 저장 상태
  bool _saveLocationInfo = false;
  
  // 권한 상태
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _loadSavePath();
    _loadSelectedTag();
    _checkAndRequestPermissions();
  }

  // 권한 확인 및 요청
  Future<void> _checkAndRequestPermissions() async {
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
        
    if (cameraStatus.isGranted && storageGranted) {
      setState(() {
        _permissionsGranted = true;
      });
    } else {
      final result = await _requestPermissions();
      setState(() {
        _permissionsGranted = result;
      });
      
      // 권한이 거부된 경우 알림
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and storage permissions are required. Please allow permissions in settings.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // 필요한 권한 요청
  Future<bool> _requestPermissions() async {
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

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTags = prefs.getStringList('tags');
    
    setState(() {
      tags = savedTags ?? List.from(defaultTags);
    });
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tags', tags);
  }

  // 저장 경로를 불러오는 함수
  Future<void> _loadSavePath() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('photoSavePath');
    final isCustom = prefs.getBool('isCustomPath') ?? false;
    final saveLocation = prefs.getBool('saveLocationInfo') ?? false;
    
    setState(() {
      _saveLocationInfo = saveLocation;
    });
    
    if (customPath != null && isCustom) {
      setState(() {
        _photoSavePath = customPath;
        _isCustomPath = true;
        _pathController.text = customPath;
      });
    } else {
      // 기본 경로 설정 (안드로이드 DCIM/AntCamera)
      final defaultPath = await _getDefaultPhotoPath();
      setState(() {
        _photoSavePath = defaultPath;
        _isCustomPath = false;
        _pathController.text = defaultPath;
      });
    }
  }

  // 기본 사진 저장 경로 가져오기
  Future<String> _getDefaultPhotoPath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      final basePath = dir?.path.split('Android')[0] ?? '/storage/emulated/0/';
      final path = '${basePath}DCIM/AntCamera';
      
      print('기본 저장 경로 생성: $path');
      
      // 디렉토리가 없으면 생성
      final directory = Directory(path);
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
          print('저장 디렉토리 생성 성공: $path');
        } catch (e) {
          print('저장 디렉토리 생성 실패: $e');
          
          // 대체 경로 시도 (Download 폴더)
          final downloadPath = '${basePath}Download/AntCamera';
          final downloadDir = Directory(downloadPath);
          if (!await downloadDir.exists()) {
            try {
              await downloadDir.create(recursive: true);
              print('대체 저장 디렉토리 생성 성공: $downloadPath');
              return downloadPath;
            } catch (e) {
              print('대체 저장 디렉토리 생성 실패: $e');
            }
          } else {
            print('대체 저장 디렉토리 이미 존재: $downloadPath');
            return downloadPath;
          }
        }
      } else {
        print('저장 디렉토리 이미 존재: $path');
      }
      
      return path;
    } else {
      // iOS 또는 다른 플랫폼
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/AntCamera';
      
      // 디렉토리가 없으면 생성
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      return path;
    }
  }

  // 저장 경로를 SharedPreferences에 저장
  Future<void> _saveSavePath(String path, bool isCustom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photoSavePath', path);
    await prefs.setBool('isCustomPath', isCustom);
    
    setState(() {
      _photoSavePath = path;
      _isCustomPath = isCustom;
    });
  }

  // 선택된 태그 불러오기
  Future<void> _loadSelectedTag() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTag = prefs.getString('selectedTag');
    if (savedTag != null) {
      setState(() {
        selectedTag = savedTag;
      });
    }
  }

  // 선택된 태그 저장
  Future<void> _saveSelectedTag(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTag', tag);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  void _addNewTag() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Tag'),
          content: TextField(
            controller: _tagController,
            decoration: const InputDecoration(hintText: 'Enter new tag name'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
                _tagController.clear();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  setState(() {
                    tags.add(_tagController.text);
                  });
                  _saveTags();
                  Navigator.pop(context);
                  _tagController.clear();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 설정 다이얼로그 표시
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Photo Save Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pathController,
                          decoration: const InputDecoration(
                            hintText: 'Enter save path',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Restore Default'),
                        onPressed: () async {
                          final defaultPath = await _getDefaultPhotoPath();
                          setDialogState(() {
                            _pathController.text = defaultPath;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.folder),
                        label: const Text('Add and Manage Folder Categories'),
                        onPressed: () async {
                          // Folder category management is available in the paid version. Show message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Folder category management is available in the paid version.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context);
                    _loadSavePath(); // Reload saved settings
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (_pathController.text.isNotEmpty) {
                      final directory = Directory(_pathController.text);
                      // Create directory if it doesn't exist
                      if (!await directory.exists()) {
                        await directory.create(recursive: true);
                      }
                      
                      // Update save path
                      await _saveSavePath(_pathController.text, true);
                      
                      // Update location info save setting
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('saveLocationInfo', _saveLocationInfo);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings have been updated.')),
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _permissionsGranted 
        ? Stack(
          children: [
            // 카메라 영역을 SafeArea 내부에 배치하고 화면 비율에 맞게 조정
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), // 테두리 반경 감소
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CameraAwesomeBuilder.awesome(
                      previewAlignment: Alignment.bottomCenter,
                      sensorConfig: SensorConfig.single(
                        sensor: Sensor.position(SensorPosition.back),
                        aspectRatio: CameraAspectRatios.ratio_16_9,
                        flashMode: FlashMode.none,
                        zoom: 0.0,
                      ),
                      saveConfig: SaveConfig.photo(
                        pathBuilder: (sensors) async {
                          final String baseSavePath = _photoSavePath ?? await _getDefaultPhotoPath();
                          String tagFolderPath = baseSavePath;
                          
                          // 태그에 따른 폴더 경로 생성 (선택안함도 별도 폴더로 처리)
                          if (selectedTag != null) {
                            tagFolderPath = '$baseSavePath/$selectedTag';
                            
                            // 태그 폴더가 없으면 생성
                            final tagDirPath = Directory(tagFolderPath);
                            if (!await tagDirPath.exists()) {
                              try {
                                await tagDirPath.create(recursive: true);
                                print('태그 폴더 생성 성공: $tagFolderPath');
                              } catch (e) {
                                print('태그 폴더 생성 실패: $e');
                                // 실패 시 기본 경로 사용
                                tagFolderPath = baseSavePath;
                              }
                            }
                          }
                          
                          final fileName = 'ANT_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final fullPath = '$tagFolderPath/$fileName';
                          
                          // 기본 디렉토리가 없으면 생성
                          final dirPath = Directory(baseSavePath);
                          if (!await dirPath.exists()) {
                            try {
                              await dirPath.create(recursive: true);
                              print('기본 디렉토리 생성 성공: $baseSavePath');
                            } catch (e) {
                              print('기본 디렉토리 생성 실패: $e');
                              
                              // 앱 내부 저장소 시도
                              final appDir = await getApplicationDocumentsDirectory();
                              final appPath = '${appDir.path}/AntCamera';
                              
                              // 태그 폴더 경로 생성
                              final appTagPath = selectedTag != null ? '$appPath/$selectedTag' : appPath;
                              final appDirPath = Directory(appTagPath);
                              if (!await appDirPath.exists()) {
                                await appDirPath.create(recursive: true);
                              }
                              
                              return SingleCaptureRequest('$appTagPath/$fileName', sensors.first);
                            }
                          }
                          
                          print('사진 저장 경로 설정: $fullPath, 위치 정보: $_saveLocationInfo, 태그: $selectedTag');
                          
                          // 첫 번째 센서(주요 카메라)로 사진 촬영 요청
                          return SingleCaptureRequest(fullPath, sensors.first);
                        },
                      ),
                      previewFit: CameraPreviewFit.fitWidth, // 카메라가 잘리지 않도록 contain 사용
                      // UI 테마 설정
                      theme: AwesomeTheme(
                        bottomActionsBackgroundColor: Colors.transparent,
                        buttonTheme: AwesomeButtonTheme(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          iconSize: 22, // 아이콘 크기 줄임
                          padding: const EdgeInsets.all(6), // 패딩 줄임
                          foregroundColor: Colors.white,
                        ),
                      ),
                      previewDecoratorBuilder: (state, preview) {
                        print('previewDecoratorBuilder 호출');
                        print('preview: $preview');
                        return Stack(
                          children: [
                            
                            // 상단에 커스텀 컨트롤 배치
                            Positioned(
                              top: 10,
                              left: 10,
                              right: 10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // 원하는 커스텀 컨트롤 추가
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      onMediaCaptureEvent: (mediaCapture) async {
                        try {
                          print('onMediaTap 호출: 미디어 캡처 성공');
                          mediaCapture.captureRequest.when(
                            single: (single) async {
                              if (single.file != null) {
                                print('저장된 파일 경로: ${single.file!.path}');
                                final directory = File(single.file!.path).parent.path;
                                // 파일이 실제로 존재하는지 확인
                                final savedFile = File(single.file!.path);
                                if (await savedFile.exists()) {
                                  print('파일이 존재합니다. 크기: ${await savedFile.length()} 바이트');
                                  //태그에 따른 저장 위치 메시지 생성
                                  String saveLocationMsg = 'Photo saved in [$selectedTag] folder';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(saveLocationMsg),
                                      duration: const Duration(seconds: 2),
                                      action: SnackBarAction(
                                        label: 'View Details',
                                        onPressed: () async {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Save Path: $directory'),
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                        },
                                      ),
                                    ),
                                  );
                                } else {
                                  print('⚠️ 파일이 존재하지 않습니다: ${single.file!.path}');
                                }
                              }
                            },
                            multiple: (multiple) async {
                              // 멀티 센서 카메라의 경우 각 센서별로 처리
                              multiple.fileBySensor.forEach((sensor, file) async {
                                if (file != null) {
                                  if (selectedTag != null) {
                                    print('사진 저장 완료, 태그: $selectedTag, 센서: ${sensor.position == SensorPosition.front ? "front" : "back"}');
                                  }
                                  
                                  if (mounted) {
                                    // 태그에 따른 저장 위치 메시지 생성
                                    String saveLocationMsg = 'Photo saved';
                                    
                                    if (selectedTag != null) {
                                      saveLocationMsg = 'Photo saved in [$selectedTag] folder';
                                    } else {
                                      saveLocationMsg = 'Photo saved in default folder';
                                    }
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(saveLocationMsg),
                                        duration: const Duration(seconds: 2),
                                        action: SnackBarAction(
                                          label: 'View Details',
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Save Path: ${file.path}'),
                                                duration: const Duration(seconds: 3),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                }
                              });
                            },
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving photo: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            // 하단 태그 영역
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              height: 40, // 높이 줄임
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 태그 버튼들을 담는 리스트뷰
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero, // 패딩 제거
                        children: [
                          // 모든 태그 버튼 생성
                          ...tags.map((tag) => _buildTagButton(tag)).toList(),
                        ],
                      ),
                    ),
                    // 설정 아이콘을 리스트뷰 밖으로 빼서 오른쪽에 배치
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 18), // 아이콘 크기 줄임
                        padding: const EdgeInsets.all(4), // 패딩 줄임
                        constraints: const BoxConstraints(), // 제약 조건 제거
                        onPressed: _showSettingsDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera and storage permissions are required.',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _checkAndRequestPermissions();
                },
                child: const Text('Request Permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 태그 버튼 생성 함수 - 더 작게 조정
  Widget _buildTagButton(String? tag) {
    // 태그가 현재 선택된 태그와 일치하는지 확인
    final bool isSelected = tag == selectedTag;
    final String displayText = tag ?? 'etc';

    return Container(
      margin: const EdgeInsets.only(right: 10), // 마진 줄임
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            selectedTag = tag ?? "etc"; // null을 "선택안함"으로 처리
          });
          _saveSelectedTag(selectedTag!); // 선택된 태그 저장
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.black.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 패딩 더 줄임
          minimumSize: const Size(10, 24), // 크기 더 줄임
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16, // 폰트 크기 더 줄임
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

