program HEF4543B; { Softwaresimulatie Philips-HEF4543B-chip (hersengymnastiek) }

uses CRT;

const
  Intro1 = 'Dit programma simuleert de Philips-HEF4543B-chip.';
  Intro2 = 'Het resultaat wordt op het scherm getoond.';
  BL     = 'Leeg cijfer      (BL=1) ? ';
  LD     = 'Cijfer weergeven (LD=1) ? ';
  PH     = 'Positieve fase   (PH=1) ? ';
  Again  = 'Nog eens ? ';

var
  DX      : array[1..4] of string;
  Blank   : boolean;
  D       : array[1..4] of boolean;
  LatchD,
  Phase   : boolean;
  Step1   : array[1..6] of boolean;
  Step2   : array[1..8] of boolean;
  Step3   : array[1..8] of boolean;
  Step4   : array[1..4] of boolean;
  Step5   : array[1..9] of boolean;
  Step6   : boolean;
  Step7   : array[1..7] of boolean;
  Step8   : array[1..7] of boolean;
  O       : array[1..7] of boolean;

{ **************************************************************************** }

procedure Init;
var
  i : byte;
begin
  for i  := 1 to 4 do
     DX[i] := 'Bit '+chr(48+i)+' actief     (D'+chr(64+i)+'=1) ? ';
  ClrScr;
  writeln(Intro1);
  writeln(Intro2);

  for i := 1 to 8 do Step3[i] := false; { In begin geen spanning }
end;

{ **************************************************************************** }

function Inquire_JNAntw(msg : string) : boolean;
var
  b : char;
begin
  write(msg, ' :');
  readln(b);
  Inquire_JNAntw := (b = 'J') or (b = 'j') or (b = '1'); 
end;

{ **************************************************************************** }

procedure GetInput;
var
  i : byte;
begin
  GoToXY(1,4);
  Blank  := Inquire_JNAntw(BL);
  for i  := 1 to 4 do D[i] := Inquire_JNAntw(DX[i]);
  LatchD := Inquire_JNAntw(LD);
  Phase  := Inquire_JNAntw(PH);
end;

{ **************************************************************************** }

procedure ShowValues(YCor,Count : byte; offset : word);
var
  i : word;
begin
  GoToXY(70,YCor);
  for i := 0 to Count-1 do write(chr(48{+mem[DSeg:Offset+i]}));
end;

{ **************************************************************************** }

procedure NORFlipflop(S,R : boolean; var Q,QInv : boolean);
begin
  if S or R then begin
    if S <> R then begin
      Q := S;
      QInv := R;
    end;
  end;
end;
{ S  R  Q \Q
  0  0  Q \Q
  0  1  0  1
  1  0  1  0
  1  1  X  X  }

{ **************************************************************************** }

procedure ProcessData;
var
  i : byte;
begin

  { Inverteer alles (buffer) : ok }
  Blank  := not Blank;
  for i  := 1 to 4 do D[i] := not D[i];
  LatchD := not LatchD;
  Phase  := not Phase;
  ShowValues(3,7,ofs(Blank));

  { Stap 1,verkrijg de originelen : ok }
  for i    := 1 to 4 do Step1[i] := not D[i];
  Step1[5] := not LatchD;
  Step1[6] := not Phase;
  ShowValues(4,6,ofs(Step1));

  { Stap 2 :  ok }
  Step2[1] := D    [1] and Step1[5];
  Step2[2] := Step1[5] and Step1[1];
  Step2[3] := D    [2] and Step1[5];
  Step2[4] := Step1[5] and Step1[2];
  Step2[5] := D    [3] and Step1[5];
  Step2[6] := Step1[5] and Step1[3];
  Step2[7] := D    [4] and Step1[5];
  Step2[8] := Step1[5] and Step1[4];
  ShowValues(5,8,ofs(Step2));

  { Stap 3 : ok }
  NORFlipflop(Step2[2],Step2[1],Step3[1],Step3[2]);
  NORFlipflop(Step2[4],Step2[3],Step3[3],Step3[4]);
  NORFlipflop(Step2[6],Step2[5],Step3[5],Step3[6]);
  NORFlipflop(Step2[8],Step2[7],Step3[7],Step3[8]);
  ShowValues(6,8,ofs(Step3));

  { Stap 4 : ok }
  Step4[1] := not (Step3[3] and Step3[5]);
  Step4[2] := not (Step3[4] and Step3[5]);
  Step4[3] := not (Step3[3] and Step3[6]);
  Step4[4] := not (Step3[6] and Step3[4]);
  ShowValues(7,4,ofs(Step4));

  { Stap 5 : ok }
  Step5[1] := not (Step3[7] and Step4[4]);
  Step5[2] := not (Step3[2] or  Step4[1]);
  Step5[3] := not (Step4[1] or  Step3[1]);
  Step5[4] := not (Step3[2] or  Step4[2]);
  Step5[5] := not (Step4[2] or  Step3[1]);
  Step5[6] := not  Step4[3];
  Step5[7] := not (Step4[3] or  Step3[1]);
  Step5[8] := not (Step3[2] or  Step4[4] or Step3[7]);
  Step5[9] := not (Step4[4] or  Step3[7]);
  ShowValues(8,9,ofs(Step5));

  { Stap 6 : ok }
  Step6 := not (Blank and Step5[1]);
  ShowValues(9,1,ofs(Step6));

  { Stap 7 : ok }
  Step7[1] := not (Step6 or Step5[5] or Step5[8]);
  Step7[2] := not (Step6 or Step5[3] or Step5[4]);
  Step7[3] := not (Step6 or Step5[7]);
  Step7[4] := not (Step6 or Step5[2] or Step5[8] or Step5[5]);
  Step7[5] := not (Step6 or Step3[1] or Step5[5]);
  Step7[6] := not (Step6 or Step5[2] or Step5[6] or Step5[8]);
  Step7[7] := not (Step6 or Step5[2] or Step5[9]);
  ShowValues(10,7,ofs(Step7));

  { Stap 8 : ok }
  for i := 1 to 7 do Step8[i] := not (Step7[i] xor Step1[6]);
  ShowValues(11,7,ofs(Step8));

  { Verkrijg de uitvoer : ok }
  for i := 1 to 7 do O[i] := not Step8[i];

end;

{ **************************************************************************** }

procedure ShowOutPut;
var
  i : byte;
begin

  writeln;
  write('De uitvoerbits (Oa..Og) zijn : ');
  for i := 1 to 7 do write(chr(48+ord(O[i])));

  TextColor(10*ord(O[1])+5); { a }
  GoToXY(2,14);
  write('ﬂﬂﬂﬂ');

  TextColor(10*ord(O[6])+5); { f }
  GoToXY(1,14);
  write('€');
  GoToXY(1,15);
  write('€');
  GoToXY(1,16);
  write('€');

  TextColor(10*ord(O[2])+5); { b }
  GoToXY(6,14);
  write('€');
  GoToXY(6,15);
  write('€');
  GoToXY(6,16);
  write('€');

  TextColor(10*ord(O[7])+5); { g }
  GoToXY(1,17);
  write('€€€€€€');

  TextColor(10*ord(O[5])+5); { e }
  GoToXY(1,18);
  write('€');
  GoToXY(1,19);
  write('€');
  GoToXY(1,20);
  write('€');

  TextColor(10*ord(O[3])+5); { c }
  GoToXY(6,18);
  write('€');
  GoToXY(6,19);
  write('€');
  GoToXY(6,20);
  write('€');

  TextColor(10*ord(O[4])+5); { d }
  GoToXY(2,20);
  write('‹‹‹‹');

  GoToXY(1,22);
  TextColor(7); { Laat het scherm in normale toestand achter ! }

end;

{ **************************************************************************** }

begin
  Init;
  repeat
    GetInput;
    ProcessData;
    ShowOutput;
  until not Inquire_JNAntw(Again);
end.
