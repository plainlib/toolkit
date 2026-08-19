//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

unit AppInstance;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TAppInstanceMessageEvent = procedure(Sender: TObject; const AMessage: string) of object;

function AcquireSingleInstance: boolean;
function SendToExistingInstance(const AMessage: string): boolean;
procedure SetAppInstanceMessageEvent(AEvent: TAppInstanceMessageEvent);
procedure ReleaseSingleInstance;

implementation

uses
  MD5
  {$IFDEF MSWINDOWS}
  , Windows
  , Messages
  , Forms
  {$ELSE}
  , BaseUnix
  {$ENDIF}
  ;

const
  APP_INSTANCE_PREFIX = 'LazarusAppInstance_';
  {$IFDEF MSWINDOWS}
  WM_APP_INSTANCE = WM_APP + 1001;
  {$ENDIF}

var
  InstanceName: string = '';
  MessageEvent: TAppInstanceMessageEvent = nil;
{$IFDEF MSWINDOWS}
  MutexHandle: THandle = 0;
  InstanceWindow: HWND = 0;
  WindowClassName: string = '';
{$ELSE}
  LockFileHandle: Integer = -1;
  LockFileName: string = '';
{$ENDIF}

function GetInstanceName: string;
begin
  Result := APP_INSTANCE_PREFIX + MD5Print(MD5String(UpperCase(ExpandFileName(ParamStr(0)))));
end;

{$IFDEF MSWINDOWS}

function GetWindowClassName: string;
begin
  Result := InstanceName + '_Class';
end;

function InstanceWindowProc(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  CopyData: PCOPYDATASTRUCT;
  S: string;
begin
  Result := 0;
  case Msg of
    WM_APP_INSTANCE:
    begin
      if Assigned(Application.MainForm) then
      begin
        if IsIconic(Application.MainForm.Handle) then
          ShowWindow(Application.MainForm.Handle, SW_RESTORE);
        ShowWindow(Application.MainForm.Handle, SW_SHOW);
        SetForegroundWindow(Application.MainForm.Handle);
      end;
      Result := 1;
    end;
    WM_COPYDATA:
    begin
      {$HINTS OFF}
      CopyData := Pointer(LParam);
      {$HINTS ON}
      if (CopyData <> nil) and (CopyData^.lpData <> nil) and (CopyData^.cbData > 0) then
      begin
        SetString(S, PChar(CopyData^.lpData), CopyData^.cbData - 1);
        if Assigned(MessageEvent) then
          MessageEvent(nil, S);
        Result := 1;
      end;
    end;
    else
      Result := DefWindowProc(Wnd, Msg, WParam, LParam);
  end;
end;

function CreateInstanceWindow: boolean;
var
  WC: WNDCLASSEX;
begin
  WindowClassName := GetWindowClassName;
  WC := Default(WNDCLASSEX);
  WC.cbSize := SizeOf(WC);
  WC.lpfnWndProc := @InstanceWindowProc;
  WC.hInstance := HInstance;
  WC.lpszClassName := PChar(WindowClassName);
  if RegisterClassEx(WC) = 0 then
    if GetLastError <> ERROR_CLASS_ALREADY_EXISTS then
      Exit(False);
  InstanceWindow := CreateWindowEx(0, PChar(WindowClassName), PChar(InstanceName), 0, 0, 0, 0, 0, HWND(-3), 0, HInstance, nil);
  Result := InstanceWindow <> 0;
  if not Result then
    UnregisterClass(PChar(WindowClassName), HInstance);
end;

procedure DestroyInstanceWindow;
begin
  if InstanceWindow <> 0 then
  begin
    DestroyWindow(InstanceWindow);
    InstanceWindow := 0;
  end;
  if WindowClassName <> '' then
  begin
    UnregisterClass(PChar(WindowClassName), HInstance);
    WindowClassName := '';
  end;
end;

function FindExistingInstanceWindow: HWND;
begin
  Result := FindWindow(PChar(GetWindowClassName), nil);
end;

{$ENDIF}

function AcquireSingleInstance: boolean;
  {$IFDEF MSWINDOWS}
var
  MutexName: string;
  {$ENDIF}
begin
  Result := False;
  {$IFDEF MSWINDOWS}
  if MutexHandle <> 0 then
    Exit(True);
  {$ELSE}
  if LockFileHandle <> -1 then
    Exit(True);
  {$ENDIF}

  InstanceName := GetInstanceName;

  {$IFDEF MSWINDOWS}
  MutexName := 'Local\' + InstanceName;
  MutexHandle := CreateMutex(nil, True, PChar(MutexName));
  if MutexHandle = 0 then
    Exit;
  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    CloseHandle(MutexHandle);
    MutexHandle := 0;
    Exit;
  end;
  if not CreateInstanceWindow then
  begin
    CloseHandle(MutexHandle);
    MutexHandle := 0;
    Exit;
  end;
  {$ELSE}
  LockFileName := IncludeTrailingPathDelimiter(GetTempDir) + InstanceName + '.lock';
  LockFileHandle := fpOpen(PChar(LockFileName), O_RDWR or O_CREAT, &666);
  if LockFileHandle = -1 then
    Exit;
  if fpFlock(LockFileHandle, LOCK_EX or LOCK_NB) <> 0 then
  begin
    fpClose(LockFileHandle);
    LockFileHandle := -1;
    Exit;
  end;
  {$ENDIF}

  Result := True;
end;

{$IFDEF MSWINDOWS}

function SendToExistingInstance(const AMessage: string): boolean;
var
  ExistingWindow: HWND;
  Buffer: utf8string;
  CopyData: COPYDATASTRUCT;
begin
  Result := False;
  if InstanceName = '' then
    InstanceName := GetInstanceName;
  ExistingWindow := FindExistingInstanceWindow;
  if ExistingWindow = 0 then
    Exit;

  SendMessage(ExistingWindow, WM_APP_INSTANCE, 0, 0);

  Buffer := UTF8Encode(AMessage) + #0;
  CopyData := Default(COPYDATASTRUCT);
  CopyData.dwData := 1;
  CopyData.cbData := Length(Buffer);
  CopyData.lpData := PChar(Buffer);
  {$HINTS OFF}
  Result := SendMessage(ExistingWindow, WM_COPYDATA, 0, LPARAM(@CopyData)) <> 0;
  {$HINTS ON}
end;

{$ELSE}

function SendToExistingInstance(const AMessage: string): Boolean;
begin
  Result := False;
end;

{$ENDIF}

procedure SetAppInstanceMessageEvent(AEvent: TAppInstanceMessageEvent);
begin
  MessageEvent := AEvent;
end;

procedure ReleaseSingleInstance;
begin
  {$IFDEF MSWINDOWS}
  DestroyInstanceWindow;
  if MutexHandle <> 0 then
  begin
    CloseHandle(MutexHandle);
    MutexHandle := 0;
  end;
  {$ELSE}
  if LockFileHandle <> -1 then
  begin
    fpFlock(LockFileHandle, LOCK_UN);
    fpClose(LockFileHandle);
    LockFileHandle := -1;
  end;
  {$ENDIF}
end;

finalization
  ReleaseSingleInstance;

end.
