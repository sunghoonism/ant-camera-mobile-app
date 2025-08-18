class BuildConfig {
  // 빌드 타입: 'paid' 또는 'free'
  // 
  // 사용법:
  // - 유료 버전: 'paid'로 설정 → 모든 기능 사용 가능
  // - 무료 버전: 'free'로 설정 → 일부 기능 제한
  static const String buildType = 'free';

  // 유료 버전 여부 확인
  static bool get isPaidVersion => buildType == 'paid';
  
  // 무료 버전 여부 확인
  static bool get isFreeVersion => buildType == 'free';
  
  // 카테고리 관리 기능 사용 가능 여부
  static bool get isCategoryManagementEnabled => isPaidVersion;
  
  // 앱 버전 정보 표시용
  static String get versionLabel => isPaidVersion ? 'Paid Version' : 'Free Version';
} 