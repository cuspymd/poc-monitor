# Cursor Prompt Monitor

이 프로그램은 Cursor IDE의 프롬프트 데이터를 수집하는 Windows 서비스입니다.

## 기능

- Cursor IDE의 workspace storage 폴더를 주기적으로 검사 (5분 간격)
- 각 workspace의 SQLite DB에서 AI 프롬프트 데이터 추출
- 추출된 데이터를 CSV 파일로 저장
- 중복 데이터 제거 (SHA-256 해시 기반)

## 시스템 요구사항

- Windows 운영체제
- Go 1.21 이상 (빌드 시에만 필요)

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

## 빌드

실행 파일을 생성하려면:
```powershell
go build -o monitor.exe
```

## 설치 및 실행

1. 프로그램 실행 파일(`monitor.exe`)을 원하는 위치에 복사합니다.

2. Windows 서비스로 등록하려면 다음과 같이 실행합니다:
   ```powershell
   sc.exe create "CursorPromptMonitor" binpath= "path\to\monitor.exe"
   sc.exe start "CursorPromptMonitor"
   ```

3. 서비스를 중지하려면:
   ```powershell
   sc.exe stop "CursorPromptMonitor"
   ```

4. 서비스를 제거하려면:
   ```powershell
   sc.exe delete "CursorPromptMonitor"
   ```

## 출력 데이터

프로그램은 `output/out.csv` 파일에 다음 형식으로 데이터를 저장합니다:

- `ip`: 현재 PC의 IP 주소
- `id`: 현재 PC의 로그인 사용자 ID
- `prompt`: 추출된 프롬프트 텍스트
- `hash`: 프롬프트의 SHA-256 해시값
- `time`: 데이터 추출 시간 (UTC)

## 주의사항

- 프로그램은 Windows 서비스로 실행되므로 적절한 권한이 필요합니다.
- 출력 디렉토리(`output`)는 자동으로 생성됩니다.
- 중복된 프롬프트는 해시값을 기준으로 판단하여 저장되지 않습니다. 