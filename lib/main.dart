import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';




import 'settings.dart';
import 'permissions.dart';

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
  
  // 폴더 선택 중복 실행 방지
  bool _isSelectingFolder = false;

  @override
  void initState() {
    super.initState();
    print('========== AntCamera 앱 시작 ==========');
    print('initState 호출됨');
    _loadTags();
    _loadSavePath();
    _loadSelectedTag();
    _checkAndRequestPermissions();
  }

  // 권한 확인 및 요청
  Future<void> _checkAndRequestPermissions() async {
    final result = await PermissionManager.checkAndRequestPermissions(context);
    setState(() {
      _permissionsGranted = result;
    });
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTags = prefs.getStringList('tags');
    
    setState(() {
      tags = savedTags ?? List.from(defaultTags);
    });
  }



  // 저장 경로를 불러오는 함수
  Future<void> _loadSavePath() async {
    final settings = await SettingsDialog.loadSavePath();
    setState(() {
      _photoSavePath = settings['photoSavePath'];
      _isCustomPath = settings['isCustomPath'];
      _saveLocationInfo = settings['saveLocationInfo'];
      _pathController.text = settings['photoSavePath'];
    });
  }

  // 기본 사진 저장 경로 가져오기
  Future<String> _getDefaultPhotoPath() async {
    return await SettingsDialog.getDefaultPhotoPath();
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

  // 설정 다이얼로그 표시
  void _showSettingsDialog() {
    SettingsDialog.showSettingsDialog(
      context,
      pathController: _pathController,
      saveLocationInfo: _saveLocationInfo,
      isSelectingFolder: _isSelectingFolder,
      onSelectingFolderChanged: (value) {
        setState(() {
          _isSelectingFolder = value;
        });
      },
      onSaveLocationInfoChanged: (value) {
        setState(() {
          _saveLocationInfo = value;
        });
      },
      onPathChanged: (path, isCustom) {
        setState(() {
          _photoSavePath = path;
          _isCustomPath = isCustom;
          _pathController.text = path;
        });
      },
      tags: tags,
      selectedTag: selectedTag,
      photoSavePath: _photoSavePath,
      onTagsChanged: (newTags) {
        setState(() {
          tags = newTags;
        });
      },
      onSelectedTagChanged: (newSelectedTag) {
        setState(() {
          selectedTag = newSelectedTag;
        });
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
                          // 사용자가 설정한 경로가 있으면 그것을 사용, 없으면 기본 경로 사용
                          String baseSavePath;
                          if (_isCustomPath && _photoSavePath != null) {
                            // 사용자가 직접 설정한 경로를 그대로 사용
                            baseSavePath = _photoSavePath!;
                            print('커스텀 경로 사용: $baseSavePath');
                          } else {
                            // 기본 경로 사용
                            baseSavePath = await _getDefaultPhotoPath();
                            print('기본 경로 사용: $baseSavePath');
                          }
                          
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
                          ...tags.map((tag) => _buildTagButton(tag)),
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
                        onPressed: () {
                          print('설정 버튼 클릭됨');
                          _showSettingsDialog();
                        },
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

