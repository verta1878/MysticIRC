{$H-}
Program test_v4;

Uses rip4api, htmlpars;

Var
  RIP    : TRIPEngine;
  Pass   : Integer;
  Fail   : Integer;
  Total  : Integer;
  GP     : THTMLParser;
  GTok   : THTMLToken;
  GSrc   : String;

Procedure Check (Name: String; Cond: Boolean);
Begin
  Inc(Total);
  If Cond Then Begin Inc(Pass); WriteLn('  PASS  ', Name); End
  Else Begin Inc(Fail); WriteLn('  FAIL  ', Name); End;
End;

Procedure TestHTMLParser;
Var Cnt : Integer;
Begin
  WriteLn; WriteLn('--- HTML Parser ---');
  GSrc := '<html><body><h1>Hello</h1><p>World</p></body></html>';
  HTMLParserInit(GP, @GSrc[1], Length(GSrc));
  Cnt := 0;
  While HTMLNextToken(GP, GTok) Do Inc(Cnt);
  Check('Parse basic HTML: tokens > 0', Cnt > 0);
  Check('TagID H1', HTMLTagNameToID('H1') = htH1);
  Check('TagID body', HTMLTagNameToID('body') = htBODY);
  Check('TagID unknown', HTMLTagNameToID('BLINK') = htUnknown);
  Check('BR is void', HTMLIsVoidTag(htBR));
  Check('IMG is void', HTMLIsVoidTag(htIMG));
  Check('P not void', Not HTMLIsVoidTag(htP));
  Check('&amp; = &', HTMLDecodeEntity('amp') = '&');
  Check('&lt; = <', HTMLDecodeEntity('lt') = '<');
  Check('&gt; = >', HTMLDecodeEntity('gt') = '>');
  Check('&#65; = A', HTMLDecodeEntity('#65') = 'A');
End;

Procedure TestHTMLParserAttrs;
Var V : String;
Begin
  WriteLn; WriteLn('--- HTML Attributes ---');
  GSrc := '<a href="http://example.com" target="_blank">Link</a>';
  HTMLParserInit(GP, @GSrc[1], Length(GSrc));
  HTMLNextToken(GP, GTok);
  Check('A tag open', GTok.Kind = htkOpenTag);
  Check('A tag ID', GTok.TagID = htA);
  Check('2 attrs', GTok.AttrCount = 2);
  V := HTMLGetAttr(GTok, 'href');
  Check('href value', V = 'http://example.com');
  V := HTMLGetAttr(GTok, 'target');
  Check('target value', V = '_blank');
  V := HTMLGetAttr(GTok, 'missing');
  Check('missing attr = empty', V = '');
End;

Procedure TestHTMLParserEdge;
Begin
  WriteLn; WriteLn('--- HTML Edge Cases ---');
  GSrc := '';
  HTMLParserInit(GP, @GSrc[1], 0);
  Check('Empty: no token', Not HTMLNextToken(GP, GTok));

  GSrc := '<!-- comment -->';
  HTMLParserInit(GP, @GSrc[1], Length(GSrc));
  HTMLNextToken(GP, GTok);
  Check('Comment token', GTok.Kind = htkComment);

  GSrc := '<br><hr><img src="test.gif">';
  HTMLParserInit(GP, @GSrc[1], Length(GSrc));
  HTMLNextToken(GP, GTok);
  Check('BR self-close', GTok.Kind = htkSelfClose);
  HTMLNextToken(GP, GTok);
  Check('HR self-close', GTok.Kind = htkSelfClose);
  HTMLNextToken(GP, GTok);
  Check('IMG self-close', GTok.Kind = htkSelfClose);

  GSrc := '<><b>ok</b>';
  HTMLParserInit(GP, @GSrc[1], Length(GSrc));
  While HTMLNextToken(GP, GTok) Do ;
  Check('Malformed: no crash', True);
End;

Procedure TestHTMLRenderPage;
Begin
  WriteLn; WriteLn('--- HTML Render Page ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body><h1>Hello BBS</h1><p>Welcome</p></body></html>';
  RIP.HTMLRenderPage(@GSrc[1], Length(GSrc));
  Check('HTMLRenderPage: no crash', True);
End;

Procedure TestHTMLRenderToRIP;
Begin
  WriteLn; WriteLn('--- HTML Render to RIP ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body><p>Test</p></body></html>';
  RIP.HTMLRenderToRIP(@GSrc[1], Length(GSrc));
  Check('HTMLRenderToRIP: no crash', True);
End;

Procedure TestPrintBMP;
Begin
  WriteLn; WriteLn('--- Print to BMP ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  RIP.SetColor(15);
  RIP.OutTextXY(10, 10, 'Print Test');
  RIP.PrintPage(3, 300, '/tmp/rip4_print_test.bmp');
  Check('PrintPage BMP: no crash', True);
End;

Procedure TestDrawTextUTF8;
Begin
  WriteLn; WriteLn('--- DrawTextUTF8 ---');
  RIP.ClearScreen;
  RIP.DrawTextUTF8(10, 10, 'Hello ASCII');
  Check('ASCII UTF8: no crash', True);
  RIP.DrawTextUTF8(10, 30, '');
  Check('Empty UTF8: no crash', True);
End;

Procedure TestMPEGOpen;
Begin
  WriteLn; WriteLn('--- MPEG Open/Close ---');
  Check('Open nonexistent: false', Not RIP.MPEGOpen('nonexistent.mpg'));
  Check('FrameCount when not loaded: 0', RIP.MPEGGetFrameCount = 0);
  RIP.MPEGRenderFrame(0);
  Check('RenderFrame not loaded: no crash', True);
  RIP.MPEGClose;
  Check('Close not loaded: no crash', True);
End;


Procedure TestHTMLTable;
Begin
  WriteLn; WriteLn('--- HTML Table ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body><table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table></body></html>';
  RIP.HTMLRenderPage(@GSrc[1], Length(GSrc));
  Check('Table render: no crash', True);
End;

Procedure TestHTMLFontColor;
Begin
  WriteLn; WriteLn('--- HTML Font Color ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body><font color="red">Red</font> <font color="#00FF00">Green</font></body></html>';
  RIP.HTMLRenderPage(@GSrc[1], Length(GSrc));
  Check('Font color: no crash', True);
End;

Procedure TestHTMLBgColor;
Begin
  WriteLn; WriteLn('--- HTML BgColor ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body bgcolor="#003366"><p>Dark blue bg</p></body></html>';
  RIP.HTMLRenderPage(@GSrc[1], Length(GSrc));
  Check('BgColor: no crash', True);
End;

Procedure TestHTMLFormElements;
Begin
  WriteLn; WriteLn('--- HTML Form Elements ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body><form><input><select><option>A</option></select><textarea></textarea></form></body></html>';
  RIP.HTMLRenderPage(@GSrc[1], Length(GSrc));
  Check('Form elements: no crash', True);
End;

Procedure TestHTMLComplex;
Begin
  WriteLn; WriteLn('--- HTML Complex ---');
  RIP.SetPixelFormat(RIP_PIXFMT_RGB24);
  RIP.ClearScreen;
  GSrc := '<html><body bgcolor="black"><h1><font color="cyan">BBS</font></h1><hr><p>Welcome</p><ul><li>Files</li><li>Msgs</li></ul><a href="menu.rip">Menu</a></body></html>';
  RIP.HTMLRenderPage(@GSrc[1], Length(GSrc));
  Check('Complex page: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== v4.0 Tests ===');
  RIP := TRIPEngine.Create;

  TestHTMLParser;
  TestHTMLParserAttrs;
  TestHTMLParserEdge;
  TestHTMLRenderPage;
  TestHTMLRenderToRIP;
  TestPrintBMP;
  TestDrawTextUTF8;
  TestMPEGOpen;

  TestHTMLTable;
  TestHTMLFontColor;
  TestHTMLBgColor;
  TestHTMLFormElements;
  TestHTMLComplex;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');
  If Fail > 0 Then Halt(1);
End.
