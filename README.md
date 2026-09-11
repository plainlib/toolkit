# Toolkit Package

A collection of lightweight, self‑contained utility units for Lazarus (Free Pascal) applications.  
These units provide low‑level system interaction, asynchronous execution, UI helpers, and drag‑and‑drop enhancements.

---

## Requirements

- **Lazarus** (tested with 4.8) / **FPC** 3.2.2
- **LCLBase** package (included in Lazarus)
- On **Windows**, the hook units use the Win32 API; on other platforms they are stubbed and can be extended later.

---

## GlobalKeyboardHook

**Unit**: `GlobalKeyboardHook.pas`

Low‑level global keyboard hook.  
Monitors and optionally blocks system‑wide key events. Maintains accurate modifier state (Ctrl/Shift/Alt) and can filter events to editable controls only.

```pascal
uses GlobalKeyboardHook;

var
  Hook: TGlobalKeyboardHook;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Hook := TGlobalKeyboardHook.Create;
  Hook.OnKeyEvent := @OnKeyEvent;
  Hook.BlockedKeys := [VK_F1, VK_F2];   // optional block list
  Hook.Enabled := True;
end;

procedure TForm1.OnKeyEvent(Sender: TObject; var Info: TKeyboardEventInfo);
begin
  if Info.IsDown then
    Memo1.Lines.Add(Format('Key %d pressed', [Info.KeyCode]));
  // To swallow the key, set Info.Handled := True;
end;
```

---

## GlobalMouseHook

**Unit**: `GlobalMouseHook.pas`

Low‑level global mouse hook.  
Captures left/right/middle button down/up events with smart window filtering. It automatically ignores non‑editable controls (when `EditFieldOnly` is enabled) and excludes clicks on virtual machines, consoles, and common UI elements.

```pascal
uses GlobalMouseHook;

var
  MouseHook: TGlobalMouseHook;

procedure TForm1.FormCreate(Sender: TObject);
begin
  MouseHook := TGlobalMouseHook.Create;
  MouseHook.OnLeftDown := @MouseClick;
  MouseHook.EditFieldOnly := True;
  MouseHook.Enabled := True;
end;

procedure TForm1.MouseClick(Sender: TObject; const Info: TMouseEventInfo);
begin
  ShowMessage(Format('Click at (%d, %d) on %s', [Info.X, Info.Y, Info.WindowClassName]));
end;
```

---

## MathParser

**Unit**: `MathParser.pas`

Parses and evaluates arithmetic expressions from strings.  
Supports `+ - * / ^ % ( )` and decimal separators. Can also clean numbers from mixed content.

```pascal
uses MathParser;

var
  Result: string;
begin
  Result := TMathParser.Eval('(2 + 3) * 4');  // "20"
  Result := TMathParser.CleanNumeric('$123.45'); // "123.45"
end;
```

---

## OneShotHint

**Unit**: `OneShotHint.pas`

A lightweight hint window with a one‑shot timer for auto‑hide.  
It can be shown with custom size, background colour, and optional click‑to‑close behaviour. Supports auto‑free.

```pascal
uses OneShotHint;

// Quick hint near the mouse, auto‑closes after 2 seconds
TOneShotHint.Show('Hello World!', 300, clInfoBk, 2000);

// Manual instance
var
  Hint: TOneShotHint;
begin
  Hint := TOneShotHint.Create(Self);
  Hint.HideOnClick := True;
  Hint.ShowHintText('My hint', 100, 100, 0, 0, 3000, clYellow);
end;
```

---

## OneShotThread

**Unit**: `OneShotThread.pas`

Run any method in a background thread with optional cancellation and completion callbacks.  
Supports synchronous waiting for results and provides a global shutdown mechanism for a clean application exit.

```pascal
uses OneShotThread;

procedure DoHeavyWork;
begin
  Sleep(1000);
  if IsCancelled then Exit;
  // ...
end;

procedure WorkDone;
begin
  ShowMessage('Finished');
end;

// Fire and forget
RunAsync(@DoHeavyWork);

// With completion callback (runs in main thread)
RunAsync(@DoHeavyWork, @WorkDone);

// With cancellation reference
var
  MyThread: TThread;
RunAsync(MyThread, @DoHeavyWork);
CancelAsync(MyThread);

// Shutdown on form close
procedure TForm1.FormClose(...);
begin
  ShutdownThreads;
  WaitForThreads;   // blocks until all background threads finish
end;
```

---

## OneShotTimer

**Unit**: `OneShotTimer.pas`

One‑shot timers that execute a callback after a specified delay and then free themselves.  
Supports callbacks with no parameters, a pointer parameter, or an array of constants. Timers can be cancelled.

```pascal
uses OneShotTimer;

// Simple delay
SetTimeout(1000, @ShowMessageAfterDelay);

// With pointer data
SetTimeout(500, @ProcessData, Pointer(SomeData));

// With multiple arguments
SetTimeout(300, @LogValues, ['test', 123, True]);

// Cancellation
var
  Timer: TTimer;
SetTimeout(Timer, 2000, @DelayedAction);
if SomeCondition then
  ClearTimeout(Timer);
```

---

## OneShotTooltip

**Unit**: `OneShotTooltip.pas`

An advanced, resizable tooltip window that stays on top and auto‑hides when the application loses focus or the user clicks elsewhere.  
Includes a resize grip and integrates with `GlobalMouseHook` to avoid interfering with the tooltip itself.

```pascal
uses OneShotTooltip;

// Quick show
TOneShotTooltip.Show('Resizable tooltip', 400, clInfoBk, 3000);

// Managed instance
var
  Tooltip: TOneShotTooltip;
begin
  Tooltip := TOneShotTooltip.Create(Self);
  Tooltip.ShowHintText('Tooltip text', 100, 100, 400, 200, 5000, clYellow);
  // Later: Tooltip.Hide;
end;
```

---

## TextDropTarget

**Unit**: `TextDropTarget.pas`

Adds OLE drag‑and‑drop support for text onto a `TCustomEdit` (or any control) on Windows.  
Supports insert‑mode (caret follows mouse) or replace‑mode. Handles Unicode, HTML (strips tags), and plain text. Can also register sub‑controls as drop targets.

```pascal
uses TextDropTarget;

// On a form, drop a TTextDropTarget component
procedure TForm1.FormCreate(Sender: TObject);
begin
  TextDropTarget1.Target := Edit1;
  TextDropTarget1.InsertText := True;   // insert at caret position
  TextDropTarget1.OnTextDropped := @OnTextDrop;
  // Optional sub‑targets
  TextDropTarget1.AddSubTarget(Panel1);
end;

procedure TForm1.OnTextDrop(Sender: TObject; const Text: string);
begin
  ShowMessage('Dropped: ' + Text);
end;
```

## Downloader

**Unit**: `Downloader.pas`

Asynchronous multi‑URL downloader.  
Downloads files into `TMemoryStream` objects and reports per‑URL errors through a completion callback.  
On Windows it uses WinInet with an FPHTTPClient fallback; on other platforms it uses FPHTTPClient and can fall back to `curl` or `wget`. HTTPS works when OpenSSL is available (`IsSSLAvailable`). The callback runs in the main thread via `Synchronize`; failed entries contain a `nil` stream and an error string.

```pascal
uses Downloader;

procedure TForm1.FormCreate(Sender: TObject);
begin
  DownloadFiles(['https://example.com/file1.txt',
                 'https://example.com/file2.txt'], @OnDownloadComplete);
end;

procedure TForm1.OnDownloadComplete(Sender: TObject;
  AStreams: array of TMemoryStream; AErrors: array of string);
var
  i: Integer;
begin
  for i := 0 to High(AStreams) do
    if AErrors[i] = '' then
      AStreams[i].SaveToFile('file' + IntToStr(i + 1) + '.dat')
    else
      ShowMessage(AErrors[i]);
end;
```

---

## License

All units are licensed under the MIT License – see the individual file headers for details.