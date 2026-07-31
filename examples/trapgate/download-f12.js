// F12 Console Script — Download ALL TrapGate source files
// 1. Open: https://sourceforge.net/projects/trapgatemailer/files/Source%20codes/
// 2. Press F12 → Console tab
// 3. Paste this ENTIRE script and press Enter
// 4. Files download one at a time with 2-second delays
//
// Downloads save to your browser's default download folder.

(async function() {
  const files = [
    "ADMCRC32.pas","ADManager.pas","ADManager.res","ActivePorts.dcr","ActivePorts.pas",
    "BaseRules.pas","ClusterChat.dcr","ClusterChat.pas","ClusterChat.res","ClusterDCC.dcr",
    "ClusterDCC.pas","ClusterFile.dcr","ClusterFile.pas","Compilers.inc","DelphiZLib.obj",
    "DitherUnit.pas","FasterTCP.cnt","FasterTCP.dcr","FasterTCP.pas","FasterTCP_64bit.dpk",
    "FasterTCP_Pcg.dpk","FramBrwz.pas","FramView.pas","FrameViewerReg.pas","GDIPL2A.pas",
    "GetWinVersionInfo.pas","HTMLCompEdit.pas","HTMLView.pas","Html32.res","IcmpAPI.pas",
    "Irc.dpk","Irc.res","Maxword.pas","MetaFilePrinter.pas","Netmail.pas",
    "OpenAPI.Compression.pas","ReadHTML.pas","SnmpTypes.pas","StylePars.pas","StyleUn.pas",
    "Token.pas","URLSubs.pas","VortexCommon.pas","VortexD7.dpk","Vortexpkg.res","XiRC.dcr",
    "XiRC.pas","ZLibEx.inc","ZLibEx1.pas","adler32.obj","clusterchat.res","compress.obj",
    "crc32.obj","deflate.obj","dfsProgressBar.pas","ethernet_address.pas","htmlcons.inc",
    "htmlgif1.pas","htmlgif2.pas","htmlsbs1.pas","htmlsubs.pas","htmlun2.pas","infback.obj",
    "inffast.obj","inflate.obj","inftrees.obj","max.inc","mbxfile.dcr","pActivePorts.dpk",
    "pActivePorts.res","p_BinkP.pas","trees.obj","vortex.dcr","vortex.pas","vwPrint.pas",
    "FASTERTCP.HLP","TrapGate Source 14.11.2014.rar"
  ];

  const base = "https://sourceforge.net/projects/trapgatemailer/files/Source%20codes";
  let ok = 0, fail = 0;

  for (const f of files) {
    console.log(`Downloading ${f} ...`);
    try {
      const a = document.createElement('a');
      a.href = `${base}/${encodeURIComponent(f)}/download`;
      a.download = f;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      ok++;
      console.log(`  OK: ${f}`);
    } catch(e) {
      fail++;
      console.log(`  FAIL: ${f} — ${e}`);
    }
    // Wait 2 seconds between downloads
    await new Promise(r => setTimeout(r, 2000));
  }

  console.log(`\nDone! Downloaded: ${ok}  Failed: ${fail}`);
  console.log('Check your Downloads folder.');
})();
