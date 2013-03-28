program WZ2;

uses CRT, sysutils;

type
  PLetter = ^TLetter;
  TLetter = record
    Letter : char;
    Used   : byte;
    Prev,
    Next   : PLetter;
  end;

  PLine = ^TLine;
  TLine = record
    FLetter,
    CLetter : PLetter;
    Prev,
    Next    : PLine;
  end;

  PWord = ^TWord;
  TWord = record
    InWord  : string;
    TooLong : boolean;
    Next    : PWord;
  end;

const { bit markers }
  Left     = $01; Right     = $10;
  Up       = $02; Down      = $20;
  LeftUp   = $04; RightDown = $40;
  LeftDown = $08; RightUp   = $80;

var
  FLine,
  CLine       : PLine;
  FWord,
  CWord       : PWord;
  OKDirs,
  x,y,w,h,              { diagram shouldn't exceed 255x255 chars }
  l,i,p       : byte;
  Limit       : word;
  InFile,
  OutFile     : text;
  LSTFName,
  DGRFName,
  OutFName,
  InFLine,
  DirSol,
  Solution    : string; { max 255 chars }
  FoundFirst,
  Found       : boolean;
  InAns       : char;

{ **************************************************************************** }

procedure InsertWord; { sort words on length, longest first }

var
  NWord : PWord;

begin
  new(NWord);
  with NWord^ do
  begin
    InWord  := InFLine;
    TooLong := (l > h) and (l > w);
  end;

  if FWord = nil then { first item }
  begin
    NWord^.Next := nil;
    FWord       := NWord;
    CWord       := NWord;
  end else
  begin
    if l >= length(FWord^.InWord) then { add before first }
    begin
      NWord^.Next := FWord;
      FWord       := NWord;
      CWord       := NWord;
    end else
    begin { insert or add after last }
      CWord := FWord;
      while (l < length(CWord^.InWord)) and (l < length(CWord^.Next^.InWord))
         and (CWord^.Next <> nil) do CWord := CWord^.Next;

      NWord^.Next := CWord^.Next;
      CWord^.Next := NWord;
    end;
  end;
end;

{ **************************************************************************** }

procedure AddLine;

var
  NLine : PLine;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

procedure AddLetter(InChar : char);

var
  NLetter : PLetter;

begin
  new(NLetter);
  with NLetter^ do
  begin
    Letter := InChar;
    if Letter = '.' then Used := $FF else Used := 0; { all 8 directions used in
                                            case of dot, otherwise all 8 free }
    Prev   := nil;
    Next   := nil;
  end;

  if NLine^.FLetter = nil then NLine^.FLetter := NLetter else
  begin
    NLine^.CLetter^.Next := NLetter;
    NLetter^.Prev := NLine^.CLetter;
  end;
  NLine^.CLetter := NLetter;
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

begin
  new(NLine);
  with NLine^ do
  begin
    NLine^.FLetter := nil;
    for x := 1 to w do AddLetter(InFline[x]);
    Prev := nil;
    Next := nil;
  end;

  if FLine = nil then FLine := NLine else
  begin
    CLine^.Next := NLine;
    NLine^.Prev := CLine;
  end;
  CLine := NLine;

  inc(y); { count lines }
  if y = 0 then
  begin
    writeln('Too many lines in diagram !');
    close(InFile);
    halt;
  end;
end;

{ **************************************************************************** }

procedure InitVars;
begin
  y        := 0; { vertical position }
  w        := 0; { line length for all lines in diagram }
  FLine    := nil;
  FWord    := nil;
  Solution := '';
end;

{ **************************************************************************** }

function GetYNAns(Msg : string) : boolean;
begin
  write(Msg,' ? (Y/N) : ');
  repeat
    InAns := upcase(ReadKey);
    if InAns = #0 then
    begin
      InAns := ReadKey;
      InAns := #0;
    end; { flush extended key }
    Found := (InAns in ['N','Y']);
  until Found;
  writeln(InAns);
  GetYNAns := (InAns = 'Y');
end;

{ **************************************************************************** }

procedure GetLSTFile;
begin
  write('Enter list file name [.LST] : ');
  readln(LSTFName);
  for i := 1 to length(LSTFName) do LSTFName[i] := upcase(LSTFName[i]);
  if pos('.'  ,LSTFName) = 0   then LSTFName := LSTFName + '.'  ;
  if pos('LST',LSTFName) = 0   then LSTFName := LSTFName + 'LST';
  if not FileExists(LSTFName) then
  begin
    writeln(LSTFName,' not found.');
    halt(2); { 2 = File Not Found }
  end;
end;

{ **************************************************************************** }

procedure GetDGRFile;
begin
  write('Enter diagram file name [.DGR] : ');
  readln(DGRFName);
  for i := 1 to length(DGRFName) do DGRFName[i] := upcase(DGRFName[i]);
  if pos('.'  ,DGRFName) = 0   then DGRFName := DGRFName + '.'  ;
  if pos('DGR',DGRFName) = 0   then DGRFName := DGRFName + 'DGR';
  if not FileExists(DGRFName) then
  begin
    writeln(DGRFName,' not found.');
    halt(2); { 2 = File Not Found }
  end;
end;

{ **************************************************************************** }

procedure GetOutFile;
begin
  write('Enter output file name [WZ2].[LST] : ');
  readln(OutFName);
  if OutFName = '' then OutFName := 'WZ2.LST';
  for i := 1 to length(OutFName) do OutFName[i] := upcase(OutFName[i]);
  if pos('.',OutFName) = 0 then OutFName := OutFName + '.LST';
  if (FileExists(OutFName)) and
     (not GetYNAns(OutFName+' already exists, overwrite')) then halt;
end;

{ **************************************************************************** }

procedure ReadDGRFile;
begin
  assign(InFile,DGRFName);
  reset(InFile);
  while not eof(InFile) do
  begin
    readln(InFile,InFLine);
    l := length(InFLine);
    if l > 0 then
    begin
      if w = 0 then w := l;
      if l = w then AddLine else
      begin
        writeln('Error : w = ',w,' l = ',l);
        close(InFile);
        halt;
      end;
    end;
  end;
  close(InFile);
  h := y;
  writeln('Diagram sizes : height = ',h,' width = ',w);
end;

{ **************************************************************************** }

procedure ReadLSTFile;
begin
  i := 0; { nr of words }
  assign(InFile,LSTFName);
  reset(InFile);
  while not eof(InFile) do
  begin
    readln(InFile,InFLine);
    p := pos('.',InFLine);
    if p > 0 then InFLine := copy(InFLine,1,p-1);
    l := length(InFLine);
    if l > 0 then
    begin
      InsertWord;
      inc(i);
    end;
  end;
  close(InFile);
  writeln(i,' words in .LST file');
end;

{ **************************************************************************** }

procedure Tell(Msg : string);
begin
  writeln(OutFile,'WZ2.PAS : ',Msg);
end;

{ **************************************************************************** }

procedure InitOutFile;
begin
  assign(OutFile,OutFName);
  rewrite(OutFile);
  Tell('input = '+DGRFName+' with '+LSTFName);
  writeln(OutFile);
  writeln(OutFile,'word':w,'  col  row direction');
end;

{ **************************************************************************** }

procedure DoneOutFile;
begin
  writeln(OutFile);
  if length(Solution) > 0 then Tell('solution = '+Solution)
                          else Tell('no letters left');
  close(OutFile);
  writeln('Output has been written to ',OutFName);
end;

{ **************************************************************************** }

procedure RestoreX;
begin
  CLine^.CLetter := CLine^.FLetter;
  for i := 2 to x do CLine^.CLetter := CLine^.CLetter^.Next;
end;

{ **************************************************************************** }

procedure MoveLeft;
begin
  if x > 1 then
  begin
    dec(x);
    CLine^.CLetter := CLine^.CLetter^.Prev;
  end;
end;

{ **************************************************************************** }

procedure MoveRight;
begin
  if x < w then
  begin
    inc(x);
    CLine^.CLetter := CLine^.CLetter^.Next;
  end;
end;

{ **************************************************************************** }

procedure MoveUp;
begin
  if y > 1 then
  begin
    dec(y);
    CLine := CLine^.Prev;
    RestoreX;
  end;
end;

{ **************************************************************************** }

procedure MoveDown;
begin
  if y < h then
  begin
    inc(y);
    CLine := CLine^.Next;
    RestoreX;
  end;
end;

{ **************************************************************************** }

procedure MoveLeftUp;
begin
  MoveLeft;
  MoveUp;
end;

{ **************************************************************************** }

procedure MoveRightDown;
begin
  MoveDown;
  MoveRight;
end;

{ **************************************************************************** }

procedure MoveLeftDown;
begin
  MoveLeft;
  MoveDown;
end;

{ **************************************************************************** }

procedure MoveRightUp;
begin
  MoveUp;
  MoveRight;
end;

{ **************************************************************************** }

procedure ToLeft;
begin
  while x > 1 do MoveLeft;
end;

{ **************************************************************************** }

procedure GoHome;
begin
  ToLeft;
  while y > 1 do MoveUp;
end;

{ **************************************************************************** }

procedure NextLetter;
begin
  inc(Limit);
  if x < w then MoveRight else
  begin
    ToLeft;
    MoveDown;
  end;
end;

{ **************************************************************************** }

procedure FindFirstLetter;
begin
  FoundFirst := false;
  while (not FoundFirst) and (Limit < h*w) do
  begin
    FoundFirst := (upcase(CLine^.CLetter^.Letter) = upcase(CWord^.InWord[1]));
    if not FoundFirst then NextLetter;
  end;
end;

{ **************************************************************************** }

procedure CheckDirs;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

function Min(a,b : byte) : byte;
begin
  if a < b then Min := a else Min := b;
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

begin
  OKDirs := 0; { all dirs false }
  if        x         >= l then OKDirs := OKDirs or Left;
  if      w-x+1       >= l then OKDirs := OKDirs or Right;
  if              y   >= l then OKDirs := OKDirs or Up;
  if            h-y+1 >= l then OKDirs := OKDirs or Down;
  if Min(  x  ,  y  ) >= l then OKDirs := OKDirs or LeftUp;
  if Min(w-x+1,h-y+1) >= l then OKDirs := OKDirs or RightDown;
  if Min(  x  ,h-y+1) >= l then OKDirs := OKDirs or LeftDown;
  if Min(w-x+1,  y  ) >= l then OKDirs := OKDirs or RightUp;
end;

{ **************************************************************************** }

procedure CheckWord;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

function Equal : boolean;
begin
  Equal := (upcase(CWord^.InWord[p]) = upcase(CLine^.CLetter^.Letter));
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

procedure Move(InDir : byte);
begin
  case InDir of
    Left      : MoveLeft;
    Right     : MoveRight;
    Up        : MoveUp;
    Down      : MoveDown;
    LeftUp    : MoveLeftUp;
    RightDown : MoveRightDown;
    LeftDown  : MoveLeftDown;
    RightUp   : MoveRightUp;
  end;
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

procedure MoveInv(InDir : byte);
begin
  case InDir of
    Left      : MoveRight;
    Right     : MoveLeft;
    Up        : MoveDown;
    Down      : MoveUp;
    LeftUp    : MoveRightDown;
    RightDown : MoveLeftUp;
    LeftDown  : MoveRightUp;
    RightUp   : MoveLeftDown;
  end;
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

function DirOK(InDir : byte) : boolean;

var
  OKDir : boolean;

begin
  OKDir := ((OKDirs and InDir) = InDir);
  if OKDir then
  begin
    { head on tail is allowed, second letterdirection has to be free }
    Move(InDir);
    OKDir := OKDir and ((CLine^.CLetter^.Used and InDir) = 0); { next 1 free }
    MoveInv(InDir);
  end;
  DirOK := OKDir;
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

procedure DoWord(InDir : byte; InDirSol : string);
begin
  if DirOK(InDir) then
  begin
    p := 1;
    while Equal and (p < l) do
    begin
      Move(InDir);
      inc(p);
    end;
    Found := ((p = l) and Equal);
    if Found then
    begin
      DirSol := InDirSol;
      OKDirs := 0; { cancel all other directions }
    end;
    while p > 0 do
    begin
      if Found then with CLine^.CLetter^ do Used := Used or InDir;
      if p > 1 then MoveInv(InDir);
      dec(p);
    end;
  end;
end;

{ * * * * * * * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * * }

begin
  DoWord(Left     ,'left'     );
  DoWord(Right    ,'right'    );
  DoWord(Up       ,'up'       );
  DoWord(Down     ,'down'     );
  DoWord(LeftUp   ,'leftup'   );
  DoWord(RightDown,'rightdown');
  DoWord(LeftDown ,'leftdown' );
  DoWord(RightUp  ,'rightup'  );
end;

{ **************************************************************************** }

procedure FindWord;
begin
  DirSol := '';
  Found  := false;
  Limit  := 0; { counter to prevent escape from diagram }
  l      := length(CWord^.InWord);
  write(OutFile,CWord^.InWord:w,' ');
  GoHome;
  while (not Found) and (Limit < h*w) do
  begin
    FindFirstLetter;
    if FoundFirst then
    begin
      CheckDirs;
      Found := (OKDirs > 0);
      if Found then
      begin
        Found := false;
        CheckWord;
      end;
      if Found then writeln(OutFile,x:4,' ',y:4,' ',DirSol)
               else NextLetter; { jump to next letter }
    end else
    begin
      Limit := h*w; { error ! }
      Tell('word not in diagram, skipped.');
    end;
  end;
end;

{ **************************************************************************** }

procedure GetSolution;
begin
  GoHome;
  Limit := 0; { the no-escape counter }
  while Limit < h*w do
  begin
    with CLine^.CLetter^ do
      if Used = 0 then Solution := Solution + Letter;
    NextLetter;
  end;
end;

{ **************************************************************************** }

procedure SolvePuzzle;
begin
  CWord := FWord;
  while CWord <> nil do
  begin
    if CWord^.TooLong then Tell(CWord^.InWord+' too long, skipped.')
                      else FindWord;
    CWord := CWord^.Next;
  end;
end;

{ **************************************************************************** }

begin
  writeln('WZ2.PAS, 2000-07-06 -- 2000-07-16 (c) René Ladan');
  GetLSTFile;
  GetDGRFile;
  GetOutFile;
  InitVars;
  ReadDGRFile;
  ReadLSTFile;
  if GetYNAns('Accept diagram sizes and number of words') then
  begin
    InitOutFile;
    SolvePuzzle;
    GetSolution;
    DoneOutFile;
  end;
end.
