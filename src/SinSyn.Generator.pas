unit SinSyn.Generator;

{
  Delphi version of the excellent Javascript code by Christian d'Heureuse

  https://github.com/chdh/sin-syn (MIT license)

  https://github.com/tothpaul/Delphi-SinSyn

  2022-10-16

}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Math;

type
  TGeneratorComponent = record
    frequency: Single;
    amplitude: Single;
    phase: Single;
  end;

  TGenerator = record
    duration: Single;
    fadingDuration: Single;
    components: TArray<TGeneratorComponent>;
    amplitudes: TArray<Single>;
    phases: TArray<Single>;
    omega: TArray<Single>;
    fadeinPos: Single;
    fadeoutPos: Single;
    procedure createGeneratorFunction;
    function GetValue(t: Single): Single;
    procedure normalizeMaxAmplitude(var amplitudes: TArray<Single>; maxOverallAmplitude: Single);
    procedure limitMaxPower(var amplitudes: TArray<Single>; maxOverallPower: Single);
    function getMaxFrequency: Single;
    function getMaxAmplitude: Single;
    function findFrequency(f: Single; start: Integer): Integer;
    function GCD: Single;
  end;

  TUiParms = record
    components: string;
    duration: Single; // 0..1000
    fadingDuration: Single;
//    reference: string;
    spectrumXMin: Single;
    spectrumXMax: Single;
    spectrumYMin: Single;
    spectrumYMax: Single;
    function getGenerator: TGenerator;
  end;

implementation

function parseComponentParmsString(const s: string): TArray<TGeneratorComponent>;

var
  p: Integer;

  procedure skipBlanks;
  begin
    while (p <= Length(s)) and (s[p] = ' ') do
      Inc(p);
  end;

  function parseNumber: Single;
  begin
    var p0 := p;
    if CharInSet(s[p], ['+', '-']) then
      Inc(p);
    while p <= Length(s) do
    begin
      var c := s[p];
      if (c <> '.') and ((c < '0') or (c > '9')) then
        Break;
      Inc(p);
    end;
    Result := StrToFloat(Copy(s, p0, p - p0), TFormatSettings.Invariant);
  end;

var
  Comp: TGeneratorComponent;

  procedure AddComp();
  begin
    var l := Length(Result);
    for var i := 0 to l - 1 do
    begin
      if Result[i].frequency > Comp.frequency then
      begin
        Insert(Comp, Result, i);
        Exit;
      end;
    end;
    SetLength(Result, l + 1);
    Result[l] := comp;
  end;

begin
  Result := nil;
  p := 1;
  var lastAbsoluteFrequency: Single := 1;
  while p < Length(s) do
  begin
    skipBlanks;
    if p > Length(s) then
      Break;
    var frequencyIsRelative := False;
    if s[p] = '*' then
    begin
      frequencyIsRelative := True;
      Inc(p);
    end;
    var frequency: Single := parseNumber;
    if frequency < 0 then
      raise Exception.Create('Negative frequency value in components string');
    if frequencyIsRelative then
      frequency := frequency * lastAbsoluteFrequency
    else
      lastAbsoluteFrequency := frequency;
    skipBlanks;
    var amplitude: Single := 0;
    var phase: Single := 0;
    if (p <= Length(s)) and (s[p] = '/') then
    begin
      Inc(p);
      skipBlanks;
      amplitude := parseNumber;
      skipBlanks;
      if (p <= Length(s)) and (s[p] = '/') then
      begin
        Inc(p);
        skipBlanks;
        phase := parseNumber;
      end;
    end;
    Comp.frequency := frequency;
    Comp.amplitude := amplitude;
    Comp.phase := phase;
    AddComp();
    skipBlanks;
    if (p <= Length(s)) and (s[p] = ',') then
      Inc(p);
  end;
end;

{ TUiParms }

function TUiParms.getGenerator: TGenerator;
begin
  Result.duration := duration;
  Result.fadingDuration := fadingDuration;
  Result.components := parseComponentParmsString(components);
end;

{ TGenerator }

function fadingFactor(t: Single): Single;
begin
  Result := power(t, 2 * (1 - t));
end;

procedure TGenerator.createGeneratorFunction;
begin
  var n := Length(components);
  fadeinPos := Min(fadingDuration, duration / 2);
  fadeOutPos := Max(duration - fadingDuration, duration / 2);
  SetLength(amplitudes, n);
  for var i := 0 to n - 1 do
    amplitudes[i] := Power(10, components[i].amplitude / 20);
  normalizeMaxAmplitude(amplitudes, 0.99);
  limitMaxPower(amplitudes, 0.5);
  SetLength(phases, n);
  for var i := 0 to n - 1 do
    phases[i] := 2 * PI * components[i].phase;
  SetLength(omega, n);
  for var i := 0 to n - 1 do
    omega[i] := 2 * PI * components[i].frequency;
end;

function TGenerator.findFrequency(f: Single; start: Integer): Integer;
begin
  Result := start;
  while (Result < length(Components) - 1) and (Components[Result].frequency < f) do
  begin
    Inc(Result);
  end;
end;

function fmod(a, b: Single): Single;
begin
  var c: Single := Trunc(a / b);
  Result := a - b * c;
end;

function TGenerator.GCD: Single;
const
  eps1 = 1e-4;
  eps2 = 1e-7;
begin
  var n := Length(components);
  if n = 0 then
    Exit(0);

(*
// 2.14, 235.5, 706.5, 1177.5, 1648.5, 2119.5, 2590.5, 3061.5
*)
  var v: Int64 := Round(components[0].frequency * 1000);
  for var i := 1 to n - 1 do
  begin
    var a := v;
    var b: Int64 := Round(components[i].frequency * 1000);
    if a < b then
    begin
      a := b;
      b := v;
    end;
    while b > 0 do
    begin
      var r := a mod b;
      if r = 0 then
      begin
        v := b;
        break;
      end;
      a := b;
      b := r;
    end;
  end;
  Result := v / 1000;

//
//  Result := components[0].frequency;
//  for var i := 1 to n - 1 do
//  begin
//    var a := Result;
//    var b := components[i].frequency;
//    if a < b then
//    begin
//      a := b;
//      b := Result;
//    end;
//    while b > eps1 do
//    begin
//      var r := FMod(a, b);
//      if r < eps2 then
//      begin
//        Result := b;
//        break;
//      end;
//      a := b;
//      b := r;
//    end;
//  end;

end;

function TGenerator.GetValue(t: Single): Single;
begin
  Result := 0;
  if (t < 0) or (t > duration) then
    Exit;
  for var i := 0 to Length(phases) - 1 do
  begin
    Result := Result + sin(phases[i] + t * omega[i]) * amplitudes[i];
  end;
  if t < fadeInPos then
    Result := Result * fadingFactor(t / fadingDuration)
  else
  if t > fadeOutPos then
    Result := Result * fadingFactor((duration - t) / fadingDuration);
end;

function TGenerator.getMaxAmplitude: Single;
begin
  var N := Length(Components);
  if N = 0 then
    Exit(0);
  Result := components[0].amplitude;
  for var i := 1 to N - 1 do
    Result := max(Result, components[i].amplitude);
end;

function TGenerator.getMaxFrequency: Single;
begin
  var N := Length(Components);
  if N = 0 then
    Exit(0);
  Result := components[N - 1].frequency;
end;

procedure TGenerator.limitMaxPower(var amplitudes: TArray<Single>;
  maxOverallPower: Single);
begin
  var power: Double := 0;
  for var i := 0 to Length(amplitudes) - 1 do
    power := power + System.Math.Power(amplitudes[i], 2);
  if power <= maxOverallPower then
    Exit;
  var f := sqrt(maxOverallPower / power);
  for var i := 0 to Length(amplitudes) - 1 do
    amplitudes[i] := amplitudes[i] * f;
end;

procedure TGenerator.normalizeMaxAmplitude(var amplitudes: TArray<Single>;
  maxOverallAmplitude: Single);
begin
  var a: Double := 0;
  for var i := 0 to Length(amplitudes) - 1 do
  begin
    a := a + Abs(amplitudes[i]);
  end;
  if Abs(a) < 0.001 then
    Exit;
  var f := maxOverallAmplitude / a;
  for var i := 0 to Length(amplitudes) - 1 do
  begin
    amplitudes[i] := amplitudes[i] * f;
  end;
end;


end.
