# TimeBuddy 0.2.1

즐거운 컴퓨터 생활, 건강한 시간 습관. / Happy computer time, healthy everyday habits.

Windows 10/11 Electron 앱. HTML/CSS, JavaScript, Node.js, JSON 번역(한국어·영어·일본어), electron-builder/NSIS로 제작했습니다. Python, Django 및 PowerShell 런타임이 필요 없습니다.

## 개발 PC 실행 / 설치 파일 제작

Node.js 24 LTS와 Git을 설치한 Windows 개발 PC에서 실행합니다.

~~~bat
npm install
npm start
npm test
npm run dist
~~~

설치 파일: dist/TimeBuddy-Setup-0.2.1-x64.exe. 설치된 PC에는 Node.js를 별도로 설치할 필요가 없습니다. ARM64는 npm run dist:arm64.

## 주요 기능

- 아이용 남은 시간·사용시간 그래프, 친근한 버디 캐릭터, 5분 전 안내.
- 요일별 여러 시간대(자정 넘김 지원), 하루 총량, 부모 승인 시간.
- 모니터별 전체화면 휴식 화면 및 부모 비밀번호, 10초 테스트.
- Telegram 시작 알림 및 등록된 개인 Chat ID의 원격 명령: /lock, /unlock [1–720], /extend 1–120, /status, /usage, /help.
- 부모 인증 후 시간표/설정 편집, 자동 시작, 업데이트 확인, NSIS 설치/제거.

## 이전 버전에서 업데이트

기존 PowerShell 앱을 부모 비밀번호로 종료하고 시작프로그램 폴더의 TimeBuddy.lnk를 제거한 뒤 Electron 설치본을 실행하세요. 동시에 실행하지 마세요.

첫 실행 때 기존 %LOCALAPPDATA%\TimeBuddy\settings.json 및 usage.json을 읽어 요일/일일 제한/비밀번호/사용기록을 새 Electron 사용자 데이터에 이전합니다. 기존 파일은 삭제하지 않습니다. 기존 Telegram 토큰은 암호화 형식이 달라 다시 입력해야 합니다. 이전 비밀번호는 최초 인증 시 scrypt로 전환합니다.

## 삭제 / 보안 / 한계

Windows 설정 > 앱 > 설치된 앱 > TimeBuddy > 제거. 먼저 부모 설정 > 프로그램 종료를 선택하는 것이 좋습니다. NSIS 기본 제거는 OS 권한에 따르며 앱 부모 비밀번호로 별도 보호하지 않습니다. 제거 시 설정과 기록을 기본 보존합니다. 완전 삭제가 필요한 부모는 종료/제거 후 %APPDATA%\TimeBuddy (또는 %APPDATA%\timebuddy) 사용자 데이터와 구 버전 %LOCALAPPDATA%\TimeBuddy를 확인하세요.

휴식 화면은 일반 데스크톱 창입니다. Windows 보안 화면, 관리자, 작업 관리자 등을 막지 않으며 표준 사용자 계정과 Windows Family Safety 병행을 권장합니다. Telegram 시작 알림은 전원 켜짐 자체가 아닌 로그인/앱 실행 기준입니다. 사용량은 앱 실행 중 허용된 시간을 기준으로 집계하고 시스템 잠금/절전은 제외합니다. Telegram 토큰은 Windows Electron safeStorage로 암호화되지만 관리자나 동일 사용자 계정에 대한 강한 보안 경계는 아닙니다. 설정 파일이나 운영체제 시각을 수정할 수 있는 계정은 우회할 수 있습니다. 전용 봇을 PC 한 대당 사용하세요.

## 릴리스

GitHub Actions의 Windows 빌드 워크플로에서 테스트 및 NSIS 빌드를 실행합니다. v0.2.1 형식의 태그로 릴리스하려면 테스트를 확인한 뒤 태그를 생성하고 워크플로 결과를 확인하세요. 업데이트는 GitHub Releases의 설치 파일과 latest.yml을 사용하며 부모가 다운로드 및 재시작을 승인합니다. 서명 인증서가 없으면 Windows SmartScreen 경고가 발생할 수 있습니다.

이 변경은 소스 단계이며 실제 Windows 다중 모니터, 설치/삭제, Telegram 및 업데이트의 통합 검증이 필요합니다.
