//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

unit GlobalMouseHook;

{$NOTES OFF}
{$HINTS OFF}
{$WARNINGS OFF}

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  Controls,
  Classes
  {$IFDEF WINDOWS}
  , Windows
  , Messages
  {$ENDIF}
  ;

type
  // Classification of window classes used for mouse events
  TMouseWindowClass = (
    wckUnknown,              // unknown or unclassified window class
    wckComboLBox,            // 'ComboLBox' - popup list of a ComboBox
    wckScrollBar,            // 'ScrollBar' - standard scrollbar
    wckUpDown,               // 'msctls_updown32' - up-down (spin) control
    wckTrackbar,             // 'msctls_trackbar32' - trackbar / slider
    wckHeader,               // 'SysHeader32' - column header in list view
    wckToolbar,              // 'ToolbarWindow32' - standard toolbar
    wckTabControl,           // 'SysTabControl32' - tab control (tabs)
    wckSystemMenu,           // '#32768' - system menu (popup) / window menu
    wckTooltip,              // 'tooltips_class32' - tooltip window
    wckStatic,               // 'Static' - static text / label
    wckListView,             // 'SysListView32' - classic file list in Explorer
    wckDirectUIHWND,         // 'DirectUIHWND' - modern Explorer file view (Vista+)
    wckCtrlNotifySink,       // 'CtrlNotifySink' - sometimes used in Explorer details pane
    wckShellDocObjectView,   // 'Shell DocObject View' - embedded Explorer views
    wckConsoleWindow,        // 'ConsoleWindowClass' - classic console (cmd, old PowerShell)
    wckTerminal,             // 'CASCADIA_HOSTING_WINDOW_CLASS' - Windows Terminal
    wckEdit,                 // 'Edit' - standard edit control
    wckRichEdit20A,          // 'RichEdit20A' - RichEdit version 2.0 (ANSI)
    wckRichEdit20W,          // 'RichEdit20W' - RichEdit version 2.0 (Unicode), used by Outlook and others
    wckRichEdit50W,          // 'RichEdit50W' - RichEdit version 5.0 (Unicode)
    wckMemo,                 // 'TMemo' - VCL/LCL memo control
    wckTEdit,                // 'TEdit' - VCL/LCL single-line edit
    wckScintilla,            // 'Scintilla' - Scintilla editing component (Notepad++, etc.)
    wckBrowser,              // 'Chrome_RenderWidgetHostHWND' - Chromium-based browsers (Chrome, Edge)
    wckMozillaContent,       // 'MozillaContentWindowClass' - Firefox content area
    wckIEServer,             // 'Internet Explorer_Server' - IE / Trident engine
    wckOpera,                // 'OperaWindowClass' - older Opera
    wckUWPCoreWindow,        // 'Windows.UI.Core.CoreWindow' - UWP / WinRT text controls
    wckMfcView,              // 'Afx:FrameOrView:100' - MFC-based applications
    wckOutlookMain,          // '_WwG' - main Outlook window (contains editor)
    wckQWidget,              // 'QWidget' - VirtualBox (older) / Qt main window
    wckVMwareUnityHostWnd    // 'VMwareUnityHostWnd' - VMware Workstation/Player
    );

type
  PMouseEventInfo = ^TMouseEventInfo;

  TMouseEventInfo = record
    Button: TMouseButton;
    X, Y: integer;
    Time: longword;
    CtrlDown: boolean;
    ShiftDown: boolean;
    AltDown: boolean;
    WindowClass: TMouseWindowClass;
    WindowClassName: string[255];
  end;

  TMouseEvent = procedure(Sender: TObject; const Info: TMouseEventInfo) of object;

  {$IFDEF WINDOWS}
type
  PMouseLLHookStruct = ^TMouseLLHookStruct;
  TMouseLLHookStruct = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  {$ENDIF}

  TGlobalMouseHook = class
  private
    FEnabled: boolean;
    FEditFieldOnly: boolean;
    FOnLeftDown, FOnLeftUp: TMouseEvent;
    FOnRightDown, FOnRightUp: TMouseEvent;
    FOnMiddleDown, FOnMiddleUp: TMouseEvent;
    FLeftDownAccepted: boolean;
    FIgnoredWindows: TList;
    procedure SetEnabled(AValue: boolean);
    {$IFDEF WINDOWS}
    class var FActiveInstance: TGlobalMouseHook;
    FHook: HHOOK;
    class function HookProc(nCode: Integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; static;
    function ClassifyWindowClass(const AClassName: string): TMouseWindowClass;
    procedure InternalMouseEvent(wParam: WPARAM; const p: TMouseLLHookStruct);
    function IsInputWindow(Wnd: THandle): Boolean;
    {$ENDIF}
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddIgnoredWindow(AHandle: THandle);
    procedure RemoveIgnoredWindow(AHandle: THandle);
    class function GetActiveInstance: TGlobalMouseHook; static;
    property Enabled: boolean read FEnabled write SetEnabled;
    property EditFieldOnly: boolean read FEditFieldOnly write FEditFieldOnly;
    property OnLeftDown: TMouseEvent read FOnLeftDown write FOnLeftDown;
    property OnLeftUp: TMouseEvent read FOnLeftUp write FOnLeftUp;
    property OnRightDown: TMouseEvent read FOnRightDown write FOnRightDown;
    property OnRightUp: TMouseEvent read FOnRightUp write FOnRightUp;
    property OnMiddleDown: TMouseEvent read FOnMiddleDown write FOnMiddleDown;
    property OnMiddleUp: TMouseEvent read FOnMiddleUp write FOnMiddleUp;
    class function IsCtrlPressed: boolean;
    class function IsShiftPressed: boolean;
    class function IsAltPressed: boolean;
  end;

  {$IFDEF WINDOWS}
const
  WH_MOUSE_LL = 14;
  {$ENDIF}

implementation

{$IFDEF WINDOWS}

const
  // Window classes that are always ignored (blacklist)
  IgnoredWindowClasses: set of TMouseWindowClass = [
    wckComboLBox, wckScrollBar, wckUpDown, wckTrackbar,
    wckHeader, wckToolbar, wckTabControl, wckSystemMenu,
    wckTooltip, wckStatic, wckListView, wckDirectUIHWND,
    wckCtrlNotifySink, wckShellDocObjectView,
    wckConsoleWindow, wckTerminal
  ];

  // Window classes treated as text editing fields (whitelist)
  TextEditWindowClasses: set of TMouseWindowClass = [
    wckEdit, wckRichEdit20A, wckRichEdit20W, wckRichEdit50W,
    wckMemo, wckTEdit, wckScintilla, wckBrowser,
    wckMozillaContent, wckIEServer, wckOpera,
    wckUWPCoreWindow, wckMfcView,
    wckOutlookMain   // added to allow Outlook main window
  ];

  // Window classes of known virtual machine windows
  VMWindowClasses: set of TMouseWindowClass = [
    wckQWidget, wckVMwareUnityHostWnd
  ];

  // Process names of known virtual machines and emulators
  VMProcessNames: array[0..2] of string = (
    'virtualboxvm.exe',
    'vboxheadless.exe',
    'vmware-vmx.exe'
  );

  // Process names for console applications - mouse events are ignored there
  ConsoleProcessNames: array[0..4] of string = (
    'conhost.exe',
    'cmd.exe',
    'powershell.exe',
    'pwsh.exe',
    'windowsterminal.exe'
  );

class function TGlobalMouseHook.HookProc(nCode: integer; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  p: PMouseLLHookStruct;
  Instance: TGlobalMouseHook;   // Local copy of active instance
  Hook: HHOOK;                  // Local copy of hook handle
begin
  // Cache class-level values once per call
  Instance := FActiveInstance;
  if Instance = nil then
  begin
    // No active hook instance, just pass through
    Result := CallNextHookEx(0, nCode, wParam, lParam);
    Exit;
  end;

  // Cache the hook handle from the instance
  Hook := Instance.FHook;

  if nCode >= 0 then
  begin
    // Forward only button-down/up messages to our handler; ignore everything else
    case wParam of
      WM_LBUTTONDOWN, WM_LBUTTONUP,
      WM_RBUTTONDOWN, WM_RBUTTONUP,
      WM_MBUTTONDOWN, WM_MBUTTONUP:
      begin
        p := PMouseLLHookStruct(Pointer(PtrUInt(lParam)));
        Instance.InternalMouseEvent(wParam, p^);
      end;
      // all other messages (move, wheel, etc.) are passed through without any processing
    end;
  end;

  // Always call the next hook in the chain
  Result := CallNextHookEx(Hook, nCode, wParam, lParam);
end;

function TGlobalMouseHook.ClassifyWindowClass(const AClassName: string): TMouseWindowClass;
begin
  Result := wckUnknown;
  if AClassName = '' then Exit;

  if StrIComp(PChar(AClassName), 'ComboLBox') = 0 then
    Result := wckComboLBox
  else if StrIComp(PChar(AClassName), 'ScrollBar') = 0 then
    Result := wckScrollBar
  else if StrIComp(PChar(AClassName), 'msctls_updown32') = 0 then
    Result := wckUpDown
  else if StrIComp(PChar(AClassName), 'msctls_trackbar32') = 0 then
    Result := wckTrackbar
  else if StrIComp(PChar(AClassName), 'SysHeader32') = 0 then
    Result := wckHeader
  else if StrIComp(PChar(AClassName), 'ToolbarWindow32') = 0 then
    Result := wckToolbar
  else if StrIComp(PChar(AClassName), 'SysTabControl32') = 0 then
    Result := wckTabControl
  else if StrIComp(PChar(AClassName), '#32768') = 0 then
    Result := wckSystemMenu
  else if StrIComp(PChar(AClassName), 'tooltips_class32') = 0 then
    Result := wckTooltip
  else if StrIComp(PChar(AClassName), 'Static') = 0 then
    Result := wckStatic
  else if StrIComp(PChar(AClassName), 'SysListView32') = 0 then
    Result := wckListView
  else if StrIComp(PChar(AClassName), 'DirectUIHWND') = 0 then
    Result := wckDirectUIHWND
  else if StrIComp(PChar(AClassName), 'CtrlNotifySink') = 0 then
    Result := wckCtrlNotifySink
  else if StrIComp(PChar(AClassName), 'Shell DocObject View') = 0 then
    Result := wckShellDocObjectView
  else if StrIComp(PChar(AClassName), 'ConsoleWindowClass') = 0 then
    Result := wckConsoleWindow
  else if StrIComp(PChar(AClassName), 'CASCADIA_HOSTING_WINDOW_CLASS') = 0 then
    Result := wckTerminal
  else if StrIComp(PChar(AClassName), 'Edit') = 0 then
    Result := wckEdit
  else if StrIComp(PChar(AClassName), 'RichEdit20A') = 0 then
    Result := wckRichEdit20A
  else if StrIComp(PChar(AClassName), 'RichEdit20W') = 0 then
    Result := wckRichEdit20W
  else if StrIComp(PChar(AClassName), 'RichEdit50W') = 0 then
    Result := wckRichEdit50W
  else if StrIComp(PChar(AClassName), 'TMemo') = 0 then
    Result := wckMemo
  else if StrIComp(PChar(AClassName), 'TEdit') = 0 then
    Result := wckTEdit
  else if StrIComp(PChar(AClassName), 'Scintilla') = 0 then
    Result := wckScintilla
  else if StrIComp(PChar(AClassName), 'Chrome_RenderWidgetHostHWND') = 0 then
    Result := wckBrowser
  else if StrIComp(PChar(AClassName), 'MozillaContentWindowClass') = 0 then
    Result := wckMozillaContent
  else if StrIComp(PChar(AClassName), 'Internet Explorer_Server') = 0 then
    Result := wckIEServer
  else if StrIComp(PChar(AClassName), 'OperaWindowClass') = 0 then
    Result := wckOpera
  else if StrIComp(PChar(AClassName), 'Windows.UI.Core.CoreWindow') = 0 then
    Result := wckUWPCoreWindow
  else if StrIComp(PChar(AClassName), 'Afx:FrameOrView:100') = 0 then
    Result := wckMfcView
  else if StrIComp(PChar(AClassName), '_WwG') = 0 then
    Result := wckOutlookMain
  else if StrIComp(PChar(AClassName), 'QWidget') = 0 then
    Result := wckQWidget
  else if StrIComp(PChar(AClassName), 'VMwareUnityHostWnd') = 0 then
    Result := wckVMwareUnityHostWnd;
end;

function TGlobalMouseHook.IsInputWindow(Wnd: THandle): Boolean;
type
  TQueryFullProcessImageNameW = function(hProcess: THandle; dwFlags: DWORD; lpExeName: PWideChar; lpdwSize: LPDWORD): BOOL; stdcall;
var
  szClass: array[0..255] of char;
  cls: TMouseWindowClass;
  i: integer;
  pid: DWORD;
  hProc: THandle;
  fileName: array[0..MAX_PATH] of widechar;
  len: DWORD;
  s: widestring;
  j: integer;
  dwStart, dwEnd: DWORD;
  QueryFull: TQueryFullProcessImageNameW;
  hKernel32: THandle;
  isVM: boolean;

  function WindowBelongsToVM(Wnd: THandle): boolean;
  var
    pidLocal: DWORD;
    hP: THandle;
    fname: array[0..MAX_PATH] of widechar;
    fLen: DWORD;
    nameStr: widestring;
    k: integer;
    ext: string;
  begin
    Result := False;
    if not Assigned(QueryFull) then Exit;
    GetWindowThreadProcessId(HWND(Wnd), @pidLocal);
    hP := OpenProcess(PROCESS_QUERY_INFORMATION, False, pidLocal);
    if hP = 0 then Exit;
    try
      fLen := MAX_PATH;
      if QueryFull(hP, 0, @fname[0], @fLen) then
      begin
        SetString(nameStr, PWideChar(@fname[0]), fLen);
        k := LastDelimiter('\', string(nameStr));
        if k > 0 then
          ext := LowerCase(Copy(string(nameStr), k + 1, MaxInt))
        else
          ext := LowerCase(string(nameStr));
        for k := Low(VMProcessNames) to High(VMProcessNames) do
          if ext = VMProcessNames[k] then
            Exit(True);
      end;
    finally
      CloseHandle(hP);
    end;
  end;

  function IsConsoleProcess(Wnd: THandle): boolean;
  var
    pidLocal: DWORD;
    hP: THandle;
    fname: array[0..MAX_PATH] of widechar;
    fLen: DWORD;
    nameStr: widestring;
    k: integer;
    ext: string;
    QueryFull: TQueryFullProcessImageNameW;
    hKernel32: THandle;
  begin
    Result := False;
    hKernel32 := GetModuleHandle('kernel32.dll');
    if hKernel32 <> 0 then
      Pointer(QueryFull) := GetProcAddress(hKernel32, 'QueryFullProcessImageNameW')
    else
      Pointer(QueryFull) := nil;
    if not Assigned(QueryFull) then Exit;

    GetWindowThreadProcessId(HWND(Wnd), @pidLocal);
    hP := OpenProcess(PROCESS_QUERY_INFORMATION, False, pidLocal);
    if hP = 0 then Exit;
    try
      fLen := MAX_PATH;
      if QueryFull(hP, 0, @fname[0], @fLen) then
      begin
        SetString(nameStr, PWideChar(@fname[0]), fLen);
        k := LastDelimiter('\', string(nameStr));
        if k > 0 then
          ext := LowerCase(Copy(string(nameStr), k + 1, MaxInt))
        else
          ext := LowerCase(string(nameStr));
        for k := Low(ConsoleProcessNames) to High(ConsoleProcessNames) do
          if ext = ConsoleProcessNames[k] then
            Exit(True);
      end;
    finally
      CloseHandle(hP);
    end;
  end;

begin
  Result := False;
  if Wnd = 0 then Exit;

  hKernel32 := GetModuleHandle('kernel32.dll');
  if hKernel32 <> 0 then
    Pointer(QueryFull) := GetProcAddress(hKernel32, 'QueryFullProcessImageNameW')
  else
    Pointer(QueryFull) := nil;

  if GetClassName(HWND(Wnd), szClass, Length(szClass)) > 0 then
  begin
    cls := ClassifyWindowClass(szClass);

    // Immediate rejection for known VM window classes
    if cls in VMWindowClasses then
      Exit(False);

    // Reject blacklisted window classes
    if cls in IgnoredWindowClasses then
      Exit(False);

    // If not EditFieldOnly mode, allow all windows except processes blacklist
    if not FEditFieldOnly then
    begin
      // Reject explorer.exe
      if Assigned(QueryFull) then
      begin
        GetWindowThreadProcessId(HWND(Wnd), @pid);
        hProc := OpenProcess(PROCESS_QUERY_INFORMATION, False, pid);
        if hProc <> 0 then
        begin
          len := MAX_PATH;
          if QueryFull(hProc, 0, @fileName[0], @len) then
          begin
            SetString(s, PWideChar(@fileName[0]), len);
            j := LastDelimiter('\', string(s));
            if (j > 0) and (StrIComp(PWideChar(@s[j + 1]), 'explorer.exe') = 0) then
            begin
              CloseHandle(hProc);
              Exit(False);
            end;
          end;
          CloseHandle(hProc);
        end;
      end;

      // Reject VM processes
      if Assigned(QueryFull) and WindowBelongsToVM(Wnd) then
        Exit(False);

      // Reject console processes
      if Assigned(QueryFull) and IsConsoleProcess(Wnd) then
        Exit(False);

      // All remaining windows are allowed
      Exit(True);
    end;

    // EditFieldOnly mode: first check if class is in the text editing whitelist
    if cls in TextEditWindowClasses then
      Exit(True);

    // Unknown class - try EM_GETSEL after process checks
    if Assigned(QueryFull) then
    begin
      // Reject explorer.exe
      GetWindowThreadProcessId(HWND(Wnd), @pid);
      hProc := OpenProcess(PROCESS_QUERY_INFORMATION, False, pid);
      if hProc <> 0 then
      begin
        len := MAX_PATH;
        if QueryFull(hProc, 0, @fileName[0], @len) then
        begin
          SetString(s, PWideChar(@fileName[0]), len);
          j := LastDelimiter('\', string(s));
          if (j > 0) and (StrIComp(PWideChar(@s[j + 1]), 'explorer.exe') = 0) then
          begin
            CloseHandle(hProc);
            Exit(False);
          end;
        end;
        CloseHandle(hProc);
      end;

      if WindowBelongsToVM(Wnd) or IsConsoleProcess(Wnd) then
        Exit(False);

      if SendMessageTimeout(HWND(Wnd), EM_GETSEL, WPARAM(@dwStart), LPARAM(@dwEnd), SMTO_ABORTIFHUNG,
        20, nil) <> 0 then
        Exit(True);
    end;

    Exit(False);
  end;

  Exit(False);
end;

procedure TGlobalMouseHook.InternalMouseEvent(wParam: WPARAM; const p: TMouseLLHookStruct);
var
  handler: TMouseEvent;
  info: TMouseEventInfo;
  wndHandle: THandle;
  R: TRect;
  Pt: TPoint;
  i: integer;
begin
  // 1. Determine which handler (if any) is assigned for this message type
  case wParam of
    WM_LBUTTONDOWN: handler := FOnLeftDown;
    WM_LBUTTONUP: handler := FOnLeftUp;
    WM_RBUTTONDOWN: handler := FOnRightDown;
    WM_RBUTTONUP: handler := FOnRightUp;
    WM_MBUTTONDOWN: handler := FOnMiddleDown;
    WM_MBUTTONUP: handler := FOnMiddleUp;
    else
      Exit;   // ignore all other messages (move, wheel, etc.) immediately
  end;

  // 2. If no handler is assigned for this event, exit without any further work
  if not Assigned(handler) then
    Exit;

  // 3. Only now, for events we actually care about, fill the event info
  info.X := p.pt.X;
  info.Y := p.pt.Y;
  info.Time := p.time;
  info.CtrlDown := (GetAsyncKeyState(VK_CONTROL) and $8000) <> 0;
  info.ShiftDown := (GetAsyncKeyState(VK_SHIFT) and $8000) <> 0;
  info.AltDown := (GetAsyncKeyState(VK_MENU) and $8000) <> 0;

  // 4. Find the window under the cursor and check if it's a valid input target
  wndHandle := THandle(WindowFromPoint(p.pt));

  // Check if this window or its ancestor is in the ignored list
  if FIgnoredWindows <> nil then
  begin
    for i := 0 to FIgnoredWindows.Count - 1 do
    begin
      if (THandle(FIgnoredWindows[i]) = wndHandle) or IsChild(THandle(FIgnoredWindows[i]), wndHandle) then
        Exit; // Ignore events inside hint window
    end;
  end;

  // Get window class name and classification
  FillChar(info.WindowClassName[1], SizeOf(info.WindowClassName) - 1, #0);
  info.WindowClassName[0] := #0;
  if wndHandle <> 0 then
  begin
    GetClassName(wndHandle, @info.WindowClassName[1], SizeOf(info.WindowClassName) - 2);
    info.WindowClassName[0] := Char(StrLen(@info.WindowClassName[1]));
  end;
  info.WindowClass := ClassifyWindowClass(info.WindowClassName);

  if not IsInputWindow(wndHandle) then
  begin
    if wParam = WM_LBUTTONDOWN then
      FLeftDownAccepted := False;
    Exit;
  end;

  // 5. Extra check for EditFieldOnly mode: release must be inside client area
  if FEditFieldOnly and (wParam = WM_LBUTTONUP) then
  begin
    if GetClientRect(wndHandle, @R) then
    begin
      Pt := p.pt;
      ScreenToClient(wndHandle, Pt);
      if not PtInRect(R, Pt) then
        Exit;
    end;
  end;

  // 6. Left button acceptance logic (prevents stray up events)
  if wParam = WM_LBUTTONDOWN then
    FLeftDownAccepted := True
  else if wParam = WM_LBUTTONUP then
  begin
    if not FLeftDownAccepted then
      Exit;
    FLeftDownAccepted := True;   // keep valid for subsequent clicks
  end;

  // 7. Set button type and call the assigned handler
  case wParam of
    WM_LBUTTONDOWN,
    WM_LBUTTONUP: info.Button := mbLeft;
    WM_RBUTTONDOWN,
    WM_RBUTTONUP: info.Button := mbRight;
    WM_MBUTTONDOWN,
    WM_MBUTTONUP: info.Button := mbMiddle;
  end;

  handler(Self, info);
end;

constructor TGlobalMouseHook.Create;
begin
  inherited;
  FHook := 0;
  FEnabled := False;
  FEditFieldOnly := False;
  FIgnoredWindows := TList.Create;
end;

destructor TGlobalMouseHook.Destroy;
begin
  Enabled := False;      // safe cleanup – see SetEnabled
  FreeAndNil(FIgnoredWindows);
  inherited;
end;

class function TGlobalMouseHook.GetActiveInstance: TGlobalMouseHook;
begin
  Result := FActiveInstance;
end;

procedure TGlobalMouseHook.AddIgnoredWindow(AHandle: THandle);
begin
  if FIgnoredWindows = nil then Exit;
  if FIgnoredWindows.IndexOf(Pointer(AHandle)) < 0 then
    FIgnoredWindows.Add(Pointer(AHandle));
end;

procedure TGlobalMouseHook.RemoveIgnoredWindow(AHandle: THandle);
var
  idx: integer;
begin
  if FIgnoredWindows = nil then Exit;
  idx := FIgnoredWindows.IndexOf(Pointer(AHandle));
  if idx >= 0 then
    FIgnoredWindows.Delete(idx);
end;

procedure TGlobalMouseHook.SetEnabled(AValue: boolean);

  function IsWindowsXP: boolean;
  begin
    // Windows XP has major version 5 and minor version 1
    Result := (Win32MajorVersion = 5) and (Win32MinorVersion = 1);
  end;

  function hMod: HINST;
  begin
    if IsWindowsXP then
      Result := HInstance
    else
      Result := 0;
  end;

begin
  if FEnabled = AValue then Exit;
  if AValue then
  begin
    if FActiveInstance <> nil then
      raise Exception.Create('Only one TGlobalMouseHook can be active at a time.');

    // Try to install the hook. HInstance is used for XP safety (error 1428 may still occur).
    FHook := SetWindowsHookEx(WH_MOUSE_LL, @HookProc, HMod, 0);
    if FHook = 0 then
    begin
      // Hook installation failed – keep FActiveInstance nil and FEnabled false.
      // Show a warning instead of crashing, especially important for XP.
      MessageBox(0,
        PChar('Cannot enable global mouse hook.' + sLineBreak + 'System error: ' +
        SysErrorMessage(GetLastError)),
        'Trayslate',
        MB_ICONWARNING);
      Exit;   // FEnabled stays False, FActiveInstance stays nil
    end;

    // Success – mark as active
    FActiveInstance := Self;
    FEnabled := True;
  end
  else
  begin
    // Disable: only unhook if we are the active instance
    if FActiveInstance = Self then
    begin
      if FHook <> 0 then
      begin
        UnhookWindowsHookEx(FHook);
        FHook := 0;
      end;
      FActiveInstance := nil;
    end;
    FEnabled := False;
  end;
end;

class function TGlobalMouseHook.IsCtrlPressed: boolean;
begin
  Result := (GetAsyncKeyState(VK_CONTROL) and $8000) <> 0;
end;

class function TGlobalMouseHook.IsShiftPressed: boolean;
begin
  Result := (GetAsyncKeyState(VK_SHIFT) and $8000) <> 0;
end;

class function TGlobalMouseHook.IsAltPressed: boolean;
begin
  Result := (GetAsyncKeyState(VK_MENU) and $8000) <> 0;
end;

{$ELSE}

// Non Windows stub – compiles but does nothing

constructor TGlobalMouseHook.Create;
begin
  inherited;
  FEnabled := False;
  FEditFieldOnly := False;
end;

destructor TGlobalMouseHook.Destroy;
begin
  inherited;
end;

procedure TGlobalMouseHook.SetEnabled(AValue: boolean);
begin
  if AValue then
    raise Exception.Create('GlobalMouseHook is only supported on Windows.');
end;

class function TGlobalMouseHook.IsCtrlPressed: boolean;
begin
  Result := False;
end;

class function TGlobalMouseHook.IsShiftPressed: boolean;
begin
  Result := False;
end;

class function TGlobalMouseHook.IsAltPressed: boolean;
begin
  Result := False;
end;

{$ENDIF}

end.
