//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

unit OneShotTimer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, Forms;

type
  PTimer = ^TTimer;
  TOneShotCallback = procedure of object;

// Schedules a one-time callback after the specified delay.
// Call with two arguments to run without cancellation.
// Call with three arguments to get a timer reference for cancellation.
procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallback); overload;
procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallback); overload;

// Cancels a pending timer obtained from SetTimeout.
// Safe to call even if the timer has already fired or is nil.
procedure ClearTimeout(var Timer: TTimer);

implementation

var
  FOneShotTimers: TList; // Stores all active timers

type
  TOneShotTimer = class(TTimer)
  private
    FCallback: TOneShotCallback;
    FUserVar: ^TTimer;
  public
    constructor CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; AUserVar: PTimer);
    destructor Destroy; override;
    procedure TimerFire(Sender: TObject);
  end;

constructor TOneShotTimer.CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; AUserVar: PTimer);
begin
  // No owner - timer is managed via the global list and freed manually
  inherited Create(nil);
  FCallback := ACallback;
  FUserVar := AUserVar;
  Interval := ADelay;
  OnTimer := @TimerFire;
  Enabled := True;
  if FUserVar <> nil then
    FUserVar^ := Self;
  // Add to global list for guaranteed cleanup
  FOneShotTimers.Add(Self);
end;

destructor TOneShotTimer.Destroy;
begin
  // Remove from global list
  FOneShotTimers.Remove(Self);
  // Clear external reference if still valid (may be nil if already cleared)
  if FUserVar <> nil then
    FUserVar^ := nil;
  FUserVar := nil;
  inherited Destroy;
end;

procedure TOneShotTimer.TimerFire(Sender: TObject);
begin
  Enabled := False;
  // Immediately nil the external variable so no one touches a dead object
  if FUserVar <> nil then
  begin
    FUserVar^ := nil;
    FUserVar := nil;
  end;
  try
    if Assigned(FCallback) then
      FCallback();
  finally
    // Free immediately; global list will remove it in destructor
    Free;
  end;
end;

procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallback);
begin
  TOneShotTimer.CreateWith(Delay, Callback, nil);
end;

procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallback);
begin
  Timer := nil;
  TOneShotTimer.CreateWith(Delay, Callback, @Timer);
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
  // Prevent destructor from writing to possibly destroyed external variables
  for i := 0 to FOneShotTimers.Count - 1 do
    TOneShotTimer(FOneShotTimers[i]).FUserVar := nil;
  // Free all remaining timers
  while FOneShotTimers.Count > 0 do
    TOneShotTimer(FOneShotTimers[0]).Free;
end;

initialization
  FOneShotTimers := TList.Create;

finalization
  FreeAllOneShotTimers;
  FOneShotTimers.Free;

end.
