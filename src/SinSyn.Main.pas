unit SinSyn.Main;

{
  Delphi version of the excellent Javascript code by Christian d'Heureuse

  https://github.com/chdh/sin-syn (MIT license)

  https://github.com/tothpaul/Delphi-SinSyn

  2022-10-16

}

interface

{$DEFINE WAVE_FORMAT_IEEE_FLOAT}  // use Float wav instead of 16bits

uses
  Winapi.Windows, Winapi.Messages, Winapi.MMSystem,
  System.SysUtils, System.Variants, System.Classes, System.Math,
  System.IOUtils, System.JSON.Serializers,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  SinSyn.Graphs, SinSyn.Generator;

type
  TWaveChunkHeader = packed record
    ckID           : array[0..3] of AnsiChar;
    ckSize         : Cardinal;
  end;

  TWaveFMT = packed record
    Header : TWaveChunkHeader; // 'fmt '
    Format : TWaveFormatEx;
  end;

  TWaveHeader = packed record
    RIFF  : TWaveChunkHeader;         // 'RIFF'
    WAVEID: array [0..3] of AnsiChar; // 'WAVE'
    FMT   : TWaveFMT;                 // 'fmt '
    Data  : TWaveChunkHeader;         // 'data'
  end;

  TSampleType = {$IFDEF WAVE_FORMAT_IEEE_FLOAT}Single{$ELSE}SmallInt{$ENDIF};
  TWaveData = array of TSampleType;

  TWaveInfo = record
    Header: TWaveHdr;
    Data  : TWaveData;
    procedure Setup(WaveOut: HWaveOut; SampleRate: Cardinal);
  end;

  TConfiguration = record
    Reference: string;
    uiParms: TUiParms;
  end;
  TConfigurations = TArray<TConfiguration>;

  TMain = class(TForm)
    Label1: TLabel;
    Panel1: TPanel;
    Label2: TLabel;
    edComponents: TEdit;
    Panel2: TPanel;
    Label3: TLabel;
    cbReference: TComboBox;
    edFadings: TEdit;
    Label4: TLabel;
    edDuration: TEdit;
    Label5: TLabel;
    Panel3: TPanel;
    lbHighestFactor: TLabel;
    btPlay: TButton;
    btWAVFile: TButton;
    Label7: TLabel;
    spectrumView: TPaintBox;
    curveView: TPaintBox;
    pnSpectrumView: TPanel;
    pnCurveView: TPanel;
    pnOptions: TPanel;
    pnButtons: TPanel;
    Label11: TLabel;
    lbRange: TLabel;
    pnRange: TPanel;
    edAmp1: TEdit;
    edFreq2: TEdit;
    edAmp2: TEdit;
    edFreq1: TEdit;
    Label10: TLabel;
    Label6: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    procedure spectrumViewPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure curveViewPaint(Sender: TObject);
    procedure btPlayClick(Sender: TObject);
    procedure lbRangeClick(Sender: TObject);
    procedure btWAVFileClick(Sender: TObject);
    procedure cbReferenceChange(Sender: TObject);
  private
    { Déclarations privées }
    WaveOut: HWaveOut;
    Waves  : array[0..1] of TWaveInfo;
    PlayWav: Integer;
    spectrumGraph: TGraph;
    curveGraph: TGraph;
    Generator: TGenerator;
    Configurations: TConfigurations;
    procedure createAudioBufferFromUiParms;
    function getUiParms: TUiParms;
    procedure setUiParms(const UiParms: TUiParms);
    procedure PlaySound(const gParms: TGenerator);
    procedure Refresh;
  public
    { Déclarations publiques }
  end;

var
  Main: TMain;

implementation

{$R *.dfm}

const
  CONF_FILE = 'SinSyn.json';

function RoundUp10(x: Single): Single;
begin
  if x < 1E-99 then
    Result := 1
  else begin
    var u := Power(10, Floor(Log10(x)));
    Result := ceil(x / u) * u;
  end;
end;

{ TWaveInfo }

procedure TWaveInfo.Setup(WaveOut: HWaveOut; SampleRate: Cardinal);
begin
  SetLength(Data, SampleRate);
  FillChar(Header, SizeOf(TWaveHdr), 0);
  Header.dwBufferLength := Length(Data) * SizeOf(TSampleType);
  Header.lpData := Pointer(Data);
  waveOutPrepareHeader(WaveOut, @Header, SizeOf(TWaveHdr));
end;

procedure SetupFormat(var Format: TWaveFormatEx);
begin
{$IFDEF WAVE_FORMAT_IEEE_FLOAT}
  Format.wFormatTag      := 3;
{$ELSE}
  Format.wFormatTag      := WAVE_FORMAT_PCM;
{$ENDIF}
  Format.nChannels       := 1;
  Format.nSamplesPerSec  := 48000;
  Format.wBitsPerSample  := 8 * SizeOf(TSampleType);
  Format.nBlockAlign     := Format.nChannels * SizeOf(TSampleType);
  Format.nAvgBytesPerSec := Format.nSamplesPerSec * Format.nBlockAlign;
  Format.cbSize          := 0;
end;

{ TMain }

procedure test;
var
  H: TWaveHeader;
  F: TFileStream;
begin
  F := TFileStream.Create('Sound.wav', fmOpenRead);
  try
    F.Read(H, SizeOf(H));
  finally
    F.Free;
  end;
end;

procedure TMain.FormCreate(Sender: TObject);
var
  WaveFormat: TWaveFormatEx;
begin
  test();
  SetupFormat(WaveFormat);

  if waveOutOpen(@WaveOut, WAVE_MAPPER, @WaveFormat, 0, 0, CALLBACK_NULL) = MMSYSERR_NOERROR then
  begin
    Waves[0].Setup(WaveOut, WaveFormat.nSamplesPerSec);
    Waves[1].Setup(WaveOut, WaveFormat.nSamplesPerSec);
  end;

  curveGraph.yMin := -1;
  curveGraph.yMax := +1;
  curveGraph.xAxisUnit := ' s';
  curveGraph.gridEnabled := True;

  spectrumGraph.xAxisUnit := ' Hz';
  spectrumGraph.yAxisUnit := ' dB';
  spectrumGraph.gridEnabled := True;

  var uiParms := getUiParms;
  Generator := uiParms.getGenerator;
  Generator.createGeneratorFunction;

  if Tfile.Exists(CONF_FILE) then
  begin
    var conf := TFile.ReadAllText(CONF_FILE);
    var json := TJsonSerializer.Create;
    try
      Configurations := json.Deserialize<TConfigurations>(conf);
    finally
      json.Free;
    end;
  end;
  if Configurations = nil then
  begin
    SetLength(Configurations, 5);

    Configurations[0].Reference := '440';
    Configurations[0].uiParms.components := '440';
    Configurations[0].uiParms.duration := 1;
    Configurations[0].uiParms.fadingDuration := 0.05;

    Configurations[1].Reference := '440 660 880';
    Configurations[1].uiParms.components := '440 660 880';
    Configurations[1].uiParms.duration := 1;
    Configurations[1].uiParms.fadingDuration := 0.05;

    Configurations[2].Reference := '440/0 660/-10 880/-20';
    Configurations[2].uiParms.components := '440/0 660/-10 880/-20';
    Configurations[2].uiParms.duration := 1;
    Configurations[2].uiParms.fadingDuration := 0.05;

    Configurations[3].Reference := 'clarinet-like';
    Configurations[3].uiParms.components := '235.5 *3/-2.5 *5/-6 *7/-17 *9/-6 *11/-18.4 *13/-15.4';
    Configurations[3].uiParms.duration := 1;
    Configurations[3].uiParms.fadingDuration := 0.15;

    Configurations[4].Reference := '3Hz beat';
    Configurations[4].uiParms.components := '440/0/0 443/0/0.5';
    Configurations[4].uiParms.duration := 1;
    Configurations[4].uiParms.fadingDuration := 0.05;
  end;

  for var i := 0 to Length(Configurations) - 1 do
    cbReference.Items.Add(Configurations[i].Reference);
end;

function TMain.getUiParms: TUiParms;
begin
  Result.components := edComponents.Text;
  Result.duration := StrToFloat(edDuration.Text);
  Result.fadingDuration := StrToFloat(edFadings.Text);
  Result.spectrumXMin := StrToFloatDef(edAmp1.Text, 0);
  Result.spectrumXMax := StrToFloatDef(edAmp2.Text, 0);
  Result.spectrumYMin := StrToFloatDef(edFreq1.Text, 0);
  Result.spectrumYMax := StrToFloatDef(edFreq2.Text, 0);
end;

procedure TMain.lbRangeClick(Sender: TObject);
begin
  pnRange.Enabled := not pnRange.Enabled;
  if pnRange.Enabled then
    pnOptions.Height := pnButtons.Height + pnRange.Height
  else
     pnOptions.Height := pnButtons.Height;
end;

procedure TMain.PlaySound(const gParms: TGenerator);
var
  Index: Integer;
begin
  PlayWav := 1 - PlayWav;
  with Waves[PlayWav] do
  begin
    for Index := 0 to Length(Data) - 1 do
    begin
    {$IFDEF WAVE_FORMAT_IEEE_FLOAT}
      Data[Index] := gParms.GetValue(Index * gParms.duration / Length(Data));
    {$ELSE}
      Data[Index] := Max(-32768, Min(32767, Round(32768 * gParms.generator(Index * gParms.duration / Length(Data)))));
    {$ENDIF}
    end;
    waveOutWrite(WaveOut, @Header, SizeOf(TWaveHdr));
  end;
end;

procedure TMain.setUiParms(const UiParms: TUiParms);
begin
  edComponents.Text := UiParms.components;
  edDuration.Text := FloatToStrF(UiParms.duration, TFloatFormat.ffFixed, 14, 2);
  edFadings.Text := FloatToStrF(UiParms.fadingDuration, TFloatFormat.ffFixed, 14, 2);
  edAmp1.Text := FloatToStrF(UiParms.spectrumXMin, TFloatFormat.ffFixed, 14, 2);
  edAmp2.Text := FloatToStrF(UiParms.spectrumXMax, TFloatFormat.ffFixed, 14, 2);
  edFreq1.Text := FloatToStrF(UiParms.spectrumYMin, TFloatFormat.ffFixed, 14, 2);
  edFreq2.Text := FloatToStrF(UiParms.spectrumYMax, TFloatFormat.ffFixed, 14, 2);
end;

procedure TMain.spectrumViewPaint(Sender: TObject);
begin
  spectrumGraph.xMin := 0;
  spectrumGraph.xMax := max(1E-99, RoundUp10(Generator.getMaxFrequency * 1.02));
  spectrumGraph.yMax := ceil(Generator.getMaxAmplitude / 10) * 10 + 5;
  spectrumGraph.yMin := spectrumGraph.yMax - 80;

  spectrumGraph.Rect := spectrumView.ClientRect;
  spectrumGraph.canvas := spectrumView.Canvas;
  spectrumGraph.paint;
  spectrumGraph.drawSpectrum(Generator);
end;

procedure TMain.btPlayClick(Sender: TObject);
begin
  createAudioBufferFromUiParms();
  PlaySound(Generator);
end;

procedure TMain.btWAVFileClick(Sender: TObject);
var
  header: TWaveHeader;
begin
// tags
  header.RIFF.ckID := 'RIFF';
  header.WAVEID := 'WAVE';
  header.FMT.Header.ckID := 'fmt ';
  header.Data.ckID := 'data';

// sizes
  header.FMT.Header.ckSize := SizeOf(header.FMT) - SizeOf(header.FMT.Header);
  header.Data.ckSize := Length(Waves[PlayWav].Data) * SizeOf(TSampleType);
  header.RIFF.ckSize := SizeOf(header) - SizeOf(header.RIFF) + header.Data.ckSize;

// format
  SetupFormat(header.FMT.Format);

  var wav := TFileStream.Create('Sound.wav', fmCreate);
  try
    wav.Write(header, SizeOf(header));
    wav.Write(Waves[PlayWav].Data[0], header.Data.ckSize);
  finally
    wav.Free;
  end;
end;

procedure TMain.cbReferenceChange(Sender: TObject);
begin
  var Index := cbReference.ItemIndex;
  if Index < 0 then
    Exit;
  SetUiParms(Configurations[Index].uiParms);
  Generator := Configurations[Index].uiParms.getGenerator;
  Refresh;
end;

procedure TMain.Refresh;
begin
  Generator.createGeneratorFunction;
  lbHighestFactor.Caption := FloatToStrF(Generator.GCD, TFloatFormat.ffFixed, 14, 2);
  curveView.Invalidate;
  spectrumView.Invalidate;
end;

procedure TMain.createAudioBufferFromUiParms;
begin
  var uiParms := getUiParms;
  Generator := uiParms.getGenerator;
  Refresh;
end;

procedure TMain.curveViewPaint(Sender: TObject);
begin
  var defaultXRange := 0.01;
  var defaultXMin := Min(Generator.fadingDuration, Generator.duration / 2 - defaultXRange / 2);
  curveGraph.xMin := defaultXMin;
  curveGraph.xMax := defaultXMin + defaultXRange;

  curveGraph.Rect := curveView.ClientRect;
  curveGraph.canvas := curveView.Canvas;
  curveGraph.paint;
  curveGraph.drawCurve(Generator);
end;

end.
