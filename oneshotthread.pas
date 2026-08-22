//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------
// OneShotThread - utility for running methods in background threads.
//
// Examples:
//
// 1. Fire and forget:
//    RunAsync(@DoHeavyWork);
//
// 2. With cancellation:
//    var MyThread: TThread;
//    RunAsync(MyThread, @DoHeavyWork);
//    ...
//    CancelAsync(MyThread);
//
// 3. With completion callback (runs in main thread):
//    RunAsync(@DoHeavyWork, @UpdateUIAfterWork);
//
// 4. Synchronous wait for result with a procedure (blocks calling thread):
//    procedure CalculateSomething(out AResult: Integer);
//    begin
//      AResult := 42;
//    end;
//
//    var Res: Integer;
//    Res := specialize RunAsyncAndWait<Integer>(@CalculateSomething);
//
// 5. Synchronous wait for result with a function (blocks calling thread):
//    function CalculateSomethingFunc: Integer;
//    begin
//      Result := 42;
//    end;
//
//    var Res2: Integer;
//    Res2 := specialize RunAsyncAndWaitFunc<Integer>(@CalculateSomethingFunc);
//
// In methods run via RunAsync, use IsCancelled to check for cancellation.
// OnDone is skipped if CancelAsync was called before the Proc finished.
// RunAsyncAndWait/RunAsyncAndWaitFunc must not be used from main thread if the
// called method tries to synchronize with the main thread (deadlock risk).

unit OneShotThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TOneShotProc = procedure of object;

  // Generic procedure that fills the result variable, runs in background
  generic TOneShotResultProc<T> = procedure(out AResult: T) of object;

  // Generic function that returns a result, runs in background
  generic TOneShotResultFunc<T> = function: T of object;

  // Generic thread for synchronous waiting with result from a procedure
  generic TOneShotWaitThreadProc<T> = class(TThread)
  private
    FProc: specialize TOneShotResultProc<T>;
    FResult: T;
    FErrorMessage: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AProc: specialize TOneShotResultProc<T>);
    property Result: T read FResult;
    property ErrorMessage: string read FErrorMessage;
  end;

  // Generic thread for synchronous waiting with result from a function
  generic TOneShotWaitThreadFunc<T> = class(TThread)
  private
    FFunc: specialize TOneShotResultFunc<T>;
    FResult: T;
    FErrorMessage: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AFunc: specialize TOneShotResultFunc<T>);
    property Result: T read FResult;
    property ErrorMessage: string read FErrorMessage;
  end;

// Runs Proc in a background thread, fire and forget.
procedure RunAsync(Proc: TOneShotProc); overload;
// Runs Proc in a background thread and returns a thread reference for CancelAsync.
// The external variable must remain valid until the thread has finished.
procedure RunAsync(out Thread: TThread; Proc: TOneShotProc); overload;
// Runs Proc in a background thread, then calls OnDone in the main thread once finished.
// OnDone is skipped if CancelAsync was called before Proc returned.
procedure RunAsync(Proc: TOneShotProc; OnDone: TOneShotProc); overload;
procedure RunAsync(out Thread: TThread; Proc: TOneShotProc; OnDone: TOneShotProc); overload;

// Requests cancellation of a pending thread obtained from RunAsync.
// This does not force-stop the thread; the running Proc must check IsCancelled itself
// and return early. Safe to call from the main thread and before the thread has finished.
procedure CancelAsync(var Thread: TThread);

// Returns True if the currently running background Proc has been asked to cancel.
// Must be called from inside the Proc itself, since it checks the calling thread.
function IsCancelled: Boolean;

// Runs Proc in a background thread, waits for it to finish, and returns its result.
// Warning: blocks the calling thread until Proc completes.
// Do not call from the main thread if Proc uses Synchronize or needs the main thread,
// otherwise a deadlock will occur.
generic function RunAsyncAndWait<T>(Proc: specialize TOneShotResultProc<T>): T;

// Runs Func in a background thread, waits for it to finish, and returns its result.
// Warning: blocks the calling thread until Func completes.
// Do not call from the main thread if Func uses Synchronize or needs the main thread,
// otherwise a deadlock will occur.
generic function RunAsyncAndWaitFunc<T>(Func: specialize TOneShotResultFunc<T>): T;

implementation

type
  // Pointer to TThread, needed because inline ^TThread sometimes confuses the compiler
  PTThread = ^TThread;

  TOneShotThread = class(TThread)
  private
    FProc: TOneShotProc;
    FOnDone: TOneShotProc;
    FUserVar: PTThread;
  protected
    procedure Execute; override;
  public
    constructor CreateWith(AProc: TOneShotProc; AOnDone: TOneShotProc; AUserVar: PTThread);
  end;

threadvar
  // Points to the TOneShotThread instance running on this thread, if any
  CurrentOneShotThread: TOneShotThread;

constructor TOneShotThread.CreateWith(AProc: TOneShotProc; AOnDone: TOneShotProc; AUserVar: PTThread);
begin
  FProc := AProc;
  FOnDone := AOnDone;
  FUserVar := AUserVar;
  FreeOnTerminate := True;
  // Create suspended to avoid a race: set the external reference before the thread starts
  inherited Create(True);
  if FUserVar <> nil then
    FUserVar^ := Self;
  Start;
end;

procedure TOneShotThread.Execute;
begin
  CurrentOneShotThread := Self;
  try
    // Exceptions raised inside FProc are caught to avoid crashing the whole program.
    // The caller can handle them inside Proc if needed.
    try
      if Assigned(FProc) then
        FProc();
    except
      // Optionally log the exception here
    end;
  finally
    CurrentOneShotThread := nil;
    // Immediately nil the external variable so no one touches a dead object
    if FUserVar <> nil then
      FUserVar^ := nil;
    if Assigned(FOnDone) and not Terminated then
      Synchronize(FOnDone);
  end;
end;

constructor TOneShotWaitThreadProc.Create(AProc: specialize TOneShotResultProc<T>);
begin
  FProc := AProc;
  FErrorMessage := '';
  FreeOnTerminate := False;
  inherited Create(True);
end;

procedure TOneShotWaitThreadProc.Execute;
begin
  try
    FProc(FResult);
  except
    on E: Exception do
      FErrorMessage := E.Message;
  end;
end;

constructor TOneShotWaitThreadFunc.Create(AFunc: specialize TOneShotResultFunc<T>);
begin
  FFunc := AFunc;
  FErrorMessage := '';
  FreeOnTerminate := False;
  inherited Create(True);
end;

procedure TOneShotWaitThreadFunc.Execute;
begin
  try
    FResult := FFunc();
  except
    on E: Exception do
      FErrorMessage := E.Message;
  end;
end;

procedure RunAsync(Proc: TOneShotProc);
begin
  TOneShotThread.CreateWith(Proc, nil, nil);
end;

procedure RunAsync(out Thread: TThread; Proc: TOneShotProc);
begin
  Thread := nil;
  TOneShotThread.CreateWith(Proc, nil, @Thread);
end;

procedure RunAsync(Proc: TOneShotProc; OnDone: TOneShotProc);
begin
  TOneShotThread.CreateWith(Proc, OnDone, nil);
end;

procedure RunAsync(out Thread: TThread; Proc: TOneShotProc; OnDone: TOneShotProc);
begin
  Thread := nil;
  TOneShotThread.CreateWith(Proc, OnDone, @Thread);
end;

procedure CancelAsync(var Thread: TThread);
begin
  if Thread = nil then Exit;
  if Thread is TOneShotThread then
  begin
    // Warning: this is not fully thread-safe if the thread has already completed.
    // It should be called from the main thread and before the thread finishes.
    TOneShotThread(Thread).FUserVar := nil;
    Thread.Terminate;
  end;
  Thread := nil;
end;

function IsCancelled: Boolean;
begin
  Result := (CurrentOneShotThread <> nil) and CurrentOneShotThread.Terminated;
end;

generic function RunAsyncAndWait<T>(Proc: specialize TOneShotResultProc<T>): T;
var
  Thread: specialize TOneShotWaitThreadProc<T>;
  ErrMsg: string;
begin
  ErrMsg := '';
  Thread := specialize TOneShotWaitThreadProc<T>.Create(Proc);
  try
    Thread.Start;
    Thread.WaitFor;
    ErrMsg := Thread.ErrorMessage;
    if ErrMsg <> '' then
      raise Exception.Create(ErrMsg);
    Result := Thread.Result;
  finally
    Thread.Free;
  end;
end;

generic function RunAsyncAndWaitFunc<T>(Func: specialize TOneShotResultFunc<T>): T;
var
  Thread: specialize TOneShotWaitThreadFunc<T>;
  ErrMsg: string;
begin
  ErrMsg := '';
  Thread := specialize TOneShotWaitThreadFunc<T>.Create(Func);
  try
    Thread.Start;
    Thread.WaitFor;
    ErrMsg := Thread.ErrorMessage;
    if ErrMsg <> '' then
      raise Exception.Create(ErrMsg);
    Result := Thread.Result;
  finally
    Thread.Free;
  end;
end;

end.
