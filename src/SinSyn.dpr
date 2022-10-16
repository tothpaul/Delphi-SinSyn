program SinSyn;

uses
  Vcl.Forms,
  SinSyn.Main in 'SinSyn.Main.pas' {Main},
  SinSyn.Graphs in 'SinSyn.Graphs.pas',
  SinSyn.Generator in 'SinSyn.Generator.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
