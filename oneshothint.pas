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
    FHideOnClick: boolean;   // if True, the hint can be hidden by a mouse click
    procedure DoHideHint;    // callback for timer
    procedure MouseDownOutside(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HideHintInternal; // common cleanup and hide
    procedure SetHideOnClick(AValue: boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Show hint text at specified position.
    // Duration = 0  : hint stays until manually hidden (or clicked, if HideOnClick = True)
    // Duration > 0  : hint hides after Duration ms
    // AWidth, AHeight : custom size; 0 means auto-calculate
    procedure ShowHintText(const AText: string; X, Y: integer;
      AWidth: integer = 0; AHeight: integer = 0; Duration: integer = 0);
  published
    // Determines whether the hint can be closed by a mouse click.
    // Default is False – clicks pass through to underlying controls without interference.
    property HideOnClick: boolean read FHideOnClick write SetHideOnClick default False;
  end;

implementation

{ TOneShotHint }

constructor TOneShotHint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTimer := nil;
  FHideOnClick := False;
  // Mouse handler is assigned only when needed
end;

destructor TOneShotHint.Destroy;
begin
  // Cancel any pending timer and free it
  ClearTimeout(FTimer);
  inherited Destroy;
end;

procedure TOneShotHint.SetHideOnClick(AValue: boolean);
begin
  if FHideOnClick <> AValue then
  begin
    FHideOnClick := AValue;
    // If the hint is currently visible, update mouse capture immediately
    if HandleAllocated then
    begin
      if FHideOnClick then
        Self.OnMouseDown := @MouseDownOutside
      else
        Self.OnMouseDown := nil;
      Self.MouseCapture := FHideOnClick;
    end;
  end;
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
    // No timer – hint must be hidden manually or by click (if HideOnClick is True)
  end
  else
  begin
    // Schedule hide after Duration ms
    SetTimeout(FTimer, Duration, @DoHideHint);
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

  // Enable mouse capture only if the hint should react to clicks
  if FHideOnClick then
  begin
    Self.OnMouseDown := @MouseDownOutside;
    Self.MouseCapture := True;
  end
  else
  begin
    Self.OnMouseDown := nil;
    Self.MouseCapture := False;
  end;
end;

procedure TOneShotHint.DoHideHint;
begin
  // Timer fired – hide and release capture
  HideHintInternal;
end;

procedure TOneShotHint.MouseDownOutside(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // This handler is only active when HideOnClick = True.
  // Coordinates are relative to our client area.
  // Click outside the hint or click inside always hides the hint.
  HideHintInternal;
end;

procedure TOneShotHint.HideHintInternal;
begin
  ClearTimeout(FTimer);      // cancel timer if any
  Self.MouseCapture := False; // release capture
  Self.OnMouseDown := nil;   // remove the handler
  ReleaseHandle;             // hide the hint window
end;

end.
