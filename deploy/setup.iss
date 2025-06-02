#define MyAppName "POC Monitor"
#define MyAppVersion "1.3.0"
#define MyAppPublisher "Dev.I"
#define MyAppURL "https://your-website.com"
#define MyAppExeName "poc-monitor.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
AppId={{A1B2C3D4-E5F6-4747-8899-AABBCCDDEEFF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={userappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=poc-monitor-setup-v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
DisableFinishedPage=yes
AppMutex=POCMonitorMutex
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "poc-monitor.exe"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Dirs]
Name: "{app}\logs"
Name: "{app}\output"

[Icons]
; 백그라운드 서비스이므로 시작 메뉴 아이콘 불필요
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[InstallDelete]
Type: files; Name: "{app}\{#MyAppExeName}"

[UninstallDelete]
Type: files; Name: "{app}\{#MyAppExeName}"
Type: files; Name: "{app}\logs\*"
Type: dirifempty; Name: "{app}\logs"
Type: files; Name: "{app}\output\*"
Type: dirifempty; Name: "{app}\output"
Type: files; Name: "{app}\*"
Type: dirifempty; Name: "{app}"

[Code]
const
  PROCESS_TERMINATE = $0001;
  PROCESS_QUERY_INFORMATION = $0400;
  MAX_PATH = 260;
  TH32CS_SNAPPROCESS = $00000002;
  INVALID_HANDLE_VALUE = $FFFFFFFF;

type
  TProcessEntry32W = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: DWORD;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: Longint;
    dwFlags: DWORD;
    szExeFile: array[0..MAX_PATH - 1] of WideChar;
  end;

// Windows API 함수 선언
function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwProcessId: DWORD): THandle;
  external 'OpenProcess@kernel32.dll stdcall';

function CloseHandle(hObject: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';

function TerminateProcess(hProcess: THandle; uExitCode: DWORD): BOOL;
  external 'TerminateProcess@kernel32.dll stdcall';

function CreateToolhelp32Snapshot(dwFlags: DWORD; th32ProcessID: DWORD): THandle;
  external 'CreateToolhelp32Snapshot@kernel32.dll stdcall';

function Process32FirstW(hSnapshot: THandle; var lppe: TProcessEntry32W): BOOL;
  external 'Process32FirstW@kernel32.dll stdcall';

function Process32NextW(hSnapshot: THandle; var lppe: TProcessEntry32W): BOOL;
  external 'Process32NextW@kernel32.dll stdcall';

// WideChar 배열을 문자열로 변환하는 함수
function WideCharToString(const Buf: array of WideChar): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Buf) do
  begin
    if Buf[I] = #0 then
      Break;
    Result := Result + Char(Buf[I]);
  end;
end;

// 프로세스 이름으로 프로세스 찾기
function FindProcessByName(const ExeFileName: string; var ProcessID: DWORD): Boolean;
var
  SnapshotHandle: THandle;
  ProcessEntry32: TProcessEntry32W;
  ContinueLoop: Boolean;
  ProcessName: string;
begin
  Result := False;
  ProcessID := 0;
  
  SnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if SnapshotHandle = INVALID_HANDLE_VALUE then
    Exit;
    
  try
    ProcessEntry32.dwSize := SizeOf(ProcessEntry32);
    ContinueLoop := Process32FirstW(SnapshotHandle, ProcessEntry32);
    
    while ContinueLoop do
    begin
      ProcessName := WideCharToString(ProcessEntry32.szExeFile);
      if CompareText(ProcessName, ExeFileName) = 0 then
      begin
        ProcessID := ProcessEntry32.th32ProcessID;
        Result := True;
        Break;
      end;
      ContinueLoop := Process32NextW(SnapshotHandle, ProcessEntry32);
    end;
  finally
    CloseHandle(SnapshotHandle);
  end;
end;

// 프로세스 종료
function KillProcess(ProcessID: DWORD): Boolean;
var
  ProcessHandle: THandle;
begin
  Result := False;
  
  if ProcessID = 0 then
    Exit;
    
  ProcessHandle := OpenProcess(PROCESS_TERMINATE or PROCESS_QUERY_INFORMATION, False, ProcessID);
  if ProcessHandle = 0 then
    Exit;
    
  try
    Result := TerminateProcess(ProcessHandle, 0);
  finally
    CloseHandle(ProcessHandle);
  end;
end;

// 프로세스 종료 공통 함수
function TerminateAppProcess(const AppExeName: string; ShowDialog: Boolean): Boolean;
var
  ProcessID: DWORD;
  AttemptCount: Integer;
  MaxAttempts: Integer;
  UserResponse: Integer;
begin
  Result := True;
  MaxAttempts := 10;
  AttemptCount := 0;
  
  while FindProcessByName(AppExeName, ProcessID) and (AttemptCount < MaxAttempts) do
  begin
    Inc(AttemptCount);
    
    if KillProcess(ProcessID) then
    begin
      Sleep(1000); // 프로세스가 완전히 종료될 때까지 대기
    end
    else
    begin
      if ShowDialog then
      begin
        UserResponse := MsgBox('실행 중인 ' + ExpandConstant('{#MyAppName}') + ' 프로세스를 종료할 수 없습니다.' + #13#10 + 
                      '수동으로 프로그램을 종료한 후 다시 시도하시겠습니까?', 
                      mbConfirmation, MB_YESNO);
        if UserResponse = IDYES then
        begin
          AttemptCount := 0;
          Continue;
        end
        else
        begin
          Result := False;
          Break;
        end;
      end
      else
      begin
        // 언인스톨 시에는 대화상자 없이 강제 종료 시도
        Sleep(500);
        Break;
      end;
    end;
  end;
  
  if AttemptCount >= MaxAttempts then
  begin
    if ShowDialog then
      MsgBox('프로세스 종료에 실패했습니다. 설치를 계속 진행합니다.', mbInformation, MB_OK);
  end;
end;

// 설치 초기화 - 실행 중인 프로세스 종료
function InitializeSetup(): Boolean;
begin
  Result := TerminateAppProcess(ExpandConstant('{#MyAppExeName}'), True);
end;

// 언인스톨 초기화 - 실행 중인 프로세스 종료
function InitializeUninstall(): Boolean;
begin
  Result := True;
  // 언인스톨 시에는 사용자 대화상자 없이 강제 종료
  TerminateAppProcess(ExpandConstant('{#MyAppExeName}'), False);
end;

// 프로그램이 이미 실행 중인지 확인하는 함수
function IsAppRunning(const AppExeName: string): Boolean;
var
  ProcessID: DWORD;
begin
  Result := FindProcessByName(AppExeName, ProcessID);
end;

[Run]
Filename: "{app}\{#MyAppExeName}"; Check: "not IsAppRunning('{#MyAppExeName}')"; Flags: nowait runhidden