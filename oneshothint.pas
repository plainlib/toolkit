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
    procedure DoHideHint;    // callback for timer
    procedure MouseDownOutside(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HideHintInternal; // common cleanup and hide
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Show hint text at specified position.
    // Duration = 0  : hint stays until clicked
    // Duration > 0  : hint hides after Duration ms
    // AWidth, AHeight : custom size; 0 means auto-calculate
    procedure ShowHintText(const AText: string; X, Y: integer;
      AWidth: integer = 0; AHeight: integer = 0; Duration: integer = 0);
  end;

implementation

{ TOneShotHint }

constructor TOneShotHint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimer := nil;
  FHideByClick := False;
  // Single mouse handler for both inside and outside clicks
  Self.OnMouseDown := @MouseDownOutside;
end;

destructor TOneShotHint.Destroy;
begin
  // Cancel any pending timer and free it
  ClearTimeout(FTimer);
  inherited Destroy;
end;

procedure TOneShotHint.ShowHintText(const AText: string; X, Y: integer;
  AWidth: integer; AHeight: integer; Duration: integer);
var
  HtRect: TRect;
  DisplayPos: TPoint;
  MaxW: integer;
begin
  // Cancel any previously scheduled hide
  ClearTimeout(FTimer);
  // Hide current hint if it is still visible (and release capture if any)
  Self.MouseCapture := False;
  ReleaseHandle;

  if Duration = 0 then
  begin
    // No timer – hide on click only (inside or outside)
    FHideByClick := True;
  end
  else
  begin
    FHideByClick := False;
    // Schedule hide after Duration ms
    SetTimeoutSafe(FTimer, Duration, @DoHideHint);
  end;

  // Determine maximum width for text calculation
  if AWidth <= 0 then
    MaxW := Screen.Width
  else
    MaxW := AWidth;

  // Calculate initial rectangle based on text
  HtRect := CalcHintRect(MaxW, AText, nil);

  // Apply custom width if specified
  if AWidth > 0 then
    HtRect.Right := HtRect.Left + AWidth;

  // Apply custom height if specified
  if AHeight > 0 then
    HtRect.Bottom := HtRect.Top + AHeight;

  // Default positioning (bottom-right corner with small margin)
  DisplayPos.X := X;
  DisplayPos.Y := Y;
  if X = 0 then
    DisplayPos.X := Screen.Width - (HtRect.Right - HtRect.Left) - 20;
  if Y = 0 then
    DisplayPos.Y := Screen.WorkAreaHeight - (HtRect.Bottom - HtRect.Top) - 5;
  OffsetRect(HtRect, DisplayPos.X, DisplayPos.Y);

  ActivateHint(HtRect, AText);
  // Capture all mouse events so we can detect clicks outside
  Self.MouseCapture := True;
end;

procedure TOneShotHint.DoHideHint;
begin
  // Timer fired – hide and release capture
  HideHintInternal;
end;

procedure TOneShotHint.MouseDownOutside(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // Coordinates are relative to our client area
  if (X < 0) or (X >= ClientWidth) or (Y < 0) or (Y >= ClientHeight) then
    // Click outside – always hide
    HideHintInternal
  else if FHideByClick then
    // Click inside and hint is in "click-to-hide" mode
    HideHintInternal;
  // Otherwise (inside click with Duration>0) do nothing – timer will hide it later
end;

procedure TOneShotHint.HideHintInternal;
begin
  ClearTimeout(FTimer);      // cancel timer if any
  Self.MouseCapture := False; // release capture
  ReleaseHandle;             // hide the hint window
end;

end.
