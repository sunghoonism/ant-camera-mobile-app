import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'paid.dart';
import 'config/build_config.dart';

class SettingsDialog {
  // 저장 경로를 불러오는 함수
  static Future<Map<String, dynamic>> loadSavePath() async {
    print('_loadSavePath 함수 시작');
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('photoSavePath');
    final isCustom = prefs.getBool('isCustomPath') ?? false;
    final saveLocation = prefs.getBool('saveLocationInfo') ?? false;
    
    print('불러온 설정 - customPath: $customPath, isCustom: $isCustom, saveLocation: $saveLocation');
    
    String photoSavePath;
    
    if (customPath != null && isCustom) {
      print('커스텀 경로 사용: $customPath');
      photoSavePath = customPath;
    } else {
      print('기본 경로 설정 시작');
      // 기본 경로 설정 (안드로이드 DCIM/AntCamera)
      final defaultPath = await getDefaultPhotoPath();
      print('기본 경로 설정 완료: $defaultPath');
      photoSavePath = defaultPath;
    }
    
    print('_loadSavePath 함수 완료 - 최종 경로: $photoSavePath, 커스텀: $isCustom');
    
    return {
      'photoSavePath': photoSavePath,
      'isCustomPath': isCustom,
      'saveLocationInfo': saveLocation,
    };
  }

  // 기본 사진 저장 경로 가져오기
  static Future<String> getDefaultPhotoPath() async {
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
  static Future<void> saveSavePath(String path, bool isCustom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photoSavePath', path);
    await prefs.setBool('isCustomPath', isCustom);
  }

  // 설정 다이얼로그 표시
  static void showSettingsDialog(
    BuildContext context, {
    required TextEditingController pathController,
    required bool saveLocationInfo,
    required bool isSelectingFolder,
    required Function(bool) onSelectingFolderChanged,
    required Function(bool) onSaveLocationInfoChanged,
    required Function(String, bool) onPathChanged,
    required List<String> tags,
    required String? selectedTag,
    required String? photoSavePath,
    required Function(List<String>) onTagsChanged,
    required Function(String?) onSelectedTagChanged,
  }) {
    print('설정 다이얼로그 열기');
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
                          controller: pathController,
                          decoration: const InputDecoration(
                            hintText: 'Enter save path',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                          readOnly: true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: () async {
                          if (isSelectingFolder) {
                            print('폴더 선택 이미 진행 중이므로 중단');
                            return;
                          }
                          try {
                            onSelectingFolderChanged(true);
                            
                            String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                            
                            if (selectedDirectory != null) {
                              
                              // UI 텍스트 필드만 업데이트 (실제 상태는 Save 버튼에서 처리)
                              setDialogState(() {
                                pathController.text = selectedDirectory;
                              });
                              print('UI 텍스트 필드 업데이트 완료: $selectedDirectory');
                            } else {
                              print('폴더 선택이 취소되었습니다.');
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error selecting folder: $e')),
                            );
                          } finally {
                            onSelectingFolderChanged(false);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Restore Default'),
                          onPressed: () async {
                            print('=== 기본 경로 복원 버튼 클릭됨 ===');
                            final defaultPath = await getDefaultPhotoPath();
                            print('기본 경로로 복원: $defaultPath');
                            // UI 텍스트 필드만 업데이트 (실제 상태는 Save 버튼에서 처리)
                            setDialogState(() {
                              pathController.text = defaultPath;
                            });
                            print('기본 경로 복원 완료');
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          Icons.folder,
                          color: BuildConfig.isCategoryManagementEnabled 
                              ? null 
                              : Colors.grey,
                        ),
                        label: Text(
                          'Add and Manage Folder Categories',
                          style: TextStyle(
                            color: BuildConfig.isCategoryManagementEnabled 
                                ? null 
                                : Colors.grey,
                          ),
                        ),
                        onPressed: () async {
                          if (BuildConfig.isCategoryManagementEnabled) {
                            // 유료 버전: 카테고리 관리 대화상자 표시
                            CategoryManagement.showCategoryManagementDialog(
                              context,
                              tags,
                              selectedTag,
                              photoSavePath,
                              onTagsChanged,
                              onSelectedTagChanged,
                              getDefaultPhotoPath,
                            );
                          } else {
                            // 무료 버전: 유료 버전 안내 메시지 표시
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Folder category management is available in the paid version.'),
                              ),
                            );
                          }
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
                    // 설정을 다시 로드하도록 메인 화면에 알림
                    loadSavePath().then((settings) {
                      onPathChanged(settings['photoSavePath'], settings['isCustomPath']);
                      onSaveLocationInfoChanged(settings['saveLocationInfo']);
                    });
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (pathController.text.isNotEmpty) {
                      final directory = Directory(pathController.text);
                      // Create directory if it doesn't exist
                      if (!await directory.exists()) {
                        await directory.create(recursive: true);
                      }
                      
                      // 기본 경로인지 커스텀 경로인지 판단
                      final defaultPath = await getDefaultPhotoPath();
                      final bool isCustom = pathController.text != defaultPath;
                      // Update save path
                      await saveSavePath(pathController.text, isCustom);
                      // Update location info save setting
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('saveLocationInfo', saveLocationInfo);
                      
                      // 메인 화면 상태 업데이트
                      onPathChanged(pathController.text, isCustom);
                      onSaveLocationInfoChanged(saveLocationInfo);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings have been updated.'), duration: Duration(seconds: 2)),
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
}
