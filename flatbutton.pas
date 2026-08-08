unit flatbutton;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, Buttons, Graphics, Themes, LCLType, Types;

type
  TFlatButton = class(TSpeedButton)
  private
    FOffsetY: integer;
    procedure SetOffsetY(AValue: integer);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // Vertical offset for the caption relative to the icon center (0 = default centered)
    property OffsetY: integer read FOffsetY write SetOffsetY default 0;
  end;

implementation

constructor TFlatButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOffsetY := 0;
  Flat := True; // Always draw as a flat button
end;

procedure TFlatButton.SetOffsetY(AValue: integer);
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
  textWidth, totalWidth, xStart: Integer;
  gap: Integer;
begin
  gap := 4;
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

  // Calculate total content width
  Canvas.Font.Assign(Font);
  textWidth := Canvas.TextWidth(Caption);
  if imgW > 0 then
    totalWidth := imgW + gap + textWidth
  else
    totalWidth := textWidth;

  // Horizontal alignment of the whole icon+text block
  case Alignment of
    taRightJustify:
      xStart := ClientWidth - totalWidth - gap;
    taCenter:
      begin
        xStart := (ClientWidth - totalWidth) div 2;
        if xStart < gap then
          xStart := gap;
      end;
  else // taLeftJustify
    xStart := gap;
  end;

  // Draw the icon vertically centered
  if imgW > 0 then
  begin
    xIcon := xStart;
    yIcon := (ClientHeight - imgH) div 2;
    if (ImageIndex >= 0) and (Images <> nil) then
      Images.Draw(Canvas, xIcon, yIcon, ImageIndex, Enabled)
    else if (Glyph <> nil) and (not Glyph.Empty) then
      Canvas.Draw(xIcon, yIcon, Glyph);
    xText := xIcon + imgW + gap;
  end
  else
    xText := xStart;

  // Caption rectangle shifted vertically by OffsetY
  case Alignment of
    taRightJustify:
      r := Rect(xText, FOffsetY, ClientWidth - gap, ClientHeight + FOffsetY);
    taCenter:
      r := Rect(xText, FOffsetY, ClientWidth - xStart, ClientHeight + FOffsetY);
  else // taLeftJustify
    r := Rect(xText, FOffsetY, ClientWidth - gap, ClientHeight + FOffsetY);
  end;

  // Draw caption centered vertically inside the shifted rectangle
  ts := Canvas.TextStyle;
  ts.Alignment := taLeftJustify; // text always left-aligned inside its rect
  ts.Layout := tlCenter;
  Canvas.TextRect(r, r.Left, r.Top, Caption, ts);
end;

end.
