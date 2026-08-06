unit flatbutton;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, Buttons, Graphics, Themes, LCLType, Types;

type
  TFlatButton = class(TSpeedButton)
  private
    FOffsetY: Integer;
    procedure SetOffsetY(AValue: Integer);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // Vertical offset for the caption relative to the icon center (0 = default centered)
    property OffsetY: Integer read FOffsetY write SetOffsetY default 0;
  end;

implementation

constructor TFlatButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOffsetY := 0;
  Flat := True; // Always draw as a flat button
end;

procedure TFlatButton.SetOffsetY(AValue: Integer);
begin
  if FOffsetY = AValue then Exit;
  FOffsetY := AValue;
  Invalidate;
end;

procedure TFlatButton.Paint;
var
  r: TRect;
  xIcon, yIcon, xText: Integer;
  ts: TTextStyle;
  Details: TThemedElementDetails;
  imgW, imgH: Integer;
begin
  // Toolbar theme elements give the native flat look
  if Down then
    Details := ThemeServices.GetElementDetails(ttbButtonPressed)
  else if MouseInClient then
    Details := ThemeServices.GetElementDetails(ttbButtonHot)
  else
    Details := ThemeServices.GetElementDetails(ttbButtonNormal);

  // Draw the themed background
  ThemeServices.DrawElement(Canvas.Handle, Details, ClientRect);

  // Determine icon dimensions from ImageList or Glyph
  if (ImageIndex >= 0) and (Images <> nil) then
  begin
    imgW := Images.Width;
    imgH := Images.Height;
  end
  else if (Glyph <> nil) and (not Glyph.Empty) then
  begin
    imgW := Glyph.Width;
    imgH := Glyph.Height;
  end
  else
  begin
    imgW := 0;
    imgH := 0;
  end;

  // Draw the icon vertically centered
  if imgW > 0 then
  begin
    xIcon := 2;  // left padding
    yIcon := (ClientRect.Height - imgH) div 2;
    if (ImageIndex >= 0) and (Images <> nil) then
      Images.Draw(Canvas, xIcon, yIcon, ImageIndex, Enabled)
    else if (Glyph <> nil) and (not Glyph.Empty) then
      Canvas.Draw(xIcon, yIcon, Glyph);
    xText := xIcon + imgW + 4; // gap between icon and text
  end
  else
    xText := 4; // no icon

  // Caption rectangle shifted vertically by OffsetY
  r := Rect(xText, FOffsetY, ClientRect.Width - 4, ClientRect.Height + FOffsetY);

  // Preserve the button's font settings
  Canvas.Font.Assign(Font);

  // Draw caption centered vertically inside the shifted rectangle
  ts := Canvas.TextStyle;
  ts.Alignment := taLeftJustify;
  ts.Layout := tlCenter;
  Canvas.TextRect(r, r.Left, r.Top, Caption, ts);
end;

end.
