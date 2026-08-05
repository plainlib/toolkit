//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

unit OneShotHint;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  ExtCtrls,
  Types,
  OneShotTimer;

type
  // Custom hint window with built-in auto-hide using OneShotTimer
  TOneShotHint = class(THintWindow)
  private
    FTimer: TTimer;          // one-shot timer for auto-hide
    FHideByClick: boolean;   // if True, hide only by clicking the window
    procedure DoHideHint;    // callback for timer and click
    procedure HandleClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Show hint text at specified position.
    // Duration = 0  : hint stays until clicked
    // Duration > 0  : hint hides after Duration ms
    // The method safely cancels any previous pending timer.
    procedure ShowHintText(const AText: string; X, Y: integer; Duration: integer = 0);
  end;

implementation

{ TOneShotHint }

constructor TOneShotHint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimer := nil;
  FHideByClick := False;
  // Hide window when user clicks on it
  Self.OnClick := @HandleClick;
end;

destructor TOneShotHint.Destroy;
begin
  // Cancel any pending timer and free it
  ClearTimeout(FTimer);
  inherited Destroy;
end;

procedure TOneShotHint.ShowHintText(const AText: string; X, Y: integer; Duration: integer);
var
  HtRect: TRect;
  DisplayPos: TPoint;
begin
  // Cancel any previously scheduled hide
  ClearTimeout(FTimer);
  // Hide current hint if it is still visible
  ReleaseHandle;

  if Duration = 0 then
  begin
    // No timer – hide on click only
    FHideByClick := True;
  end
  else
  begin
    FHideByClick := False;
    // Schedule hide after Duration ms
    SetTimeoutSafe(FTimer, Duration, @DoHideHint);
  end;

  // Calculate size and position
  HtRect := CalcHintRect(Screen.Width, AText, nil);
  DisplayPos.X := X;
  DisplayPos.Y := Y;
  if X = 0 then
    DisplayPos.X := Screen.Width - (HtRect.Right - HtRect.Left) - 20;
  if Y = 0 then
    DisplayPos.Y := Screen.WorkAreaHeight - (HtRect.Bottom - HtRect.Top) - 5;
  OffsetRect(HtRect, DisplayPos.X, DisplayPos.Y);

  ActivateHint(HtRect, AText);
end;

procedure TOneShotHint.DoHideHint;
begin
  // The timer already nilled FTimer, we just need to hide
  ReleaseHandle;
end;

procedure TOneShotHint.HandleClick(Sender: TObject);
begin
  if FHideByClick then
  begin
    // Cancel timer if one is somehow still active (safety)
    ClearTimeout(FTimer);
    ReleaseHandle;
  end;
end;

end.
