unit SinSyn.Graphs;

{
  Delphi version of the excellent Javascript code by Christian d'Heureuse

  https://github.com/chdh/sin-syn (MIT license)

  https://github.com/tothpaul/Delphi-SinSyn

  2022-10-16

}

interface

uses
  System.Types,
  System.SysUtils,
  System.Math,
  Vcl.Graphics,
  SinSyn.Generator;

type
  TGridParams = record
    space: Single;
    span: Integer;
    pos: Single;
    decPow: Single;
  end;

  TGraph = record
    canvas: TCanvas;
    rect: TRect;
    gridEnabled: Boolean;
    xMin, xMax: Single;
    yMin, yMax: Single;
    xAxisUnit: string;
    yAxisUnit: string;
    procedure paint;
    procedure clearCanvas;
    procedure drawGrid;
    procedure gridOrLabels(labels, xy: Boolean);
    function getGridParams(xy: Boolean; var params: TGridParams): Boolean;
    function getZoomFactor(xy: Boolean): Single;
    function mapLogicalToCanvasXCoordinate(lx: Single): Single;
    function mapLogicalToCanvasYCoordinate(ly: Single): Single;
    function mapCanvasToLogicalXCoordinate(cx: Single): Single;
    procedure drawGridLine(p, cPos: Single; xy: Boolean);
    procedure drawLabel(cPos, value, decPow: Single; xy: Boolean);
    function formatLabel(value, decPow: Single; xy: Boolean): string;
    procedure drawCurve(const Generator: TGenerator);
    procedure drawSpectrum(const Generator: TGenerator);
  end;

implementation

{ TGraph }

procedure TGraph.clearCanvas;
begin
  canvas.Brush.Color := clWhite;
  canvas.Pen.Color := $aaaaaa;
  canvas.Pen.Width := 1;
  canvas.Rectangle(rect);
  canvas.Pen.Color := $f5f5f5;
end;

procedure TGraph.drawGrid;
begin
  canvas.Font.Color := $aaaaaa;
  canvas.Font.Size := 8;
  gridOrLabels(false, false);
  gridOrLabels(false, true);
  gridOrLabels(true, false);
  gridOrLabels(true, true);
end;

procedure TGraph.drawGridLine(p, cPos: Single; xy: Boolean);
var
  x1, y1, x2, y2: Integer;
begin
  if xy then
  begin
    x1 := Round(cPos);
    if x1 = 0 then
      Exit;
    y1 := 1;
    x2 := x1;
    y2 := rect.Height - 1;
  end else begin
    x1 := 1;
    y1 := Round(cpos);
    x2 := rect.Width - 1;
    y2 := y1;
  end;
  var color := Round(p);
  if color = 0 then
    color := $989898
  else
  if (color mod 10) = 0 then
    color := $d4d4d4
  else
    color := $eeeeee;
  canvas.Pen.Color := color;

  canvas.MoveTo(x1, y1);
  canvas.LineTo(x2, y2);
end;

procedure TGraph.drawLabel(cPos, value, decPow: Single; xy: Boolean);
var
  x, y: Integer;
  s: string;
begin
  if xy then
  begin
    x := Round(cPos + 5);
    y := rect.Height - 16;
  end else begin
    x := 5;
    y := Round(cPos - 16);
  end;
  s := formatLabel(value, decPow, xy);
  canvas.TextOut(x, y, s);
end;

function TGraph.formatLabel(value, decPow: Single; xy: Boolean): string;
begin
  if (decPow < 7) and (decPow >= -6) then
    Result := FloatToStrF(value, TFloatFormat.ffFixed, 14, Max(0, -Round(decPow)))
  else
    Result := FloatToStr(value);
   if Length(Result) > 10 then
     Result := FloatToStrF(value, TFloatFormat.ffExponent, 5, 2);
   if xy then
     Result := Result + xAxisUnit
   else
     Result := Result + yAxisUnit;
end;

function TGraph.getGridParams(xy: Boolean; var params: TGridParams): Boolean;
const
  minSpaceC: array[False..True] of Integer = (50, 66);
var
  edge, edgeDecPow: Single;
begin
  if xy then
    edge := xMin
  else
    edge := yMin;
  var minSpaceL := minSpaceC[xy] / getZoomFactor(xy);
  params.decPow := ceil(LN(minSpaceL / 5) / LN(10));
  if Abs(edge) < 0.001 then
    edgeDecPow := -99
  else
    edgeDecPow := LN(Abs(edge)) / LN(10);
  if edgeDecPow - params.DecPow > 10 then
    Exit(False);
  params.space := Power(10 , params.decPow);
  var f := minSpaceL / params.space;
  if f > 2.001 then
    params.span := 5
  else
  if f > 1.001 then
    params.span := 2
  else
    params.span := 1;
  var p1 := ceil(edge/params.space);
  params.pos := params.span * ceil(p1 / params.span);
  Result := True;
end;

function TGraph.getZoomFactor(xy: Boolean): Single;
begin
  if xy then
    Result := (rect.Width - 2) / (xMax - xMin)
  else
    Result := (rect.Height - 2) / (yMax - yMin);
end;

procedure TGraph.gridOrLabels(labels, xy: Boolean);
var
  gp: TGridParams;
  lPos, cPos: Single;
begin
  if not getGridParams(xy, gp) then
    Exit;
  var p := gp.pos;
  for var loopCtr := 0 to 100 do
  begin
    lPos := p * gp.space;
    if xy then
    begin
      cPos := mapLogicalToCanvasXCoordinate(lPos);
      if cPos >= rect.width then
        Break;
    end else begin
      cPos := mapLogicalToCanvasYCoordinate(lPos);
      if cPos <= 0 then
        Break;
    end;
    if labels then
      drawLabel(cPos, lPos, gp.decPow, xy)
    else
      drawGridLine(p, cPos, xy);
    p := p + gp.span;
  end;
end;

function TGraph.mapCanvasToLogicalXCoordinate(cx: Single): Single;
begin
  Result := xMin + cx * (xMax - xMin) / rect.width;
end;

function TGraph.mapLogicalToCanvasXCoordinate(lx: Single): Single;
begin
  Result := (lx - xMin) * rect.Width / (xMax - xMin);
end;

function TGraph.mapLogicalToCanvasYCoordinate(ly: Single): Single;
begin
  Result := rect.Height - (ly - yMin) * rect.Height / (yMax - yMin);
end;

procedure TGraph.paint;
begin
  clearCanvas;
  if gridEnabled then
    drawGrid;
end;

procedure TGraph.drawCurve(const Generator: TGenerator);
begin
  canvas.Pen.Color := $47cc47;
  canvas.Pen.Width := 2;
  for var cx := 1 to rect.Width - 1 do
  begin
    var lx := mapCanvasToLogicalXCoordinate(cx + 0.5);
    var ly := Generator.GetValue(lx);
    var cy := Round(max(-1E6, min(1E6, mapLogicalToCanvasYCoordinate(ly))));
    if cx = 1 then
      Canvas.MoveTo(cx, cy)
    else
      Canvas.LineTo(cx, cy);
  end;
end;

procedure TGraph.drawSpectrum(const Generator: TGenerator);
begin
  canvas.Pen.Color := $47cc47;
  canvas.Pen.Width := 3;
  var sampleWidth := (xMax - xMin) / (rect.Width - 2) / 3*2;
  var n := Length(Generator.components);
  var p := 0;
  for var cx := 1 to rect.Width - 1 do
  begin
    var lx := mapCanvasToLogicalXCoordinate(cx + 0.5);

    var fMin := lx - sampleWidth;
    p := Generator.findFrequency(fMin, p);
    var fMax := lx + sampleWidth;
    var maxAmplitude: Single;
    var found := False;
    while (p < n) and (Generator.components[p].frequency < fMax) do
    begin
      var amplitude := Generator.components[p].amplitude;
      if found then
        maxAmplitude := max(amplitude, maxAmplitude)
      else begin
        maxAmplitude := amplitude;
        found := True;
      end;
      Inc(p);
    end;
    if not found then
      Continue;
    var ly := maxAmplitude;

    var cyLo0 := max(-1, min(rect.Height - 1, Round(mapLogicalToCanvasYCoordinate(ly))));
    var cyHi0 := max(-1, min(rect.Height - 1, mapLogicalToCanvasYCoordinate(-1e+99)));
    var cyLo1 := cyLo0;
    var cyHi1 := ceil(cyHi0);
    var cyLo2 := cyLo1;
    var cyHi2 := max(cyHi1, cyLo1 + 1);
    Canvas.MoveTo(cx, cyLo2);
    Canvas.LineTo(cx, cyHi2);
  end;
end;

end.
