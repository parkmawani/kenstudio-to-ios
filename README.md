# KenStudio (개인용 사이드로드 앱)

켄스튜디오 모바일 사이트를 띄우는 iOS 웹뷰 앱입니다. 윈도우에서 Mac 없이 빌드·설치합니다.

## 1. GitHub에서 빌드

1. GitHub에서 새 저장소를 만듭니다 (Public이면 빌드 시간 무제한 무료).
2. 이 폴더의 파일을 전부 올립니다. **`.github` 폴더도 꼭 포함**해야 합니다.
   - 웹에서 올릴 땐 "Add file → Upload files"에 폴더째 드래그.
3. 저장소의 **Actions** 탭 → `Build unsigned IPA` 실행 확인 (main에 올리면 자동 실행, 수동은 "Run workflow").
4. 5분쯤 뒤 초록 체크가 뜨면, 실행 화면 아래 **Artifacts**의 `KenStudio-ipa`를 다운로드 → 압축 해제하면 `KenStudio.ipa`.

## 2. Sideloadly로 설치 (윈도우)

1. 웹사이트 버전 **iTunes**와 **iCloud**를 설치합니다 (MS Store 버전 말고 애플 홈페이지 버전 권장).
2. Sideloadly 설치 → 아이폰을 케이블로 연결 → 아이폰에서 "이 컴퓨터 신뢰".
3. `KenStudio.ipa`를 Sideloadly 창에 끌어놓고, Apple ID 입력 후 **Start**.
4. 아이폰 **설정 → 개인정보 보호 및 보안 → 개발자 모드** 켜기 (재부팅).
5. **설정 → 일반 → VPN 및 기기 관리**에서 본인 Apple ID를 신뢰.

무료 Apple ID는 7일마다 만료됩니다. Sideloadly의 자동 갱신을 켜두면 같은 와이파이에서 알아서 다시 서명해줍니다.

## 파일 구성

- `KenStudio/KenStudioApp.swift` — 앱 코드 전체 (시작 주소는 여기서 변경)
- `KenStudio/Assets.xcassets` — 앱 아이콘 (`icon-1024.png`를 1024×1024 이미지로 교체 가능)
- `project.yml` — XcodeGen 설정 (앱 이름, 번들 ID)
- `.github/workflows/build-ipa.yml` — 빌드 자동화
