import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class CategoryManagement {
  // 카테고리 관리 다이얼로그 표시
  static void showCategoryManagementDialog(
    BuildContext context,
    List<String> tags,
    String? selectedTag,
    String? photoSavePath,
    Function(List<String>) onTagsChanged,
    Function(String?) onSelectedTagChanged,
    Future<String> Function() getDefaultPhotoPath,
  ) {
    // 현재 태그 목록의 복사본을 만듦
    List<String> tempTags = List.from(tags);
    // 이전 태그 이름과 변경된 태그 이름을 매핑하기 위한 맵 생성
    Map<String, String> renamedTags = {};
    String? currentSelectedTag = selectedTag;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Folder Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ReorderableListView(
                        shrinkWrap: true,
                        children: tempTags.asMap().entries.map((entry) {
                          int index = entry.key;
                          String tag = entry.value;
                          return ListTile(
                            key: Key('$index'),
                            title: GestureDetector(
                              onTap: () {
                                // 카테고리명 수정을 위한 다이얼로그 표시
                                TextEditingController editController = TextEditingController(text: tag);
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Edit Category Name'),
                                      content: TextField(
                                        controller: editController,
                                        decoration: const InputDecoration(hintText: 'Enter new name'),
                                        autofocus: true,
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Save'),
                                          onPressed: () {
                                            if (editController.text.isNotEmpty) {
                                              final String oldName = tempTags[index];
                                              final String newName = editController.text;
                                              
                                              setDialogState(() {
                                                tempTags[index] = newName;
                                                // 태그 이름이 변경되면 매핑에 추가
                                                if (oldName != newName) {
                                                  renamedTags[oldName] = newName;
                                                  
                                                  // 현재 선택된 태그가 이름이 변경된 태그인 경우 선택된 태그도 업데이트
                                                  if (currentSelectedTag == oldName) {
                                                    currentSelectedTag = newName;
                                                  }
                                                }
                                              });
                                              Navigator.pop(context);
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Text(tag),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setDialogState(() {
                                      tempTags.removeAt(index);
                                    });
                                  },
                                ),
                                const Icon(Icons.drag_handle),
                              ],
                            ),
                          );
                        }).toList(),
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = tempTags.removeAt(oldIndex);
                            tempTags.insert(newIndex, item);
                          });
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Category'),
                      onPressed: () {
                        TextEditingController newCategoryController = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Add New Category'),
                              content: TextField(
                                controller: newCategoryController,
                                decoration: const InputDecoration(hintText: 'Enter category name'),
                                autofocus: true,
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                                TextButton(
                                  child: const Text('Add'),
                                  onPressed: () {
                                    if (newCategoryController.text.isNotEmpty) {
                                      setDialogState(() {
                                        tempTags.add(newCategoryController.text);
                                      });
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    // 폴더 이름 변경 처리
                    if (renamedTags.isNotEmpty) {
                      // 로딩 다이얼로그 표시
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return const Dialog(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 20),
                                  Text('Category name change in progress...'),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                      
                      // 폴더 이름 변경 작업 수행
                      await _renameFolders(renamedTags, photoSavePath, getDefaultPhotoPath);
                      
                      // 로딩 다이얼로그 닫기
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                    
                    // 변경된 태그 목록 저장
                    onTagsChanged(tempTags);
                    await _saveTags(tempTags);
                    
                    // 선택된 태그가 변경되었으면 저장
                    if (currentSelectedTag != null) {
                      onSelectedTagChanged(currentSelectedTag);
                      await _saveSelectedTag(currentSelectedTag!);
                    }
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category updated.'), duration: Duration(seconds: 2)),
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 폴더 이름 변경 처리 함수
  static Future<void> _renameFolders(
    Map<String, String> renamedTags,
    String? photoSavePath,
    Future<String> Function() getDefaultPhotoPath,
  ) async {
    // photoSavePath가 있으면 그것을 사용, 없으면 기본 경로 사용
    final String baseSavePath = photoSavePath ?? await getDefaultPhotoPath();
    
    for (final entry in renamedTags.entries) {
      final String oldPath = '$baseSavePath/${entry.key}';
      final String newPath = '$baseSavePath/${entry.value}';
      
      final Directory oldDirectory = Directory(oldPath);
      
      try {
        if (await oldDirectory.exists()) {
          // 새 디렉토리가 이미 존재하는지 확인
          final Directory newDirectory = Directory(newPath);
          if (!await newDirectory.exists()) {
            // 새 디렉토리를 생성하고 이전 디렉토리의 내용을 복사
            await newDirectory.create(recursive: true);
            
            // 이전 디렉토리의 모든 파일을 새 디렉토리로 이동
            final List<FileSystemEntity> entities = await oldDirectory.list().toList();
            for (final entity in entities) {
              if (entity is File) {
                final String fileName = entity.path.split('/').last;
                final File newFile = File('$newPath/$fileName');
                await entity.copy(newFile.path);
                await entity.delete();
              }
            }
            
            // 이전 디렉토리 삭제
            await oldDirectory.delete(recursive: true);
            print('폴더 이름 변경 성공: $oldPath -> $newPath');
          } else {
            // 새 디렉토리가 이미 존재하는 경우
            print('새 디렉토리가 이미 존재함: $newPath');
            // 이전 디렉토리의 모든 파일을 새 디렉토리로 이동
            final List<FileSystemEntity> entities = await oldDirectory.list().toList();
            for (final entity in entities) {
              if (entity is File) {
                final String fileName = entity.path.split('/').last;
                final File newFile = File('$newPath/$fileName');
                if (!await newFile.exists()) {
                  await entity.copy(newFile.path);
                  await entity.delete();
                }
              }
            }
            
            // 이전 디렉토리 삭제
            await oldDirectory.delete(recursive: true);
          }
        } else {
          print('기존 폴더가 존재하지 않음: $oldPath');
        }
      } catch (e) {
        print('폴더 이름 변경 중 오류 발생: $e');
      }
    }
  }

  // 태그를 SharedPreferences에 저장
  static Future<void> _saveTags(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tags', tags);
  }

  // 선택된 태그 저장
  static Future<void> _saveSelectedTag(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTag', tag);
  }
}
