//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------
//  Module for delayed one-shot procedure calls via a timer.
//
//  Key features:
//  1. SetTimeout(Delay, Callback) - call a procedure without parameters.
//  2. SetTimeout(Delay, Callback, Data: Pointer) - pass an arbitrary pointer.
//  3. SetTimeout(Delay, Callback, Args: array of const) - pass a list of mixed-type parameters.
//
//  In all variants you can get a timer reference (for cancellation) via out parameter.
//  Cancellation is done by ClearTimeout(var Timer).
//  All timers are freed automatically; calling ClearTimeout twice is safe.
//-----------------------------------------------------------------------------------

unit OneShotTimer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, Forms;

type
  PTimer = ^TTimer;
  // Original callback without parameters
  TOneShotCallback = procedure of object;
  // Callback that receives a Pointer to user data
  TOneShotCallbackWithData = procedure(Data: Pointer) of object;
  // Callback that receives an array of const (multiple typed parameters)
  TOneShotArrayCallback = procedure(const Args: array of const) of object;

// Existing overloads (no data)
procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallback); overload;
procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallback); overload;

// Existing overloads with Pointer data
procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallbackWithData; Data: Pointer); overload;
procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallbackWithData; Data: Pointer); overload;

// New overloads with array of const
procedure SetTimeout(Delay: cardinal; Callback: TOneShotArrayCallback; const Args: array of const); overload;
procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotArrayCallback; const Args: array of const); overload;

// Cancels a pending timer
procedure ClearTimeout(var Timer: TTimer);

implementation

var
  FOneShotTimers: TList; // Stores all active timers

type
  TOneShotTimer = class(TTimer)
  private
    FCallback: TOneShotCallback;
    FCallbackWithData: TOneShotCallbackWithData;
    FArrayCallback: TOneShotArrayCallback;
    FUserVar: ^TTimer;
    FData: Pointer;
    FArgs: array of TVarRec; // Copy of array of const
    procedure CopyArgs(const A: array of const);
    procedure ClearArgs;
  public
    constructor CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; AUserVar: PTimer);
    constructor CreateWithData(ADelay: cardinal; ACallback: TOneShotCallbackWithData; AUserVar: PTimer; AData: Pointer);
    constructor CreateWithArray(ADelay: cardinal; ACallback: TOneShotArrayCallback; AUserVar: PTimer; const A: array of const);
    destructor Destroy; override;
    procedure TimerFire(Sender: TObject);
  end;

// Helper to deep copy TVarRec array (supports common simple types)
procedure TOneShotTimer.CopyArgs(const A: array of const);
var
  i: Integer;
begin
  SetLength(FArgs, Length(A));
  for i := 0 to High(A) do
  begin
    FArgs[i] := A[i];
    // For string types we need to copy the string content,
    // because the original may be destroyed after the call.
    case FArgs[i].VType of
      vtAnsiString:
        AnsiString(FArgs[i].VAnsiString) := AnsiString(A[i].VAnsiString);
      vtUnicodeString:
        UnicodeString(FArgs[i].VUnicodeString) := UnicodeString(A[i].VUnicodeString);
      vtWideString:
        WideString(FArgs[i].VWideString) := WideString(A[i].VWideString);
      vtInterface: begin
        // Save the pointer and increase reference count
        FArgs[i].VInterface := A[i].VInterface;
        if FArgs[i].VInterface <> nil then
          IInterface(FArgs[i].VInterface)._AddRef;
      end;
      // For other types (integers, booleans, chars, floats) value is stored directly
    end;
  end;
end;

procedure TOneShotTimer.ClearArgs;
var
  i: Integer;
begin
  for i := 0 to High(FArgs) do
  begin
    case FArgs[i].VType of
      vtAnsiString: AnsiString(FArgs[i].VAnsiString) := '';
      vtUnicodeString: UnicodeString(FArgs[i].VUnicodeString) := '';
      vtWideString: WideString(FArgs[i].VWideString) := '';
      vtInterface:
        if FArgs[i].VInterface <> nil then
          IInterface(FArgs[i].VInterface)._Release;
    end;
  end;
  SetLength(FArgs, 0);
end;

constructor TOneShotTimer.CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; AUserVar: PTimer);
begin
  inherited Create(nil);
  FCallback := ACallback;
  FCallbackWithData := nil;
  FArrayCallback := nil;
  FUserVar := AUserVar;
  FData := nil;
  Interval := ADelay;
  OnTimer := @TimerFire;
  Enabled := True;
  if FUserVar <> nil then
    FUserVar^ := Self;
  FOneShotTimers.Add(Self);
end;

constructor TOneShotTimer.CreateWithData(ADelay: cardinal; ACallback: TOneShotCallbackWithData; AUserVar: PTimer; AData: Pointer);
begin
  inherited Create(nil);
  FCallback := nil;
  FCallbackWithData := ACallback;
  FArrayCallback := nil;
  FUserVar := AUserVar;
  FData := AData;
  Interval := ADelay;
  OnTimer := @TimerFire;
  Enabled := True;
  if FUserVar <> nil then
    FUserVar^ := Self;
  FOneShotTimers.Add(Self);
end;

constructor TOneShotTimer.CreateWithArray(ADelay: cardinal; ACallback: TOneShotArrayCallback; AUserVar: PTimer; const A: array of const);
begin
  inherited Create(nil);
  FCallback := nil;
  FCallbackWithData := nil;
  FArrayCallback := ACallback;
  FUserVar := AUserVar;
  FData := nil;
  CopyArgs(A); // Store a deep copy of the arguments
  Interval := ADelay;
  OnTimer := @TimerFire;
  Enabled := True;
  if FUserVar <> nil then
    FUserVar^ := Self;
  FOneShotTimers.Add(Self);
end;

destructor TOneShotTimer.Destroy;
begin
  FOneShotTimers.Remove(Self);
  if FUserVar <> nil then
    FUserVar^ := nil;
  FUserVar := nil;
  ClearArgs; // Free copied strings/interfaces
  inherited Destroy;
end;

procedure TOneShotTimer.TimerFire(Sender: TObject);
begin
  Enabled := False;
  if FUserVar <> nil then
  begin
    FUserVar^ := nil;
    FUserVar := nil;
  end;
  try
    if Assigned(FCallback) then
      FCallback()
    else if Assigned(FCallbackWithData) then
      FCallbackWithData(FData)
    else if Assigned(FArrayCallback) then
      FArrayCallback(FArgs); // Pass the stored args
  finally
    Free; // Destructor will clear args
  end;
end;

// Existing implementations...
procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallback);
begin
  TOneShotTimer.CreateWith(Delay, Callback, nil);
end;

procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallback);
begin
  Timer := nil;
  TOneShotTimer.CreateWith(Delay, Callback, @Timer);
end;

procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallbackWithData; Data: Pointer);
begin
  TOneShotTimer.CreateWithData(Delay, Callback, nil, Data);
end;

procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallbackWithData; Data: Pointer);
begin
  Timer := nil;
  TOneShotTimer.CreateWithData(Delay, Callback, @Timer, Data);
end;

procedure SetTimeout(Delay: cardinal; Callback: TOneShotArrayCallback; const Args: array of const);
begin
  TOneShotTimer.CreateWithArray(Delay, Callback, nil, Args);
end;

procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotArrayCallback; const Args: array of const);
begin
  Timer := nil;
  TOneShotTimer.CreateWithArray(Delay, Callback, @Timer, Args);
end;

procedure ClearTimeout(var Timer: TTimer);
begin
  if Timer = nil then Exit;
  if Timer is TOneShotTimer then
  begin
    Timer.Enabled := False;
    TOneShotTimer(Timer).FUserVar := nil;
    FreeAndNil(Timer);
  end
  else
    FreeAndNil(Timer);
end;

procedure FreeAllOneShotTimers;
var
  i: Integer;
begin
  for i := 0 to FOneShotTimers.Count - 1 do
    TOneShotTimer(FOneShotTimers[i]).FUserVar := nil;
  while FOneShotTimers.Count > 0 do
    TOneShotTimer(FOneShotTimers[0]).Free;
end;

initialization
  FOneShotTimers := TList.Create;

finalization
  FreeAllOneShotTimers;
  FOneShotTimers.Free;

end.
