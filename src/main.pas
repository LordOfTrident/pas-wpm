program PasWPM;

uses SysUtils, StrUtils, DateUtils, NCurses;

type
	ColorPair = (
		ColorPair_Background = 1, ColorPair_Unselected,
		ColorPair_BottomBar,      ColorPair_UnselectedFade1,
		ColorPair_Main,           ColorPair_UnselectedFade2,
		ColorPair_Cursor,         ColorPair_UnselectedFade3,
		ColorPair_Paused,         ColorPair_Selected
	);

	State = (Running, Result, Quit);

const
	Color_Grey:          Integer = 8;
	Color_BrightRed:     Integer = 9;
	Color_BrightGreen:   Integer = 10;
	Color_BrightYellow:  Integer = 11;
	Color_BrightBlue:    Integer = 12;
	Color_BrightMagenta: Integer = 13;
	Color_BrightCyan:    Integer = 14;
	Color_BrightWhite:   Integer = 15;

	PausedTitle: PChar = '[ Press enter to pause/unpause, ^Q to quit ]';

	TestTime: Integer = 60;

	AllWords: array [0..77] of String = (
		'hello',       'what',     'because',     'since',      'operation', 'a',
		'meat',        'for',      'as',          'an',         'when',      'while',
		'hint',        'end',      'on',          'laugh',      'poor',      'none',
		'comprehense', 'imperial', 'fact',        'initialize', 'liberal',   'programming',
		'surreal',     'apple',    'peach',       'little',     'amazing',   'wonderful',
		'grip',        'window',   'door',        'sky',        'toxicity',  'cause',
		'anthem',      'computer', 'laptop',      'football',   'kick',      'word',
		'background',  'and',      'immediately', 'the',        'dog',       'heat',
		'zero',        'one',      'two',         'three',      'four',      'five',
		'six',         'seven',    'eight',       'nine',       'ten',       'size',
		'skill',       'test',     'chat',        'chair',      'far',       'still',
		'am',          'near',     'radio',       'also',       'stand',     'conservative',
		'extra',       'manager',  'old',         'new',        'sand',      'moon'
	);

var
	ScreenX, ScreenY: Integer;
	BottomBar, MainWindow, BackWindow: PWindow;

	Words: array of String;
	TypedWords:  Integer = 0;
	CurrentChar: Integer = 1;

	AppState: State   = Running;
	Paused:   Boolean = true;

	Input: Integer = 0;

	Second, PrevSecond, StartSecond: Word;

procedure Add8NewWords;
var i: Integer;
begin
	SetLength(Words, Length(Words) + 8);

	for i := 0 to 7 do
	begin
		Words[Length(Words) - 8 + i] := AllWords[Random(Integer(Length(AllWords)))];
	end;
end;

procedure DeleteFirstWord;
var i: Integer;
begin
	for i := 0 to Length(Words) - 1 do
		Words[i] := Words[i + 1];

	SetLength(Words, Length(Words) - 1);
end;

procedure ClearScreen;
begin
	WBkgdSet(BackWindow, Color_Pair(Integer(ColorPair_Background)));
	WErase(BackWindow);
	WRefresh(BackWindow);
end;

procedure Init;
begin
	{ initialize RandSeed }
	Randomize;

	{ basic ncurses init }
	InitScr;

	Raw;
	NoEcho;                { do not echo the input }
	KeyPad(StdScr,  True);
	TimeOut(-1);           { no time out on ESC press }
	NoDelay(StdScr, True); { no program pause on getch }
	Curs_Set(0);           { disable the cursor }

	ScreenX := GetMaxX(StdScr);
	ScreenY := GetMaxY(StdScr);

	{ init windows }
	BottomBar  := NewWin(1, ScreenX, ScreenY - 1,   0);
	MainWindow := NewWin(3, ScreenX, ScreenY div 2 - 2, 0);
	BackWindow := NewWin(ScreenY, ScreenX, 0, 0);
	Refresh;

	{ init colors }

	Start_Color;
	Use_Default_Colors;

	Init_Pair(Integer(ColorPair_Background), Color_White,      Color_Black);
	Init_Pair(Integer(ColorPair_Main),       Color_White,      Color_Black);
	Init_Pair(Integer(ColorPair_BottomBar),  Color_Black,      Color_White);
	Init_Pair(Integer(ColorPair_Cursor),     Color_BrightCyan, Color_Black);
	Init_Pair(Integer(ColorPair_Paused),     Color_Black,      Color_Magenta);

	Init_Pair(Integer(ColorPair_Selected),        Color_BrightYellow, Color_Black);
	Init_Pair(Integer(ColorPair_Unselected),      Color_BrightWhite,  Color_Black);
	Init_Pair(Integer(ColorPair_UnselectedFade1), Color_White,        Color_Black);
	Init_Pair(Integer(ColorPair_UnselectedFade2), Color_BrightBlue,   Color_Black);
	Init_Pair(Integer(ColorPair_UnselectedFade3), Color_Blue,         Color_Black);

	{ init words array }
	SetLength(Words, 0);
	Add8NewWords;

	{ init timer }
	StartSecond := DateTimeToUnix(Time);
	Second      := StartSecond;

	ClearScreen;
end;

procedure Finish;
begin
	EndWin;
end;

procedure RenderBottomBar;
var
	WPM:          PChar;
	EstimatedWPM: Double;
begin
	WBkgdSet(BottomBar, Color_Pair(Integer(ColorPair_BottomBar)));
	WErase(BottomBar);

	if AppState = Running then
		WPM := 'WPM: ?'
	else
		WPM := PChar('WPM: ' + IntToStr(TypedWords));

	if Second - StartSecond = 0 then
		EstimatedWPM := 0
	else
	begin
		EstimatedWPM := TypedWords / (Second - StartSecond) * TestTime;
		EstimatedWPM := Round(EstimatedWPM * 100) / 100;
	end;

	MvWAddStr(BottomBar, 0, 1,  PChar('Estimated WPM: ' + FloatToStr(EstimatedWPM)));
	MvWAddStr(BottomBar, 0, 24, WPM);
	MvWAddStr(BottomBar, 0, 37, PChar('Typed words: ' + IntToStr(TypedWords)));
	MvWAddStr(BottomBar, 0, 58, PChar('Time left: '   + IntToStr(TestTime -
	                                                             (Second - StartSecond))));

	WRefresh(BottomBar);
end;

procedure RenderMain;
var
	i, j: Integer;
	Position:     Integer = 2;
	WordPosition: Integer = 0;
	ResultTitle:  PChar;
label 1, 2;
begin
	WBkgdSet(MainWindow, Color_Pair(Integer(ColorPair_Main)));
	WErase(MainWindow);

	WMove(MainWindow, 1, Position);

	if AppState = Running then
	begin
		WAttrOn(MainWindow, Color_Pair(Integer(ColorPair_Selected)));

		1: for i:= WordPosition to Length(Words) - 1 do
		begin
			for j:= 1 to Length(Words[i]) do
			begin
				if Position >= ScreenX div 4 * 3 then
					WAttrOn(MainWindow, Color_Pair(Integer(ColorPair_UnselectedFade3)))
				else if Position >= ScreenX div 4 * 2 then
					WAttrOn(MainWindow, Color_Pair(Integer(ColorPair_UnselectedFade2)))
				else if Position >= ScreenX div 4 * 1 then
					WAttrOn(MainWindow, Color_Pair(Integer(ColorPair_UnselectedFade1)));

				if i = 0 then
				begin
					if j >= CurrentChar then
						WAttrOn(MainWindow,  Color_Pair(Integer(ColorPair_Unselected)));
				end;

				if Position >= ScreenX then
					goto 2
				else
				begin
					Inc(Position);
					WAddCh(MainWindow, Integer(Words[i][j]));
				end;
			end;

			WAttrOn(MainWindow,  Color_Pair(Integer(ColorPair_Unselected)));

			Inc(Position);
			WAddCh(MainWindow, Integer(' '));
		end;
		WordPosition := Length(Words);

		Add8NewWords; { add new words in case they dont fill the screen }
		goto 1;

		2:
		WAttrOn(MainWindow, Color_Pair(Integer(ColorPair_Cursor)));
		MvWAddCh(MainWindow, 2, 2 + CurrentChar - 1, Integer('^'));

		if Paused then
		begin
			MvWAddStr(MainWindow, 1, ScreenX div 2 - Length(PausedTitle) div 2 - 1,
			          PChar(DupeString(' ', Length(PausedTitle) + 2)));

			WAttrOn(MainWindow,  Color_Pair(Integer(ColorPair_Paused)));
			MvWAddStr(MainWindow, 1, ScreenX div 2 - Length(PausedTitle) div 2, PausedTitle);
		end;
	end
	else
	begin
		ResultTitle := PChar('Your WPM: ' + IntToStr(TypedWords) + ', press ^Q to quit');

		WAttrOn(MainWindow, Color_Pair(Integer(ColorPair_Main)));
		MvWAddStr(MainWindow, 1, ScreenX div 2 - Length(ResultTitle) div 2, ResultTitle);
	end;

	WRefresh(MainWindow);
end;

procedure Render;
begin
	RenderMain;
	RenderBottomBar;
end;

begin
	Init;

	while AppState <> Quit do
	begin
		if AppState = Running then
		begin
			PrevSecond := Second;
			Second     := DateTimeToUnix(Time);

			if Paused then
				StartSecond := StartSecond + (Second - PrevSecond)
			else if StartSecond + TestTime <= Second then
				AppState := Result;
		end;

		Render;

		NapMs(20);

		Input := GetCh;
		case Input of
			Integer('q') and 31:
				AppState := Quit;

			Key_Resize:
			begin
				ScreenX := GetMaxX(StdScr);
				ScreenY := GetMaxY(StdScr);

				WResize(BottomBar,  1,       ScreenX);
				WResize(MainWindow, 3,       ScreenX);
				WResize(BackWindow, ScreenY, ScreenX);

				MvWin(BottomBar,  ScreenY - 1,       0);
				MvWin(MainWindow, ScreenY div 2 - 2, 0);
				{ BackWindow does not need to be moved, its always at 0:0 }

				Refresh();
				ClearScreen;
			end;

			Key_Enter: if AppState <> Result then Paused := not Paused;
			10:        if AppState <> Result then Paused := not Paused;
		else
			if not Paused and (AppState = Running) and (Input >= Integer(' ')) and
			                                           (Input <= Integer('~')) then
			begin
				if CurrentChar > Length(Words[0]) then
				begin
					if Input = Integer(' ') then
					begin
						DeleteFirstWord;
						CurrentChar := 1;
						Inc(TypedWords);
					end;
				end
				else if Integer(Words[0][CurrentChar]) = Input then
					Inc(CurrentChar);
			end;
		end;
	end;

	Finish;
end.
