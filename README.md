# POC Monitor

이 프로그램은 Cursor IDE의 프롬프트 데이터를 수집하는 프로그램입니다.

## 기능

- Cursor IDE의 workspace storage 폴더를 주기적으로 검사 (5분 간격)
- 각 workspace의 SQLite DB에서 AI 프롬프트 데이터 추출
- 추출된 데이터를 CSV 파일로 저장
- 중복 데이터 제거 (SHA-256 해시 기반)

## 시스템 요구사항

- Windows 운영체제
- Go 1.21 이상 (개발 시에만 필요)
- Inno Setup (배포 시에만 필요)

## 개발 환경 설정

1. Go 설치
   - [Go 공식 웹사이트](https://golang.org/dl/)에서 Windows용 설치 파일을 다운로드하여 설치합니다.

2. 소스 코드 다운로드
   ```powershell
   git clone <repository-url>
   cd poc-monitor
   ```

3. 종속성 설치
   ```powershell
   go mod download
   ```

## 개발 및 테스트

프로그램을 직접 실행하여 테스트할 수 있습니다:
```powershell
go run main.go
```

## 빌드 및 배포

1. `deploy` 실행 파일 빌드:
   ```powershell
   go build -ldflags -H=windowsgui -o deploy/poc-monitor.exe
   ```

2. [Inno Setup](https://jrsoftware.org/isdl.php) 설치

3. Inno Setup Compiler로 설치 프로그램 생성:
   - Inno Setup Compiler 실행
   - `deploy/setup.iss` 파일 열기
   - Compile 버튼 클릭
   - `Output` 폴더에서 `poc-monitor-setup-[버전].exe` 확인 (예: `poc-monitor-setup-1.0.0.exe`)

### 설치

1. `poc-monitor-setup-[버전].exe` 실행
2. 설치 마법사의 안내에 따라 설치 진행
3. 설치가 완료되면 프로그램이 자동으로 시작되며, Windows 시작 시 자동 실행됨

### 설치 후 확인사항

1. 시작 메뉴에서 "POC Monitor" 프로그램 확인
2. 작업 관리자에서 `poc-monitor.exe` 프로세스 실행 여부 확인
3. 로그 파일 확인: `%APPDATA%\POC Monitor\logs`
4. 출력 파일 확인: `%APPDATA%\POC Monitor\output\out.csv`

### 제거

1. Windows의 프로그램 추가/제거에서 "POC Monitor" 선택하여 제거
2. 또는 시작 메뉴의 "Uninstall POC Monitor" 실행

## 출력 데이터

프로그램은 `output/out.csv` 파일에 다음 형식으로 데이터를 저장합니다:

- `ip`: 현재 PC의 IP 주소
- `id`: 현재 PC의 로그인 사용자 ID
- `prompt`: 추출된 프롬프트 텍스트
- `hash`: 프롬프트의 SHA-256 해시값
- `time`: 데이터 추출 시간 (UTC)

## 주의사항

- 프로그램은 사용자 로그인 시 자동으로 실행됩니다.
- 출력 디렉토리는 사용자의 AppData 폴더에 생성됩니다: `%APPDATA%\POC Monitor\output`
- 중복된 프롬프트는 해시값을 기준으로 판단하여 저장되지 않습니다.

## 버전 업데이트

1. 버전 번호 업데이트:
   - `deploy/setup.iss` 파일의 `MyAppVersion` 값을 수정
   ```
   #define MyAppVersion "1.0.1"  // 예시: 1.0.0 -> 1.0.1
   ```

2. 새 버전 빌드:
   ```powershell
   go build -ldflags -H=windowsgui -o deploy/poc-monitor.exe
   ```

3. 설치 프로그램 생성:
   - Inno Setup Compiler로 `deploy/setup.iss` 컴파일
   - `Output` 폴더에서 자동으로 생성된 `poc-monitor-setup-[버전].exe` 확인
   예: `poc-monitor-setup-1.0.1.exe`

4. 업데이트 배포:
   - 이전 버전이 실행 중인 경우 자동으로 종료되고 새 버전이 설치됨
   - 사용자의 설정과 데이터는 보존됨 (`%APPDATA%\POC Monitor` 폴더 유지)
   - 설치 완료 후 새 버전이 자동으로 시작됨

### 버전 관리 규칙

버전 번호는 [Semantic Versioning](https://semver.org/) 규칙을 따릅니다:
- MAJOR.MINOR.PATCH
  - MAJOR: 호환되지 않는 변경사항
  - MINOR: 호환되는 새로운 기능 추가
  - PATCH: 버그 수정

예시:
- 1.0.0: 최초 릴리스
- 1.0.1: 버그 수정
- 1.1.0: 새로운 기능 추가
- 2.0.0: 호환되지 않는 변경사항 