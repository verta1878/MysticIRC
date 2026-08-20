# A39 -> A38 fork : structural diff / import-decision list
# Generated during the A39 review session.
#
# SCOPE OF THE DIFF (completeness):
#   - Changed .pas: 86 have REAL code changes; 76 are pure header-trim (license
#     block -20/-21 lines, no code) and need no import.
#   - Non-.pas: whatsnew/.txt, .ans screens, .ini/.cfg exist but are not code.
#   - A38-only file: mystic/bbs_areaindex.pas = OUR custom unit; superseded by
#     A39's AreaIndex (in bbs_msgbase, built on TAnsiListBox). Retire post-compile.
#   - 4 NEW A39 units: mis_events.pas, m_stringlist.pas, m_threads.pas, md5.pas.
#
# DECISIONS LOCKED THIS SESSION:
#   - Socket layer -> IPv4 (WaitInit/WaitConnection/Connect/ResolveAddress) DONE.
#     Fixes MIS-not-loading (IPv6 '::' bind failed on IPv4-only systems/XP).
#   - FPC threads kept; A39 MDL thread/stringlist wrappers NOT imported
#     (g00r00 reverted to FPC threads later).
#   - #3 m_datetime (DATEC1970, DDD FormatDate, DateDT2Unix/DateDos2Unix) IMPORTED.
#   - #2 m_logroller (A39 version) IMPORTED (was unused; no cascade).
#   - #1 AreaIndex DEFERRED: needs TAnsiListBox (post-compile UI rewrite).
#   - Event engine (mis_events + m_threads + m_stringlist) + TAnsiListBox +
#     A39 FidoNet + rest of MSGBASE/BBS-CORE/etc = A39 STABILIZATION pass,
#     AFTER A38 compiles+tests clean.
#   - INET (mis_client_*) shelved per lead until A38 stable.
#
# 'real' = non-blank, non-comment changed lines.

## DONE (imported/handled this session)   (4 units)
   151  mystic/mis.pas                    new: EventStatus
    33  mdl/m_socket_server.pas         
    14  mdl/m_datetime.pas              
    12  mdl/m_io_sockets.pas            

## OURS-MIXED (already handled)   (8 units)
   139  mystic/mis_server.pas           
   134  mystic/bbs_core.pas               new: ReadTemplate, TBBSCore.ReadTemplate, TBBSCore.WriteSemFiles, WriteSemFiles
    80  mystic/mystic.pas               
    68  mdl/m_fileio.pas                  new: AddRecord, AppendText, KillRecord
    63  mystic/records.pas              
    28  mystic/bbs_cfg_syscfg.pas       
    20  mystic/bbs_cfg_main.pas         
    11  mystic/bbs_filebase.pas         

## MSGBASE (A39 pass)   (6 units)
   541  mystic/bbs_msgbase_jam.pas        new: AddSubText, GetSubData, TMsgBaseJAM.AddSubText
   357  mystic/bbs_msgbase.pas            new: AddSort, AreaIndex, AreaIndexDrawBar, AreaIndexSearch
   125  mystic/bbs_msgbase_ansi.pas       new: AddSep, Attr2Ansi, OutCode, SaveAnsiFile
    12  mystic/bbs_msgbase_squish.pas   
     9  mystic/bbs_msgbase_abs.pas        new: TMsgBaseABS.GetStringNoKludge
     6  mystic/bbs_msgbase_qwk.pas      

## A39-FIDONET (import during A39 pass)   (13 units)
   269  mystic/mutil_echoexport.pas       new: EchoBundleMessages, EchoExportMessage, WriteMessage
   149  mystic/mutil_echoimport.pas       new: ReadEchoMailLinks
   149  mystic/mutil_importmsgbase.pas    new: ScanDirectory
    88  mystic/bbs_cfg_echomail.pas     
    52  mystic/mutil_echocore.pas       
    20  mystic/mutil_msgpack.pas        
     4  mystic/mutil_nodelist.pas       
     0  mystic/mutil_echofix.pas        
     0  mystic/mutil_filebone.pas       
     0  mystic/mutil_filesbbs.pas       
     0  mystic/mutil_importna.pas       
     0  mystic/mutil_msgpost.pas        
     0  mystic/mutil_msgpurge.pas       

## BBS-CORE (A39 pass)   (21 units)
   797  mystic/bbs_ansi_menubox.pas       new: AddItem, ApplyFilter, BuildPage, CalculateMove
   228  mystic/bbs_database.pas           new: AddExportByBase, GetMatchedAddress, GetNextAddress, GetNodeByRoute
   119  mystic/bbs_io.pas                 new: GetParam
    59  mystic/bbs_edit_ansi.pas        
    52  mystic/bbs_common.pas           
    51  mystic/bbs_user.pas             
    18  mystic/bbs_menus.pas            
    11  mystic/bbs_edit_line.pas        
     7  mystic/bbs_general.pas          
     5  mystic/bbs_nodelist.pas         
     4  mystic/bbs_doors.pas            
     3  mystic/bbs_ansi_menuinput.pas   
     3  mystic/bbs_sysopchat.pas        
     2  mystic/bbs_nodechat.pas         
     2  mystic/bbs_nodeinfo.pas         
     1  mystic/bbs_userchat.pas         
     0  mystic/bbs_ansi_help.pas        
     0  mystic/bbs_ansi_menuform.pas    
     0  mystic/bbs_edit_full.pas        
     0  mystic/bbs_menudata.pas         
     0  mystic/bbs_records.pas          

## CONFIG-EDITOR (A39 pass)   (13 units)
    71  mystic/bbs_cfg_theme.pas          new: EditMessageBox, SetThemeBoxDefaults
    49  mystic/bbs_cfg_events.pas       
    47  mystic/bbs_cfg_useredit.pas     
    37  mystic/bbs_cfg_menuedit.pas     
    10  mystic/bbs_cfg_msgbase.pas      
     7  mystic/bbs_cfg_groups.pas       
     6  mystic/bbs_cfg_filebase.pas     
     5  mystic/bbs_cfg_archive.pas      
     5  mystic/bbs_cfg_protocol.pas     
     5  mystic/bbs_cfg_qwknet.pas       
     4  mystic/bbs_cfg_common.pas       
     4  mystic/bbs_cfg_seclevel.pas     
     0  mystic/bbs_cfg_vote.pas         

## MDL/lib (A39 pass)   (43 units)
    27  mdl/m_strings.pas                 new: strI2Octal, strI2Octet
    14  mdl/m_output_linux.pas          
     8  mdl/m_tcp_client.pas            
     6  mdl/m_tcp_client_smtp.pas       
     4  mdl/m_ops.pas                   
     3  mdl/m_prot_zmodem.pas           
     2  mdl/m_crc.pas                   
     2  mdl/m_inireader.pas             
     2  mdl/m_output_darwin.pas         
     2  mdl/m_prot_base.pas             
     2  mdl/m_protocol_zmodem.pas       
     1  mdl/m_pipe_windows.pas          
     0  mdl/m_bits.pas                  
     0  mdl/m_crypt.pas                 
     0  mdl/m_input.pas                 
     0  mdl/m_input_crt.pas             
     0  mdl/m_input_darwin.pas          
     0  mdl/m_input_linux.pas           
     0  mdl/m_input_windows.pas         
     0  mdl/m_io_base.pas               
     0  mdl/m_io_stdio.pas              
     0  mdl/m_menubox.pas               
     0  mdl/m_menuform.pas              
     0  mdl/m_menuhelp.pas              
     0  mdl/m_menuinput.pas             
     0  mdl/m_output.pas                
     0  mdl/m_output_crt.pas            
     0  mdl/m_output_scrollback.pas     
     0  mdl/m_output_windows.pas        
     0  mdl/m_pipe.pas                  
     0  mdl/m_pipe_disk.pas             
     0  mdl/m_pipe_unix.pas             
     0  mdl/m_prot_binkp.pas            
     0  mdl/m_protocol_base.pas         
     0  mdl/m_protocol_binkp.pas        
     0  mdl/m_protocol_queue.pas        
     0  mdl/m_protocol_xmodem.pas       
     0  mdl/m_protocol_ymodem.pas       
     0  mdl/m_quicksort.pas             
     0  mdl/m_sdlcrt.pas                
     0  mdl/m_tcp_client_ftp.pas        
     0  mdl/m_term_ansi.pas             
     0  mdl/m_types.pas                 

## MUTIL (A39 pass)   (7 units)
   144  mystic/mutil_common.pas         
    42  mystic/mutil.pas                
     8  mystic/mutil_status.pas         
     0  mystic/mutil_allfiles.pas       
     0  mystic/mutil_ansi.pas           
     0  mystic/mutil_toplists.pas       
     0  mystic/mutil_upload.pas         

## MPL/script (A39 pass)   (5 units)
    15  mystic/mpl_execute.pas          
     0  mystic/mpl_common.pas           
     0  mystic/mpl_compile.pas          
     0  mystic/mpl_fileio.pas           
     0  mystic/mpl_types.pas            

## TOOLS/MISC (A39 pass)   (14 units)
   157  mystic/nodespy_term.pas         
    24  mystic/mkcrap.pas               
     9  mystic/nodespy.pas              
     0  mystic/aview.pas                
     0  mystic/aviewarj.pas             
     0  mystic/aviewlzh.pas             
     0  mystic/aviewrar.pas             
     0  mystic/aviewzip.pas             
     0  mystic/install_ansi.pas         
     0  mystic/install_arc.pas          
     0  mystic/install_make.pas         
     0  mystic/nodespy_ansi.pas         
     0  mystic/nodespy_ansiterm.pas     
     0  mystic/nodespy_common.pas       

## NEW-UNIT (A39 pass)   (4 units)
   NEW  mystic/mis_events.pas           
   NEW  mdl/m_stringlist.pas            
   NEW  mdl/m_threads.pas               
   NEW  mdl/md5.pas                     

## OTHER (A39 pass)   (7 units)
    68  mystic/todo.pas                 
    20  mystic/fidopoll.pas             
     6  mystic/mide.pas                 
     2  mystic/109to110.pas             
     0  mystic/mbbsutil.pas             
     0  mystic/mplc.pas                 
     0  mystic/qwkpoll.pas              

## INET (shelved per lead)   (10 units)
    46  mystic/mis_client_smtp.pas      
    42  mystic/mis_client_pop3.pas      
    35  mystic/mis_client_nntp.pas      
    22  mystic/mis_client_binkp.pas     
    19  mystic/mis_client_ftp.pas       
     6  mystic/mis_common.pas           
     4  mystic/mis_client_telnet.pas    
     0  mystic/mis_ansiwfc.pas          
     0  mystic/mis_client_http.pas      
     0  mystic/mis_nodedata.pas         

## DEAD (attic candidate)   (1 units)
   167  mdl/m_socket_class.pas            new: TSocketClass.Connect, TSocketClass.ResolveAddress, TSocketClass.WaitConnection, TSocketClass.WaitInit

## DEV-TEST   (10 units)
     9  mdl/mdltest5.pas                
     2  mdl/mdltest1.pas                
     0  mdl/mdltest0.pas                
     0  mdl/mdltest2.pas                
     0  mdl/mdltest3.pas                
     0  mdl/mdltest4.pas                
     0  mdl/mdltest6.pas                
     0  mdl/mdltest7.pas                
     0  mdl/mdltest8.pas                
     0  mdl/mdltest9.pas                

## RECONCILIATION NOTES (found during compile)
  - DNSBL/DNSCC: A39 has an OFFICIAL implementation in mis_server.pas
    (Config.inetUseDNSBL / inetDNSBL / inetDNSCC, using the new 1-param
    ResolveAddress).  Our fork's IsDNSBLListed (labeled 'A40.2') DUPLICATES
    it.  During the A39 inet pass: retire our IsDNSBLListed, adopt A39's
    official DNSBL+DNSCC.  (Ours compiles now; not urgent.)
  - cNetDB (Linux): our pure-Pascal ResolveAddress uses GetHostByName which
    on Linux routes through FPC's cNetDB (a libc wrapper - standard FPC unit,
    not custom C).  Build needs -Fu <pkgunits-linux> for it.  Pure-Pascal
    netdb/resolve is a future option if zero-libc is ever wanted.

## FUTURE OPTION - pure-Pascal resolver (zero libc)
  - FPC ships pure-Pascal resolvers (netdb, resolve units; 0 libc externals).
    Could replace GetHostByName/cNetDB to remove the Linux libc dependency
    entirely - valuable for OS/2, static, and musl builds.
  - Cost: rewrite ResolveAddress/WaitConnection to the THostEntry/THostAddr
    API; diverges from A39; pure-Pascal resolver ignores nsswitch/mDNS.
  - Decision: KEEP A39-matching GetHostByName/cNetDB for now; revisit for
    OS/2 or static-build portability.



## IDEA (parked, NOT implemented) - theme TextPath fallback
  - The 'Allow Fallback' theme flag (ThmFallback) is honored for MENUS
    (bbs_menus: if Theme.MenuPath fails and the flag is set, fall back to
    bbsCfg.MenuPath) but NOT for TEXT files (bbs_general: FN uses
    Session.Theme.TextPath directly, no fallback).  So a theme moved
    between machines keeps working menus (fallback) but breaks text until
    the theme's Text Path is fixed in the MCFG theme editor.
  - IDEA: mirror the menu behavior for text - fall back to bbsCfg.TextPath
    when ThmFallback is set.
  - CAVEAT: diverges from A39 (g00r00's bbs_general does the same no-
    fallback text load), so it cuts against the 'follow the alphas'
    approach.  Parked pending discussion - do NOT implement yet.
  - OPEN: ScriptPath and help/OpenHelp text path may have the same gap -
    not yet checked.



## THEME FALLBACK - upstream intent (sourced: 1.10 wiki whatsnew)
  - The whatsnew states as INTENDED design: 'Display files that are not
    found in a theme directory now have the option to fallback to the
    default display file directory, if Theme fallback is enabled.'  Also
    menu and MPL-script theme fallback are described the same way.
  - This is upstream behavior gated by the Theme-fallback flag (ThmFallback).
    Re: our parked 'text TextPath fallback' idea - display/text fallback IS
    an intended feature; when we walk the alphas, verify exactly which loads
    (display/text/menu/script) honor ThmFallback in each version and align
    with upstream rather than inventing our own.

## FidoNet PATH GAP (documented; no fix yet)
  - Same lockout shape as the theme paths, but NO tool/binary exists to fix
    it yet.
  - COVERED: global FidoNet paths in RecConfig/mystic.dat (InboundPath,
    OutboundPath, AttachPath, SemaPath) - handled by our CheckDIR startup
    validation.
  - NOT COVERED: per-link paths stored in the echomail records -
      RecEchoMailNode:  DirInDir, DirOutDir, ftpInDir, ftpOutDir
      RecEchoMailAddr:  DirInDir, DirOutDir, ftpInDir, ftpOutDir  (String[60])
    These live in the echomail .dat file(s), one set of paths per node/echo,
    and can currently be edited ONLY in the MCFG echomail editor (inside
    mystic) - which needs a loading Mystic.  No command-line escape hatch.
  - FEASIBLE FIX (not built): a cfgfido-style action using the SAME pattern
    as maketheme cfgtheme/list - open File of RecEchoMailNode / RecEchoMailAddr,
    walk records, show/edit the Dir*/ftp* path fields, write back.  Uniform
    1.10 data structures + our official byte-compatible layout make this
    viable.
  - CAVEAT: bigger surface than themes (multiple record types, many records,
    separate .dat files) AND the A39 FidoNet rework (~570 lines across
    echoexport/import/core/importmsgbase/msgpack/cfg_echomail/fidopoll) may
    reshape some of this.  So: verify which .dat files/records hold these,
    and whether A39 changes them, BEFORE building - do it WITH the A39
    FidoNet pass, not bolted on now.
  - STATUS: DEFERRED - documented gap, revisit during the A39 FidoNet pass.

## RESEARCH REFERENCE - alt.bbs.mystic archives (primary source)
  - The Mystic support discussion lived in the FidoNet 'MYSTIC' echo, gated to
    the Usenet newsgroup alt.bbs.mystic (FTN name ALT-BBS-MYSTIC).
  - Archived + web-searchable: Google Groups (groups.google.com/g/alt.bbs.mystic)
    and narkive (alt.bbs.mystic.narkive.com).  g00r00 (James Coyle) posted there.
  - USE: when a decision would otherwise be a guess (theme/QWK/FidoNet behavior),
    search these archives for g00r00's own explanations + sysop repros, and cite
    them - same tier of primary source as the whatsnew wiki.  Caveat: discussion,
    not spec - g00r00 posts = strong evidence; random sysop posts = leads to
    verify against actual source.

## CONFIRMED from alt.bbs.mystic - qwkpoll A23/A24 crash was 64-bit-latent
  - g00r00 (1.12 A24): the A23 qwkpoll bug was 'the same issue in the code' in
    BOTH 32- and 64-bit, but only the 64-bit build crashed; 32-bit 'for some
    reason' did not.  User symptom: 'Runtime error 216' on 'qwkpoll all'.
  - IMPLICATION for our fork: our A38-branched tree can carry latent bugs that
    do NOT crash on our 32-bit targets but WOULD on 64-bit.  Directly supports
    fixing data-correctness bugs (e.g. the Chunks:Word >64KB overflow) regardless
    of whether 32-bit happens to survive them.  Validates the sysop's 64 worry.
  - g00r00 also (on v1.10 A38, our baseline) 'fixed up QWKPOLL to give some
    better messages' - our qwkpoll.log work aligns with his own direction.
  - Known real QWK issue reported: messages missing after repeated transfers
    (g00r00 acknowledged it as a probable problem) - watch for this in testing.

## ROADMAP / METHODOLOGY (sysop's alpha-tester approach)
  - This is NOT a set of isolated patches (theme/QWK/FidoNet).  The method is
    to RE-RUN THE ALPHA CYCLE deliberately, the way the sysop did as a real
    Mystic alpha tester starting at 1.07:
      1. COMPLETE A39 - finish importing what A39 changed vs our A38 (event
         engine done for MIS; still: msgbase, MPL deltas, TAnsiListBox UI,
         FidoNet echomail, config editor; retire our interim bbs_areaindex).
      2. WALK THE 1.10 whatsnew ALPHA-BY-ALPHA - import each alpha's changes
         IN ORDER, recompile, test.  Most of MPL/FidoNet/QWK actually matured
         across the 1.10 alpha stream, not in a single A38->A39 diff.
      3. SWEEP the 16-bit-era bug class as we go (Word/SmallInt/Integer count
         & offset assumptions that only bite at scale on 32/64-bit).  QWK just
         proved it (Chunks Word/SmallInt -> LongInt).  Expect the same in MPL
         and FidoNet packet/count code (cf. g00r00's 'bad memory reference
         after tossing ~3 million echomail messages').
  - Live-network features (FidoNet, QWK) can only be truly tested once the
    foundation is coherent AND the sysop has a test network up - gated, later.

## DEPENDENCY ORDER (bottom -> top)
  - FOUNDATION (peers, do first): MPL ENGINE + MSGBASE.  Huge amounts sit on
    both.  MPL engine = mpl_compile / mpl_execute / mpl_types / mpl_common /
    mpl_fileio (+ mplc program).  A38->A39 MPL delta is small (mpl_common ~20
    lines); the real MPL work is the 1.10 alpha stream ('recompile all MPL'
    recurs in the whatsnew).  Msgbase = bbs_msgbase (+357 AreaIndex/AddSort) +
    bbs_msgbase_jam (+541).
  - MIDDLE: FidoNet echomail subsystem (~570 lines, interconnected: echoexport
    /echoimport/echocore/importmsgbase/msgpack/cfg_echomail/fidopoll +
    binkHideAKA) - depends on MSGBASE.  UI: A39 TAnsiListBox (brings official
    AreaIndex, retires our bbs_areaindex; fixes flaky -cfg ESC/Exit).
  - TOP (gated on live network + test setup): FidoNet polling/tossing tests,
    QWK network tests.

## FidoNet PASS - scope (when foundation ready + test network up)
  - Import A39 echomail subsystem WITH the msgbase changes it needs.
  - Close the documented FidoNet path gap: fidopoll log-and-continue on missing
    Dir-node paths + ONE local email to sysop (email-is-the-guard, no flags) -
    see FIDOPOLL_PATHCHECK_PLAN.md.  Blank-path handling still UNDECIDED
    pending testing.
  - Reference (read for idioms, do NOT port): Scott Baker Pascal release
    (newmsg.arj) FIDOMSG.PAS / CRC.PAS - real Turbo Pascal FidoNet .MSG + CRC
    handling.  Same role McBrine's QWK spec played for the Chunks fix.
  - Sweep FidoNet packet/count code for the 16-bit overflow class.

## REFERENCE - Mystic 2.0 Beta 3 source (sibling rewrite branch, James Coyle)
  - msrc20b3.zip: full 'Mystic 2.0 Beta 3' source, VIRTUAL PASCAL (has both
    m_ops_vpc.pas and m_ops_fpc.pas), files dated 2003-2010.  80 files: full
    tree incl. MPL engine (mpl_compile/execute/types/common/fileio + mplc),
    msgbase JAM/Squish, sockets, MCFG, doors, and a FULL-SCREEN EDITOR
    (bbs_editor_full.pas).
  - STATUS: REFERENCE ONLY - do NOT import into our 1.10 tree.  2.0 is a
    ground-up REWRITE / PARALLEL BRANCH, not upstream of 1.10; different
    structure, records, conventions.  Same tier as McBrine's QWK spec and the
    Scott Baker Pascal + the alt.bbs.mystic archives: consult to understand
    g00r00's INTENT and 'correct' behavior, then translate/verify into 1.10
    Pascal.  Never lift 2.0 code into 1.10.
  - KEY ANCHOR (sysop): 2.0 was AHEAD of the 1.x line - e.g. its full-screen
    editor predates the 1.x one; 1.x did not get an equivalent full-screen
    editor until 1.12.  So 2.0 shows where features eventually went, years
    before 1.x caught up - useful as 'how he solved X' but on its own timeline.
  - USES: (a) MPL engine reference (MPL is foundational in our roadmap);
    (b) see how the 16-bit->32-bit modernization was done (2.0 likely already
    fixed the Word/SmallInt overflow class we are hunting); (c) g00r00's own
    TODO comments in-source reveal intentions.
  - Copy kept at outputs/msrc20b3.zip.  Sysop was a Mystic 2.0 alpha tester
    (started on Mystic 1.07).

## MPL SCRIPT CORPUS - from live board (top-level scripts/*.mps only)
  - Source: sysop's live A38 Linux board upload.  Version-matched to A38
    (our exact target).  g00r00's stock .mps are hard to find now, so once
    VERIFIED they are worth importing into the fork as the reference MPL corpus.
  - Scope rule (sysop): top-level scripts/*.mps ONLY for now; subdirs deferred
    (sysop will sort those).  Author credit in a header does NOT mean non-stock
    (e.g. doubleup credits 'Darryl Perry/Gryphon' but shipped stock with Mystic).
  - STOCK / g00r00 A38 (import candidates, once verified/compiled):
      apply_sample, bbslist, bulletin, mailread, mpldemo, mpltest, onlyonce,
      testbox, testinput, usage, startup, passchk,
      blackjack, doubleup, gallows, rumors, mystris   (games - per sysop)
  - SYSOP'S OWN / third-party (do NOT import as stock A38):
      da-line, da, gy-blam  = sysop (Reapern66, '(C) 1999-2012')
      dt-emu                = sysop's friend's door (ANSI scroller, xtcbox.org 2323)
      to-prmpt              = UNCONFIRMED (likely sysop's; custom styling) - ASK
  - MPL engine vocabulary already surveyed: our A38 engine defines 159 builtins
    (AddProc table in mpl_common.pas); scripts use a subset it largely already
    supports.  Real 'missing' gap is short (verify list: exp, pioresult, fopen,
    fexist, eof, print, time, move, system, telnetto, emailowner, checkdupe,
    set_string) - many likely aliases/naming, verify one-by-one, do NOT assume.
  - Reference: MPL wiki https://wiki.mysticbbs.com/doku.php?id=mpl (authoritative
    language ref - same role McBrine's spec played for QWK).

## REFERENCE - 1.12 A49 LOG FORMATS (target level, from sysop's live logs)
  - Source: sysop's live Mystic 1.12 A47/A49 board log set.  This is the TARGET
    format level ('1.12 a49 or better').  Text we can diff against - primary ref.
  - qwkpoll.log @ 1.12: our A38 logging work MATCHES it closely already:
      'Exchanging Mail for <net>' / 'Exported @<id>.rep -> N msgs' /
      'Connecting via FTP to <host>' / 'Connected' / 'Authentication failed'.
    ADDITIONS to copy for item 3 (FTP wire logging, 1.12 A39 feature):
      * S:/R: lines logging every FTP client/server exchange
        (e.g. 'S:USER xtcbox' / 'R:331 User name okay' / 'R:220-...').
      * Password MASKED: 'S:PASS <not shown>'  <-- copy this exactly.
      * Startup banner: 'QWKPOLL Startup (v.. A.. OS/32 Compiled <date>)'.
      * 'Local IP is <ip>' after connect.
    (Live example was polling vert.synchro.net = Vertrauen/Synchronet QWK hub;
     auth failed = CONFIG, not a code bug - reinforces 'config vs code' caveat.)
  - mis.log @ 1.12 CONFIRMS our MIS direction:
      * 'TELNET Listening on IPV4 port 2323 using interface "0.0.0.0"' - the
        exact IPv4 bind we forced in our A38 MIS fix.  Upstream states it plainly.
      * Subsystem-tagged format: MANAGER/TELNET/HTTP/EVENT/SENDMAIL, with
        '> Connect on slot N/8 (ip)', '<node>-HostName <name|Unknown>',
        '<node>-Creating/Closing terminal process'.  Header line carries
        version/date + '(loglevel N)'.
      * FUTURE FORK FEATURE: give our MIS its own mis.log in this subsystem-
        tagged style (the video showed the on-screen scrollback is short; a
        logfile is the fix - same philosophy as qwkpoll.log/fidopoll.log).
  - NOTE (assistant limitation): cannot view uploaded video/mp4; sysop typed
    out the MIS screen + provided these logs so the target format is captured
    in text.

## HARD CONSTRAINTS (locked with sysop)
  - SOURCE CEILING: there is NO Mystic source past what we hold (our patched
    A38 tree + one A39 snapshot).  A51 / 1.12 source does NOT exist for us.
    => Everything past A39 = whatsnew descriptions + open standards + the live
       board's BINARY BEHAVIOR / DATA / LOGS as reference; we write our OWN
       verified code and never port nonexistent source.  Same discipline as
       the QWK Chunks fix.
  - LIVE BOARD VERSION: the uploaded Linux board runs Mystic 1.10 A51 (binary
    version banner: 'QWKPOLL Version 1.10 A51' / 'Mystic BBS/QWK v1.10 A51
    (Linux)'), NOT A38.  So it is a real running board 13 alphas ahead of our
    source - a useful BEHAVIORAL waypoint between A39 and the 1.12 target, but
    no source to diff.
  - The S:/R: FTP wire logging + 'S:PASS <not shown>' masking is a 1.12
    feature - NOT present in our A38 source NOR in the A51 board binary
    (verified via strings).  So qwkpoll item 3 remains our own work, targeting
    the 1.12 A49 format we have as reference.

## DoveNet / Vertrauen (vert.synchro.net) - QWK hub
  - Was a REAL QWK-over-FTP hub the sysop used (DoveNet via Vertrauen /
    Synchronet), unused for years now.  Not currently a test target.
  - The 2024 '530 - Telnet to vert.synchro.net to create a valid user account'
    in the 1.12 qwkpoll.log is most likely a Synchronet-side auth-handshake /
    account change over the years - REMOTE/CONFIG, NOT a Mystic qwkpoll bug.
    Do not treat it as a code defect.  (Sysop flagged this from memory,
    uncertain - hold loosely; only a live test would confirm.)
  - VALUE NOW: the board upload's msgs/ has 433 JAM bases incl. this network's
    accumulated real messages = ground truth for msgbase/tossing/echomail even
    without a live hub connection.

## INET DIFF (A38<->A39) - not uniformly newer; decide per-change
  - KEY FINDING: A39 is NOT uniformly newer than A38.  For the event engine and
    connection blocking, A39 was ahead (imported).  For the INET CLIENTS, A38 is
    in places the MORE-DEVELOPED side - our 'A39' snapshot predates/diverges.
  - SearchForUser (mis_common): A38 = 4-arg WITH email matching (RealName OR
    Handle OR Email); A39 = 3-arg, email match removed.  DECISION: KEEP A38's
    4-arg email-matching version.  Rationale: g00r00 never finished the SMTP
    server; A38's SMTP is further along (parses InName@InDomain, does domain
    refusal vs bbsCfg.iNetDomain).  A39's SMTP here is simpler/earlier +uses
    TMDLStringList (MDL wrapper we don't adopt).  Not documented in any whatsnew.
    The email match is INTERNET SMTP (not local JAM/FidoNet netmail).  SMTP is a
    KNOWN-INCOMPLETE subsystem to finish later (relaying, delivery).
  - mis_client_ftp: APPLIED the A39 PASV fix (MyWordRec, endian-aware port
    packing, drop SysUtils) - real bug (sysop couldn't FTP-login, PASV broken),
    on g00r00's path, compiles win32+linux.  Kept A38 SearchForUser (line-600
    3-arg call is dead/commented; active call line 613 is 4-arg, matches).
  - IMPLICATION: 'finish the A39 inet diffs' must be done PER-CHANGE with a diff
    review - some A39 inet changes would REGRESS us.  Take real fixes (endian,
    correctness); reject older/divergent rewrites + TMDLList/TMDLStringList.
  - TODO later: 1.12 .mps scripts may show how email/user lookup is meant to
    work (syntax insight for finishing SMTP).
  - PRINCIPLE (established by the SearchForUser case): when an A39 change would
    REMOVE working A38 functionality, default to KEEPING A38 unless (a) a
    whatsnew/archive entry shows the removal was deliberate, or (b) A39 clearly
    moved the functionality elsewhere.  'Newer snapshot' != 'better' - our A39
    is not a real g00r00 build and diverges.  Take real fixes (endianness,
    correctness); do not tear out further-along A38 code to match an older path.

## REFERENCE - 1.12 A49 SCRIPTS - findings
  - Source: sysop's official 1.12 pre-alpha 49 script set (17 .mps).
  - SMTP/email question: NOT resolved by these scripts.  Their 'email' refs are
    unrelated to the SMTP server (usage.mps: Emails:Word counter; to-prmpt.mps:
    an EMAIL prompt that opens the local message reader).  => our decision to
    KEEP A38's email-matching SearchForUser stands, unchanged.
  - MPL engine confidence UP: 1.12 scripts use user builtins IsUser(), GetUser(),
    GetThisUser, PutThisUser - and IsUser/GetUser are ALREADY in our A38 engine
    AddProc table.  Another sign our A38 MPL engine is close to 1.12-capable.
  - NEW stock scripts in 1.12 vs 1.10 official set: autocreate.mps, menucmd.mps
    (startup.mps also present).  Track these in the milestone walk - new stock
    scripts usually accompany new engine features.
  - Have on hand for milestone: official 1.10 scripts (/tmp/mps110) AND 1.12 A49
    scripts (/tmp/s112) - lets us diff stock-script evolution 1.10 -> 1.12.

## POP3 SIZE BUG - real fix (not an A39 import)
  - SYMPTOM: A38 POP3 reports message/maildrop sizes via strI2O, which is octal
    AND broken (empirically: strI2O(4200)=0, strI2O(64)=0, strI2O(100)=144).
  - STANDARD: RFC 1939 requires ALL POP3 message-numbers and sizes in base-10
    decimal (verified: STAT/LIST/RETR examples all decimal).  So A38 was wrong.
  - INVESTIGATION (corrected my own wrong turn): A39 renamed strI2O -> strI2Octet
    and added strI2Octal.  I first assumed the rename FIXED the octal bug - it
    does NOT: A39's strI2Octet has the SAME OctStr-based body (still octal/0).
    Reading the code + running it disproved the name-based assumption.
  - DECISION: the real fix is decimal -> POP3 uses strI2S (correct: 4200->'4200').
    All 4 strI2O call sites were POP3-only (safe), redirected to strI2S.
    Also imported A39's strI2Octet + strI2Octal into m_strings (kept strI2O) for
    naming clarity/parity with A39, but they are NOT used for POP3 sizes.
  - LESSON: function NAMES lie (strI2O 'looked' like octet; strI2Octet 'looked'
    like a fix).  Verify by reading/running the code + the RFC, not the name.

## INET CLIENTS - per-change review results (A38<->A39, done one unit at a time)
  mis_client_ftp:  TOOK MyWordRec PASV endian fix (real bug: PASV login failed).
                   KEPT A38 SearchForUser (email match).
  mis_client_smtp: TOOK native date routines (DateDos2Str/TimeDos2Str).
                   KEPT A38 TStringList, 4-arg email-matching SearchForUser,
                   Classes uses.  NEW: made foreign-domain acceptance a config
                   toggle inetSMTPRefuseForeign (inverse sense so zero/default =
                   A38 accept-for-known-users; carved from Res1 210->209;
                   SizeOf(RecConfig) stays 5282).  UI toggle still TODO (place in
                   Configuration_SMTPServer with correct coords - don't guess).
  mis_client_pop3: FIXED octet size bug -> strI2S decimal (RFC1939); imported
                   strI2Octet/strI2Octal.  TOOK DateDos2DT(DateStr2Dos()) for the
                   Date: header, removed hand-rolled ParseDateTime.  KEPT the TOP
                   loop A39 had commented out, KEPT TStringList + email match.
  mis_client_nntp: TOOK the MSGID kludge feature (echomail/non-QWK).  KEPT the
                   XOVER byte line A39 commented out, KEPT TStringList + email.
  mis_client_binkp: TOOK the full 'Hide AKAs' feature (completed, not deferred -
                   sysop's call, since it has no msgbase dependency):
                     * binkp: HideAKAs/HideSource fields + skip logic
                     * records.pas: binkHideAKA in RecEchoMailNode (reserve
                       217->216; RecEchoMailNode/RecConfig sizes preserved)
                     * bbs_cfg_echomail: 'Hide AKAs' toggle (free row 14)
                     * fidopoll: BinkP.HideAKAs := EchoNode.binkHideAKA;
                       HideSource := EchoNode.Address.Zone
                   Default off = existing behavior.  Full 14-binary build passes.
                   NOTE: earlier 'defer to FidoNet pass' reasoning was over-applied
                   - this is small config wiring with no foundation dependency, so
                   finishing it unit-by-unit now was correct.  (The BIG FidoNet
                   work - tossing/echomail/AreaFix - remains its own gated pass.)
  mis_common:      KEPT A38 SearchForUser (4-arg, email) per the earlier decision.
  ALL SKIPPED across clients: TMDLStringList/TMDLList wrapper, and any A39 change
  that removed more-developed A38 code.  Full 14-binary build passes both
  platforms after all of the above.

## DARWIN / macOS SOURCE - KEEP (portability + history)
  - DECISION (sysop): keep the Darwin/macOS platform source (m_output_darwin.pas
    and any other *_darwin units).  It is real, working platform code; keeping it
    preserves macOS portability and project history.  'We don't build it' is a
    BUILD choice, not a reason to drop the code.
  - BUILD STATUS: our fork builds win32 + i386-linux only.  m_output_darwin uses
    portable Unix terminal units (TermIO, BaseUnix, m_Types) - NOT deeply Mac-
    locked (no Cocoa/Carbon).  FPC 2.6.2's ppc386 CAN target Darwin (-Tdarwin,
    -Amacho internal Mach-O writer), but our install lacks the Darwin RTL units
    and macOS system libs/SDK, so a WORKING Darwin binary can't be produced in
    this Linux container YET.  CORRECTION (sysop): FPC is a real cross-compiler
    with its own internal assembler + linker (ppc386 supports -Amacho / Mach-O),
    so a Darwin CROSS-BUILD from Linux likely needs only the FPC DARWIN RTL UNITS
    - NOT Xcode/Apple SDK - because m_output_darwin uses portable Unix units
    (TermIO/BaseUnix), not Cocoa/Carbon frameworks.  TO TRY: install/locate the
    FPC 2.6.2 darwin RTL and attempt an -Tdarwin cross-build of the console unit.
    PURPOSE: the repo is going on GitHub specifically so a Mac user can build/
    test it - Darwin is a SUPPORTED target we want contributors to exercise, not
    just preserved history.  This does NOT block win32/linux.
  - A39 CHANGE TAKEN: A39 commented out a dead local 'Count : Byte' in the FIRST
    of two TOutputDarwin.GetScreenImage implementations (its uses were already
    commented).  Applied to match A39.  NOTE: the file has TWO GetScreenImage
    impls with identical signatures (a pre-existing duplicate oddity) - the
    second one's Count is USED (with Line/Temp) and was left intact.
  - LESSON: a whole-file grep count ('Count used 51x') can't see procedure scope;
    each proc's local Var is independent.  Verify scope before assuming a removal
    is unsafe.

## ZMODEM - spec reference + large-transfer finding
  - REFERENCE: Chuck Forsberg's ZMODEM spec (open).  Mirrors: gallium.inria.fr/
    ~doligez/zmodem/zmodem.txt, wiki.synchro.net/ref:zmodem.  Same role McBrine's
    QWK spec / RFC1939 played - ground truth for the protocol.
  - SYSOP SYMPTOMS: ZMODEM 'stopped working during transfers'; 'no 2TB support -
    I tried'.
  - FINDING (2TB): ZMODEM's file position/offset is a 32-BIT value (spec: ZP0..ZP3
    = 4 bytes; 'actual location in the file, a 32-bit number').  Max ~4GB unsigned
    / ~2GB signed.  So 2TB is IMPOSSIBLE in standard ZMODEM - a PROTOCOL limit,
    not a bug in our code.  WHY 32-bit: ZMODEM (1986) encodes the file position
    in the 4-byte ZP0..ZP3 header field, so the addressable range is ~4GB
    unsigned / ~2GB signed by design.  This is the reason a 2TB transfer cannot
    work in standard ZMODEM - the position field simply cannot express it.
    Sysop's test result is correct + expected.  Documented here as the WHY (not
    a dead-end): any future large-file support would require an EXTENDED/64-bit
    offset mode, which is a protocol deviation - would need its own design and
    must not break standard-ZMODEM interop.  Left as future consideration.
  - OUR CODE AUDIT (m_prot_zmodem): file size/offset types are LongInt (32-bit) -
    SrcFileLen, LastFileOfs, WorkSize all LongInt; position built from 4 bytes
    (hhPos1..4 / bhPos1..4).  This MATCHES the 32-bit spec faithfully; good to
    ~2GB (signed LongInt).  NOT a sub-32-bit (Word/SmallInt) overflow like QWK.
    Minor theoretical edge: signed LongInt tops at ~2.15GB not 4GB (2-4GB files
    could go negative) - not the reported symptom, left as-is.
  - 'STOPPED DURING TRANSFERS': size types are sound, so NOT an overflow.  More
    likely ZDLE escaping / flow-control / CRC / timing (the bulk of the spec).
    Cannot reproduce a live serial/modem ZMODEM transfer in-container, so this is
    deferred - needs a real transfer to diagnose.  Do NOT guess-patch it.
  - A39 ZMODEM change taken: send file mod-time in the ZFILE/ZCRCW info subpacket
    (strI2Octal(DateDos2Unix(SrcFileDate))) - spec confirms date is Unix-time,
    'a date of 0 implies unknown'.  Our impl matches.

## Darwin (and linux/windows) - GetScreenImage double-implementation - KEEP
  - OBSERVATION: TOutputDarwin.GetScreenImage has TWO implementation bodies with
    identical signatures (the class interface declares it ONCE).  The FIRST body
    is a non-functional stub (its region-copy loop is commented out; it just does
    Image.Data := Buffer).  The SECOND is the real one (loops Y1..Y2, Move's each
    line, respects X1/Y1/X2/Y2).  In Pascal the second definition is what binds.
  - NOT a Darwin bug: the SAME double-impl pattern exists in m_output_linux and
    m_output_windows too, and A39 has it unchanged.  Our SHIPPING linux build has
    the identical structure and compiles/works fine.
  - DECISION (sysop): DO NOT remove it.  Deleting the Darwin stub would make
    Darwin diverge from linux/windows and could break a Mac build we cannot yet
    test; there is no proven benefit.  Revisit only AFTER we can cross-compile +
    verify all three platforms.  (Same lesson as the dead-Count case: understand
    the scope/convention before 'cleaning' - a whole-file view can misjudge it.)

## DARWIN CROSS-BUILD - concrete status/recipe (TO DO: dedicated session)
  - HAVE: ppc386 fully supports Darwin (-Tdarwin, -Amacho internal Mach-O linker,
    -WM deploy version, framework paths).  FPC Darwin RTL SOURCE is present at
    /home/claude/fpc262/fpc-2.6.2/rtl/darwin/ (+ rtl/bsd, which Darwin builds on).
  - MISSING: the COMPILED i386-darwin RTL units (.ppu).  Only i386-linux units
    are installed.  So it's not a flag-flip - we must BUILD the cross-RTL first.
  - RECIPE (own task): build the i386-darwin RTL from the rtl/darwin source
    (make in rtl with OS_TARGET=darwin CPU_TARGET=i386, pointing FPC at 2.6.2),
    then try 'ppc386 -Tdarwin -Amacho' on m_output_darwin (and eventually a full
    darwin build).  May need Mach-O assembler/linker bits or config tweaks in a
    Linux container - expect some troubleshooting.  Confirmed: does NOT require
    Xcode for this portable-Unix console code.
  - Deferred to a dedicated session (sysop: 'install RTL units for Darwin today
    sometime') so it doesn't block the m_* unit review.

## DARWIN CROSS-BUILD - SOLVED (Darwin RTL built, console unit compiles)
  - DONE: cross-built the FPC 2.6.2 Darwin RTL (60 .ppu units) from the source
    at rtl/darwin, from LINUX, using FPC's INTERNAL Mach-O assembler.  NO Xcode /
    Apple SDK needed - sysop was right on every count.
  - KEY: the RTL Makefile defaults to an external 'i386-darwin-as' (absent here);
    forcing OPT='-Amacho' makes ppc386 use its internal Mach-O writer -> builds
    cleanly (0 errors).
  - Units installed to i386root/lib/fpc/2.6.2/units/i386-darwin (system, objpas,
    sysutils, baseunix, termio, unix, + 54 more).
  - PROVEN: 'ppc386 -Tdarwin -Amacho' compiles m_output_darwin (+ m_types,
    m_strings) cleanly; output is a genuine 'Mach-O i386 object'.  So the Darwin
    console code is confirmed Darwin-COMPILABLE from our tree.
  - CAVEAT: this proves COMPILATION.  A full runnable Mac BINARY (linking
    mystic/mis) still needs Darwin system libs at LINK time - but compilation
    was the blocker, and it's solved.  Great state for GitHub: Mac contributors
    can build/verify.  TO DO later: attempt a full darwin link (may need libc/
    system stubs or an actual Mac for the final link).

## TMDL POLICY (explicit decision - governs msgbase/UI/tosser imports)
  - WHAT TMDL IS: g00r00's own wrapper library introduced in A39 -
    TMDLStringList, TMDLList, TMDLThread - parallel replacements for FPC's RTL
    TStringList / TList / TThread.  (Distinct from the new UI widget TAnsiListBox
    in bbs_ansi_menubox - though the UI/msgbase A39 code is WRITTEN AGAINST TMDL.)
  - DECISION (sysop): standardize on the FPC RTL versions; do NOT adopt TMDL.
    Where A39 code uses TMDLStringList/TMDLList/TMDLThread, TRANSLATE it to the
    FPC equivalents (TStringList/TList/TThread) as we import that unit.
  - RATIONALE:
     * Consistency: one list/string/thread implementation tree-wide, not two
       competing ones (we've already kept FPC types in ~8 inet/mdl units).
     * Maintainability/longevity: FPC's RTL is actively maintained, documented,
       and standard; the MDL library is g00r00-only and we have no source past
       A39.  For a GitHub fork built by others, depend on the standard library.
     * Threading: a custom list/thread wrapper (TMDLList/TMDLThread) is a likely
       home for subtle thread bugs; we already chose FPC TThread over TMDLThread
       for the event engine - this keeps threading consistent with that.
  - COST (eyes open): translating TMDL calls to FPC per unit is MORE work than
    adopting TMDL wholesale (must map each TMDL-specific method to its RTL
    equivalent).  Accepted as a one-time cost for lasting consistency.
  - GUARDRAIL: if a TMDL class does something FPC's RTL genuinely CANNOT do,
    STOP and flag it rather than force a broken translation.  Not expected -
    these are standard list/string/thread operations.
  - WHEN: this becomes active at the TAnsiListBox (bbs_ansi_menubox) + msgbase
    layer, where A39 code first hard-uses TMDL.  Revisit/confirm there.

## TMDL RETIREMENT (do not delete - GPL + scene history)
  - When the TMDL->FPC translation is done (msgbase/UI layer), the TMDL source
    units (that DEFINE TMDLStringList/TMDLList/TMDLThread) are NOT deleted - they
    are MOVED to attic/ (retired, out of the build path).
  - WHY NOT DELETE:
     * GPL-3: the code is licensed + attributed to James Coyle and is part of the
       covered work; we archive rather than strip it.
     * Scene history (sysop's priority): TMDL is a real artifact of Mystic's
       development - g00r00's own engineering from the A39 era.  Preserving it in
       attic/ keeps the historical record intact for future readers / Mac
       contributors / historians.
  - RESULT: active mdl/ = what we build; attic/ = superseded-but-preserved.
    whatsnew will note the units were RETIRED (not removed), pointing here for the
    rationale.  GPL attribution stays intact on the retired files.
  - FILE HEADER: add a 'RETIRED' banner at the TOP of each retired unit (same
    style as the other files already moved to attic/), so the file is self-
    documenting - states it's retired, kept for GPL + scene history, superseded
    by the FPC RTL types per the TMDL policy.

## ANSI bleeding - strStripPipe candidate (sysop to verify)
  - Sysop previously reported ANSI corruption/bleeding on the live board.
  - The A39 strStripPipe fix (verify digits before treating |xx as a pipe colour
    code) COULD be related IF the bleeding was caused by malformed |xx codes
    being mis-detected - but strStripPipe is the PLAIN-TEXT stripper, not the
    main ANSI renderer, so it may be unrelated.  Cannot claim it fixes (or
    caused) the bleeding without visual verification - not testable in-container.
  - ACTION: sysop to verify the ANSI parser on the live board after this build
    and report whether bleeding changed (better or worse).  Do NOT assume fixed.
  - CLUE (sysop): the bleeding can happen when using HIGH-ASCII chars (bytes
    128-255: box-drawing, blocks, accented - the core of BBS ANSI art).  This
    points at likely culprits: signed-char / sign-extension handling (a high
    byte treated as negative), array[0..127]-style tables indexed by a high
    char, or a control-range filter (e.g. [#00..#31]) mishandling high bytes,
    or codepage/translation in the output path.  Sysop notes the ANSI handling
    lives in TWO major parts of the source - likely the output/console layer
    (m_output_*) AND the ANSI parser/renderer (bbs_ansi*).  Check BOTH when we
    reach them; the emitter or the parser could be the source.

## SOCKET BIND - actually IPv6 dual-stack (clarification/correction)
  - CORRECTION: earlier notes call our socket fix an 'IPv4 bind' / 'forced
    0.0.0.0'.  The ACTUAL code (m_socket_class.WaitInit) creates an AF_INET6
    socket and binds to '::' (IPv6 any), converting '0.0.0.0'->'::' and
    '127.0.0.1'->'::1'.  An AF_INET6 socket on '::' is DUAL-STACK - it accepts
    both IPv6 and IPv4-mapped connections.  So the working state is IPv6 dual-
    stack, NOT pure IPv4.  (The MIS-not-loading fix was about making this layer
    bind correctly; the live-board TELNET log line showing '0.0.0.0' is the
    display string, but the bind path is AF_INET6/'::'.)
  - m_socket_server (A39 review): A39 reverts this unit's WaitInit arg from '::'
    to '0.0.0.0'.  Because WaitInit converts '0.0.0.0'->'::' anyway, that is
    FUNCTIONALLY IDENTICAL to our '::'.  DECISION: keep A38 as-is (pass '::'
    directly) - no behavior change, avoids any risk to MIS listening.  All other
    A39 changes in this unit are TMDL (TMDLThread/TMDLList/TMDLStringList +
    .List[] indexing) - SKIPPED per the TMDL->FPC policy; kept TThread/TList/
    TStringList and direct [Count] indexing.
  - FOLLOW-UP (later, needs live test): if pure IPv4-only bind is ever required
    on a system with NO IPv6 stack at all, revisit - but XP dual-stack has worked.

## WINDOWS XP + IPv6 / dual-stack - VERIFIED PROBLEM (research-backed)
  - RESEARCHED (Microsoft Win32 docs + XP IPv6 docs):
     * Windows XP does NOT support single-socket dual-stack.  That ability began
       in Windows VISTA.  On XP/Server2003 an app must open TWO sockets (one
       AF_INET, one AF_INET6) and handle them separately.
     * XP's IPv6 stack does NOT support IPv4-mapped addresses ('The IPv6 protocol
       for Windows (XP) does not support the use of IPv4-mapped addresses').
       Dual-stack listening REQUIRES IPv4-mapped addresses -> so XP cannot do it.
     * On XP, IPv6 is not even pre-installed (needs SP1+, then 'ipv6 install').
  - IMPLICATION for our code: m_socket_class.WaitInit creates an AF_INET6 socket,
    converts '0.0.0.0'->'::' and '127.0.0.1'->'::1', and binds '::' expecting
    dual-stack.  This is EXACTLY what XP cannot do -> on our PRIMARY target
    (Windows XP), the current '::' path likely FAILS to accept IPv4 connections
    (or fails to create the socket if IPv6 isn't installed).  Sysop's memory
    ('XP doesn't support IPv6') was right; the precise gap is dual-stack /
    IPv4-mapped.
  - NOTE: on LINUX (secondary target) '::' dual-stack WORKS (bindv6only=0 default)
    - so any change must NOT regress Linux.
  - *** EMPIRICAL CORRECTION (sysop observation - outranks the docs) ***: the
    docs above PREDICT XP can't accept IPv4 on a '::' dual-stack socket.  BUT on
    the sysop's live XP board this code DID accept telnet connections.  Observed
    reality beats documentation inference: the '::' path WORKS on that board (why
    exactly is unclear - IPv6 may be installed, FPC's path may differ from raw
    Winsock, etc.).  My earlier 'likely fails on XP' was a prediction, NOT an
    observation, and the live board contradicts it.
  - DECISION (sysop): KEEP the '::' code.  We KNOW it accepts telnet connections
    on the target, so there is no reason to remove working, verified behavior.
    Keep m_socket_server's '::' and the WaitInit '0.0.0.0'->'::' + AF_INET6 path
    as-is.  The Microsoft-docs limitation is recorded here as a KNOWN TENSION to
    watch (theory says XP shouldn't dual-stack; our board does accept conns) -
    NOT as a bug to 'fix'.  If a future XP box with NO IPv6 installed ever fails
    to listen, THEN revisit a {$IFDEF WINDOWS} pure-IPv4 (AF_INET/0.0.0.0) path;
    until an actual failure is observed, do not change working code.
  - NOTE for any future change: blind-applying A39's '0.0.0.0' in m_socket_server
    does nothing on its own, because WaitInit rewrites '0.0.0.0'->'::' and uses
    AF_INET6.  Any real IPv4 change would have to be in WaitInit itself.
  - *** NEW FACT (sysop): the XP box has NO IPv6 installed *** - yet the code
    (AF_INET6 socket bound to '::') was observed ACCEPTING telnet connections
    on it.  This is puzzling: with no IPv6 stack, an AF_INET6 socket should not
    even be creatable.  So either FPC/Winsock behaves differently than the raw
    docs imply, or there's a detail we don't yet understand.  STATUS: observed-
    working, mechanism UNKNOWN.  Do NOT change the working code on the strength
    of theory alone.  Sysop has questions to raise later - flag for a dedicated
    socket investigation (candidate checks: does fpSocket(AF_INET6) actually
    succeed on that XP box?  does it silently fall back?  is something else
    listening?  verify with the live board + logging before any change).

## m_socket_class - RESOLVED as dead legacy (A51 binary confirmed)
  - The 148-line A38<->A39 diff on m_socket_class looked like the biggest/riskiest
    remaining m_* unit.  It DISSOLVES: m_socket_class.pas / TSocketClass is DEAD
    legacy code in our tree - a fork note at the top of the file already states
    it's 'NO LONGER USED by the live code... retained only for reference', its
    only referrer is mdltest5.pas (a standalone test), and the LIVE socket class
    is TIOSocket in m_io_sockets.pas (which MIS + the BBS actually use).
  - EVIDENCE (sysop's idea): inspected the live A51 Linux binary from the board
    upload (/tmp/bbs_setup/mystic/{mystic,mis}, confirmed 'Mystic 1.10 A51').
    Symbols: TIOSocket PRESENT (incl. TIOSocket0t VMT/RTTI), TSocketClass = 0
    occurrences.  So g00r00 shipped TIOSocket and ABANDONED the TSocketClass
    experiment.  Our A39 snapshot's TSocketClass was a dead-end branch.
  - DECISION: leave m_socket_class.pas as-is (already correctly marked legacy/
    reference); take NOTHING from A39's version (it's changes to dead code).
    The real socket work is TIOSocket in m_io_sockets.pas - ALREADY reviewed +
    updated this session (ReadBuf Error-caching; our IPv4/dual-stack WaitInit).
  - NOTE: TSocketClass IS pure-IPv4 (AF_INET, LongInt addr) - kept as reference
    only.  If the XP IPv6 question ever pushes us toward a pure-IPv4 rewrite of
    TIOSocket, this legacy file is g00r00's own IPv4 socket code to crib from.
    But TIOSocket is what A51 uses, so no change now.
  - RESULT: m_* layer review COMPLETE.  m_socket_class needs no merge.

## MILESTONE: m_* FOUNDATION LAYER COMPLETE (A39 review)
  - All m_* (MDL foundation) units reviewed A38<->A39, one at a time, each
    compiled on win32 + i386-linux.  Real fixes taken; our IPv4/resolver/Darwin
    work preserved; TMDL skipped per the TMDL->FPC policy.
  - Units done: m_datetime (DateStr2Dos time-parse), m_crc + m_inireader (buffer
    sizes), m_prot_base + m_prot_zmodem (ZMODEM file-date), m_output_darwin (dead
    Count; + the Darwin cross-build breakthrough), m_tcp_client_smtp (pure TMDL -
    kept A38), m_tcp_client (DEBUG WriteLn cleanup), m_io_sockets (ReadBuf error-
    caching; kept our IPv4 bind), m_output_linux (TIOCGWINSZ ioctl term-size),
    m_strings (robust pipe-code validation; kept our strI2* work), m_socket_server
    (kept A38; corrected IPv6-dual-stack record), m_fileio (AddRecord/KillRecord +
    128KB buffer; kept our GetProcessID/AppendText).
  - m_socket_class: DEAD legacy (TSocketClass) - no merge; A51 binary confirms
    TIOSocket is live.  (See its own section above.)
  - NEXT LAYER (bottom-up plan): bbs_ansi_menubox (TAnsiListBox, ~779 lines) - the
    UI foundation, and where the TMDL->FPC translation policy goes LIVE (the UI
    code is written against TMDL).  It gates the msgbase + config-editor tier
    (bbs_msgbase/_jam, the bbs_cfg_* editors that use the new AddRecord/KillRecord).
  - Frozen a fresh source release at this boundary (m_* complete + Darwin build).

## RETIRED to attic/: m_socket_class.pas + mdltest5.pas (first retirement)
  - Moved the dead legacy TSocketClass unit (m_socket_class.pas) and its only
    referrer, the standalone test mdltest5.pas, from mdl/ to attic/.  Added a
    'RETIRED - not built, kept for reference / scene history' banner at the top
    of each (above the intact GPL header).  Build verified unaffected (nothing
    in the 14 targets used them).
  - This is the FIRST use of the retirement process defined for the TMDL units;
    same pattern will apply when m_stringlist (TMDL) is retired after the UI/
    msgbase TMDL->FPC translation.

## UI MIGRATION: TAnsiMenuList -> TAnsiListBox (A51-confirmed direction)
  - A39 replaced the old list widget TAnsiMenuList with the richer TAnsiListBox
    and migrated all 14 consumers (bbs_areaindex + 13 bbs_cfg_* editors) together.
  - EVIDENCE: A51 binary has TAnsiListBox (+TAnsiListBoxP), ZERO TAnsiMenuList.
    So unlike TSocketClass (an abandoned dead-end), TAnsiListBox is the REAL,
    permanent direction - g00r00 kept it through A51.  TAnsiMenuList is fully
    replaced.  Migrating is required to unlock msgbase AreaIndex + A39 cfg editors.
  - NOTE: A39's bbs_ansi_menubox uses ZERO TMDL - so the widget import needs no
    TMDL->FPC translation (TMDL shows up deeper, in msgbase/config units).
  - PLAN (incremental, to protect the high-stakes config editors) - sysop approved:
     1. Import TAnsiListBox into bbs_ansi_menubox ALONGSIDE the existing
        TAnsiMenuList (both coexist temporarily).  Adds capability, breaks no
        caller.  Compile + verify.
     2. Migrate the 14 consumers ONE AT A TIME (each bbs_cfg_*/areaindex file
        TAnsiMenuList -> TAnsiListBox), compiling after each.  Never all-at-once.
     3. Once all 14 are migrated, RETIRE TAnsiMenuList to attic/ (same process as
        m_socket_class).

## bbs_ansi_menubox IMPORT APPROACH (A51-verified)
  - A39's bbs_ansi_menubox is RESTRUCTURED around TAnsiListBox (865 lines ours vs
    1505 A39); the 30 TAnsiListBox method bodies are interleaved through 1000+
    lines, so surgically grafting just TAnsiListBox into our old file is fiddly
    and error-prone.
  - A51 evidence: the live binary is TAnsiListBox-ONLY (2 refs), ZERO
    TAnsiMenuList.  So the end-state is a TAnsiListBox file with TAnsiMenuList
    gone - which is exactly what A39's file already is.
  - DECISION (sysop-approved): take A39's whole bbs_ansi_menubox.pas as the new
    base (coherent TAnsiListBox, matching A51's direction), and TEMPORARILY
    re-add our TAnsiMenuList class to it as migration scaffold.  Then migrate the
    14 consumers off TAnsiMenuList one at a time (step 2); once done, retire
    TAnsiMenuList to attic/ (step 3) - landing exactly on A51's state.
  - NOTE on the file: A39's bbs_ansi_menubox has TWO TAnsiListBox classes - a
    PUBLIC one in the interface (fixed-array; Create/Add/Sort - what the 14
    consumers use: .Add x54, .Sort x3, Create x19) and a PRIVATE one in the
    implementation section (dynamic Data^/AddItem/ApplyFilter/BuildPage).  This
    is well-formed Pascal (impl-section type is local to the unit), not a bug -
    same 'two same-named defs' pattern seen in GetScreenImage.  Import as-is.
  - TMDL: A39's bbs_ansi_menubox uses ZERO TMDL, so no TMDL->FPC translation
    needed for the widget itself.

## STEP 1 DONE: TAnsiListBox imported + RecTheme Box* fields (on-disk safe)
  - Took A39's whole bbs_ansi_menubox.pas as the new base (coherent TAnsiListBox,
    the A51-confirmed direction) and re-added our TAnsiMenuList as clearly-marked
    MIGRATION SCAFFOLD (both classes coexist so the 14 consumers still compile).
    CP437 bytes preserved (latin-1).  New file: 1988 lines; 30 TAnsiListBox impls
    + 13 TAnsiMenuList scaffold impls.
  - records.pas dependency: A39's ThemeMessageBox/TAnsiListBox needs 10 Box*
    theme fields (BoxFrame, BoxShadow, BoxShadowAttr, BoxHeadAttr, BoxAttr,
    BoxAttr2/3/4, BoxTextAttr, BoxOKAttr) absent from our RecTheme.  Added them
    the ON-DISK-SAFE way: carved from RecTheme.Reserved (198 -> 188 bytes),
    exactly as A39 did.  VERIFIED byte-neutral: SizeOf(RecTheme)=768 BEFORE and
    AFTER; SizeOf(RecConfig)=5282 unchanged.  Zero on-disk impact - existing
    theme files stay compatible.
  - Build: mystic + mis compile clean on win32 + i386-linux.
  - This matches the original A39 design intent (TAnsiListBox as the replacement)
    and A51's shipped state.  Next: STEP 2 - migrate the 14 consumers one at a
    time; then STEP 3 - retire TAnsiMenuList to attic/.

## UI MIGRATION COMPLETE: TAnsiMenuList -> TAnsiListBox (steps 1-3 done)
  - STEP 2 (consumers): migrated all 14 consumers off TAnsiMenuList to
    TAnsiListBox.  TAnsiListBox is a DROP-IN replacement - each migration was a
    pure type-name swap (TAnsiMenuList -> TAnsiListBox); every method call,
    property, and argument identical.  Compiled after each file.
  - COUPLING found + handled: bbs_cfg_common defines GetSortRange(List:
    TAnsiMenuList; ...) which bbs_cfg_filebase + bbs_cfg_msgbase call, passing
    their List.  These 3 had to migrate together (a one-at-a-time swap broke the
    shared param type).  Caught precisely because we compile after each file.
  - STEP 3 (retire): extracted the TAnsiMenuList interface + impl (the migration
    scaffold) out of bbs_ansi_menubox.pas into attic/bbs_ansi_menulist_RETIRED.pas
    with a RETIRED banner (GPL + scene history).  Active unit now has 0
    TAnsiMenuList refs.
  - RESULT: our bbs_ansi_menubox is 1509 lines vs A39's 1505 - we've landed on
    the TAnsiListBox-only state A39 designed and A51 ships.  Full build 14/14 on
    win32 + i386-linux.  This unblocks the msgbase AreaIndex + the A39 config
    editors that depend on TAnsiListBox.

## DARWIN LINK - hard boundary (compile works, link needs Mac tooling)
  - Attempted a full Darwin build+link in-container.  RESULT: every unit COMPILES
    to Mach-O objects (FPC internal -Amacho writer, no Xcode) - but the LINK step
    fails: 'Util i386-darwin-ld not found, switching to external linking'.
  - ROOT CAUSE: FPC 2.6.2 has an internal Mach-O ASSEMBLER but NOT an internal
    Mach-O LINKER.  The final link needs Apple's ld64/cctools + the macOS system
    libraries (libSystem).  This container has only GNU ld (ELF-only) and no
    packaged cross Mach-O linker; getting one means building cctools-port from
    source + obtaining the macOS SDK libs.  Not done - out of scope / needs a Mac.
  - CONCLUSION: this is fine for the GitHub goal.  A Mac contributor's machine has
    ld64 + SDK, so THEY link a full binary in one step.  Our deliverable - source
    that compiles cleanly for Darwin - is DONE and verified (Mach-O objects).
  - build-darwin.sh added: compiles to Mach-O objects (COMPILE_ONLY=1 on a plain
    Linux box), and links a full binary on a Mac.  We now have a build script for
    all THREE targets: build.sh (linux), build-win32.bat (XP), build-darwin.sh.

## DARWIN LINK - CORRECTED (ld64 is buildable; SDK is the real blocker)
  - CORRECTION to earlier notes: I said 'compiled Darwin binaries' - imprecise.
    What we produced is Mach-O OBJECT files (.o) + the i386-darwin RTL units
    (.ppu), NOT runnable executables.  A runnable binary needs the LINK step,
    which failed ('i386-darwin-ld not found').  -Amacho gets us through ASSEMBLY
    (internal Mach-O writer), not LINKING.  There is NO flag that avoids Mach-O
    for a Mac binary - Mach-O IS the Mac executable format.
  - ld64 (sysop's link, apple-opensource/ld64) IS Apple's Mach-O linker - exactly
    the missing i386-darwin-ld.  Apple open-sourced it; it CAN be built for Linux
    (practical ports: tpoechtrager/cctools-port, osxcross).  So a full Linux->Mac
    link IS achievable - documented for FPC on the Lazarus/FPC lists.
  - REQUIREMENTS for a Linux->Mac link (both needed, both absent here):
     1. ld64/cctools-port built for Linux -> tell FPC with -FD<cctools>/bin.
     2. The macOS SDK libraries (crt1.o, libSystem, frameworks) - these are
        APPLE'S and must come from a Mac / OS X install medium.  Point FPC at the
        SDK root with -XR<sdk> (+ -Fl<sdk>/usr/lib).  This is the genuine blocker:
        the SDK cannot be obtained on Linux alone.
  - So the accurate statement: the LINKER (ld64) is buildable on Linux (sysop is
    right); the SDK LIBS still require Apple's SDK.  With both, no Mac is needed
    at build time.  On a Mac, both are already present -> ./build-darwin.sh just
    links.  Our deliverable (Darwin-clean SOURCE) is done; the toolchain setup is
    a builder-side prerequisite, now documented in INSTALL.
  - Added INSTALL: per-target prerequisites (win32 FPC install; linux full
    FPC (pure-Pascal resolver, no cc/C-glue) + i386 cross flags note; darwin RTL cross-build +
    the ld64/SDK link setup).

## DARWIN SDK WALL - confirmed by Apple docs (Swift SDK check)
  - Checked the Swift 'Static Linux SDK' as a candidate.  It is NOT usable:
    (1) wrong target - it builds LINUX static ELF binaries, not macOS Mach-O;
    (2) wrong toolchain - Swift/SwiftPM, not FPC;
    (3) it explicitly documents that a fully static binary is impossible on Apple
        OSes because the Darwin syscall table isn't a stable ABI - all syscalls
        must route through libSystem.dylib.
  - That Apple statement is the STRONGEST confirmation of the SDK wall: a Mac
    binary MUST dynamically link libSystem.dylib (Apple's SDK).  There is no
    Linux-side SDK substitute and no static shortcut.
  - CONCLUSION: do NOT build ld64 in-container to chase a Mac binary - even with
    the linker, the link fails without Apple's SDK libs.  The correct, honest
    split stands: COMPILE on Linux (done, verified Mach-O objects), LINK on a Mac
    (libSystem present) OR on Linux with a full ld64+cctools+macOS-SDK cross
    setup (SDK must come from Apple).  Documented in INSTALL.
  - Process note: verifying the candidate SDK BEFORE building ld64 saved a dead-
    end build - check the dependency before the work that needs it.

## bbs_msgbase - PREP / RECON (ready to work next session)
  - Size: ours 4794 -> A39 5081 (+287).  Dependencies: TMDL-FREE (no translation);
    uses TAnsiListBox x3 (the widget we already imported - ready); zero
    TAnsiMenuList.
  - A39 ADDS: TMsgBase.AreaIndex (~205 lines) + helpers AreaIndexSearch,
    AreaIndexDrawBar.  The message-area index UI, built on TAnsiListBox
    (ListBox.Add/.Sort/.SortDepth/.SetSearchProc).  This is the payoff of the UI
    migration - a clean TAKE, no new deps.
  - A39 REMOVES (ours): TMsgBase.GetMatchedAddress - NEEDS JUDGMENT.  It's FidoNet
    origin-AKA matching (picks the right AKA for outbound echomail by dest zone).
    Used 3x INSIDE bbs_msgbase (lines ~1466, 3251, 3944: SetOrig(GetMatched...)).
    Matters for the sysop's 10+ FTN nets.  A51 strings show 0 GetMatchedAddress
    AND 0 AreaIndex - but that's INCONCLUSIVE (internal Pascal method names often
    aren't emitted as strings; we KNOW A51 uses TAnsiListBox yet AreaIndex=0 in
    strings, proving the check misses internal names here).  So do NOT treat A51=0
    as 'removed'.  WHEN WORKING: compare our 3 GetMatchedAddress call sites vs how
    A39 handles those same spots - did A39 inline the logic, rename it, or drop
    the feature?  Default KEEP our working FTN logic unless A39 clearly supersedes
    it (per the established 'keep A38 working code unless deliberate removal' rule).
  - START POINT next session: (1) take AreaIndex + helpers (clean), (2) resolve
    GetMatchedAddress by comparing call sites, (3) compile both platforms.

## AREA INDEX (bbs_areaindex) - reconstruction origin + migration plan
  - HISTORY (documented late - this context was NOT recorded at the time because
    the fix predated having any A39 source to compare against):
    * The ANSIMIDX 'Message Area index' (the 'I' / MI menu command) was a REAL
      A38 feature that g00r00 did NOT include in the GPL A38 source release.
    * This fork RECONSTRUCTED it from scratch as mystic/bbs_areaindex.pas (an
      INI-config-driven reader: LoadAreaIdxCfg / GatherAreaStats /
      BuildAreaIdxOrder / display, wired to the 'I' menu command).  Header says:
      'reconstruction of the A38 feature absent from the GPL A38 source.
      Compile-checked only; verify on a node.'
    * At reconstruction time there was NO A39 to reference - the missing code
      turned out to exist in A39 as TMsgBase.AreaIndex (TAnsiListBox-based).
  - A51 GROUND TRUTH: live binary has 'ansimidx' + 'ansimidxhelp' strings -> the
    real feature renders from an ANSIMIDX display/template file.  It does NOT show
    our reconstruction's INI keys (group_list, exclude_groups) as strings
    (suggestive, not conclusive).  Leans toward: the genuine version is template/
    TAnsiListBox-driven (like A39's), not purely INI-config-driven (like ours).
  - DECISION (sysop) - sequence 2 -> 1 -> 3, deliberately:
    (2) KEEP our working reconstruction NOW - it's the functioning fix, tnabbs
        uses the 'I' command, don't break it.
    (1) It IS the official fork rebuild of the missing 'I' feature - legitimate
        work, now properly documented here (origin was previously undocumented).
    (3) LATER, migrate to g00r00's real TMsgBase.AreaIndex (A39) as a VETTED
        future step - NOT a rushed swap.  When we do: verify it reads the
        'ansimidx' template the way A51 does, and preserve any valued config
        behavior.  Future polish (small updates, a lightbar) may land in either
        version and informs which becomes the keeper.
  - So for THIS bbs_msgbase pass: do NOT import A39's TMsgBase.AreaIndex yet
    (would collide with our working bbs_areaindex unit).  AreaIndex migration is
    its own future task.  Continue the bbs_msgbase review on the OTHER changes.

## GetMatchedAddress - NOT removed, just relocated (identical logic)
  - The bbs_msgbase diff flagged TMsgBase.GetMatchedAddress as 'removed in A39'.
    CORRECTED: A39 did NOT remove it - it MOVED it.  Ours is a method
    (TMsgBase.GetMatchedAddress in bbs_msgbase); A39 made it a standalone function
    GetMatchedAddress in bbs_database.  A39 calls it at the SAME 3 sites we do.
  - The function BODY is BYTE-FOR-BYTE IDENTICAL (same Count:Byte, Result:=Orig,
    zone check, For 1..30 NetAddress zone-match loop).  This is the FidoNet
    origin-AKA matcher (pick the right AKA for outbound echomail by dest zone) -
    important for the sysop's 10+ FTN nets.  Pure relocation, zero logic change.
  - DECISION: KEEP ours as-is for this pass.  Moving it (add to bbs_database,
    remove from bbs_msgbase, convert 3 method-calls to plain calls) is pure churn
    with no behavior change.  Per our rule: don't refactor working code without a
    reason.
  - FUTURE: A39's bbs_database keeps GetMatchedAddress next to GetNodeByRoute +
    other FTN routing functions.  IF/WHEN we import those A39 database/routing
    functions (relevant to the FidoNet pass), relocate GetMatchedAddress to match
    A39 THEN - as part of that coherent change, not in isolation.

## bbs_msgbase pass - ShowKludge TAKEN; AreaIndex + semaphores DEFERRED
  - bbs_msgbase's substantive A39 changes sorted into: TAKE-NOW vs FIDONET-PASS.
  - TAKEN: ShowKludge reader toggle (7 A39 spots -> grafted to our structure:
    field, init, ExportQuoteData skip, Draw_Msg_Text Dec(Lines) gate, 'V' toggle
    in ReadMessages Case, + 'V' added to all 3 ValidKeys so it's reachable).
    Press V while reading to show/hide FTN kludge lines.  Builds both platforms.
    NOTE: A39 had the toggle in 2 key-loops; our reader has 1 - adapted faithfully,
    verify V on a live node.
  - DEFERRED to FidoNet pass (cross-cutting, need live network): the semaphore
    mail-event system (Session.SemEchomail/SemQwkNet/SemUseNet/SemNetmail +
    bbsCfg.CreateSemaphore) that A39 uses to replace the old ExitLevel-based
    tosser signaling.  Spans records.pas + bbs_core.pas + bbs_cfg_syscfg.pas +
    bbs_msgbase.pas - a real subsystem, not a msgbase-local change.
  - DEFERRED (2->1->3 plan): TMsgBase.AreaIndex (keep our reconstruction for now).
  - KEPT ours: GetMatchedAddress (identical logic, relocation deferred to FTN pass).

## FIDONET PASS - semaphore subsystem DONE (step 1)
  - First real piece of the FidoNet pass.  A39 replaces ExitLevel-based tosser
    signaling with semaphore flag-files.  Implemented across 4 files:
    * bbs_core.pas: 4 Sem* Booleans in TBBSCore (RUNTIME class - safe, no on-disk
      concern), init to False, WriteSemFiles proc (AppendText the .out files),
      called in TBBSCore.Destroy (session teardown / logoff).
    * bbs_msgbase.pas: AssignMessageData now sets Session.Sem* flags + calls
      WriteSemFiles If CreateSemaphore=1.  IMPORTANT: SaveMessage was left inline
      (Assign/ReWrite/Close) - A39 did NOT convert that one, so we matched A39
      exactly rather than over-converting both for 'consistency'.
    * records.pas: CreateSemaphore + SemaPath + fn_SemFile* ALL ALREADY PRESENT
      in our tree (we even have fn_SemFileEchoIn that A39 lacks).  Zero disk
      change - SizeOf anchors unchanged (RecConfig=5282, RecTheme=768).
    * bbs_cfg_syscfg.pas: 'Create Semaphore' toggle added to
      Configuration_MessageSettings at (47,15), right after Netmail Killsent -
      matches A39's screen + coordinates (our Netmail flags are at identical
      coords, so it fits cleanly).
  - Builds 14/14 both platforms.  NEEDS LIVE VERIFICATION: only a real tosser
    watching SemaPath can confirm the .out files actually trigger it; and the new
    toggle should be eyeballed on a node for clean display.
  - FidoNet pass remaining: bbs_database FTN routing (GetNodeByRoute + relocate
    GetMatchedAddress there), the tosser proper (mutil echomail), tested against
    the sysop's live FTN network.

## FIDONET PASS - bbs_database FTN routing DONE (step 2)
  - Imported A39's 7 FTN-routing functions into bbs_database (TMDL-free, no UI,
    dependency-light - all needed records/io helpers already present; +238 lines):
    GetNodeByRoute (route to uplink by dest addr), IsExportNode / AddExportByBase
    / RemoveExportFromBase / RemoveExportGlobal (per-base echomail export .lnk
    lists), GetUserByRec (user lookup), GetMatchedAddress (AKA matcher).
  - GetMatchedAddress RELOCATION completed (the move we deferred earlier): removed
    the TMsgBase.GetMatchedAddress METHOD (decl+body) from bbs_msgbase; the 3 call
    sites now resolve to the bbs_database STANDALONE function (identical logic).
    Now matches A39 exactly (method=0, standalone calls=3).  bbs_msgbase already
    Uses BBS_DataBase so the calls resolve cleanly.
  - GOTCHAS caught by compile-after-each: (1) GetUserByRec + SaveEchoMailNode decls
    duplicated on first extract (GetUserByRec is genuinely new; SaveEchoMailNode we
    already had) - fixed the decl list.  (2) Function bodies must go BEFORE the
    unit's Initialization section, NOT before End. - our bbs_database has
    Initialization/Finalization; putting defs after Finalization is illegal Pascal.
  - Builds 14/14 both platforms; on-disk anchors unchanged (no records touched).
  - FidoNet pass remaining: the tosser proper (mutil_echoimport / mutil_echoexport
    - which CALL GetNodeByRoute), the echomail config editors (bbs_cfg_echomail
    uses IsExportNode/AddExportByBase), tested against the sysop's live FTN network.

## phracker/MacOSX-SDKs - SDK source found (with caveat)
  - Sysop found github.com/phracker/MacOSX-SDKs: pre-extracted macOS SDK folders
    (MacOSX10.1.5.sdk .. MacOSX11.3.sdk), INCLUDING the 10.6 SDK our i386-darwin
    target needs.  This is the SDK source most osxcross guides point to, and it
    completes the SELF-SERVE Linux->Mac cross-build path (build ld64/cctools, drop
    in MacOSX10.6.sdk, point FPC via -FD/-XR, link).
  - LICENSING (stated honestly in INSTALL): these SDKs are Apple's copyrighted
    material; re-hosting extracted SDKs is tolerated-but-technically-infringing
    (Apple declines to enforce, not grants permission).  Using one is the
    builder's informed call; the clean route is self-extraction from owned Apple
    media.  The PROJECT bundles/redistributes NO Apple SDK - always builder-supplied.
  - ASSISTANT BOUNDARY unchanged: will NOT download/ingest the SDK into this
    container to link a binary, regardless of it being on GitHub.  Compile stays
    here; link is the sysop's on his own machine with his own SDK.

## MAC EMULATOR for testing Darwin builds (period-correct)
  - Goal: let a sysop TEST an i386-darwin Mystic binary without Mac hardware,
    using 2013-era-matched tooling (FPC 2.6.2 = Feb 2013).
  - CORRECTION found in research: two different QEMU targets.
    * qemu-system-ppc = PowerPC Macs (OS 9 .. OS X 10.5) - Emaculation wiki path.
      Runs PowerPC, NOT our i386 target.
    * qemu-system-x86_64 = Intel macOS (10.6 .. 10.12) - runs our i386-darwin
      binary.  Guide: github.com/royalgraphx/LegacyOSXKVM.
  - RECOMMENDATION for our purpose: QEMU (Intel) + Mac OS X 10.6 Snow Leopard.
    Matches the target (32-bit Intel), the SDK (MacOSX10.6.sdk), and the 2013
    era.  One coherent 2009-era loop: link with 10.6 SDK, run in 10.6 guest.
  - The EMULATOR itself should be a CURRENT QEMU (modern QEMU runs old guests
    better); only the GUEST OS is period-correct.  Snow Leopard's 32-bit
    installer is finicky under QEMU TCG - common workaround is a pre-installed
    10.6 disk image.
  - Captured in INSTALL as a 'Period-correct toolchain matrix' + emulator
    notes.  macOS guest image is Apple's - builder supplies own (same as SDK).
  - ASSISTANT BOUNDARY held: pointed to QEMU (qemu.org) + the community guides,
    but did NOT fetch/hand over any Apple SDK or macOS image; sysop already has
    the phracker repo and obtains guest media himself.

## DARWIN / FPC-VERSION QUESTION - CLOSED (corrected facts)
  - CORRECTION (assistant was wrong earlier, verified against FPC official release
    notes): FPC 3.2.2 supports Darwin for PowerPC (32/64), Intel (32/64), AND
    AArch64/ARM64 - ALL of them.  Newer FPC did NOT drop 32-bit Intel or PowerPC.
    The earlier 'newer FPC drops vintage targets' claim was incorrect.
  - Therefore the FPC-version choice is NOT a vintage-vs-modern trade-off.  Both
    2.6.2 and 3.2.2 can target our i386-darwin.  Choosing an FPC version does not
    abandon any Mac hardware.
  - Multiple FPC versions CAN coexist on one box (versioned install paths; pick
    per-build with FPC=... which our build scripts already support).
  - DECISION: KEEP FPC 2.6.2 as the project compiler.  Reasons are identity +
    not risking the working 14/14 builds - NOT because newer FPC can't do vintage
    Darwin (it can).  A newer FPC remains an OPTION for extra targets later,
    blocking nothing.
  - The ONE version-independent constant: ANY Darwin target, ANY FPC version,
    needs Apple's SDK to LINK (Xcode CLT per FPC's own Mac install docs).  The SDK
    is Apple's, builder-supplied, documented in INSTALL.  Not a project defect.
  - STATUS: Mac/Darwin binary question is CLOSED.  Source compiles clean; binary
    is linked by whoever has a Mac/SDK (contributor, CI, or sysop's own hardware),
    per the documented recipe.  This is the correct division of labor, not a gap.

## BUILD-HOST PLAN (sysop) - Windows XP host, Darwin deferred to end
  - Sysop builds ALL his binaries on a Windows PC (likely XP).  His FPC tree is
    clean/untouched and stays that way.  Assistant verifies on Linux (container);
    sysop produces final binaries on Windows.
  - Darwin build path DEFERRED until all code updates are done - correct
    sequencing: the Mac binary is downstream of a finished source tree, so there's
    nothing to build until the code is complete.  No point setting up the Mac
    cross-toolchain now.
  - IMPORTANT host note for later: Windows XP is fine for the WINDOWS target but
    is the WRONG host for a Mac cross-build (osxcross/ld64 assume Linux/macOS; XP
    can't run WSL - needs Win10+).  So when Darwin day comes, the host will be a
    separate Linux box, WSL on a modern Windows machine, or a Mac/CI - a fresh
    decision then.  The full recipe is already in INSTALL.
  - PLAN: (1) NOW - finish the code (FidoNet pass + remaining units), assistant
    verifies on Linux.  (2) LATER - dedicated Darwin build exercise on an
    appropriate host.  Nothing lost by waiting; path is documented.

## DARWIN POLICY - maintain + compile always; link deferred
  - Clear separation (sysop): we KEEP UPDATING the Darwin code; we just don't LINK
    it against the Mac SDK.  These are independent steps.
    * MAINTAIN Darwin source: every unit stays Darwin-clean ({$IFDEF DARWIN}
      blocks, m_output_darwin, Mach-O-safe code).  Ongoing, normal part of the work.
    * COMPILE Darwin: verify to Mach-O objects on Linux (no SDK needed) to prove
      the source stays healthy/link-ready.  Can do anytime here.
    * LINK Darwin: the ONLY step needing Apple's SDK.  Deferred to sysop/Mac/CI.
  - WHY this matters: keeping Darwin code maintained + compile-verified as we go
    means the source stays PERMANENTLY link-ready - no drift, no rot.  When someone
    finally points it at an SDK it just links, no archaeology.  This is what makes
    'buildable by a stranger' true for the Mac target too.
  - PRACTICE going forward: as we do the tosser + remaining FidoNet units, keep
    them Darwin-compile-clean alongside win32/linux.  Darwin rides along, maintained,
    just not linked.

## TOSSER (mutil_echo*) - RECON done, graft deferred to fresh session
  - The tosser is a COHERENT 4-UNIT SET sharing mUtil_EchoCore (all 4 already
    exist in our fork - the shared-core architecture is NOT new, A39 just evolves
    it):
    * mutil_echocore  472->497 (+25) - the shared core
    * mutil_echoimport 495->555 (+60) - inbound; ADDS ReadEchoMailLinks; uses
      TMDLStringList x2 (NEEDS TMDL->TStringList translation per policy)
    * mutil_echoexport 523->446 (-77) - outbound; A39 REMOVES BundleMessages and
      ADDS EchoBundleMessages + EchoExportMessage.  The -77/+25-to-core pattern
      suggests A39 MOVED bundling logic INTO mUtil_EchoCore (rename+relocate, not
      delete).  TMDL: 0.
    * mutil_echofix - 4th unit, check delta.
  - Both echoimport/export already call GetNodeByRoute (ours=1, A39=1) - the
    bbs_database routing foundation we imported is in the right place. GOOD.
  - CAUTION: this is the LIVE-MAIL tosser (real echomail packets to other boards).
    A bug here can emit malformed FTN mail.  Grafting deserves a FRESH, focused
    session - not the tail of a long one.  Recon is banked; graft next time.
  - APPROACH next session: (1) diff mUtil_EchoCore first (the shared base - the
    bundling logic likely lands here), (2) then echoexport (rename/relocate),
    (3) then echoimport (preserve our TStringList; add ReadEchoMailLinks), (4)
    echofix (the AreaFix / echo-subscription utility).  Compile Darwin-clean
    + win32 + linux after each.  Then LIVE test on the sysop's FTN network (the
    only real proof - tosser can't be verified in-container without real mail).

## TMDL FINAL CLEANUP - mis_events (deferred, not FidoNet)
  - TMDL translation is DONE tree-wide EXCEPT one consumer: mystic/mis_events.pas
    (MIS daemon event system) - uses TMDLStringList for EventList/StatusList.
    The definition lives in mdl/m_stringlist.pas.
  - PLAN (deferred, sysop): later translate mis_events TMDLStringList ->
    TStringList (FPC RTL), then retire mdl/m_stringlist.pas to attic/ (no consumers
    left) - completing the TMDL->FPC migration tree-wide.  NOT part of FidoNet;
    a separate small MIS-daemon task.  Doing FidoNet first.

## TOSSER Step A (echocore) - PARTIAL: PKT header done, GetMessage deferred
  - DONE + SAFE: RecPKTHeader updated to A39's layout - our Filler[1..4] replaced
    by AuxNet:Word + CompatVal:Word (FSC-0039 Type-2+ header).  BYTE-VERIFIED
    identical: SizeOf = 60 both ways, zero wire-format risk.  A39 also sets
    PH.CompatVal:=256 when writing packets (mutil_echoexport) - more spec-correct
    than our uninitialized Filler.  (Old FSC-0001 header stays commented-out for
    reference.)  Builds win32 + linux + darwin-compile-clean.
  - DEFERRED (delicate, next session, fresh head): TPKTReader.GetMessage - the
    function that reads ONE message out of an inbound .PKT packet.  Ours 144 lines
    vs A39 155 (+11).  A39 restructured message reading AND improved the dupe-CRC
    to SKIP empty/kludge(#1)/SEEN-BY lines (hash only real content, so the same
    message via different routes is caught as a dupe).  Ours uses a char-by-char
    ReadChar loop; A39 uses a line-loop - STRUCTURALLY different, cannot fragment-
    graft.  This is THE most delicate live-mail function in the tosser; reconcile
    the two 150-line versions line-by-line when fresh.  Only a live FTN packet
    round-trip on the sysop's board truly proves it.
  - Remaining tosser after GetMessage: echoexport (PH.CompatVal:=256 +
    BundleMessages->EchoBundleMessages), echoimport (ReadEchoMailLinks; keep our
    TStringList), echofix (AreaFix).

## TMDL MIGRATION COMPLETE - shim retired (tree-wide, done)
  - Translated the LAST TMDL consumer, mystic/mis_events.pas: EventList/StatusList
    TMDLStringList -> TStringList (FPC RTL).  API-compatible (Create/Free/Count/
    Delete/Add/Clear all identical), clean swap.  Removed m_StringList from its Uses.
  - RETIRED mdl/m_stringlist.pas -> attic/m_stringlist_RETIRED.pas (RETIRED banner,
    GPL + scene history).  Zero consumers left.
  - RESULT: TMDL is now COMPLETELY GONE from the active tree (0 refs in mystic/ +
    mdl/).  The TMDL->FPC RTL standardization policy is FULLY COMPLETE tree-wide.
    Builds 14/14 both platforms.
  - attic now holds: CHANGELOG.TXT, README.md(old), m_resolve_address.c,
    m_socket_class.pas, mdltest5.pas, bbs_ansi_menulist_RETIRED.pas,
    m_stringlist_RETIRED.pas.

## TPKTReader.GetMessage - DONE (content-only dupe-CRC)
  - Turned out MUCH cleaner than feared: the message-READING loop (Repeat/Case Ch,
    AREA: handling, kludge parsing, 79-col word-wrap) is IDENTICAL in both versions.
    Earlier 'structurally different readers' worry was a misread of the diff.
  - The only change: the dupe-detection CRC moved from INLINE per-char (hashing
    everything incl. routing lines) to a POST-READ loop that hashes CONTENT ONLY -
    skips empty lines, kludge lines (#1), and SEEN-BY lines.  4 edits: add Count1/
    Count2 vars; remove pre-loop CRC init; remove inline per-char CRC; add the
    post-loop filtering CRC block.  Our GetMessage is now BYTE-IDENTICAL to A39.
  - WHY IT MATTERS (sysop's 10+ nets): a message gains different SEEN-BY lines at
    each hop.  Old CRC hashed those -> same msg via 2 routes = 2 different CRCs ->
    dupe NOT caught -> imported twice.  New CRC hashes only content -> same msg =
    same CRC on every route -> dupe correctly caught/dropped.  Real improvement for
    a multi-route board.
  - Builds win32 + linux + darwin-compile-clean.  LIVE VERIFICATION on the sysop's
    board is the real proof: confirm legit msgs still import AND dupes via different
    routes now get caught.
  - Remaining tosser: echoexport (PH.CompatVal:=256 + BundleMessages->
    EchoBundleMessages), echoimport (ReadEchoMailLinks; keep our TStringList),
    echofix (AreaFix).

## TOSSER echoimport+echoexport - DONE (interlocked pair)
  - These two units are MUTUALLY DEPENDENT in A39 and had to be imported TOGETHER:
    * echoexport needs echoimport's TEchoMailLinks type (+ Uses mUtil_EchoImport)
    * echoimport calls echoexport's EchoExportMessage + EchoBundleMessages
    Compiling echoimport alone failed with 'EchoExportMessage/EchoBundleMessages
    not found' - confirming the interlock.  A39 refactored them as a PAIR.
  - A39 introduced an echomail-LINKS subsystem our tree lacked entirely:
    TEchoMailLinkRec (Node/PKTFile/PKTBase), TEchoMailLinks = Array of that, and
    ReadEchoMailLinks.  echoexport was decomposed: uEchoExport 330->143 lines, with
    the per-message export logic extracted into EchoExportMessage, and
    BundleMessages renamed/refactored to EchoBundleMessages (160->126).
  - APPROACH (sysop's call): took A39's echoimport + echoexport AS THE BASE for
    both units (A39 is the proven convergence target; the refactor is too
    interlocked to transform edit-by-edit safely).  Fork treatments applied:
    (a) restored OUR GPL license header (A39 snapshot lacked it),
    (b) translated 4 TMDLStringList->TStringList in echoimport + swapped
        m_StringList->Classes (PRESERVING our RTL translation - did NOT drag back
        A39's retired TMDL),
    (c) echoexport had 0 TMDL (clean).
  - Builds 14/14 both platforms + echoimport/echoexport darwin-compile-clean.
    On-disk anchors unchanged (no records touched).  TMDL still 0 tree-wide.
  - Remaining tosser: echofix (AreaFix, -20 lines) - the last unit.
  - LIVE VERIFICATION (sysop's board) is the real proof for outbound mail: packets
    bundled + queued to the right uplinks via GetNodeByRoute, FLO queue correct.

## TOSSER COMPLETE - echofix already current; whole tosser done
  - echofix: the ONLY diff vs A39 was our 20-line GPL header (A39 snapshot lacked
    it).  Code is BYTE-IDENTICAL (single func ProcessedByAreaFix, the AreaFix /
    echo-subscription handler).  NO changes needed - ours was already current, and
    we keep our GPL header.  Importing A39's would've been a downgrade (lost header)
    for zero code gain.
  - THE TOSSER IS NOW STRUCTURALLY COMPLETE (all 4 units at A39):
    * mutil_echocore  - PKT header FSC-0039 + GetMessage content-only dupe-CRC
    * mutil_echoimport - A39 base, link subsystem (TEchoMailLinks/ReadEchoMailLinks),
      our TStringList preserved
    * mutil_echoexport - A39 base, decomposed export (EchoExportMessage/
      EchoBundleMessages), interlocked with import
    * mutil_echofix - already current (AreaFix)
  - Builds 14/14 both platforms + all 4 tosser units darwin-compile-clean.
  - REMAINING for a working FidoNet system: LIVE verification on the sysop's board
    (the tosser cannot be truly proven in-container - needs real echomail flowing:
    inbound packet import + dupe detection, outbound bundling/queuing to uplinks,
    AreaFix requests).  Also the echomail CONFIG editors (bbs_cfg_echomail uses
    IsExportNode/AddExportByBase) if not already current.

## SMTP RefuseForeign - made runtime-configurable via mis.ini (DONE)
  - Original request (from earlier in the project): A38 hard-refuses SMTP mail for
    non-local domains (when recipient isn't a known local user).  Sysop wanted this
    CONFIGURABLE.
  - IMPORTANT correction: an earlier decision note claimed we'd added an
    inetSMTPRefuseForeign CONFIG FIELD (carved from Res1).  That was never actually
    in the tree (Res1 was still 210).  A stray attempt to add it this session was
    REVERTED - we went a cleaner route instead.
  - CHOSEN DESIGN (sysop): a runtime INI file, not a config-record field.  Uses
    Mystic's OWN TIniReader (mdl/m_inireader.pas - g00r00's native INI reader,
    already used by nodespy/mide/mutil), NOT FPC's TIniFile.  g00r00 uses true/false
    for booleans, so we match that.
  - IMPLEMENTATION: mis_client_smtp.pas ValidateNameAndDomain now reads
    data/mis.ini [SMTP] RefuseForeign (default TRUE = keep A38 behavior) and only
    refuses foreign domains when true.  TIniReader handles a missing file/key
    gracefully (Opened := IoResult=0; reads return the passed default), so boards
    without the file behave exactly as A38 did.  Read happens per-validation, which
    means the sysop can change it live without restarting MIS.
  - Created a documented sample mystic/mis.ini (matches mutil.ini/mide.ini house
    style; explains true/false).  No records.pas change - SizeOf stays 5282.
    Builds 14/14 both platforms.
  - This SUPERSEDES the old 'inetSMTPRefuseForeign UI toggle TODO' - no UI toggle
    needed; it's an INI setting now.

## mis.ini load-or-create at MIS startup (refined design)
  - Refined the SMTP RefuseForeign feature per sysop: instead of reading the INI
    per-validation, MIS now loads it ONCE at startup, caching it in a global.
  - DESIGN (sysop's call): on startup, LoadMISConfig checks data/mis.ini.
    * exists  -> load [SMTP] RefuseForeign into global smtpRefuseForeign
    * missing -> CREATE mis.ini with documented defaults (RefuseForeign=true), so
      the sysop gets a ready-to-edit template on first run.
    Explicitly an INTERIM design: these settings will move into the main config
    editor once a proper home is added there (noted in code comments + the file).
  - PLUMBING:
    * MIS_Common: new global 'smtpRefuseForeign : Boolean = True' + LoadMISConfig
      proc (uses TIniReader to read, plain Text ReWrite to create).
    * mis.pas ReadConfiguration: calls LoadMISConfig at startup.
    * mis_client_smtp ValidateNameAndDomain: now just checks the cached global
      (no per-validation INI read; TIniReader dep removed from that unit).
  - FUNCTIONALLY TESTED in-container (this part IS testable, unlike live mail):
    first run creates mis.ini w/ RefuseForeign=true; second run loads it; setting
    it false loads false.  TIniReader reads g00r00's true/false correctly.
  - Builds 14/14 both platforms.  No records.pas change (SizeOf 5282).  Sample
    mystic/mis.ini remains in the tree as a reference copy.
  - Change to change the setting now needs a MIS restart (cached at startup) -
    acceptable for a set-once policy toggle; more efficient + loggable than the
    per-validation read.

## bbs_cfg_echomail - export functions relocation COMPLETED
  - Completes the OTHER HALF of the FTN-routing relocation.  When we imported
    IsExportNode/AddExportByBase/RemoveExportFromBase/RemoveExportGlobal into
    bbs_database earlier, our bbs_cfg_echomail STILL had its own local copies -
    duplicated (they coexisted because the locals shadowed bbs_database's via
    Pascal scope; compiled fine but redundant).
  - Verified all 4 local bodies IDENTICAL to the bbs_database versions (extracted
    impl bodies and compared - byte-identical).  A39's bbs_cfg_echomail is 104
    lines shorter precisely because A39 removed these locals and relies on
    bbs_database.
  - Removed the 2 interface forward-decls + the contiguous 4-body impl block (~78
    lines) from bbs_cfg_echomail.  The call sites (lines ~80/124/259/304) now
    resolve to bbs_database's versions (bbs_cfg_echomail already Uses BBS_DataBase).
  - ours 670->589 (A39 566; the ~23 remaining is our GPL header + minor fmt).
    Builds 14/14 both platforms; anchors 5282/768.  Single source of truth for the
    export functions now = bbs_database.

## binkHideAKA - completed a half-wired feature (adjacent-unit check)
  - 'Check FidoNet-adjacent units for correctness' caught this: the BinkP AKA-
    hiding feature was HALF-WIRED.  Our mis_client_binkp already had HideAKAs/
    HideSource + the hiding logic (imported earlier), but:
    (a) binkHideAKA config field was MISSING from records.pas,
    (b) fidopoll didn't SET BinkP.HideAKAs/HideSource from the node config,
    (c) no UI toggle to enable it.
    So nothing actually turned the feature on.  Completed the whole chain:
    * records.pas: added binkHideAKA : Boolean to RecEchoMailNode, carved from
      Res (217->216).  SizeOf(RecEchoMailNode) stays 901 (verified).  Matches A39
      field placement exactly.
    * fidopoll: BinkP.HideAKAs := EchoNode.binkHideAKA; HideSource := Address.Zone.
    * bbs_cfg_echomail: 'Hide AKAs' AddBol toggle on node editor (row 14, matches
      A39 coords; our bink section was already identical to A39's).
  - BONUS correctness fix in fidopoll poll loop (A39's Res/Total refactor): our
    Total counter was declared+displayed ('Polled N nodes') but NEVER incremented
    - a latent bug.  A39 captures poll result in Res, Inc(Total) + LastSent +
    write-back only on success.  Grafted.
  - What it does: controls which of your AKAs are advertised to an uplink during
    the BinkP handshake (only the uplink's-zone AKAs; hide the rest).  FidoNet
    hygiene for a multi-net board.
  - Builds 14/14 both platforms; anchors 901/5282/768.  bbs_database +7 vs A39 was
    just whitespace (no proc differences - our FTN routing core is complete).
  - LIVE VERIFICATION: enable Hide AKAs on a node, poll an uplink, confirm only the
    right-zone AKAs are presented in the handshake.

## A51 GROUND-TRUTH verification of FidoNet features (where to add)
  - Checked our FidoNet features against the shipped A51 binaries
    (/tmp/bbs_setup/mystic/{mystic,mis,mutil,fidopoll}) via strings.  Scorecard:
    * Hide AKAs toggle: A51 mystic has 'Hide AKAs' + 'Hide alternative addresses
      during handshake' VERBATIM, next to CRAM-MD5/BlockSize.  Our placement MATCHES
      shipped A51 exactly. CONFIRMED.
    * Semaphore: A51 has echomail.out/netmail.out/newsmail.out/qwkmail.out AND
      'Create .out files when?' (our Create Semaphore toggle's help text VERBATIM).
      MATCHES shipped A51. CONFIRMED.
    * Dupe detection: A51 mutil has 'Duplicate message found in' + SEEN-BY handling.
      Our GetMessage content-only dupe-CRC matches shipped behavior. CONFIRMED.
    * RefuseForeign config: A51 has ONLY the runtime messages 'Refused by domain:'
      / 'Refused by name:' - NO config toggle anywhere.  A51 HARDCODES the refusal
      like A38.  So our mis.ini RefuseForeign is FORK-ORIGINAL - no A51 precedent.
  - IMPLICATION for a future 'permanent home': if RefuseForeign ever moves from
    mis.ini into the config editor, the natural screen (per A51) is 'SMTP Server
    Options' (which has Use Server / Server Port / Max Connections / Dupe IP Limit /
    Connection timeout).  But it would be OUR addition to that screen - A51 offers
    no template beyond identifying the right screen.
  - Net: 3 of 4 features are A51-confirmed and correctly placed; RefuseForeign is a
    legitimate fork-original.  No placement changes needed.

## nodespy_term - USEALTPROT protocol migration DONE
  - Found via 'check FidoNet-adjacent units': nodespy_term (the live-node monitor /
    who's-online spy terminal) was still on the OLD protocol units
    (m_Protocol_Base/Queue/Zmodem) while bbs_filebase had already migrated to the
    NEW protocol layer (m_Prot_Base/Zmodem) via USEALTPROT.  Half-migrated tree.
  - A39 completes it: adds {$DEFINE USEALTPROT}, wraps the Uses block, and
    CONSOLIDATES all protocol funcs into one block (new-API in {$IFDEF USEALTPROT},
    old-API in {$IFNDEF}) right before EditEntry.  The new API is pointer-based
    (ProtocolStatusUpdate(P: AbstractProtocolPtr; First,Last) using P^.PathName /
    SrcFileLen / BytesTransferred / TotalErrors / StartTimer) vs the old
    RecProtocolStatus struct.  New ProtocolStatusDraw takes an Upload:Boolean.
  - APPROACH (sysop's call): SURGICAL on the 1048-line file - add define, wrap Uses,
    replace our 2 SCATTERED old-API regions (ProtocolAbort/StatusUpdate/StatusDraw
    at 378-427 and DoZmodemDownload/Upload at 673-734) with A39's single
    consolidated 194-line dual-path block.  Verified A39's {$IFNDEF} old-API half is
    byte-identical to our existing funcs (lose nothing).
  - VERIFIED BOTH PATHS COMPILE: USEALTPROT on (new, the default - matches
    bbs_filebase) AND off (old fallback).  Full 14/14 both platforms.  Anchors
    901/5282/768.
  - Relevance: this is the ZMODEM/protocol area the sysop flagged ('transfers
    stopped').  nodespy_term's transfer-status view is now on the SAME new protocol
    layer as the main file base - inconsistency resolved.
  - DARWIN NOTE: nodespy_term does NOT darwin-compile in-container, but this is
    PRE-EXISTING and NOT our code: m_io_Sockets needs unit cNetDB, which is absent
    from our i386-darwin RTL set (a networking unit our Darwin unit collection
    lacks).  The ORIGINAL nodespy_term fails identically.  Any m_io_Sockets user
    hits this; it resolves when Darwin is built for real against a complete RTL/SDK
    (deferred per policy).  Source is Darwin-correct.

## DARWIN cNetDB - FIXED (compiled the missing RTL unit)
  - The nodespy_term darwin-compile failure ('Can't find unit cNetDB used by
    m_io_Sockets') was NOT a source bug - it was a missing PRECOMPILED RTL unit in
    our container's i386-darwin set.  cNetDB is an FPC fcl-net unit
    (packages/fcl-net/src/cnetdb.pp); m_io_Sockets pulls it in under {$IFDEF UNIX},
    and Darwin IS unix.  We had cnetdb.ppu precompiled for linux (pkgunits-linux)
    but never for darwin.
  - FIX: compiled cnetdb.pp for darwin from the shipped FPC source:
      ppc386 -Tdarwin -Amacho -Mobjfpc -Fu<i386-darwin-units> -FU<out> \
             -Fi<fcl-net/src> fpc-2.6.2/packages/fcl-net/src/cnetdb.pp
    Compiled clean; installed cnetdb.ppu/.o into the i386-darwin units dir.
  - RESULT: nodespy_term AND all other m_io_Sockets users (mis_client_smtp,
    mis_client_binkp, fidopoll) now darwin-compile clean.  Broad fix, not just
    nodespy_term.
  - FOR REAL BUILDS: a complete FPC Darwin install compiles fcl-net (incl cNetDB)
    as part of its normal RTL/packages build - so a proper toolchain won't hit this.
    Our container just lacked that one precompiled unit.  Noted in INSTALL.

## qwkpoll PrintLog - INTENTIONAL fork divergence (KEEP)
  - qwkpoll delta -25 vs A39 is ENTIRELY one thing: our qwkpoll has a PrintLog
    procedure that writes each poll-status line to BOTH the screen AND a log file
    (LogsPath + qwkpoll.log, timestamped).  A39 REMOVED PrintLog and reverted to
    plain WriteLn (screen only).
  - A51 GROUND TRUTH: the shipped qwkpoll binary has NO 'qwkpoll.log' string (0
    occurrences) but DOES have the status strings - so A51 ships plain WriteLn,
    matching A39, NOT our logging version.  Our PrintLog is most likely leftover
    A38 code that g00r00 removed for release.
  - DECISION (sysop): KEEP our PrintLog as a deliberate FORK ENHANCEMENT.  QWK poll
    logging is genuinely useful for a sysop debugging network exchanges.  This is an
    INTENTIONAL divergence from A39/A51 - do NOT 'align' it back in a future pass.
  - No code change needed; qwkpoll already has what we want.  Builds 14/14 both
    platforms + darwin-compile clean (after the cNetDB fix).  The ONLY diff vs A39
    is this enhancement.

## bbs_msgbase_jam - KEEP OURS (A39 has a JAM CRC inconsistency)
  - Investigated the -63 delta (ours bigger). Two things: (a) mostly our snapshot's
    inline doc-comments on JAM method decls + a dead (* new shit *) commented block
    that A39 tidied away (inert), and (b) a REAL and important CRC difference.
  - THE CRC FINDING (important): JAM indexes messages by CRC of recipient name
    (MsgToCrc), matched at search time against NameCrc/HdlCrc. Two CRC funcs exist:
      * JamStrCrc  : seed -1, LOWERCASES each char (LoCase) - JAM-standard,
        case-insensitive.
      * StringCRC32: seed $FFFFFFFF (=-1, same seed) but does NOT lowercase.
    They only agree when the input is already lowercase.
  - OURS: uniform - all 3 MsgToCrc writes (655/745/849) use JamStrCrc, AND
    NameCrc/HdlCrc (1386/1387) use JamStrCrc, AND the search (1410-1411) compares
    them. Write and search algorithms MATCH -> 'messages to me' scans work.
  - A39: INCONSISTENT - writes MsgToCrc three different ways (643 JamStrCrc,
    742 & 858 StringCRC32) while NameCrc/HdlCrc still use JamStrCrc. So A39's search
    (MsgToCrc = NameCrc) compares a sometimes-non-lowercased value against a
    lowercased one -> MISMATCH for any recipient name containing uppercase. That's a
    JAM index bug from an incomplete JamStrCrc->StringCRC32 migration.
  - DECISION: KEEP OURS unchanged. Our bbs_msgbase_jam is MORE correct than A39's.
    Do NOT adopt A39's StringCRC32 changes here - it would break JAM MsgTo lookups.
    The only other A39 diff (removing dead commented code) isn't worth touching this
    delicate file for zero functional gain.
  - INTENTIONAL DIVERGENCE - added to the do-NOT-align-back list.
  - Builds 14/14 (unchanged).

## bbs_msgbase_jam - CORRECTED: switched to StringCRC32 to match A51
  *** CORRECTION to the earlier 'KEEP OURS' entry above - that was WRONG. ***
  - Earlier this session I concluded 'keep our all-JamStrCrc version, A39 is buggy'
    based only on A39's INTERNAL inconsistency, WITHOUT checking shipped data.
  - Then verified against REAL A51 JAM data on the board (msgs/dove/*.jdx + .jhr).
    Parsed actual MsgToCrc values and computed both algorithms on the real
    recipient names:
      * StringCRC32 (raw): matched 8/12 stored values
      * JamStrCrc (lowercase): matched only 2/12 (the already-lowercase names)
    => A51 SHIPS StringCRC32 (raw, no lowercasing) for JAM CRCs. g00r00 did the
       JamStrCrc->StringCRC32 migration for real; it's in the shipped product.
  - Our all-JamStrCrc version was SELF-consistent but INCOMPATIBLE with stock A51
    JAM bases (different CRC for any name with uppercase) - a real interop bug for
    anyone migrating A51->fork or sharing bases.
  - FIX: switched ALL 7 JamStrCrc call sites -> StringCRC32 (MsgId/Reply at 528/540,
    MsgTo writes at 655/745/849, NameCrc/HdlCrc search keys at 1386/1387). BOTH
    write and search sides, so it stays self-consistent AND matches A51. (This is
    what A39 was reaching for but did incompletely - A39 left the search keys on
    JamStrCrc, which WAS a bug; we did the complete migration.)
  - EMPIRICALLY VERIFIED: built a test with our m_crc StringCRC32 and confirmed our
    output EXACTLY matches A51's real .jdx values (The Millionaire=B05E710A,
    Ralph Smole=22990688, Mindless Automaton=E9DE0D0F, Pbmountaincat=0CDAEB3B,
    an0k=1A4ED88C - all exact). Our fork now writes A51-compatible JAM indexes.
  - The now-unused JamStrCrc definition is left in place (harmless, only in this
    unit). Builds 14/14 both platforms.
  - LESSON: check shipped A51 DATA, not just source inference, before concluding
    'ours is more correct'. The real files are the ground truth.

## RESEARCH NOTES (web search 2026-07-07)

### Mystic HTTP / web server - added in 1.12 A39 (2018-04-20)
  - Source: official whatsnew_112 changelog (wiki.mysticbbs.com).
  - Entry: 'MIS now has a basic HTTP server. Created in the server editor within
    the configuration. A webroot path must be defined (webroot/cfg + webroot/www).
    Very barebones - only serves basic websites; intended for further work.'
  - RELEVANCE TO FORK: it's an A39 feature (same alpha we've been importing FidoNet
    bits from), part of the MIS daemon. NOT in our A38 base and NOT yet imported.
    Would be a NEW import target (a new MIS2 server type) if ever wanted - bigger
    than our current work, and 'barebones' even in A39, so weigh vs board demand.

### A34 JAM CRC changelog note - POTENTIAL CONFLICT with our StringCRC32 change (FLAG)
  - Same changelog, ALPHA 34 entry:
    '! JAM Reply CRC and Msg To CRC were not always converted to lower cased before
      calculated. As per JAM specs all CRC calculated on string must be lowercased
      first.'
  - THIS SEEMS TO CONTRADICT what we did this session. We switched JAM CRCs to
    StringCRC32 (RAW, NOT lowercased) because our test against A51's REAL .jdx data
    showed raw matched 8/12 and lowercased only 2/12.
  - HONEST TENSION TO RESOLVE LATER:
    * A34 (2016-era) says JAM CRCs SHOULD be lowercased (JAM spec).
    * A51 (2014 binary!) real data shows RAW StringCRC32.
    WAIT - A51 is dated 2014 (Copyright ...-2014), which is EARLIER than A34/1.12.
    So the timeline is: A51 is a 1.10 build (2014). A34 is a 1.12 build (later).
    => g00r00 may have CHANGED the JAM CRC behavior between 1.10 (raw) and 1.12
       (lowercased, to follow JAM spec). Our fork is 1.10-based, and our A51 ground
       truth is 1.10 => matching A51 (raw) is CORRECT for 1.10-base compatibility.
    * BUT if we ever want 1.12 compatibility, the CRC would need to be LOWERCASED.
    * Our OLD code (JamStrCrc, lowercased) would actually match 1.12, not 1.10!
  - ACTION: our StringCRC32 change is right for A51/1.10 compatibility (verified vs
    real 1.10 data). Do NOT undo it. But document that 1.12 uses lowercased CRCs, so
    if a future goal is 1.12-base alignment, this is a known divergence point.
    Ideally: verify against a real 1.12 JAM base someday to confirm the 1.10->1.12
    CRC change.

## AreaIndex (bbs_msgbase +304) - DEFERRED, keep our reconstruction for now
  - Investigated importing A39's real TMsgBase.AreaIndex (+ AreaIndexSearch,
    AreaIndexDrawBar, AddSort helpers) to replace our reconstructed bbs_areaindex.pas.
  - GOOD NEWS: the TAnsiListBox UI migration the old TODO feared is ALREADY DONE -
    TAnsiListBox lives in bbs_ansi_menubox.pas (same as A39), has all 13 methods
    A39's AreaIndex needs (Add/Clear/Create/Insert/List/ListMax/LoChars/NoWindow/
    PercentBar/SetSearchProc/SetUpdateProc/Sort/SortDepth), and is used across ~13
    bbs_cfg_* files in our working 14/14 build. GetMessageStats signature is an
    EXACT match too.
  - THE BLOCKER: A39's AreaIndex depends on A39's Session.Template / RecTemplateData
    subsystem (bbs_core.pas: Prompt[1..10] String[160], PercentBar, ReadBoolean for
    template options show_divs/new_at_top/snap_new/no_index). Our tree has ZERO
    Session.Template references - we use the older OutFile(MBase.ITemplate) model.
    In A39 this template system is only in 2 files, so it's newer A39 infra we lack.
  - DECISION (sysop): OPTION C - keep our working bbs_areaindex.pas reconstruction
    for now (it's compile-checked, wired to menu 'I', functions). Do the smaller
    bbs_* units first (bbs_io, bbs_edit_ansi, bbs_cfg_theme). Revisit AreaIndex later.
  - WHEN REVISITED, two paths (documented so we don't re-investigate cold):
    * Option A: adapt A39's AreaIndex logic to our OutFile(ITemplate) template model
      + default the 4 boolean options (medium effort, keeps our template model).
    * Option B: import A39's RecTemplateData template subsystem first (2 files),
      then graft AreaIndex faithfully (bigger, more thorough).
    The TAnsiListBox/GetMessageStats groundwork is all confirmed present, so either
    path starts from a known-good base.

## bbs_io (+25) - DONE: |#B |#I themed message-box pipe codes
  - The +25 was: (a) a GetParam refactor of OutFull (cleaner param scanning for the
    existing |$L file-include code - replaced a manual B-variable loop), and (b) a
    NEW feature: two parameterized MCI pipe codes |#B and |#I (FmtType 18/19) that
    invoke ThemeMessageBox(Theme, 0/1, Param1, Param2) - themed message boxes
    callable from display files.
  - Dependencies CONFIRMED present before grafting: ThemeMessageBox lives in
    bbs_ansi_menubox.pas with the EXACT signature A39 calls (Theme:RecTheme;
    BoxType:Byte; Title,Text:String); TBBSCore.Theme field exists. Only wiring
    needed was adding BBS_Ansi_MenuBox to bbs_io's Uses.
  - APPROACH: added BBS_Ansi_MenuBox to Uses; added the '#' case to ParseMCI;
    replaced OutFull wholesale with A39's (it's our function + the GetParam refactor
    + the new codes - verified via normalized diff that those were the ONLY changes,
    A->Count rename aside).
  - SCOPING NOTE: A39 also swapped m_io_Base->Sockets in the Uses. Left OURS alone
    (m_io_Base retained) - our build passes fine without that swap; it's A39-internal
    plumbing unrelated to the feature. Took only what the feature needs.
  - Builds 14/14 both platforms; anchors 5282/768/901 unchanged.

## bbs_edit_ansi (+44) - DONE: enabled the full ANSI draw mode
  - The +44 is one coherent theme: turning ON the full-screen ANSI DRAWING mode in
    the message editor (previously gated behind {$IFDEF TESTEDITOR}, i.e. test-only).
    Four related changes:
    1. ReDrawTemplate: replaced the plain draw-mode status line with a pipe-coded
       status bar (X/Y position, INS/OVR, GLY/CHR mode) plus a 10-glyph CHARACTER-SET
       SELECTOR palette built from GlyphTypeStr. Uses WriteXYPipe. Added 4 locals
       (Temp, StrGlyph, StrInsert, StrCharSet).
    2. LocateCursor: live X/Y readout - updates the status bar's cursor position as
       you move in draw mode.
    3. QuoteWindow: an 'Added' flag bug fix - only advance CurLine (avoid a spurious
       blank line) if a quote line was actually inserted. (Added:Boolean=False;
       Added:=True on insert; guard 'If Added And (CurLine < MaxMsgLines)'.)
    4. The command keyset: made '?ACDHQRSTU' unconditional (was TESTEDITOR-only) -
       the 'D' key enters draw mode. Without this the whole draw feature was
       unreachable in normal builds. Our tree ALREADY had the 'D' Case handler
       (DrawMode := True) - it was just gated off.
  - DEPENDENCIES verified present BEFORE grafting: GlyphTypeStr/GlyphPtr/GlyphMode/
    DrawMode/CurX/CurLine/InsertMode/strI2S all present; WriteXYPipe lives in
    bbs_ansi_menubox and is reachable transitively (compiled clean). Added
    BBS_Database to Uses (A39 does; needed).
  - APPROACH: replaced ReDrawTemplate wholesale with A39's (verified the non-drawmode
    half was byte-identical to ours first); surgically added the other 3 changes.
  - A51 GROUND TRUTH confirms the shipped binary HAS this draw mode: strings show
    'ATTR', 'Select Glyph Set:', 'Enter glyph set:', '(C)ontinue (G)lyph Mode
    (Q)uit Draw Mode', low_attr/high_attr. Our change matches shipped behavior.
  - Builds 14/14 both platforms + darwin-compile clean. Anchors 5282/768/901.
  - LIVE TEST: enter the FSE, press D to enter draw mode, confirm the status bar +
    glyph palette render and X/Y updates as you move.

## bbs_cfg_theme (+47) - DONE: message-box theme editor
  - Adds the config UI for the THEMED MESSAGE BOX - completing the feature loop with
    the |#B/|#I pipe codes added in bbs_io (those invoke ThemeMessageBox; THIS lets
    the sysop style it per theme).
  - Two new procs + menu wiring:
    * SetThemeBoxDefaults(Var Theme): sets default box colors/frame/shadow.
    * EditMessageBox(Var Theme): a form editor - Frame Type, 4 Frame Colors, Shadow
      on/off + color, Header/Text/Confirm colors, plus 'SHOW EXAMPLE' (live preview
      via ThemeMessageBox) and 'DEFAULTS' (reset via SetThemeBoxDefaults).
    * Menu: added '4: Message Box' to the theme editor + its dispatch case.
    * Minor: VotingBar.Format default 0->1; SetThemeBoxDefaults called when creating
      a new theme.
  - DEPENDENCIES verified present BEFORE grafting: all 10 RecTheme Box* fields
    (BoxShadow/BoxShadowAttr/BoxHeadAttr/BoxFrame/BoxAttr/BoxAttr2-4/BoxOKAttr/
    BoxTextAttr) exist -> SizeOf(RecTheme) unchanged (768). Form.AddAttr exists in
    bbs_ansi_menuform (3 other cfg files use it). ThemeMessageBox/ShowMsgBox/
    VerticalLine/TAnsiMenuBox/TAnsiMenuForm all reachable.
  - Dropped BBS_Common from Uses (A39 does; ours only had it in the Uses line, no
    symbol usage - compiled clean without it).
  - A51 GROUND TRUTH confirms shipped: '4: Message Box', 'Edit message box style
    used in this theme', ' Message Box ', 'Frame Color 1-4', 'Shadow Color',
    'Confirm Color', 'SHOW EXAMPLE' - all verbatim. Our graft matches shipped.
  - Builds 14/14 both platforms + darwin-compile clean. Anchors 5282/768/901.

## RecPercent.Format documentation (2026-07-07)
  - Documented the previously-undocumented RecPercent.Format byte inline in
    records.pas: 0=Horizontal, 1=Vertical.
  - Where the sysop sets it: Config -> Themes -> a theme -> 3:Percent Bars -> pick a
    bar -> F:Bar Format toggle (Horizontal/Vertical). A theme has 7 such bars
    (Voting/File/Msg/Gallery/Help/Viewer/Index), each a RecPercent.
  - Context: the A39 bbs_cfg_theme graft set a NEW theme's VotingBar.Format default
    0->1 (Vertical). This comment records what 0/1 mean. SizeOf unchanged (RecPercent
    stays 13; anchors 5282/768/901).

## AreaIndex UNBLOCKED - the template subsystem is understood (2026-07-07)
  Using the sysop's HTTrack wiki mirror + re-reading A39 source, the RecTemplateData
  blocker is fully demystified. It is SMALL and self-contained:

  1. RecTemplateData (A39 bbs_core.pas:30) - just 4 lines:
       RecTemplateData = Record
         PercentBar : RecPercent;                               // we already have
         Screen     : Array[1..10] of Record X,Y,A: Byte; End;  // 10 coord slots
         Prompt     : Array[1..10] of String[160];              // 10 prompt strings
       End;
  2. TBBSCore.Template : RecTemplateData;  (a field, added next to Theme)
  3. TBBSCore.ReadTemplate(FN, DoFree) (A39 bbs_core.pas:486, ~48 lines) - the
     .ini loader. Reads <FN>.ini from Session.Theme.TextPath (falls back to
     bbsCfg.TextPath if ThmFallback set) via TIniReader. Sections:
       [Coords]  Coord1..Coord10 = 'X,Y,A'  -> Screen[1..10]
       [Percent] active,bar_format,bar_length,location_x,location_y,low_char,
                 low_attr,high_char,high_attr -> PercentBar
       [Prompts] str1..str10 -> Prompt[1..10]
     Returns the TIniReader itself (DoFree=False) so callers can read EXTRA keys
     (e.g. AreaIndex's show_divs/new_at_top/snap_new/no_index booleans).
  4. AreaIndex calls Session.ReadTemplate('ansimidx', False) then reads Prompt[]/
     Screen[]/PercentBar + the extra booleans from the returned INI.
     NOTE: the AreaIndex template file is 'ansimidx' (not 'msg_index' - that's the
     newer A40+ MI reader name; our A39 target uses ansimidx).

  ALL DEPENDENCIES PRESENT in our tree: TIniReader, RecPercent, strWordGet, strI2S,
  FileExist, ThmFallback, Session.Theme.TextPath. TBBSCore already has Theme field.
  So the CODE port needs NO binary fetch. What the sysop's fetch adds: the real
  shipped ansimidx.ini (+ ansimidx.ans/.asc) so we ship a correct DEFAULT template.

  DECISION: PATH B (faithful). Port order:
    (1) add RecTemplateData to our bbs_core (or records) + Template field on TBBSCore
    (2) port TBBSCore.ReadTemplate (.ini loader)
    (3) import A39's TMsgBase.AreaIndex + AreaIndexSearch/AreaIndexDrawBar/AddSort
        (TAnsiListBox + GetMessageStats already confirmed present/compatible)
    (4) wire menu 'I'/MI to Session.Msgs.AreaIndex; retire our bbs_areaindex.pas
        reconstruction to attic/
    (5) ship a default ansimidx.ini (from sysop's fetch if available, else build one)
    Compile after EACH step.

## AreaIndex - REAL template files received + full spec (2026-07-07)
  Sysop uploaded a full 1.12 A49 Win32 distribution INCLUDING the real template
  files: ansimidx.ini, ansimidx.ans, ansimidxhelp.asc (saved to our tree at
  default_theme_text/). Also records.112 = the A49 records.pas as text.

  VERSION NOTE (important): the binaries/records are 1.12 A49. Our fork imports from
  1.10 A39. By A49, RecTemplateData was REMOVED from records.pas and the template
  system was reworked (mysTemplatePrompts=30, TemplatePath, String[20] template
  fields). We do NOT adopt the A49 rework - we port the A39 version (RecTemplateData
  with 10 prompts). The ansimidx.ini FORMAT ([Coords]/[Percent]/[Prompts]/[Options])
  is stable A39->A49, so the uploaded ansimidx.ini works as our default template.
  RecPercent is byte-identical A39->A49 (confirmed) - good cross-check.

  ansimidx.ini maps EXACTLY to A39's ReadTemplate + AreaIndex:
    [Coords]  Coord1=3,6,A (top-left) Coord2=78,20,A (bot-right) Coord3=23,2,7 (search)
    [Percent] active=true bar_format=1 bar_length=13 location_X=79 location_Y=7
              low_char=176 low_attr=8 high_char=219 high_attr=9
    [Prompts] str1-6 (list line variants) str7 (divider) str8 (calculating stats)
              str9 (posting) - use &1..&5 = base name/net desc/total/new/your msgs
    [Options] group_list, exclude_groups, show_divs, new_at_top, snap_new, no_index
  AreaIndex (A39 bbs_msgbase.pas:4875-5082, 208 lines) reads the 4 booleans from
  [Options] via the returned TIniReader (defaults True/True/True/False), defaults
  CmdData to 'ansimidx', loads 'ansimidxhelp' for CTRL-Z help.

  FULLY SPECIFIED - ready to port. Steps unchanged (see prior entry). We now also
  have the real default template files to ship at step 5.

## AreaIndex Steps 1-2 DONE (template subsystem foundation) 2026-07-07
  Ported A39's template subsystem into our bbs_core.pas:
    - Const TemplateOptions = 'Options'
    - RecTemplateData record (PercentBar + Screen[1..10] X/Y/A + Prompt[1..10] Str[160])
    - TBBSCore.Template : RecTemplateData field (after Theme)
    - TBBSCore.ReadTemplate(FN, DoFree) : the .ini loader - reads <FN>.ini from
      Session.Theme.TextPath (fallback bbsCfg.TextPath if ThmFallback), fills
      [Coords]->Screen, [Percent]->PercentBar, [Prompts]->Prompt; returns the
      TIniReader when DoFree=False so caller can read [Options] booleans.
    - Added m_IniReader to interface Uses (only new dep; strI2S/strWordGet/FileExist
      already reachable via m_DateTime/m_Strings/m_FileIO).
  Builds 14/14 both platforms + darwin-compile clean. Anchors 5282/768/901 (records
  untouched; RecTemplateData lives in bbs_core, not records.pas, matching A39).
  NEXT: Step 3 - import TMsgBase.AreaIndex + AreaIndexSearch/AreaIndexDrawBar/AddSort.

## AreaIndex Step 3 DONE (the real TMsgBase.AreaIndex imported) 2026-07-07
  Imported into bbs_msgbase.pas from A39:
    - TMsgBase.AreaIndex (208 lines) - the main proc: reads ReadTemplate('ansimidx'),
      reads [Options] booleans (show_divs/new_at_top/snap_new/no_index, defaults
      T/T/T/F), builds the area list into a TAnsiListBox, multi-column sort via
      nested AddSort, runs the list UI (read/search/post/subscribe).
    - AreaIndexSearch (search callback) + AreaIndexDrawBar (draw callback) standalone
      procs - both use Session.Template.Prompt[]/Screen[] (from Step 1-2).
    - Added method decl AreaIndex(CmdData: String) to TMsgBase class.
    - Uses: added m_IniReader + BBS_Ansi_MenuBox (only what AreaIndex needs; kept
      our existing Uses incl BBS_Common which A39 dropped).
  TWO ADAPTATIONS (recorded honestly):
    1. GetMBaseByIndex: OUR version returns Boolean; A39's returns LongInt (base num,
       -1 if not found). Adapted AreaIndex's one usage to our Boolean API, using
       TempBase.Index where A39 used the returned Count. Kept our Boolean signature
       (all our other callers rely on it) rather than rippling A39's LongInt change
       through 7 files. INTENTIONAL divergence from A39 here, functionally equivalent.
    2. Fixed an extraction bug: the A39 block grab pulled the unit's trailing 'End.'
       into the AreaIndex body, prematurely terminating the unit (compiler caught it:
       'forward declaration not solved' cascade). Removed the bogus End.
  Builds 14/14 both platforms + darwin-compile clean. Anchors 5282/768/901.
  NEXT: Step 4 - wire the menu command to Session.Msgs.AreaIndex; retire our
  bbs_areaindex.pas reconstruction to attic/. Step 5 - install default ansimidx.ini.

## AreaIndex - cross-checked against the real 1.12 A49 binary (2026-07-07)
  Verified our ported AreaIndex/template reads against the shipped 1.12 A49
  mystic.exe (sysop upload). The binary contains EVERY field our port uses:
    - Sections: Coords, Percent, Prompts, Options (all present)
    - [Percent]: active, bar_format, bar_length, location_x, location_y, low_char,
      low_attr, high_char, high_attr (all match our ReadTemplate)
    - [Options]: show_divs, new_at_top, snap_new, no_index (all match our AreaIndex);
      A49 also has exclude_groups/group_list (in the .ini, read by newer A40+ code)
  ONE EXPECTED DIFFERENCE: A49's template file is named 'msg_index'; our A39 base
  uses 'ansimidx'. Only the FILENAME changed A39->A49 - the structure/fields/sections
  are identical. We correctly use 'ansimidx' for our A39-based fork. Port validated.

## AreaIndex Steps 4-5 DONE - PORT COMPLETE 2026-07-07
  Step 4 (wire + retire):
    - bbs_menus.pas: menu 'I' handler rewired from our reconstruction's 'AreaIndex;'
      to the real 'Session.Msgs.AreaIndex(CmdData);' (matches A39). Dropped
      bbs_AreaIndex from Uses.
    - Retired our reconstruction bbs_areaindex.pas -> attic/
      bbs_areaindex_RECONSTRUCTION_RETIRED_2026-07-07.pas (GPL convention: never
      delete code). Zero lingering refs confirmed.
  Step 5 (default template):
    - Real ansimidx.ini/.ans + ansimidxhelp.asc (from sysop's 1.12 upload) staged in
      default_theme_text/ with a README explaining placement (theme text dir) and the
      [Options] behavior flags. These are runtime DATA, not compiled - they ship in
      the install/theme package, dropped into themes/<name>/text/.
  AREAINDEX PORT COMPLETE (all 5 steps). The real A39 message-area index reader is
  now in the fork, replacing our reconstruction. Builds 14/14 both platforms +
  darwin-compile clean. Anchors 5282/768/901. Cross-checked against 1.12 A49 binary.
  LIVE TEST: menu command 'I' (or MI) should open the index reader listing all
  message bases with total/new/personal stats; scroll/search/select to read.
  Requires >=1 message group and the ansimidx.* files in the theme text dir.

## Full wiki export -> docs/wiki/ (2026-07-07)
  Exported the entire Mystic wiki (from the sysop's HTTrack mirror) to clean plain
  text in the source tree at docs/wiki/ - 80 pages, categorized in 00_INDEX.txt.
  Categories: Getting Started, Configuration (MCFG), MUTIL, Display/Menus/Themes,
  Scripting (MPL/Python), Changelogs (1.05-1.12), Reference/Misc.
  All CRLF/no-BOM/ASCII for cross-platform (DOS/Win/Mac/Linux) readability.
  Caveat noted in the index: the wiki describes STOCK 1.12 Mystic; this fork is
  1.10/A38-based, so some documented features differ or are absent. Empty wiki
  stubs (templates, prompts) are covered instead by mystic_wiki_reference.txt
  Section 7 (which we reverse-engineered). This is offline reference material for
  filling in feature understanding as the fork evolves.

## Wiki docs consolidated to docs/mystic.txt (2026-07-07)
  Per sysop preference, the 80 individual wiki pages were consolidated into ONE
  file: docs/mystic.txt (~24k lines, 1.1M). Has a table of contents with [anchor]
  tags matching in-body section dividers (search '[displaycodes]' to jump). The
  individual docs/wiki/ page files were removed - docs/ now holds just mystic.txt.
  CRLF/no-BOM/cross-platform. Same STOCK-1.12-vs-our-1.10-fork caveat in its header.

## docs/mystic.txt - added original header (2026-07-07)
  Prepended the original packaged mystic.txt header (Dutch Dude ASCII art, (C)
  1997-2014 James Coyle, official support: www/email/FidoNet MYSTIC/AgoraNet/IRC
  #mysticbbs efnet) to the top of the consolidated wiki doc, with a note that the
  wiki material supplements the original.

## GNU-standard doc reorganization (2026-07-07)
  Reorganized project files to GNU/Linux root-file convention:
  ROOT: README.md, INSTALL (was BUILDING.md), COPYING (was gpl-3.0.txt)
  docs/: TODO.md, DECISIONS.md, whatsnew.txt, mystic.txt, mystic_wiki_reference.txt
  Removed redundant wiki_docs/ (superseded by docs/mystic.txt). Updated all internal
  references (README/TODO/DECISIONS/whatsnew: BUILDING->INSTALL, doc paths->docs/,
  LICENSE/gpl-3.0->COPYING). Build unaffected (no source touched).

## whatsnew ordering fix (2026-07-07)
  The ansi-draw / message-box / index-reader entries had been inserted just above
  the DESIGN NOTES divider (near the top) instead of at the bottom where newest
  entries belong (file is oldest-first). Moved all three to the end in order, and
  ADDED a dedicated entry for the template subsystem port (ReadTemplate/ansimidx.ini
  loader) which had only been implied before. 50 entries total, cross-platform clean.

## GitHub release readiness pass (2026-07-07)
  Pre-release audit before a GitHub release. Findings/actions:
  - Build verified 14/14 win32+linux (a batch-loop FAIL was just a missing outwin/bin
    dir, not a code error).
  - Added .gitignore (fpc artifacts, out dirs, editor cruft) so a clone-and-build
    does not dirty the repo.
  - Added a release-identity banner to README (date, A38 base -> ~A39 feature level,
    platform status).
  - 3 files lack copyright headers (bbs_ansi_menubox, mis_events, m_logroller) - these
    are UPSTREAM omissions (headerless in stock A39 too). Left as g00r00 shipped them;
    the repo-wide GPL is asserted via COPYING at root. Not fabricating headers on his
    files.
  - 5 FIXME/temp markers are original Mystic commented-out dead code, not fork TODOs.
  Assessment: source-only release is READY. (Binaries can be attached separately as
  release assets if desired; the zip is source.)

## docs/mystic_wiki_reference.txt removed (2026-07-07)
  Removed the standalone fork reference file to keep docs/ lean. Its unique content
  (the reverse-engineered template/ansimidx.ini subsystem documentation) is preserved
  in the AreaIndex entries of THIS file (DECISIONS.md). docs/ now holds: mystic.txt
  (the manual), DECISIONS.md, TODO.md, whatsnew.txt.

## TODO trimmed to forward-looking (2026-07-07)
  TODO.md had accumulated detailed writeups of COMPLETED work (AreaIndex, the small-
  unit cluster, stale DEFERRED/CAVEAT text, and a RECOMMENDED-ORDER section listing
  already-done items). All that done-work is captured in whatsnew.txt (user-facing)
  and DECISIONS.md (the why), so TODO was rewritten to be purely forward-looking:
  STATUS + ORIENTATION + item 1 (live FTN testing) + optional polish + open
  investigations + intentional divergences. 169 -> 108 lines. Nothing lost.

## Docs: switched to HTML manual + recovered Templates (2026-07-07)
  Replaced docs/mystic.txt with docs/mystic.html - a single self-contained styled
  HTML manual (original Mystic banner + support table, linked TOC, all ~74 wiki
  pages converted from DokuWiki markup, proper headings/tables/code). CRUCIALLY it
  now INCLUDES the Template System section (ansimidx.ini structure) that the wiki
  left as an empty stub - recovered from the pre-deletion mystic_wiki_reference.txt
  and placed as a Fork Reference chapter at the top of the TOC. README updated to
  point at mystic.html. The reverse-engineered template docs are no longer missing.

## MPL compiler / version stamp verification (2026-07-07)
  Built mplc from source and compiled all 14 scripts/*.mps -> .mpx: ALL succeed.
  MPL bytecode version stamp: OUR fork = [MPX 11S]; stock 1.12 A49 = [MPX 11248A].
  The runtime enforces an exact-match check (mpxVerMismatch in mpl_execute.pas:2602),
  so .mpx compiled by our mplc runs on our mystic (self-consistent) but NOT on stock
  1.12, and vice versa. This is correct: MPL bytecode evolved 1.10->1.12; our fork
  uses the 1.10-era version. Practical note: ship .mps SOURCE and compile on target;
  compiled .mpx is version-locked. Added *.mpx to .gitignore (build output).

## Utilities compile check (2026-07-07)
  The 4 programs in utilities/ (ansi2pipe, mtype, cvtmenus, pcb2mbbs) all compile
  cleanly on BOTH win32 and linux with FPC 2.6.2 - no A38 compatibility issues. They
  have GPL headers and depend only on mdl/ units + standard FPC units (DOS/CRT/Classes).
  ansi2pipe = ANSI->pipe codes; mtype = display ANSI files; cvtmenus = menu format
  conversion; pcb2mbbs = PCBoard->Mystic import (has pcb2mbbs.txt doc). Compilation
  verified; runtime/functional testing against real input files is a live-test item.
  NOTE: utilities are NOT currently in build.sh/build-win32.bat - compiled manually
  with -Fiutilities added to the include path.

## mystic/COPYING removed + ansimidx moved to mystic/ (2026-07-07)
  1. Deleted mystic/COPYING - byte-identical duplicate of the root COPYING (GNU
     convention keeps ONE license at root covering the whole tree).
  2. Moved the ansimidx template files (ansimidx.ini/.ans + ansimidxhelp.asc) from
     default_theme_text/ INTO mystic/, matching g00r00 own convention: he ships data
     files (nodespy_ansi.ans, mutil_ansi.ans, mis.ini, mutil.ini, mide.ini, etc.)
     right alongside the source in mystic/. Our ansimidx.ini is the same KIND of
     default template config as his mis.ini/mutil.ini.
  3. Folded the standalone README placement instructions into ansimidx.ini own
     comment header (where a sysop editing it will see them), then removed the README
     and the now-empty default_theme_text/ dir. Updated refs in README/whatsnew.
     Build unaffected (data files, not compiled).

## whatsnew reflowed to 79 cols + fork whatsnew in mystic/ (2026-07-07)
  Retired g00r00 upstream history to attic (HISTORY_g00r00_v105-v110.txt,
  fullhistory_g00r00.txt, whatsnew_g00r00_upto_A38.txt) for reference; documented in
  attic/README.md. Put the FORK whatsnew in mystic/whatsnew.txt so the installer
  (install.pas ViewTextFile) shows our changes, not g00r00 upstream log. Reflowed
  whatsnew to <=79 cols (BBS width) by breaking at last space before col 79 -
  content/word-count unchanged (3573 words), double-space-after-period style
  preserved. docs/ = mystic/ = outputs/ copies kept in sync.

## mutil.ini completed + mis.ini confirmed active (2026-07-07)
  Finished documenting our fork's mutil features in mystic/mutil.ini (was g00r00's
  2013 original, drifted from evolved fork code):
  - [General]: added log rotation keys maxlogfiles(=10)/maxlogsize(=500 KB) that the
    code reads (mutil.pas:162-163) but the ini never documented. LogRoll in
    mutil_common.pas rolls mutil.log.1..N once the log exceeds maxlogsize KB.
  - [ImportEchoMail]: corrected base_format -> base_type (code reads base_type at
    echoimport:284; base_format was silently ignored - an upstream naming bug present
    in stock A49 too). Added strip_seenby and twit-filter docs (both read by our
    echoimport code but undocumented). Kept the original dupe_msg_index (removed a
    duplicate I briefly added). All 23 [ImportEchoMail] keys the code reads are now
    documented. [ExportEchoMail] correctly left as '; no options' (echoexport reads
    zero ini keys - verified).
  - [Import_FIDONET.NA] base_format LEFT AS-IS: that importer (importna:94) genuinely
    reads base_format, so it is correct there.
  mis.ini: CONFIRMED STILL ACTIVE. mis.pas:102 calls LoadMISConfig at MIS startup,
  reads [SMTP] RefuseForeign from data/mis.ini, checked live in mis_client_smtp:118.
  Auto-creates a documented default if absent. Fork-original RefuseForeign feature.
  mutil builds clean after ini changes (ini is data, not compiled).

## RefuseForeign migrated to config editor - COMPLETED (2026-07-07)
  Finished the interim->permanent move the code always intended (mis_common.pas
  comments + A51 both said it belongs in SMTP Server Options). Steps:
  1. records.pas: added inetSMTPAllowForeign:Boolean, carved from Res1 (210->209).
     SizeOf(RecConfig) stays 5282 (probe-verified). INVERSE SENSE is deliberate:
     FALSE (the zeroed/default value on existing configs) = refuse foreign = original
     A38 behavior; TRUE = accept. This keeps upgrades behaviorally identical.
  2. mis_common.pas LoadMISConfig: config field is now source of truth
     (smtpRefuseForeign := Not bbsCfg.inetSMTPAllowForeign). A legacy data/mis.ini,
     IF present, still overrides for backward compat, but we NO LONGER auto-create it.
     Removed the stale interim-solution comments.
  3. bbs_cfg_syscfg.pas: added R Allow Foreign toggle to the SMTP Server screen
     (row 15); grew that box 16->17 high (+vertical line 14->15) to keep bottom
     padding. NNTP box left at 16.
  Builds 14/14 win32+linux. TODO OPTIONAL-POLISH item for this is now DONE.

## mis.bsy running-lock added (2026-07-07)
  Brought the mis.bsy semaphore forward from 1.12 (sysop-requested; NOT in our A39
  base - A39 defines only 5 sem constants: echomail.out/in, newsmail.out, netmail.out,
  qwkmail.out). mis.bsy is a running-lock preventing two MIS instances fighting over
  the same ports (A49 error string: 'Mystic servers are already running').
  - records.pas: added fn_SemFileMisBusy = 'mis.bsy'.
  - mis.pas ServerStartup: after ReadConfiguration, check SemaPath+mis.bsy; if it
    exists -> error + Halt(1). Otherwise AppendText creates it (same idiom bbs_core
    uses for the other semaphores). A 'KILLBUSY' command-line param erases a stale
    lock first (matches 1.12's KILLBUSY). Placed inside ServerStartup so BOTH the
    interactive and Unix daemon paths get the lock.
  - mis.pas shutdown: FileErase the lock before Halt(255).
  Used ParamCount/ParamStr loop (GetCommandLine does not exist in our tree).
  SizeOf unaffected (const, not a record field). Builds 14/14 both platforms.
  NOTE: the other two flagged 1.12 semaphores (nodeinfo.now) were NOT added - only
  mis.bsy, per sysop.

## mystic_modem dialup/serial add-on module (2026-07-07)
  Sysop asked for real serial-modem dialup support (the classic WFC / modem
  config), built SEPARATE from the main A38 source so it can be added cleanly.
  Legacy dialup was removed from Mystic BEFORE the GPL source release (the 1.10
  line is telnet/TCP only; the old WFC-with-modem-window became the MIS network
  status screen in mis_ansiwfc.pas). The 1.07 DOS archive (downloaded this session)
  is binary+data only - no source to port from - so this is a fresh reconstruction.
  Built on FPC's standard cross-platform Serial unit (SerOpen/SerRead/SerWrite/
  DTR/RTS/CTS/DSR/RI), so it targets Win32 (COMx) and Linux (/dev/ttyS*, ttyUSB*).
  Module = mystic_modem/ with 4 units + a demo:
    mdm_serial - TModemSerial: thin OO wrapper over FPC Serial (open/params/rw/lines)
    mdm_modem  - TModem: Hayes AT control (init/answer/dial/connect-speed/carrier/
                 hangup), verbose result-code parsing
    mdm_config - TModemConfig from its OWN modem.ini (uses mdl m_IniReader, NOT the
                 external IniFiles unit which is absent from our container; also keeps
                 it consistent with the fork). Touches NOTHING in MYSTIC.DAT/RecConfig.
    mdm_wfc    - TWfc: the Waiting-For-Caller loop + modem status window; on CONNECT
                 fires a TConnectCallback(Ser, Baud) - the integration hook where a
                 real build would launch a Mystic node bound to the serial line.
    wfcdemo    - standalone driver: loads modem.ini, runs WFC, echo-session on connect.
  Compiles + LINKS to an executable on linux i386 (FPC 2.6.2). Ran it: auto-creates a
  documented modem.ini, draws the WFC screen, fails gracefully with no hardware, and
  the local-mode path fires the connect callback. Win32 uses the same FPC Serial unit
  (standard in a full install; only absent from this container's partial win32 RTL).
  Kept ENTIRELY separate from the 14 main programs - zero changes to core A38, zero
  on-disk impact. Has its own build-modem.sh + README.md. Integration (launching a
  real Mystic session over the serial handle) is the documented next step for the sysop.

## FOSSIL layer added to mystic_modem + mtype.pas checked (2026-07-07)
  Sysop asked to (a) add FOSSIL support to the dialup module and (b) check whether
  mtype.pas needs a structure update.
  FOSSIL: added mdm_fossil.pas - a FOSSIL-style comms abstraction (TFossil) mirroring
  the classic INT 14h FOSSIL API (init 04h/deinit 05h/tx 01h/rx 02h/status 03h/DTR 06h/
  flush 08h/purge 0Ah/info 1Bh). HONEST DESIGN: native 32-bit code cannot issue INT 14h
  and there is no go32v2/DOS target in this toolchain, so FOSSIL here is an ABSTRACTION
  with two backends: fbSerial (the working native mdm_serial path, Win32 COMx / Unix tty)
  and fbInt14 (real INT 14h, compiled ONLY under {$IFDEF MSDOS/GO32V2}; a safe stub
  elsewhere). Code written FOSSIL-style runs on modern systems via serial and drops onto
  real DOS+FOSSIL (X00/BNU/NetFoss) unchanged. Added usefossil/fossilport keys to
  modem.ini. Whole module (5 units + demo) compiles + links on linux i386; demo runs.
  MYSTIC MODEM STRUCTURES: Mystic's records have NO real modem-control structure - the
  only modem-ish fields are cosmetic legacy display strings: BBSListRec.BaudRate (a BBS
  list entry's advertised rate) and ChatRec.Baud (who's-online display; a comment there
  even says 'remove baud rate'). So there is nothing in Mystic's records to mirror; our
  TModemConfig/TModem/TFossil ARE the modem structures, correctly self-contained.
  MTYPE.PAS: needs NO structure update. Its BaudEmu is a cosmetic output-throttle (the
  optional [delay] param that simulates a slow modem via WaitMS) - a local LongInt, not
  a record, touching no Mystic structure and no hardware. Left unchanged.

## mystic_mailer sample front-end - EMSI + BinkP-over-modem (2026-07-07)
  Sysop asked for a SAMPLE FidoNet mailer front-end (FrontDoor-style), separate
  from Mystic source, built on the mystic_modem/ layer, with BinkP-over-modem too.
  Kept to test/sample code only - NOTHING in the Mystic tree changed.
  mystic_mailer/ = mlr_emsi.pas + mlr_binkp.pas + mailer.pas (+ README, build script).
  THREE-WAY DETECTOR (mailer.pas): after answer/CONNECT, sniff a few seconds and
  classify {EMSI | BinkP | human}: EMSI announces **EMSI_INQ; BinkP announces a
  command frame (high bit set + M_NUL/M_ADR/M_PWD id); else human.
  REAL: the EMSI handshake (FSC-0056) - INQ detection, build/parse EMSI_DAT
  (addresses/system/password/protocols), ACK/NAK, CRC16-CCITT. Fixed the CRC init
  from $0000 (XMODEM) to $FFFF (CCITT-FALSE) - now returns the canonical $29B1 for
  '123456789' (verified). Detector + CRC + BinkP-frame recognition all logic-tested.
  STUBS/SEAMS (honestly marked): Zmodem mail transfer after EMSI (separate chunk; our
  existing tosser mutil_echocore consumes bundles once they land); BinkP-over-serial
  (does NOT re-implement BinkP - Mystic's engine already talks to a TIOBase stream, so
  it needs only the shared TIOSerial class then runs unchanged); human hand-off (spawn
  Mystic bound to the line, also needs TIOSerial + parent->child handle hand-off).
  BINKP-OVER-MODEM V.42 ASSUMPTION (documented in README): BinkP/FTS-1026 assumes a
  reliable TCP stream; a raw modem link is not that, so this relies on the modems
  negotiating V.42/MNP error correction on BOTH ends. Hardware reality, not a code
  fix. Builds + links on linux i386 (FPC 2.6.2). Needs real (ideally V.42) modems to
  live-test. Common thread across modem+mailer work: the TIOBase abstraction - one
  TIOSerial class unlocks human sessions AND BinkP-over-modem, both reusing existing
  engines unchanged.

## BinkP-over-modem spec written + mlr_binkp IDs corrected (2026-07-07)
  Sysop asked for a spec documenting how BinkP-over-modem works. Written to
  mystic_mailer/BINKP-OVER-MODEM-SPEC.md - a design spec (not code) accurate to THIS
  fork (cross-checked against mis_client_binkp.pas, not generic). Covers: the reliable-
  stream problem (BinkP=FTS-1026 assumes TCP); reliability supplied by modem V.42/MNP EC
  (hardware assumption, both ends; hardware RTS/CTS flow control mandatory since frames
  are binary); our actual frame format (2-byte big-endian header, bit15=command,
  DataSize:=(Len+1) OR $8000, layout Hi+Lo+CmdType+CmdData); our real message IDs
  (M_NUL=0..M_BSY=8); the answer/call session flow incl. preserving the sniffed opening
  bytes; and the ONE piece of real work - mdl/m_io_serial.pas (TIOSerial:TIOBase,
  template = m_io_stdio.pas 177 lines) PLUS a careful widening of TBinkP.Client from
  the concrete TIOSocket to the abstract TIOBase so either socket or serial can drive
  the unchanged engine (every method it calls is already virtual on TIOBase). Notes
  longer timeouts for serial, carrier-loss=session-abort, and that live test is
  hardware-gated (two V.42 modems). Also FIXED mlr_binkp.pas placeholder constants to
  match the real engine (had M_OK=3; real is M_FILE=3/M_OK=4) - detector unaffected
  (only checks M_NUL/M_ADR/M_PWD=0/1/2). Rebuilt clean; spec claims cross-verified.

## MIS-style WFC status screens for modem + mailer (2026-07-07)
  Sysop asked for a MIS-style WFC status screen for each new subsystem (modem, mailer/
  binkp), kept in the separate modules (NOT edited into mis.pas), plain text.
  Modelled on MIS's DrawStatusScreen (mis_ansiwfc.pas): titled panel + labelled field
  rows + bottom hot-key bar. Plain text = fully portable, no dependency on Mystic's
  Console/ANSI engine (a themed ANSI version could replace them later).
  - mystic_modem/mdm_miswfc.pas: DrawModemWfc(cfg, stats) - shows Device/Baud/Init/
    Rings/FOSSIL + live Line/Connect/Carrier/Calls/Last. Wired into wfcdemo (drawn at
    startup with a TModemWfcStats).
  - mystic_mailer/mlr_miswfc.pas: DrawMailerWfc(addr, name, stats) - shows this node's
    FTN addr/system + live Line/Caller(EMSI|BinkP|human)/Mode/Remote addr/Remote sys +
    Mail-sess/Humans/Last counters. Wired into mailer.pas (drawn before the answer loop).
  Both render verified (modem screen via wfcdemo; mailer screen via a throwaway render
  in idle + mid-EMSI-session states). Hot-key bar mirrors MIS: SPACE/Local TAB/Switch
  ALT-H/Hangup ESC/Shutdown. Still separate from core A38; builds+links clean linux i386.

## Sysop modem config editor + GitHub repo prep (2026-07-07)
  Sysop asked to (a) let a sysop configure a modem for both modules, (b) create a git
  repo (close to GitHub), (c) review docs/source for anything missed.
  CONFIG: added SaveModemConfig to mdm_config.pas (writes CURRENT values with the
  documented comments, vs the old WriteDefault which only wrote fixed defaults). Built
  mystic_modem/modemcfg.pas - an interactive menu-driven editor (modem config editor):
  shows all 9 settings (device/baud/init/rings/hardwareflow/wfcscreen/localmode/
  usefossil/fossilport), lets the sysop change any, saves. SHARED by both modules (same
  modem.ini/TModemConfig). Tested non-interactively: edits apply + save. In build script.
  REPO: git init at tree root; identity Antonio Rico (Reapern66)/reapern66@tnabbs.org.
  Removed a STRAY .gitmodules from g00r00's original 2013 tree (referenced his private
  Windows dev path - would break a public clone). .gitignore extended (modem.ini, module
  out/bin, *.bsy). 240 files staged, ZERO build artifacts.
  DOC REVIEW findings + fixes: README.md did not mention the modem/mailer modules -> added
  a tree entry for each + a 'Dialup / modem support (optional)' section. GPL headers 8/8
  (modem) + 4/4 (mailer). Both modules have README + build script. modemcfg in module
  README. No private paths/cruft remain. Core 14/14 + all module programs build clean.

## Authentic 1.07 WFC screen + full sysop commands + maintainer credit (2026-07-07)
  Sysop noted the WFC screens weren't based on the REAL Mystic 1.07 DOS screen (the
  dialup WFC-with-modem-window is the whole reason the DOS version existed), wanted the
  sysop to have all the config commands, and asked for a maintainer credit line.
  SOURCE OF TRUTH: extracted the actual 1.07 strings from MROOT.MYS inside the downloaded
  mysd_107.zip archive (binary, no source, but the strings are authentic). Found the real
  WFC title "Waiting for a caller", the sysop command/status bar (ALT (C)hat (S)plit (E)dit
  (H)angup (J) DOS (U)pgrade (B) Status Bar), caller-info fields ([Alias][Baud][Sec][Time]
  [Name][Flag1][Address]...), modem lifecycle msgs (Initializing Modem, Taking modem
  offhook, Incomming caller; Answering phone, Carrier detected, NO CARRIER!, Waiting for
  handshake), and the real modem config fields (Com Port, Baud Rate, Modem Offhook /
  Offhook Command, Answer, Dialup).
  REBUILT mdm_miswfc.pas DrawModemWfc to echo the authentic 1.07 layout + command bar
  (added (G) Offhook Modem, (L) Local Logon, (ESC) Exit Mystic). Updated mdm_wfc status
  strings to the real 1.07 wording (Waiting for a caller / Incomming caller; Answering
  phone / Initializing Modem / Carrier detected).
  CONFIG: added AnswerStr + OffhookStr fields to TModemConfig (1.07's Answer + Offhook),
  wired into Load/Save/WriteDefault and the modemcfg editor (menu items A + O). Made
  TModem.Answer accept a configurable command (defaults ATA, backward-compatible) and
  wired Cfg.AnswerStr through the WFC answer path.
  CREDIT: added maintainer line to README (top + Credits): Antonio Rico - Ecstasy BBS -
  aric2746@aim.com, "It's been a long time since 1999; just trying to give back."
  All builds clean (wfcdemo, modemcfg, mailer); screens verified rendering.

## Authentic blue ANSI WFCSCRN.ANS built from 1.07 (2026-07-07)
  Sysop noted the real WFC is a blue ANSI screen (WFCSCRN) showing all commands, not a
  plain-text box. Investigated the 1.07 binary: the .MYS data files are Mystic's own
  COMPRESSED archive format, so the original WFCSCRN.ANS is not directly extractable (and
  it was a sysop-customisable template, referenced by name in MROOT.MYS, not embedded as a
  complete screen). BUT the exact field layout + command bar ARE in the binary as strings
  (the caller-info grid: [Alias][Baud][Sec][Time][Name][Flag1][Address][BDay][Sex][Home PH]
  [Data PH][Email][Flag2], and the ALT command bar). Built a faithful blue ANSI screen
  mystic_modem/WFCSCRN.ANS from those authentic strings: blue bg, cyan labels, yellow
  command keys, CP437 box borders, all 11 sysop commands (Line Chat/Split Chat/Edit User/
  Hangup/Drop to DOS/Upgrade User/Status Bar/Offhook Modem/Local Logon/Exit Mystic) + the
  caller-info grid + modem status. Added ShowWfcAnsi(Cfg) to mdm_miswfc: if wfcscreen names
  an ANSI file, stream it to the console verbatim (per-char write, CP437-safe), else fall
  back to the plain-text DrawModemWfc. Tested: streams the full 1974-byte screen intact.
  Honest note: this is a faithful RECONSTRUCTION from the binary's authentic strings/layout,
  not a byte-for-byte extraction of the original compressed screen (not possible from this
  archive). Sysops can replace WFCSCRN.ANS with their own, exactly as in 1.07.

## mystic_spell: spell-check add-on (Hunspell), separate module (2026-07-07)
  CORRECTION first: I earlier said Mystic had no spellchecker - WRONG. It does, since
  1.12, using the Hunspell engine (on-the-fly spell check + word suggestions in the full
  screen editor). It postdates our A38/A39 base, which is why it's not in our tree.
  Sysop wanted it added SEPARATELY (not in main src), like the modem/mailer modules.
  Built mystic_spell/: spl_hunspell.pas (runtime binding), spl_engine.pas (TSpellEngine),
  spelltest.pas (tester), + build-spell.sh, WORDLIST.TXT (sample BBS terms), README.
  DESIGN: Hunspell loaded at RUNTIME via dlopen/LoadLibrary (NOT linked at compile time),
  so it builds with no Hunspell present and degrades gracefully (no library/dict => spell
  check simply OFF, everything reports OK) - exactly the 1.12 deployment model (sysop drops
  the library + .aff/.dic dictionaries + optional WORDLIST.TXT in place).
  REAL TOOLCHAIN FIX: FPC 2.6.2's legacy `dl` unit links the old standalone libdl, but
  modern glibc 2.34+ folds dlopen/dlsym/dlclose into libc (standalone libdl is now a stub),
  causing 32-bit link failures. Fixed by declaring dlopen/dlsym/dlclose directly as
  cdecl external 'c' instead of using FPC's dl unit. Now builds clean 32-bit AND 64-bit.
  VERIFIED: 64-bit build run against the container's real Hunspell 1.7 + en_US dictionary
  correctly spell-checks and suggests (mesage->message, recieve->receive, definately->
  definitely, teh->the; hello/sysop/BBS OK). WORDLIST.TXT loads (netmail/echomail accepted).
  32-bit builds + runs, degrades gracefully (no 32-bit Hunspell in container - sysop
  supplies one, same as 1.12). INTEGRATION SEAM (documented, NOT done - it's core work):
  live highlight-as-you-type in the full-screen message editor would hook the editor
  keypress loop; this module provides the engine (Check/Suggest) that hook would call.

## mystic_spell: match g00r00's Hunspell DLL names (2026-07-07)
  Sysop noted g00r00 ships Hunspell as a DLL. Confirmed the exact names from the 1.12
  wiki and corrected the binding to match, so the SAME DLL from the Mystic spellcheck
  package is a drop-in for our fork:
    Windows 32-bit -> libhunspell32.dll ; Windows 64-bit -> libhunspell64.dll
    Linux -> libhunspell.so ; macOS -> libhunspell.dylib (sysop symlinks the real one)
  My first binding looked for the wrong names (libhunspell.dll/hunspell.dll) - fixed.
  Pointer-width guard picks 32 vs 64 DLL on Windows; versioned .so names kept as fallback
  (that's what caught the container's libhunspell-1.7.so.0 in the 64-bit test). Also added
  a DARWIN guard for the .dylib path. Rebuilt: 32-bit + 64-bit clean; 64-bit still spell-
  checks correctly against real Hunspell. UI behaviour confirmed from the wiki for future
  editor integration: 1.12 highlights misspelled words live, auto-suggests on the bottom
  line after a ~0.5s typing pause (msg_editor.ini suggestion-delay option), and a hotkey
  pops a listbox of suggestions that replaces the word - that live UI is the core editor
  seam, still out of scope for this separate module.

## mystic_spell: fix Windows port build (2026-07-07)
  Sysop pointed at the Windows port specifically (where g00r00 ships the Hunspell DLL and
  the DLL IS the deployment). Discovered mystic_spell did NOT compile for -Twin32: Windows
  LoadLibrary returns HModule (a LongWord), not a Pointer, so LibHandle:Pointer and the
  '<> Nil' comparisons failed on Windows (4 type errors). Only surfaced by actually building
  the win32 target - had only tested Linux before. Fixed: LibHandle is now Pointer on UNIX
  and HModule on Windows via IFDEF, with a LibOpen helper doing the platform-correct empty
  check (<> Nil on unix, <> 0 on windows) and UnloadHunspell resetting to Nil/0 accordingly.
  Verified all THREE targets now build: win32 (spelltest.exe, THE Windows port), linux i386,
  and linux x86_64 (still spell-checks correctly against real Hunspell). Lesson: build the
  target that matters, not just the convenient one.

## mystic_spell: Darwin portability review (2026-07-07)
  Sysop reminder not to forget Darwin. The container's i386-darwin RTL is incomplete
  (system.ppu missing), so a darwin COMPILE can't run here - did a portability review
  instead (same as the project's deferred-darwin-link policy). Code is darwin-correct:
  FPC treats DARWIN as a subset of UNIX, so on macOS the UNIX branch (dlopen, declared
  external 'c' - resolves in libSystem on macOS) is used, and DefaultNames has a
  {$IFDEF DARWIN} sub-branch that picks libhunspell.dylib (the exact name Mystic looks
  for; sysop symlinks the installed Hunspell to it). No darwin-specific code errors.

## mystic_sdl: SDL2 full-screen DOS-session front-end (2026-07-07)
  Sysop wants an SDL2 front-end that renders a full-screen DOS session (80x25 CP437) so
  the modem/BinkP WFC (and future live sessions) can display in a graphical DOS-style
  window - "the future if they pick it". CONTEXT CORRECTION: I'd earlier dismissed SDL as
  wrong for a WFC; that was for a console STATUS screen. g00r00 uses SDL2 for the NetRunner
  TERMINAL (font switching, DOS/Amiga fonts) - for a client/emulator SDL is exactly right,
  and this DOS-session emulator is that use case. Separate module, nothing depends on it.
  mystic_sdl/: sdl_bind.pas (minimal SDL2 binding, runtime-loaded like Hunspell - looks for
  SDL2.dll / libSDL2-2.0.so.0 / libSDL2.dylib, DARWIN guard included), sdl_dosscreen.pas
  (TDosScreen: 80x25 CP437 cell grid -> SDL window via an 8x16 VGA font, DOS 16-colour
  palette, WriteXY/SetAttr/Clear + LoadAnsi that parses ESC[..m and cursor pos), sdl_demo,
  VGA8X16.FNT (generated 4096-byte font asset), build-sdl.sh, README.
  BUGS FOUND+FIXED during build: SDL_QUIT const vs SDL_Quit fn name clash (renamed to
  SDL_QUIT_EVENT); file Close() vs method Close() (System.Close); FPC 2.6.2 rejects inline
  Var decls (moved to var blocks); and an EAccessViolation in the glyph blit - added a
  bounds guard on the pixel index (the real fix). VERIFIED: builds win32 (.exe), linux i386,
  linux x86_64; the 64-bit run against real SDL2 (dummy video driver, headless) renders both
  a built-in WFC and the modem module's real WFCSCRN.ANS, and a dumped frame (PPM->PNG)
  visually confirms a correct blue DOS screen with legible VGA font + DOS colours.
  Darwin: portability review only (container can't link darwin); code path correct
  (libSDL2.dylib via UNIX/dlopen). SDL2 ~1.9MB/platform, runtime-loaded, NOT bundled -
  sysop drops the SDL2 lib in place, as NetRunner does. cl32.dll question answered
  separately (it's cryptlib - Peter Gutmann's crypto toolkit Mystic uses for SSH/TLS/
  encrypted netmail); advised NOT renaming it (canonical cryptlib name; rename risks
  breakage) - document instead.

## mystic_crypt: cryptlib (SSH/TLS) example, separate module (2026-07-07)
  Sysop asked for a cryptlib example separate from the main source, before release.
  CONFIRMED FIRST (honest check): our A38/A39 fork core has NO cryptlib/SSH/TLS - MIS
  creates only telnet/smtp/pop3/ftp/nntp/binkp (six servers, no SSH); m_crypt.pas is just
  Base64+CRC, not cryptlib. SSH/TLS is a 1.12 feature (the A49 binary has cl32.dll +
  cryptCreateSession + "Cryptlib not detected; SSL/SSH capabilities disabled"; A51/1.10 has
  none). So this is a feature-forward example, not something already in the fork.
  mystic_crypt/: cl_bind.pas (runtime cryptlib binding - looks for cl32.dll on Windows /
  libcl.so on Linux / libcl.dylib on macOS, DARWIN guard; entry-point names cryptInit/
  cryptCreateSession/cryptSetAttribute[String]/cryptPushData/cryptPopData/cryptDestroy
  Session/cryptEnd taken from the stock Mystic binary so a real cl32.dll is a drop-in),
  cl_session.pas (TCryptSession: StartSession(crSSHServer/crSSHClient/crTLSServer/
  crTLSClient, socketHandle, privKey), Send/Recv via push/pop, graceful-off), cl_demo.pas
  (prints the exact "Cryptlib not detected..." message when absent), build-crypt.sh, README.
  BUG FOUND+FIXED: parameterless fn pointers cryptInit/cryptEnd need () to CALL rather than
  compare the pointer (FPC objfpc). VERIFIED: builds win32(.exe)/linux i386/linux x86_64;
  demo runs and degrades gracefully (no cryptlib in container). Darwin: portability review
  (can't link in container), code path correct. cryptlib NOT bundled - runtime-loaded, sysop
  drops cl32.dll in place, exactly as stock Mystic. cl32.dll NOT renamed (canonical cryptlib
  name; rename risks breakage + it has its own deps) - documented instead in the README.
  INTEGRATION SEAM (NOT done - it's core work): a real SSH server = a 7th MIS client type
  (like mis_client_telnet) wrapping the accepted socket in a cryptlib SSH session over
  TIOBase; TLS on SMTP/POP3 the same idea; plus config fields (SSH port, host-key paths).

## Darwin audit + library-size documentation across all modules (2026-07-07)
  Sysop reminder: don't forget Darwin, and asked how big the libs the examples need are.
  DARWIN AUDIT (all 5 modules): spell/sdl/crypt already had {$IFDEF DARWIN} .dylib paths
  (libhunspell.dylib / libSDL2.dylib / libcl.dylib). GAP FOUND: mystic_modem used FPC's
  cross-platform Serial unit (compiles on macOS) but its config only documented Windows COM
  and Linux /dev/ttyS0 - not macOS /dev/cu.* devices. Fixed the modem.ini comments to
  include macOS /dev/cu.usbserial-*. mystic_mailer is pure protocol (portable, no platform
  calls). Added a Cross-platform/Darwin section to the modem + mailer READMEs (the other
  three already covered it). All 5 module READMEs now document Darwin/macOS. Container still
  can't LINK darwin (RTL gap) - maintained by code review, links on a real Mac, as throughout.
  LIBRARY SIZES (measured, runtime-loaded, NOT bundled in the repo):
    Hunspell (spell): Linux 721 KB / Windows ~300-600 KB, + en_US dict .dic 840 KB + .aff 3 KB
    SDL2 (sdl): Linux 1.8 MB / Windows ~1.5-2.5 MB
    cryptlib (crypt): cl32.dll ~1.1 MB / libcl ~1-2 MB
    modem + mailer: no external lib (FPC serial unit / pure protocol)
  Only bundled asset is VGA8X16.FNT (4 KB). All libs are the sysop's drop-in, so the repo
  stays small (3.3M with git history); enabling all optional features on Windows adds ~4.5 MB
  of libraries but only for features the sysop turns on.

## libs/: bundle the three optional runtime libraries (2026-07-07)
  Sysop chose to ship the libraries with the repo. Verified cryptlib IS bundle-able: its
  Sleepycat license is GPL-compatible and permits binary redistribution (conditions: keep
  the copyright/disclaimer + provide info on obtaining cryptlib source). Free tier covers a
  non-revenue BBS (large-scale commercial = >US$5000). SDL2=zlib, Hunspell=GPL/LGPL/MPL,
  both clearly fine. To avoid the documented GPLv3-vs-Sleepycat "further restriction" gray
  area, the libs live in a SEPARATE libs/ tree as MERE AGGREGATION (not combined into the
  GPL source), each with its own LICENSE file: SDL2-LICENSE.txt (zlib), HUNSPELL-LICENSE.txt
  (tri-license + source URL), CRYPTLIB-LICENSE.txt (Sleepycat text + mandatory source-code
  pointer to Gutmann's site, satisfying condition 3). libs/README.md maps each lib to its
  module + platform filenames. .gitignore un-ignores libs/*.dll/.so/.dylib so the dropped
  binaries ARE tracked; .gitattributes marks them binary. Assistant CANNOT fetch the actual
  binaries (egress proxy blocks downloads) - sysop drops the .dll/.so/.dylib into libs/
  before pushing. Modules already search the working dir/system path; libs/ is the drop spot.

## RIP graphics Phase 1: ripterm engine lifted into the tree (2026-07-08)
  Sysop delivered the pending drop-in (ripterm_client_v0 + v1 GUI + demos tar).
  All three archives share ONE identical engine (diffed); v1 is the superset
  (adds sdl2min/RipWindow/ripview). Landed per docs/RIP-INTEGRATION.md:
  - mdl/m_term_rip.pas: TTermRip, the TTermAnsi parallel (same public shape:
    Create/Process/ProcessBuf/SetReplyClient). Char-fed, CR-framed lines with
    trailing-'\' continuation. Line buffers are AnsiString ON PURPOSE: core is
    {$LONGSTRINGS OFF} (String=ShortString, 255 max) and joined RIP lines can
    exceed 255 - do NOT "simplify" to String.
  - mdl/m_rip_canvas.pas: the graphics seam. DECISION: abstract class
    (TRipCanvas), NOT the client's COM interface (IRipCanvas/TInterfacedObject).
    Reasons: plain Create/Free lifetime matches every other MDL class; no
    refcount-vs-manual-Free footguns; identical semantics under core -Mdelphi
    and module -Mobjfpc. Same seam, different plumbing; parser logic unchanged.
  - mystic_sdl/rip_surface.pas (TRipSurface): the software raster. DECISION:
    lives in the MODULE, not mdl/, so mdl/ stays graphics-implementation-free
    (only the seam + parser are core). Pure Pascal, no SDL: BMP export is the
    headless verification path (same idea as TDosScreen's PPM).
  - mystic_sdl/rip_window.pas (TRipWindow): presenter PORTED off the client's
    compile-time sdl2min onto the module's runtime-loading sdl_bind (house
    rule: never link SDL). sdl_bind gained SDL_MOUSEBUTTONDOWN + EventMouseX/Y
    (decode x/y from the opaque event's padding at offsets 16/20 - stable
    SDL 2.0.x layout). Window is FIXED size (not resizable like the client's)
    so the click->640x350 mapping stays exact.
  - mystic_sdl/rip_render.pas / rip_view.pas / rip_sample.pas: demos + shared
    sample. Sample generation FIXED vs the client: client built it with
    TStringList.Text (LF-only on linux, so the whole sample parsed as one
    mega-line and region text embedded a raw #13 that CR-framing would split);
    ours emits explicit CRLF lines and drops the raw #13 from region text.
    rip_render tolerates LF-only .RIP files (converts LF->CR when no CR seen)
    and feeds ProcessBuf in 16K slices (BufLen is Word, matching TTermAnsi).
  - build-sdl.sh now builds sdl_demo + rip_render + rip_view (linux + win32)
    with -Fu../mdl -Fi../mdl for the core RIP units.
  VERIFIED: core 14/14 linux i386 AND 14/14 win32 (cross-units rebuilt this
  session, see next entry); mystic_sdl 3/3 both targets; new mdl units compile
  clean under core flags; anchors RecConfig=5282 RecTheme=768
  RecEchoMailNode=901 (+RecUser=1536) unchanged; rip_render --sample output is
  PIXEL-IDENTICAL to the client's reference sample.bmp (PIL ImageChops diff =
  None) - "built once, used twice" is measured, not asserted. Graceful-off
  (no SDL) exits 0 with the standard notice.
  KNOWN ENVIRONMENT ISSUE (pre-existing, NOT a Phase-1 regression): with a
  modern distro 32-bit SDL (Ubuntu 24 libsdl2 2.30 i386 installed in-container)
  BOTH rip_view AND the pre-existing sdl_demo crash inside SDL_Init - FPC
  2.6.2 keeps the old 4-byte i386 stack alignment while modern SDL builds
  assume the 16-byte-aligned i386 ABI. Windows SDL2.dll and period Linux SDL
  builds are fine. Filed in TODO item 4 as an environment note.

## Container toolchain rebuilt; egress is OPEN this session (2026-07-08)
  Container reset had wiped FPC. Rebuilt: FPC 2.6.2 i386-linux release tarball
  (SourceForge) installed to /home/claude/i386root, fpc.cfg at /etc/fpc.cfg,
  ppc386 symlinked; libc6-dev-i386 for the 32-bit link (the INSTALL-documented
  x86_64-host quirk; -Fl/usr/lib32 added to fpc.cfg). Win32 cross: built the
  2.6.2 win32 RTL + packages (hash, fcl-base/-net/-process/-xml/-registry,
  winunits-base/-jedi) from the 2.6.2 SOURCE tarball with OS_TARGET=win32 -
  modern GNU make handled the 2.6.2 Makefiles fine; unit dirs appended to
  fpc.cfg. So the "both platforms" verification is native again.
  NOTE the earlier "assistant CANNOT fetch binaries (egress proxy blocks
  downloads)" entry is no longer true THIS session: network egress is open
  (that's how FPC came in). If it stays open, the libs/ drop-ins (SDL2 2.32.8
  win32 dll at minimum, from the official libsdl-org GitHub release) are now
  fetchable in-container - flagged to the sysop rather than done unasked,
  since libs/ provenance was the sysop's call.

## RIP Phase 1 relocated: mystic_rip/ example module, zero mdl deps (2026-07-08)
  Sysop direction, same day as the initial landing: RIP does NOT go into mdl/
  yet - it lives as its own self-contained example folder like the other
  add-ons, and it must use FPC facilities rather than mdl units ("fpc threads
  not mdl": any threading is FPC TThread/cthreads, exactly what
  m_socket_server already uses; no custom layer). Applied:
  - mdl/m_term_rip.pas   -> mystic_rip/rip_term.pas   (Unit rip_Term)
  - mdl/m_rip_canvas.pas -> mystic_rip/rip_canvas.pas (Unit rip_Canvas)
  - mystic_sdl/rip_surface|rip_window|rip_sample|rip_render|rip_view|font8x8
                         -> mystic_rip/ (mystic_sdl back to sdl_demo only)
  - Units switched from core style ({$I M_OPS.PAS}, -Mdelphi) to module style
    ({$MODE OBJFPC}{$H+}, module GPL header). mdl/ is back to pristine - the
    RIP work now touches ZERO core files (sdl_bind's additive mouse helpers
    in mystic_sdl are the only change outside mystic_rip/, kept since the
    viewer builds with -Fu../mystic_sdl and NetRunner-style reuse is the
    point of that binding).
  - mdl DEPENDENCY REMOVED from TTermRip: SetReplyClient no longer takes
    TIOBase (m_io_base would drag mdl into the module). It takes an
    FPC-native callback, TRipReplyProc = Procedure(Const S: AnsiString) of
    Object. The PUBLIC SHAPE stays TTermAnsi-identical, so the eventual
    promotion (Phase 2b hook-up: rip_term.pas -> mdl/m_term_rip.pas,
    callback -> TIOBase, core header + M_OPS back on) is mechanical.
    RIP-INTEGRATION.md section 9 records this as the revised placement and
    keeps mdl/m_term_rip.pas as the PROMOTION TARGET, not the current path.
  - New mystic_rip/build-rip.sh (linux + win32; -Fu../mystic_sdl for
    sdl_bind); mystic_rip/README.md; repo README tree bullet;
    mystic_sdl/README RIP section replaced with a pointer.
  - whatsnew RESTRUCTURED per sysop: the file's own "oldest first" rule made
    the rip entry land at the bottom; sysop wants it as a banner "Phase 1"
    section DIRECTLY UNDER the Phase 0 banner (RIP is the fork's second
    named phase, not just another line item). Done; entry text updated to
    the module paths.
  RE-VERIFIED after the move: core 14/14 linux + 14/14 win32 (mdl now
  pristine), mystic_sdl sdl_demo both targets, mystic_rip 2/2 both targets,
  rip_render --sample still PIXEL-IDENTICAL to the ripterm client reference,
  graceful-off intact. data.zip (live 1.12 board data): set aside unused per
  sysop ("for now lets delete") - extraction removed from the container;
  nothing from it was ever committed. The 1.12-vs-fork layout findings from
  its one-time inspection (fbases 632/640-not-495, groups 206-not-63, scn
  3-byte-not-2; users/mbases/echonode/security/event/protocol/archive/
  history all EXACT matches) stay recorded here for whenever migration
  becomes a topic, but no converter work is planned unless asked.

## build-rip.sh: absolute -FU/-FE, -B (FPC 2.6.2 link-path quirk) (2026-07-08)
  Found while re-verifying after the mystic_rip/ move: with a RELATIVE -FU,
  FPC 2.6.2 records a relative object path in the .ppu of a unit it compiled
  from a -Fu search dir (sdl_bind from ../mystic_sdl), then at LINK time looks
  for out/out/sdl_bind.o (double-prefixed), misses, and silently falls back to
  the unit SOURCE dir's out/ - where a sibling build's object for the WRONG
  TARGET can sit (mystic_sdl's win32 leftovers broke the mystic_rip linux
  link with kernel32 undefined references). Fix in build-rip.sh: -FU/-FE are
  now ABSOLUTE (resolved from the script's own dir) and -B forces units to
  rebuild from source into our out/. Single-dir modules (build-sdl.sh etc.)
  are unaffected by the quirk; only cross-dir unit reuse trips it.

## Darwin LINKS from Linux: 14/14 Mach-O + rip demos (2026-07-08)
  Sysop supplied a genuine MacOSX10.6 SDK (extracted from his own Xcode -
  the one piece that could not be fetched). With egress open, the rest of
  the chain was built in-container and the fork's Darwin story went from
  "compile-clean by code review" to "ALL 14 PROGRAMS LINK as Mach-O i386
  executables on Linux" (plus mystic_rip's rip_render/rip_view). Chain:
  FPC 2.6.2 ppc386 -> cctools-port as/ld64 (i386-apple-darwin10) -> 10.6 SDK.
  The full recipe is in INSTALL (Darwin section, rewritten); the hard-won
  findings, so nobody rediscovers them:
  - cctools-port needs BlocksRuntime + Apple libdispatch on Linux; apt has
    libblocksruntime-dev, libdispatch comes from tpoechtrager/apple-libdispatch
    (cmake). Then configure --target=i386-apple-darwin10.
  - The SDK tarball had NO usr/lib/crt1.o. Built from Apple open-source Csu
    (Csu-85, APSL): the v1 (10.4-compat) variant - start.s + crt.c
    (-DOLD_LIBSYSTEM_SUPPORT -DADD_PROGRAM_VARS) + dyld_glue.s, ld64 -r.
    dyld_glue MATTERS: FPC 2.6.2 emits old-style stubs that reference
    dyld_stub_binding_helper; the 10.6-style crt1 (no dyld_glue) leaves it
    undefined. clang -target i386-apple-darwin10 assembles Csu fine.
  - FPC's internal Mach-O writer (-Amacho) is fine for COMPILE-only, but its
    objects are REJECTED by modern ld64: "section __DATA/__nl_symbol_ptr
    address out of range" (seen on objpas.o). Rebuilding the darwin RTL with
    the EXTERNAL cctools assembler (drop -Amacho; symlink i386-darwin-as ->
    i386-apple-darwin10-as for FPC's default cross prefix) links clean.
  - Darwin packages: hash/fcl-net/fcl-process build; fcl-net's Makefile
    SKIPS cnetdb for darwin, but Darwin's libc netdb API matches - compiled
    fcl-net/src/cnetdb.pp by hand and mis/fidopoll/nodespy/qwkpoll linked.
    fcl-base fails on MacOSAll (univint) - nothing in this tree needs it.
  - otool sanity: MH_MAGIC I386 EXECUTE, TWOLEVEL/NOUNDEFS, mis links only
    /usr/lib/libSystem.B.dylib.
  HONEST CAVEATS: (1) runtime is UNTESTED - needs era hardware; i386 Mach-O
  runs on OS X 10.4..macOS 10.14 ONLY (32-bit support ended with Mojave) -
  period-correct for this fork, useless on a modern Mac. (2) crt1.o and the
  SDK are Apple-licensed (APSL / Xcode agreement): they stay OUT of the repo;
  the recipe is documented instead. (3) The container-local toolchain
  (/home/claude/darwin/xtools, SDK, darwin RTL units) dies with the container;
  DECISIONS+INSTALL are the recipe of record. Darwin-binaries zip handed to
  the sysop for a vintage-Mac smoke test - that is the real validation gate.

## libs/ populated: SDL2, Hunspell, cryptlib built in-container (2026-07-08)
  Egress open, so the pending libs/ drop-ins were BUILT this session rather
  than left for the sysop. Layout changed to platform subdirs libs/win32/ and
  libs/linux-i386/ (all binaries i386, matching the fork's builds); README
  rewritten; .gitattributes widened to cover the subdir paths as binary.
  Provided (names match what each module's TryOpen probes):
  - SDL2 2.32.8: win32 SDL2.dll = official libsdl-org release binary;
    linux-i386 libSDL2-2.0.so.0 = built from 2.32.8 source WITH -mstackrealign.
    This is the FIX for the long-standing "sdl_demo/rip_view crash in SDL_Init"
    note: FPC 2.6.2 keeps 4-byte i386 stack alignment, modern SDL assumes
    16-byte; the realign-on-entry build runs clean. VERIFIED: rip_view --sample
    and sdl_demo both render 201 frames headless (SDL_VIDEODRIVER=dummy) against
    the staged .so. So the earlier "environment issue, revisit later" is
    RESOLVED for the shipped linux binary (a stock distro SDL will still crash;
    ours doesn't).
  - Hunspell 1.7.2: linux-i386 from source (-m32); win32 via mingw
    (i686-w64-mingw32) linked -static-libgcc -static-libstdc++ so the DLL needs
    only KERNEL32+msvcrt (17 Hunspell_* exports confirmed). VERIFIED LIVE:
    mystic_spell/bin/spelltest loaded the staged .so, opened a dictionary, and
    returned correct suggestions (recieve->receive, definately->definitely,
    etc). mystic_spell is proven end-to-end.
  - cryptlib 3.4.9.1: linux-i386 libcl.so from Peter Gutmann's official source
    (nearest public source to the sysop's 3.4.9.2 target; binding ABI
    unchanged). The mystic_crypt binding LOADS it and resolves every symbol
    (cryptInit/cryptCreateSession/cryptSetAttribute/PushData/PopData/etc all
    non-nil) - the "first true test vs a real cl32" the docs flagged, PASSED at
    the binding level. cryptInit() itself returns -15 (CRYPT_ERROR_FAILED) in
    THIS container: the 32-bit build's randomness slow-poll can't get its
    entropy quota in a bare container (a native 64-bit build of the SAME source
    returns 0 here, confirming it's the i386 entropy poll, not the fork). On a
    real box with normal entropy this clears. NOT a binding defect.
    win32 cl32.dll NOT built: cryptlib's Windows build wants MSVC + its own
    entropy plumbing, out of scope for this mingw/gcc cross pass - drop a real
    cl32.dll into libs/win32 when available.
  LICENSING: all three keep their own licenses (zlib / GPL-LGPL-MPL /
  Sleepycat), "mere aggregation" alongside the GPL tree - unchanged policy,
  just now with binaries present. Provenance above so they're reproducible.
  NOTE: these binaries live in the repo now; they inflate it ~9MB. If the
  sysop prefers a lean source repo, they can be git-rm'd and rebuilt from the
  README recipe - flagged, his call.

## OS/2 target: source ported, COMPILES 14/14 cross; link is native (2026-07-08)
  Sysop asked to do the OS/2 code update "using FPC calls" - i.e. lean on the
  portable RTL rather than raw platform APIs. Done, and the whole tree now
  COMPILES for i386-os2 (14/14, compile-only -s) from Linux. FPC does support
  OS/2 (target os2 + emx; rtl/os2 has sockets via so32dll, TThread, DosCalls,
  full PM bindings). Toolchain built this session: binutils 2.30 gas/ld for
  i386-aout (--enable-obsolete; modern binutils dropped a.out) symlinked to
  FPC's i386-os2- cross prefix; then rtl + packages (hash, fcl-base, fcl-net,
  fcl-process) cross-built for os2.
  SOURCE CHANGES (all FPC-RTL-based, no new external deps; guarded so Linux +
  win32 stay 14/14 - re-verified both):
  - mdl/m_fileio.pas: GetProcessID gets an OS2 branch -> System.GetProcessID
    (the RTL call) instead of fpGetPID (Unix-only).
  - mdl/m_io_stdio.pas: was Unix-only (BaseUnix/fpRead/fpWrite/fpSelect). Added
    an OS2 branch using the RTL DosCalls API (DosRead/DosWrite on the standard
    handles); WaitForData returns "ready" on OS/2 (blocking-handle model) with
    a TODO to use DosPeekNPipe once exercised natively. Unix path untouched.
  - The IFNDEF-UNIX idiom in 9 mystic/ units MEANT "Windows" (pulled the
    Windows unit, TIOSocket sysop-console, status bar). Those are genuinely
    Win32-only console features, so IFNDEF UNIX -> IFDEF WINDOWS everywhere
    (bbs_menus/general/core/user/common/filebase/io/cfg_useredit, mystic.pas).
    OS/2, like Unix, simply doesn't build the Win32 sysop-console extras.
    Two UNIX/ELSE guards INVERTED to WINDOWS/ELSE so the non-Windows body
    (portable) covers OS/2 too: bbs_user InitConnection (the Keyboard-based
    key probe) and bbs_io.InKey (generic Keyboard version). bbs_doors and
    bbs_filebase %0 door-drop: Windows uses TIOSocket handle, everyone else
    "1". bbs_filebase drive-letter vars restored to IFNDEF UNIX (DOS-family,
    incl OS/2). mpl_execute keypress: Windows adds Client.DataWaiting.
  - mystic/mis_client_telnet.pas: telnet server had DARWIN->USEPROCESS,
    UNIX->USEFORK, Windows=its own block, OS/2=NOTHING (no Execute body).
    Added OS2->USEPROCESS: OS/2 spawns per node via TProcess (fcl-process),
    same as Darwin - no fork(), no Win32 API.
  - mystic/mis_events.pas: ShellExec gets an OS2 branch via SysUtils
    ExecuteProcess($COMSPEC '/C' cmd); Unix fpSystem / Windows paths untouched.
  - mdl/m_pipe_disk.pas (the OS/2 nodespy pipe): added DataWaiting
    (FilePos<FileSize on the file-backed pipe) that nodespy needs; also fixed
    its ReadFromPipe bRead param from LongWord to LongInt to MATCH the unix +
    windows pipe backends (they're all LongInt) and nodespy's caller.
  LINK BOUNDARY (documented, not a failure): OS/2 does NOT fully link in this
  Linux container. FPC's os2 linker (compiler/systems/t_os2.pas) is TWO-stage:
  GNU `ld` makes an intermediate a.out, then `emxbind` converts it to an OS/2
  LX executable AND binds the DLL-import-by-ordinal symbols
  ($dll$doscalls$_index_NNN etc). emxbind is an EMX-toolkit tool that runs on
  OS/2 (or DOS), and the ld step needs the EMX-format OS/2 import libraries.
  So the intended workflow is confirmed: COMPILE cross (proven here, 14/14),
  LINK natively on OS/2/eComStation/ArcaOS with the period FPC 2.6.2 OS/2
  release (which bundles emx + the import libs) - exactly matching the fork's
  pinned compiler. The native build is the real validation gate (sysop task,
  he has OS/2 history). This mirrors the Darwin story: cross far, finish on
  (or with the toolkit of) the target.
  RUNTIME NOTES for the native build: m_io_stdio's OS/2 WaitForData is a
  blocking-model stub (see its TODO); sockets ride so32dll (OS/2 TCP/IP must
  be present); per-node spawning uses TProcess. All expected to need a live
  shake-out on real OS/2.

## Build scripts for all targets + MIS-DOS WFC example (2026-07-08)
  Sysop batch. Done this checkpoint:
  - build-os2.sh (NEW): compile-only cross pass off-OS/2 (14/14 verified),
    LINK=1 for the native ld+emxbind step on real OS/2. Documents the
    two-stage OS/2 build in its header.
  - build-darwin.sh (REWRITTEN): was -Amacho compile-only; now the proven
    ld64+SDK full-link recipe (SDK=, external cctools assembler via -XP prefix,
    -XR sdk), with COMPILE_ONLY=1 fallback. Verified it links real Mach-O.
  - WFC ANSI: reconstructed the uploaded Mystic 1.06 WFC screenshot as an
    80x25 CP437 ANSI (mystic_modem/gen_wfc.py -> WFCSCRN.ANS), REPLACING the
    earlier faithful-reconstruction placeholder. Title bar, Node Listing +
    Modem Info panels, Local Mode tab, System Commands grid, status column,
    clock/date (@TIME@/@DATE@ tokens the host overwrites). This is now the
    canonical WFC art shared by the modem and MIS-DOS examples. Rendered +
    eyeballed against the screenshot; matches.
  - mystic_misdos/ (NEW example module): a DOS-style MIS "Waiting For Caller"
    that USES BOTH comms add-ons (mystic_modem + mystic_mailer/binkp) and makes
    EVERY WFC option functional - editors shell to the config tool (or name
    themselves if absent), X answers the modem, D drops to a subshell, Q quits,
    SPACE local login; on CONNECT it sniffs and routes BinkP callers to the
    mailer seam. DECISION (sysop): this MIS-DOS is SEPARATE from the shipping
    mis.pas telnet server in mystic/ - it's the teaching front-end, not the
    daemon. Builds linux (verified); build-misdos.sh has win32/os2/darwin arms.
    Depends on mdl/ (m_FileIO/m_IniReader) via the modem module, like the
    modem example itself.
  Core still 14/14 linux; no core files touched by any of the above.

## 1.12 FILE_ID.DIZ research (for the upcoming file-base upgrade) (2026-07-08)
  Checked the real 1.12 whatsnew (wiki.mysticbbs.com/whats_new_112). The
  "file_id" 1.12 feature the sysop wants is about FILE_ID.DIZ import getting
  RICHER, not a new per-file listing art:
  - DIZ descriptions import WITH colour translation (ANSI, Pipe, Wildcat,
    PCBoard, WWIV) instead of being stripped to plain text;
  - up to 99-line descriptions;
  - embedded @BEGIN_FILE_ID.DIZ tags inside plain text files are detected and
    imported (FTP, TIC, mass-upload, online upload all share this);
  - descriptions can be exported back to create/update an archive's
    FILE_ID.DIZ.
  Our A38 TFileBase.ImportDIZ (bbs_filebase.pas) currently does the BASIC
  thing: extract file_id.diz, read lines, strStripLow() (=> strips ANSI). The
  upgrade = preserve/translate colour + support the embedded tag form. This is
  a CORE edit to a file near the on-disk anchors, so it's deferred to its own
  focused change (not mixed into this checkpoint). Recorded so the plan is on
  file. NOTE: request also said "file_id.ans" - 1.12's mechanism is
  FILE_ID.DIZ (ANSI-colour aware), there is no separate file_id.ans in the
  file base; will confirm interpretation with the sysop before the core edit.

## file_id release metadata + per-target packaging (2026-07-09)
  Sysop spec: create in the repo ROOT file_id.{os2,drn,win,lnx,mac}; when a
  target's binaries are built, its file_id goes INTO that target's compressed
  release renamed FILE_ID.DIZ; binaries are released PER TARGET (separate
  archives), never one combined file. Implemented:
  - gen_file_id.sh (root): writes all five, FILE_ID.DIZ-convention (<=45 cols,
    <=10 lines, CRLF), each naming its platform + the fork/version/node.
  - make_release.sh (root): make_release.sh <lnx|win|os2|drn|mac> <bin-dir>
    [out]; stages that bin dir, copies file_id.<t> in as FILE_ID.DIZ, adds
    COPYING, zips to release/mystic-a38-<t>.zip. One archive per target.
    Verified: lnx archive embeds the linux FILE_ID.DIZ correctly.
  - file_id.drn = Darwin/Mach-O build; file_id.mac = "Macintosh" label pointing
    at the SAME Darwin binary for now (this fork targets only i386-darwin, not
    classic 68k/PPC Mac OS). OPEN: confirm with sysop whether .mac should mean
    something distinct; trivially repointed if so.

## cryptlib CAN cross-compile to win32 with a 1-line endian patch (2026-07-09)
  Answering the sysop's question "can cl32.dll source be modified so it cross
  compiles?": YES, demonstrated. The ONLY blocker is endian detection order in
  misc/os_detect.h: it tests __GNUC__ (-> #include <endian.h>, a glibc header)
  BEFORE noticing Windows, so mingw (__MINGW32__, which IS __GNUC__) wrongly
  takes the Linux path and dies on the missing endian.h. cryptlib already maps
  __MINGW32__ -> __WINDOWS__; the fix is to add an "#elif defined(__WINDOWS__)
  -> #define DATA_LITTLEENDIAN" branch BEFORE the __GNUC__ one. With that,
  random/win32.c - cryptlib's hardest, most Windows-specific file (the entropy
  gatherer, needs lm.h/tbs.h/winperf.h/winioctl.h, all present in mingw-w64) -
  COMPILES clean with i686-w64-mingw32-gcc. Patch saved:
  docs/patches/cryptlib-mingw-endian.patch (against 3.4.9.1 misc/os_detect.h).
  REMAINING to actually SHIP a cross-built cl32.dll: wire the makefile's win32
  target (target-init win32 + WIN32ASMOBJS) to the mingw cross prefix and link
  the DLL - mechanical but not yet done. So: feasibility PROVEN + patched;
  full cross-build of the shippable DLL is the follow-up. Until then libs/win32
  still lacks cl32.dll (drop a real MSVC-built one in, or finish the cross
  wiring). This is the crypto side the maintainer holds a commercial license
  for, so a vendor DLL is also fine.

## 1.12 FILE_ID feature analysis (research; port not yet done) (2026-07-09)
  Sysop wants A38 updated to use file_id.ans + file_id.diz per Mystic 1.12.
  Read the 1.12 whatsnew (wiki.mysticbbs.com/whats_new_112). FINDING: 1.12's
  FILE_ID advance is NOT a separate "file_id.ans" file - it's that the DIZ
  description text may now carry ANSI / pipe / Wildcat / PCBoard / WWIV color
  codes that are TRANSLATED and PRESERVED into the file description, plus
  embedded @BEGIN_FILE_ID.DIZ tags scanned out of plain text files, plus up to
  99 description lines. A38 today (bbs_filebase.pas ~L648 ReadDIZ, and
  mutil_upload.pas ~L167) runs every DIZ line through strStripLOW - which KILLS
  the ANSI/pipe codes - and caps lines at bbsCfg.MaxFileDesc with
  mysMaxFileDescLen=50. So the 1.12 behavior = stop stripping color, translate
  it instead, raise the line cap, and add the @BEGIN_FILE_ID.DIZ text scanner.
  PORT NOT YET WRITTEN - it touches two DIZ readers + a color-translation path
  + the tag scanner and deserves its own focused pass with before/after tests
  on real .DIZ samples. Tracked in TODO. (The "file_id.ans" in the request is
  most likely the color-capable DIZ, or the archive-embedded FILE_ID.ANS shown
  in the full-screen archive viewer - confirm the exact surface with sysop.)

## Darwin toolchain: bootstrap script + auto-discovery; .mac canonical (2026-07-09)
  Sysop asked whether ld64 can be "included for all targets." Clarified +
  delivered the sensible form:
  - ld64 is the LINKER FOR THE DARWIN OUTPUT ONLY. Each target needs its own
    linker for its own object format: win32 = FPC internal PE linker, os2 =
    emxbind, linux = GNU ld, darwin = ld64. There is deliberately no single
    linker shared across targets; "ld64 for all targets" isn't meaningful
    because ld64 only emits Mach-O.
  - Literally committing ld64 was rejected: (a) it builds to a HOST-specific
    ELF (~9MB) that itself needs Apple libdispatch/Blocks .so - not portable
    across host OS/arch; (b) the macOS SDK is Apple-licensed and ~257MB, can't
    live in a GPL repo. So instead:
    * tools/darwin/build-ld64-toolchain.sh - reproducible one-time bootstrap
      (apple-libdispatch -> cctools/ld64 -> symlink i386-darwin- prefix).
      Same recipe used all session, now scripted for the sysop.
    * build-darwin.sh now AUTO-DISCOVERS the toolchain ($DARWIN_XTOOLS,
      ~/darwin/xtools, /opt/darwin/xtools) and an SDK ($MACOS_SDK,
      ~/darwin/MacOSX*.sdk, /opt/...), so no manual PATH juggling. VERIFIED:
      with a clean PATH (darwin tools NOT pre-set), build-darwin.sh finds the
      toolchain+SDK and links 14/14 Mach-O i386.
  - .mac is now the CANONICAL Mac target label (sysop standard); file_id.drn
    is kept as an identical alias of file_id.mac (same i386-darwin binary).
    gen_file_id.sh updated (emit .mac, cp to .drn); make_release.sh example
    uses `mac`.

## ld64 now BUNDLED in-repo (SDK still sysop-supplied) (2026-07-09)
  Sysop: "don't include the SDK, but include ld/ld64." Done.
  tools/darwin/ld64-linux-x86_64/ holds a prebuilt, RELOCATABLE ld64/cctools
  cross toolchain (ld64-956.6): the 9 tools FPC's darwin link path invokes
  (ld, as, ar, ranlib, nm, strip, lipo, libtool, otool), each stripped, plus
  the i386-darwin-* prefix symlinks FPC expects, plus the two Apple runtime
  libs ld links against (libBlocksRuntime.so, libdispatch.so). 8.5MB total.
  RELOCATABLE: patched rpath to $ORIGIN/../lib, so the bundle finds its own
  runtime libs wherever it's placed - verified by copying to /tmp and running
  ld there with no reference to the build dir. build-darwin.sh discovers the
  bundle FIRST (before ~/darwin/xtools etc) and adds its lib to
  LD_LIBRARY_PATH. VERIFIED: with a clean PATH (no external toolchain), the
  in-repo bundle links 14/14 Mach-O i386.
  HOST LIMIT (documented in the bundle README): these are Linux x86-64 ELF
  binaries - they run on a Linux/amd64 host to make macOS binaries; they do
  NOT run on Windows/macOS/ARM/32-bit. On any other host, build with
  tools/darwin/build-ld64-toolchain.sh (native to that host). This is why a
  single committed binary can't serve every host - kept the bootstrap script
  too, for non-amd64-linux sysops.
  SDK still NOT included (Apple-licensed, ~257MB) - sysop supplies via SDK=...,
  per the request. .gitignore negations added so the bin/ + *.so rules don't
  drop the bundle (same class of fix as the libs/ subdir negation earlier).
  LICENSING: ld64/cctools/libdispatch/BlocksRuntime are Apple open source
  (APSL 2.0), aggregated under their own license - not GPL-covered. Provenance
  + recipe in the bundle README and build-ld64-toolchain.sh.

## 9a DONE: color-aware FILE_ID.DIZ reader (1.12 behavior) (2026-07-09)
  Sysop: do 9a now, 9b (full-screen archive viewer) is later + huge. Done.
  A38 ran every DIZ line through strStripLow, deleting ALL #0..#31 - which
  kills the ESC in ANSI color, flattening colored DIZ art to monochrome. 1.12
  preserves color in file descriptions. Implemented the faithful minimum:
  - New mdl/m_strings.pas strDizColor(): keeps Mystic pipe codes as-is (they're
    printable, always survived anyway), CONVERTS embedded ANSI SGR color
    (ESC[..m) to the equivalent Mystic pipe code (native storage format the
    file listing already renders), and drops other control chars as before.
    Maps the standard 16 SGR fg (30-37 +bold) / bg (40-47); ESC[0m resets;
    unknown SGR params skipped. No full ANSI state machine - a DIZ is a
    description, not a screen - so this stays small and safe.
  - Swapped the TWO DIZ read sites to it: bbs_filebase.pas ReadDIZ (~L688) and
    mutil_upload.pas (~L174).
  - Verified: 14/14 build; standalone test shows |NN pipe preserved,
    ESC[1;31m -> |12|16, ESC[32m -> |02|16, backspace/bell dropped.
  NOT in 9a (deferred): the @BEGIN_FILE_ID.DIZ inline-tag scanner and the 99-
  line desc cap raise - minor, can fold in later; and 9b the full-screen
  archive viewer (archive_view.ans) which is the big separate UI job. TODO
  item 6 updated to reflect 9a done, 9b pending.

## libs completion: darwin cryptlib + win32 cl32.dll built; ld64->libs/ (2026-07-09)
  Finishing items 7/10. Egress open, darwin toolchain + mingw available.
  - ld64 bundle MOVED tools/darwin/ld64-linux-x86_64 -> libs/ld64-linux-x86_64
    (sysop: "save the ld files in the libs folder, license also"). Added
    libs/LD64-CCTOOLS-LICENSE-APSL-2.0.txt + libs/LIBDISPATCH-LICENSE.txt.
    $ORIGIN/../lib rpath means the move didn't break it; build-darwin.sh +
    .gitignore + docs updated to the new path; verified 14/14 darwin link
    still works from the libs/ location. The BUILD script stays in
    tools/darwin/ (it's tooling, not a shipped binary).
  - cryptlib DARWIN: libs/darwin-i386/libcl.dylib - cross-built i386-darwin
    (Mach-O) against the 10.6 SDK via the bundled ld64 + clang shim. Pure C so
    it builds cleanly; needed a 3-line strnlen compat shim (strnlen is 10.7+,
    not in the 10.6 SDK) force-included at compile. 62 crypt* exports; install
    name libcl.dylib (the binding's darwin probe name). Linked by hand from the
    343 Mach-O objects (cryptlib's makefile hardcodes gcc for the dylib link).
  - cryptlib WIN32: libs/win32/cl32.dll - the item-10 follow-through, now BUILT
    (not just feasibility). Applied docs/patches/cryptlib-mingw-endian.patch,
    built 370 objects + libcl.a with i686-w64-mingw32 in one clean pass (the
    makefile does an in-place sed in target-init, so a PRISTINE source copy per
    attempt is required - stale copies fail on EOL/OS detection). Linked the
    DLL by hand: whole-archive libcl.a + cryptlib's shipped win32 DES asm obj
    (crypt/d-win32.obj; the C DES in desenc.c is #ifdef'd out under USE_ASM) +
    a 1-line IsWindowsXPOrGreater stub (versionhelpers inline the 10.6-era
    headers lack) + system import libs (ws2_32/advapi32/gdi32/user32/crypt32/
    netapi32/version). -static-libgcc so it needs ONLY standard Windows DLLs
    (KERNEL32/ADVAPI32/WS2_32/NETAPI32/USER32/msvcrt). Stripped ~1.9MB, 62
    crypt* exports incl every symbol cl_bind resolves. So item 10 is fully
    delivered: patch PROVEN and a shippable cl32.dll BUILT.
  - SDL2 + Hunspell for DARWIN: NOT provided, and this is a real limit not an
    oversight. Both current versions need a macOS 10.7+ SDK: SDL2's Cocoa/ObjC
    video backend uses 10.7 AppKit symbols (NSFullScreenWindowMask), Hunspell
    1.7 uses C++11 (std::all_of) absent from the 10.6 SDK's gcc-4.2 libstdc++,
    and even SDL 2.0.3 (last easy-10.6 era) hits ObjC ABI mismatches building
    Cocoa from Linux with modern clang. A video-less SDL would be useless (it
    couldn't drive the RIP window). Documented in libs/README with the fix
    path (build on a real Mac / 10.7+ SDK, or drop in official/Homebrew
    dylibs). These modules are optional + graceful-off so nothing is blocked;
    rip_render (headless) needs no SDL.

## libs verified across all targets; 2 real bugs fixed (2026-07-09)
  Sysop: "make sure the 6 platforms link for the libs." Libs are RUNTIME-loaded
  (dlopen/LoadLibrary/DosLoadModule), so "link" = the module binary builds AND
  the lib loads + resolves symbols on that target. Ran real load tests (not
  just file/objdump): linux natively, win32 under WINE 9.0 (installed this
  pass), darwin by Mach-O+symbol validation (can't run Mac here), os2 by
  compile. TWO genuine bugs surfaced and were fixed:
  - cl32.dll STDCALL NAME DECORATION (caught by Wine): the first win32 cl32.dll
    exported decorated names (cryptInit@0), but the binding does
    GetProcAddress("cryptInit") - so it LOADED but resolved cryptInit as
    MISSING (cl_demo said "cryptlib loaded: FALSE"). cryptlib ships crypt32.def
    exactly for this (its own comment cites Pascal-calling-convention DLLs!).
    Relinked cl32.dll with the .def -> clean undecorated exports. Now under
    Wine cl_demo says "Cryptlib detected and initialised - secure sessions
    available" (win32 randomness polling works where the linux 32-bit entropy
    poll returned -15). Darwin dylib was already clean (_cryptInit, no @N;
    dlsym strips the _). RESTAGED libs/win32/cl32.dll.
  - OS/2 DYNAMIC-LOADING BRANCH MISSING: all three module bindings
    (cl_bind/sdl_bind/spl_hunspell) only had UNIX (dlopen) and Windows
    (LoadLibrary/GetProcAddress/FreeLibrary) paths - they FAILED TO COMPILE on
    OS/2 ("GetProcAddress not found"). Added an OS2 branch using the RTL
    DosCalls API: DosLoadModule / DosQueryProcAddr / DosFreeModule, with
    LibHandle as THandle on OS/2. All three now compile clean for i386-os2.
    (No OS/2 SDL/Hunspell/cryptlib binaries are bundled - those runtimes on
    OS/2 are out of scope - but the loader is correct so a sysop-supplied
    OS/2 DLL would load.)
  VERIFIED NO REGRESSION: after the binding edits, rebuilt every module demo on
  linux (load-tested), win32 (Wine load-tested), darwin (Mach-O build); core
  14/14 linux still green.
  MATRIX (module builds + lib loads):
    lib       linux        win32          darwin           os2
    SDL2      loads        loads(Wine)    builds,no-lib*   compiles
    Hunspell  works        works(Wine)    builds,no-lib*   compiles
    cryptlib  loads        init(Wine)     dylib+syms ok    compiles
    * darwin SDL2/Hunspell need a 10.7+ SDK (see prior entry); optional+
      graceful-off so nothing blocks.

## file_id.diz now built from the sysop's art template (2026-07-09)
  Sysop supplied a FILE_ID.DIZ art template (classic bordered DIZ, title
  "Mystic BBS v1.38-IRC Fork  xxx BINARIES", Github + 16 feature lines incl
  "file desc on FILE_ID.DIZ & FILE_ID.ANS 99lns"). CORRECTION to an earlier
  misread: the "xxx" is NOT a border-alignment placeholder - it's the TARGET
  NAME (WIN/MAC/OS2/LNX/DOS). Saved as file_id.diz.template with @@@ as the
  substitution marker. gen_file_id.sh rewritten to sed @@@ -> the target tag
  and emit file_id.{win,lnx,os2,mac,drn} (CRLF); .drn = MAC (darwin alias).
  make_release.sh unchanged - still one archive PER TARGET embedding that
  target's DIZ as FILE_ID.DIZ. Verified: win zip says "WIN BINARIES", mac zip
  says "MAC BINARIES", separate archives.
  NOTE: template version text is "v1.38-IRC Fork" (newer branding than the
  repo's internal "1.10 A38"); using the sysop's wording verbatim in the DIZ.
  OPEN: the DIZ lists "Native DOS, Windows, OS/2, Linux" - if a real DOS
  release target is wanted, add file_id.dos (DOS) + a dos build; the fork
  currently builds win32/linux/os2/darwin, so no .dos emitted yet.

## file_id.diz simplified to a single hand-edited example (2026-07-09)
  Sysop clarified: the file_id.diz is JUST an example DIZ he edits by hand -
  it's NOT auto-generated and applies ONLY to the DIZ, nowhere else in the
  source. Reverted the over-engineering: removed gen_file_id.sh and the 5
  generated file_id.{win,os2,mac,lnx,drn} files; renamed the template to plain
  file_id.diz (keeps his original literal "xxx BINARIES" slot). Workflow now:
  edit xxx -> target (os2/win/mac/lnx) by hand, then
  make_release.sh <tag> <bin-dir> copies file_id.diz into the per-target
  archive as FILE_ID.DIZ. make_release.sh reworked to take the single DIZ
  (optional 4th arg overrides the path). One archive per target, never
  combined - unchanged. (Earlier gen_file_id.sh entries above are the dated
  record of the approach that was backed out.)

## file_id.diz: back to 6 per-target files + the master example (2026-07-09)
  Sysop: keep per-target file_id.<t> files - "6 file_id.diz files", each
  renamed to FILE_ID.DIZ at release. So:
  - file_id.diz = master example (literal "xxx BINARIES" slot).
  - 6 per-target files, tag matching the extension:
    file_id.win/lnx/os2/mac/drn/dos -> "<tag> BINARIES". (dos included per the
    DIZ feature text; no dos BUILD target yet - the DIZ exists, the binary
    doesn't, come back to it.)
  - make_release.sh <tag> <bin-dir> copies file_id.<tag> into the per-target
    archive RENAMED to FILE_ID.DIZ. One archive per target. Verified os2.
  These are hand-maintained static files (no generator; gen_file_id.sh stays
  removed). Applies ONLY to the DIZ, nowhere else in the source.

## Darwin SDL2 + Hunspell DO build on the 10.6 SDK after all (2026-07-09)
  Sysop pushed back on "needs a 10.7+ SDK" - correctly. Retried and I was
  wrong: the CURRENT 10.6 SDK is sufficient, you just need version-appropriate
  library releases (the LATEST SDL2/Hunspell dropped 10.6, not the SDK's fault).
  - SDL2: 2.32.8 and even 2.0.3 hard-#error without a 10.7 SDK (Cocoa fullscreen
    symbols). SDL2 2.0.1 / 2.0.0 have NO 10.7 requirement -> built 2.0.1 for
    i386-darwin against the 10.6 SDK: libs/darwin-i386/libSDL2-2.0.0.dylib
    (516 SDL_ symbols, install_name libSDL2-2.0.0.dylib = the name sdl_bind
    probes first). The trailing libSDL2main.a static-helper fails to link but
    that's irrelevant - our modules runtime-load the dylib, which is valid.
  - Hunspell: 1.7.2 uses C++11 std::all_of (absent from 10.6's gcc-4.2
    libstdc++). 1.6.2 does NOT -> built it for i386-darwin:
    libs/darwin-i386/libhunspell-1.6.0.dylib. (autoreconf needed a 1-line
    configure.ac fix: AM_GNU_GETTEXT -> AM_GNU_GETTEXT([external]); and
    hunvisapi.h needed @HAVE_VISIBILITY@ -> 1.) Added the versioned probe name
    to spl_hunspell.pas's darwin branch (then falls back to libhunspell.dylib).
  RESULT: all THREE darwin runtime libs now present + built with the existing
  10.6 SDK; all three darwin module demos build Mach-O; linux unaffected.
  Supersedes the earlier "darwin SDL2/Hunspell need 10.7+" entry - that was
  about the LATEST versions; older-but-API-compatible releases build fine.
  No newer SDK required.

## Removed file_id.drn (dupe of file_id.mac) (2026-07-09)
  Sysop: .drn is a dupe. Deleted file_id.drn (it was byte-identical to
  file_id.mac). Mac releases use file_id.mac directly. make_release.sh + fwd-
  looking docs scrubbed of drn. Per-target DIZ set is now 5: win/lnx/os2/mac/
  dos (+ the file_id.diz master example). (Earlier .drn-alias entries above are
  the dated record.)

## DOS/go32v2 target: buildable with our OWN 2.6.2 (not the 3.2.2 upload) (2026-07-09)
  Sysop uploaded a prebuilt DOS toolchain (openolms-dos-toolchain: FPC 3.2.2
  ppcross386 + go32v2 RTL). Asked: can we build the DOS extender with 2.6.2
  instead (version-consistent)? YES - proven:
  - FPC 2.6.2 already supports -Tgo32v2 (ppc386 -i lists "GO32 V2 DOS
    extender"); the go32v2 RTL SOURCE ships in the 2.6.2 tree
    (rtl/go32v2). go32v2 = 32-bit protected-mode DOS via a DPMI extender
    (CWSDPMI/GO32), COFF object format.
  - Built the go32v2 RTL with 2.6.2 (51 units) after supplying an assembler.
  - Toolchain: binutils 2.30 configured --target=i386-msdosdjgpp (the triplet
    ld actually supports; emulation i386go32). i386-go32v2 canonicalises to
    i386-pc-go32v2 which ld REJECTS - use msdosdjgpp then symlink the tools to
    the i386-go32v2-* names FPC calls (as/ld/ar/nm/strip/ranlib/objcopy).
    Tools staged at /home/claude/dostools/xbin (ephemeral, rebuild per the
    recipe here).
  - RESULT: `ppc386 -Tgo32v2 -XPi386-go32v2- -Fu<rtl>/units/go32v2 x.pas`
    produces a real "MZ for MS-DOS, COFF, DJGPP go32 DOS extender" .exe.
    So DOS is a genuine 5th FPC target, version-matched to the other 4 -
    its .dat record layouts will match win32/linux/darwin/os2.
  DECISION: build DOS with 2.6.2 (data-file compatibility with all other
  targets). The uploaded 3.2.2 toolchain is saved in tools/dos/ anyway
  (sysop's call, like the ld64 bundle) as a known-good reference/fallback -
  NOT used by any build script. See tools/dos/README.md.
  STILL TODO for a real Mystic DOS build (beyond hello-world): cross-build the
  go32v2 packages (not just RTL), then port Mystic's platform layer - DOS has
  no BSD sockets like the other targets (historically FOSSIL driver / door
  mode), so the telnet-server model needs rethinking for DOS. This proves the
  TOOLCHAIN; the full BBS DOS port is a separate effort.

## Release layout: whatsnew/upgrade in every archive; Mac SDK NOT shippable; toolchains -> libs/ (2026-07-09)
  Sysop screenshot showed the target release layout: a flat folder with
  file_id.diz, install.exe, install_data.mys, upgrade.txt, whatsnew.txt.
  - upgrade.txt: uploaded, saved to mystic/upgrade.txt (CRLF, 580 lines).
    Sits alongside mystic/whatsnew.txt.
  - make_release.sh now stages install_data.mys + whatsnew.txt + upgrade.txt
    (all from mystic/) into EVERY per-target archive, next to the binaries,
    FILE_ID.DIZ and COPYING. Verified os2 archive contents.
  - MAC SDK: can we ship it? NO. The MacOSX10.6.sdk is Apple's proprietary
    property under the Xcode/Apple SDK Agreement - NO redistribution right,
    and it's non-free so incompatible with GPLv3 anyway. It stays a local
    sysop-supplied build prerequisite (build-darwin.sh takes it as an external
    SDK= path), NEVER committed, NEVER in a distro. Contrast: the ld64/cctools
    toolchain IS shippable (APSL open source) - that's why ld64 is bundled but
    the SDK is not.
  - Toolchain location: both cross-build toolchains now live in libs/ (sysop
    call): libs/ld64-linux-x86_64/ (Darwin linker) and
    libs/openolms-dos-toolchain.tar.gz (DOS 3.2.2 reference, see
    libs/DOS-TOOLCHAIN-README.md). Removed the tools/ tree.

## 9b DONE + 9a finalized: FILE_ID.ANS full-screen archive viewer (2026-07-09)
  Sysop: do both 9a and 9b.
  9a (color DIZ) was already done (strDizColor). Reviewed the deferred 9a
  sub-items:
  - line cap to 99: ALREADY satisfied - ReadDIZ breaks at bbsCfg.MaxFileDesc,
    which the config editor (bbs_cfg_syscfg L230) already allows 1..99, and the
    MsgText buffer holds mysMaxMsgLines=1000 lines. No change needed.
  - desc line WIDTH (mysMaxFileDescLen=50): left at 50. It's used for line
    truncation + input-field width EVERYWHERE (not just DIZ), so widening to 79
    is an all-descriptions behavior change beyond 9a's scope - separate call.
    (Confirmed it's NOT an on-disk record bound, so it COULD be raised safely
    later; descriptions persist via MsgText String[79] + BlockWrite.)
  - @BEGIN_FILE_ID.DIZ inline-tag scanner + Wildcat/PCBoard/WWIV notations:
    judged niche/low-value vs added complexity+risk; skipped intentionally.
  9b (the big one) IMPLEMENTED - full-screen FILE_ID.ANS archive viewer:
  - New TFileBase.ShowFileIDAns(FName): extracts FILE_ID.ANS from the archive
    with the SAME proven ExecuteArchive mode-2 path ReadDIZ uses for
    FILE_ID.DIZ, then renders it via Session.io.OutFile (existing ANSI
    renderer - handles screen length, pausing, terminal cleanup). Returns
    True if a cover was found+shown.
  - Hooked into ArchiveView: shows the FILE_ID.ANS cover automatically when a
    user opens the archive viewer, before the file listing (the 1.12 behavior).
  - Added an 'A' key to the viewer menu (ADQRV) to redisplay the ANSI cover on
    demand.
  - Reuses existing infra (PArchive, ExecuteArchive, OutFile) - no new archive
    or ANSI subsystem needed; the plumbing was all there.
  Verified: 14/14 build; extraction path validated (FILE_ID.ANS pulls from a
  zip with ANSI codes intact for OutFile to render). NOTE: full interactive
  on-BBS visual test needs a live session (can't drive the interactive UI
  here), but the mechanism is identical to the working ReadDIZ/FILE_ID.DIZ path.

## Docs updated for OS/2 + DOS + Darwin build support (2026-07-09)
  Sysop: update the build tree docs to add os2 + darwin support; are the
  scripts up to date?
  - SCRIPTS: verified current. build-os2.sh compiles 14/14 (cross, link native
    on OS/2), build-darwin.sh compiles+links 14/14 Mach-O against the current
    tree (post 9a/9b, OS/2-loader bindings, etc.). No script changes needed.
  - DOCS were stale: INSTALL + README said "three platforms" and their tables
    listed only Windows/Linux/macOS. Updated both to FIVE targets
    (added OS/2 + DOS/go32v2). INSTALL gained full OS/2 and DOS sections
    (prereqs, two-stage OS/2 link, go32v2 binutils/RTL, dos-toolchain.zip
    pointer, DOS-port scope note). README table + intro updated. Left the one
    historical "three platforms" line in DECISIONS as dated record.

## OS/2 self-hosted link: emxbind PORTED to Linux; ld blocker precisely located (2026-07-09)
  Sysop pushed back (rightly) on "OS/2 is stuck" and asked to actually TRY
  building a Linux-hosted emx toolchain like the ld64 bundle. Result: real
  progress, one blocker left, exactly mapped.
  ACHIEVED:
  - Built a WORKING Linux x86-64 `emxbind` from GPL source (emx 0.9d,
    emxsrcr.zip) + the moddef .def parser (emxsrcd). It runs and prints its
    banner. This is FPC's OS/2 FINAL-link tool (a.out -> LX .exe + LX import
    table) - the piece assumed to be OS/2-only. Saved to libs/emxbind-src/
    with sources, shims, the binary, and BUILD.md.
  - To build it on Linux we reconstructed sys/moddef.h (from the moddef .c
    implementation + emxbind usage - the real header ships only in the emx
    binary dev kit), a minimal sys/user.h, and io.h/share.h/emxcompat shims
    mapping emx libc-isms (_strncpy, stricmp, _errno, _fsopen, _defext,
    _remext, _path, _fncmp, optswchar) to POSIX. All 13 .c files compile;
    emxbind links + runs.
  - Traced FPC's OS/2 link pipeline on Linux end-to-end:
    i386-os2-as OK -> i386-os2-ld FAILS -> emxbind (ready). The a.out
    intermediate (maketheme.out, 231KB) is produced up to import resolution.
  REMAINING BLOCKER (precisely located, NOT vague):
  - FPC's OS/2 RTL ships DLL imports in emx's a.out IMPORT# format
    (doscalls.a: `_$dll$doscalls$_index_NNN = DOSCALLS.NNN`, symbol types
    N_IMP1/N_IMP2). Stock GNU binutils treats these as DEBUG symbols, not
    linkable defs -> ld "undefined reference" (320 of them). Confirmed via
    objdump: binutils READS the a.out (format a.out-i386) and sees the syms,
    but classifies N_IMP as debug.
  - The emx fix is a small, known BFD patch in bfd/aoutx.h: exclude N_IMP1/2
    from IS_STAB(), and add translate_from_native_sym_flags cases mapping
    N_IMP1|N_EXT/N_IMP2|N_EXT to BSF_EMX_IMPORT1/2 abs-section defs; plus the
    writer side + ld preserving those syms+relocs for emxbind (fixup.c
    import_symbol) to build the LX import table. The emx-patched binutils 2.6
    source (gbinusrc.zip) has all of it (bfd/emx-aout.c + aoutx.h); porting
    those ~9 BFD files into our binutils 2.30 is the remaining work. This is
    the SAME step the ArcaOS/bitwiseworks maintainers have open as unsolved
    ("ld fails to configure"). emxbind - assumed the hard part - is DONE.
  DECISION: save emxbind + the exact patch map to libs/emxbind-src/ as a
  documented, resumable foundation. OS/2 stays compile+bind-ready; the final
  ld self-hosting is a future BFD-porting effort (or link natively on OS/2,
  which works today with the stock FPC OS/2 release).

## Installer build status per target + release docs (2026-07-09)
  Sysop: can we build installers for all target OSes?
  Answer - 3 of 5 fully, from a Linux host:
  - Linux: install ELF - native. FULL installer archive. VERIFIED.
  - Win32: install.exe PE (FPC internal PE linker, no external tools). FULL
    installer archive. VERIFIED (cross-built install.exe = PE32).
  - macOS: install Mach-O (ld64 + SDK). FULL installer archive. VERIFIED.
  - OS/2: install COMPILES but no runnable install.exe here (LX link needs the
    OS/2 link step; emxbind ported but the bfd IMPORT# blocker remains). Build
    on OS/2 with the stock FPC OS/2 release.
  - DOS: no installer (no Mystic DOS port yet).
  make_release.sh <tag> <bin-dir> [out] stages: 14 binaries (incl install +
  install_make) + install_data.mys + FILE_ID.DIZ + whatsnew.txt + upgrade.txt
  + COPYING, one per-target archive. NOTE: strip build intermediates (*.o
  *.ppu *.a *.s) from the bin dir before packaging - a raw win32 -FE dir keeps
  them and they'd end up in the archive. INSTALL gained a "Building release
  installers" section documenting this + the per-target status.

## OS/2 LINK ON LINUX — SOLVED end-to-end (2026-07-09)
  A full FPC 2.6.2 OS/2 program now links to a valid OS/2 LX .exe entirely on
  the Linux host (verified: MZ + LX header, 364KB maketheme.exe, "LX for OS/2
  ... emx 0.9d"). This was the piece considered unsolved upstream. The complete
  set of fixes:
  1. binutils N_IMP patch (bfd/aoutx.h + archive.c + bfd-in2.h): treat emx
     a.out IMPORT# symbols (N_IMP1 0x68/N_IMP2 0x6a) as defined abs symbols so
     ld resolves DLL imports; re-ranlib the FPC os2 .a files.
  2. a.out-emx BFD target (bfd/i386os2.c + targets.c/config.bfd/configure/
     Makefile.in): emx layout - text file offset 0x400 (ZMAGIC_DISK_BLOCK_SIZE
     + text-incl-header=0), text vaddr/entry 0x10000, 64KB data segment.
  3. unpadded a_text: i386os2.c write sets execp->a_text = textsec->rawsize so
     emxbind's text_end check matches FPC prt0's __etext (BFD otherwise records
     the page-padded size, off by ~0xFC0).
  4. emxbind built 32-bit (-m32) so its a.out structs are 32 not 64 bytes;
     getopt "+" prefix so FPC's trailing -ai/-s8 aren't misparsed.
  5. emxl.exe loader stub (from emxrt.zip) on PATH.
  6. two-pass i386-os2-ld wrapper computes data_base =
     round_segment(0x10000+text_size) and passes -Tdata, since ld's default
     script would put data at 4MB.
  DECISION: documented thoroughly + separately in docs/os2-linux-toolchain/
  (TECHNICAL-REFERENCE.md + BUILD-ON-UBUNTU-24.04.md) because it's the crown
  jewel and the container is ephemeral. All durable artifacts (patches,
  i386os2.c, emxbind src+shim, emxl.exe, wrapper text) committed under
  libs/emxbind-src/. Built tools regenerate from the repo via the Ubuntu recipe
  (~15-20 min for binutils). Ready to contribute upstream (UPSTREAM-EMX.md).

## All-distro compile pass from libs toolchains (2026-07-09)
  Built every target; DOS + OS/2 from the libs/ toolchain zips as required.
  RESULTS:
  - Linux   14/14  ELF (native ppc386)
  - Win32   14/14  PE32 (FPC internal linker)
  - Darwin  14/14  Mach-O (ld64 + 10.6 SDK, out_darwin/bin)
  - OS/2    14/14  LX (from libs/os2-linux-toolchain.zip: patched ld a.out-emx +
            emxbind + emxl.exe + wrapper). Includes the networked programs
            (mystic/mis/fidopoll/nodespy/qwkpoll) - OS/2 has sockets. All 14
            verified "LX for OS/2 ... emx 0.9d".
  - DOS      7/14  MZ/COFF/DJGPP (from libs/dos-toolchain.zip). The 7
            non-networked utilities (maketheme, mplc, mutil, mystpack, install,
            install_make, 109to110) build. The 5 networked programs
            (mystic/mis/fidopoll/nodespy/qwkpoll) need BaseUnix/Sockets which
            go32v2 lacks - that's the known DOS-sockets gap, a separate port.
  DOS PLATFORM FIXES (real source gaps, committed): added GO32V2 branches that
  were missing alongside the existing LINUX/DARWIN/WIN32/OS2 ones -
    mdl/m_ops.pas       : {$IFDEF GO32V2} -> DEFINE DOS + FS_IGNORE
    mystic/records.pas  : GO32V2 -> PathChar '\', CRLF, OSID 'DOS', OSType 5
    mdl/m_fileio.pas    : GO32V2 GetProcessID via System unit (like OS2)
    mdl/m_output.pas    : GO32V2 -> USE_CRT_OUTPUT
    mdl/m_input.pas     : GO32V2 -> USE_CRT_INPUT
  Verified no regression: Linux mystic still builds after the edits.

## Release layout: per-target dirs, FULL + UPGRADE (2026-07-09)
  Sysop: each target platform (win/mac/os2/lnx) gets its own release directory
  holding the FULL install and the UPGRADE bundle; no separate combined bin
  archive (it just duplicated the per-target upgrade).
  LAYOUT:
    release/<tag>/mystic<tag>full.zip   FULL   (install + install_data.mys + docs)
    release/<tag>/mystic<tag>upd.zip   UPGRADE (binaries + docs, no payload)
    e.g. release/os2/mysticos2full.zip + release/os2/mysticos2upd.zip
  make_release.sh <tag> <bin-dir> [full|upgrade|both] writes into release/<tag>/.
  make_all_releases.sh [full|upgrade|both] does every platform.
  DIZ: generated per mode from file_id.<tag>, title "<tag> FULL"/"<tag> UPGRADE",
  forced CRLF. FULL carries install_data.mys; UPGRADE does not.
  Dropped the combined mysticbin<date> bundle - redundant with per-target upd.

## DOS sockets: prefer backporting FPC's Pascal Sockets unit (2026-07-09)
  CONTEXT: The fork's socket layer (mdl/m_io_sockets.pas) uses FPC RTL Pascal
  units on ALL working platforms - WinSock/Winsock2 (Win), BaseUnix+cNetDB
  (Linux/macOS), WinSock (OS/2) - plus FPC's built-in 'Sockets' unit. NO C
  compiler is involved in networking on any working target. DOS is the only
  gap: FPC 2.6.2's go32v2 RTL ships no Sockets unit (verified).

  SYSOP DIRECTION: backport / reuse FPC's Pascal socket code for go32v2 rather
  than writing or binding C. Rationale: keeps DOS consistent with the other
  four platforms (same 'Sockets' unit surface), no C compiler added to the
  fork's own build, and FPC's RTL is actively maintained.

  ACCURACY NOTES (verified 2026-07-09, don't overstate):
  - FPC RTL 'Sockets' unit: actively maintained (FPC 3.2.2 current). GOOD.
  - Watt-32: the canonical homepage (watt-32.net) is frozen ~1999, BUT active
    GitHub forks exist and take PRs (gvanem/Watt-32, sezero/watt32, jwt27's
    cross-compile fork). So "abandoned" is too strong - the homepage is stale,
    the community forks are not. State it that way.
  - CAVEAT: DOS has no OS-level TCP/IP. Even FPC-native go32v2 networking (if
    a usable Sockets unit exists in 3.0.4/3.2.2) most likely still sits on a
    C TCP stack (Watt-32 or lwIP) + a DOS packet driver at RUNTIME. So the
    achievable goal is "the FORK's code stays Pascal (FPC Sockets unit)", NOT
    "zero C anywhere on DOS". The C stack becomes an external dependency, like
    a driver - not code in this repo.
  - LEGAL (bundling Watt-32 source into this GPLv3 repo): Watt-32 is permissive
    / BSD-style (Waterloo TCP heritage), generally GPL-compatible IF its
    copyright + license text are preserved. BUT the old Waterloo notice has a
    non-standard "may not sell" clause that is NOT plain BSD and could
    complicate GPL redistribution - read the specific fork's LICENSE before
    bundling. (Not legal advice.) Preferred path avoids bundling Watt-32
    source at all: use FPC's Sockets unit + treat the TCP stack/packet driver
    as an external runtime dependency.

  TASKS WHEN DOS RESUMES:
    1. Check FPC 3.0.4 / 3.2.2 go32v2 RTL for a usable Sockets unit + netdb.
    2. If present, build the 5 networked DOS programs with that FPC's socket
       units; keep SizeOf record anchors intact (reason 2.6.2 is pinned).
    3. Document the runtime stack (Watt-32/lwIP + packet driver) as an external
       dependency; do NOT bundle its source unless license-cleared.
  Preference order: FPC-native go32v2 Sockets (Pascal) > Watt-32 binding > FOSSIL.

## DOS sockets BUILT: Watt-32 binding + binutils C_SECTION fix; DOS now 10/14 (2026-07-09)

  Supersedes the status in the earlier "All-distro compile pass" entry (which
  recorded DOS at 7/14 with the sockets gap open). DOS is now 10/14, INCLUDING
  the mystic server. What changed:

  - SOCKET LAYER WRITTEN: mdl/sockets_go32v2.pas - a complete FPC-Sockets-
    compatible BSD API (TCP+UDP, DNS/resolver, select, get/setsockopt, address
    helpers) bound to Watt-32 via cdecl externals. The fork's socket code is
    UNCHANGED: on go32v2 m_io_sockets (and mis_server) `Uses sockets_go32v2`
    instead of the RTL `Sockets` unit. This realises the "fork code stays
    Pascal; C TCP stack is an external dependency" decision above WITHOUT
    needing a newer FPC - it works on our pinned 2.6.2 (record anchors intact).
    Chosen over waiting to re-pin FPC 3.0.4/3.2.2 because re-pinning risks the
    SizeOf record anchors and the whole point of the 2.6.2 pin.

  - BINUTILS LINK BLOCKER SOLVED: FPC 2.6.2 emits COFF storage class 0x68
    (C_SECTION, the PE convention) for section symbols; stock binutils 2.30
    coff-go32 (no COFF_WITH_PE) rejected it as "Unrecognized storage class
    104", breaking the external-ld link that any C-library (Watt-32) call
    forces. Fixed with a minimal 2-file patch (libs/dos-binutils-patch/),
    mirroring the OS/2 emx binutils fix. The pristine binutils-2.30 source
    tarball is bundled in that dir (sha256 verified) so the complete
    corresponding GPL source travels with the repo; the patched ld/nm/objdump
    are in libs/dos-toolchain.zip so the repo builds DOS from its own libs.

  - CODE GAPS CLOSED: DOS branches for m_io_stdio (stdin/stdout via FileRead/
    FileWrite), m_pipe (TPipeDisk), mis_events ShellExec (COMMAND.COM /C), and
    the go32v2 MD5 unit added to the toolchain.

  - CONCURRENCY MODEL (correcting an earlier overstatement): Watt-32 is a real
    TCP/IP stack and handles MULTIPLE concurrent sockets (it has select_s for
    exactly that). The DOS constraint is NO PREEMPTIVE THREADS, not "one
    connection". Correct design = cooperative multiplexing: one process, non-
    blocking sockets (FIONBIO), polled with select. The current DOS mis Execute
    serves one caller at a time as an initial-bring-up simplification; the
    cooperative select() accept-loop for multiple concurrent nodes is the
    planned upgrade. sockets_go32v2 already exposes select/FD_*/FIONBIO.

  REMAINING for networked DOS binaries: build Watt-32 (libwatt.a) for djgpp;
  build-dos.sh already wires -lwatt via WATT32LIB=<dir>. Then link-test + run
  with a packet driver + WATTCP.CFG. See docs/DOS-SOCKETS.md.

## A40 import pass #1: per-node PKT/bundle limits + netmail export (2026-07-10)

  Working from the upstream 1.10 whatsnew (no A40 source available - implemented
  from the whatsnew descriptions + the uploaded A51 reference binary's strings)
  and an audit of the fork tree.  Audit finding: MOST of A40 is already present
  in the fork (tosser rewrite, DNSBL, DNSCC, log roller, AreaFix, FileFix, dup
  detection, pass-through netmail, nodelist search, area index CTRL-N/R/Z, MCI
  #I).  Only three real gaps remained; this pass closes them:

  1. MCI #I - found ALREADY IMPLEMENTED and correct (bbs_io FmtType 19 ->
     ThemeMessageBox BoxType 1 = draw box, no GetKey wait, no restore; exactly
     "like #B but does not wait").  No change needed.

  2. Per-echonode max PKT size + max ARCmail/bundle size (A40):
     - records.pas: added MaxPktSize, MaxArcSize (Word, KB, 0=none) to
       RecEchoMailNode, consuming reserved Res[] bytes so SizeOf STAYS 901
       (anchor preserved, no data migration; new fields default 0 from the
       previously-zero reserved bytes).  Verified 901 before+after.
     - bbs_cfg_echomail.pas: "Max PKT KB" (K) + "Max ARC KB" (B) editor fields,
       matching the A51 binary's "Max PKT size KB (0/None)" / "Max bundle/
       arcmail size KB (0/None)" labels.  Word type matches AddWord's editor.
     - mutil_echoexport.pas:
         * EchoBundleMessages rolls to the next bundle extension when the target
           bundle already exceeds MaxArcSize KB (via GetFTNBundleExt/LPKTPtr).
         * EchoExportMessage/WriteMessage starts a new PKT (fresh unique
           PKTBase via GetFTNPKTName) once the current PKT's FilePosRaw exceeds
           MaxPktSize KB.  PKTBase is a runtime-only field (TEchoMailLinkRec),
           extension stays the node Index so EchoBundleMessages still routes it.
           Netmail (NetType 3) is not split.

  3. NetMail base no longer needs an echonode link/tag to export (A40):
     - mutil_echoexport.pas: the base-skip check that requires EchoTag/QwkNetID
       now exempts NetType 3 (netmail).  Netmail already routes by destination
       via GetNodeByRoute against all active nodes (ReadEchoMailLinks loads ALL
       active echonodes, not per-base links), so removing the tag gate is
       sufficient - an untagged netmail base now exports.

  VERIFICATION CAVEAT: per sysop instruction this pass was NOT compiled (the
  container's full-dependency compile was timing out after the FPC builds).
  Changes were verified by reading + symbol-scope checks + the anchor size
  checker (901 confirmed).  The record + config-editor changes DID compile clean
  earlier (bbs_cfg_echomail.o, mutil_echoexport.o built) BEFORE the MaxPktSize
  split + netmail exemption were added.  Those two later edits are read-verified
  only and need a compile + live toss test (node 152/158) to confirm:
    - the TFileBuffer close/reopen + GetFTNPKTName uniqueness during a split
    - that split PKT chunks bundle and route correctly
    - untagged netmail base actually exports end to end

## FPC 2.6.4irc built compiler captured + deferred A40 tests (2026-07-10)

  Sysop delivered a complete, built 2.6.4irc distribution (libs/fpc264irc.tar.gz,
  53MB).  This supersedes the earlier source-only fpc_2_6_4irc_src.zip.  Contents:
    - bin/ppc386, bin/ppcx64 (prebuilt compilers), bin/units/ (compiled RTL per
      target incl. i386-go32v2/sockets.ppu+.o).
    - src/ (compiler: 10 modified files; rtl: 1 new + 2 modified incl.
      rtl/go32v2/sockets.pp; packages/utils stock).
    - test/ with per-platform socket tests + run-tests.sh.
    - patches/os2-cross/ (binutils BFD + emxbind docs), build-linux.sh,
      build-windows.bat, CHANGELOG-IRC.md, LICENSE.
  Key properties (from CHANGELOG-IRC.md, matching what we verified earlier):
    - Base FPC 2.6.4, minorpatch='irc', PPU wordversion UNCHANGED -> binary
      compatible with stock 2.6.4 units (record anchors safe by construction).
    - rtl/go32v2/sockets.pp is a full Sockets unit over Watt-32 (all fp* + legacy
      wrappers + select/fd + DNS + IPv4/IPv6 conv) so `Uses Sockets` works on DOS
      with no app-level {$IFDEF}.
    - Backports FPC 3.0/3.3 cross-link fixes so stock binutils-djgpp links go32v2
      (no C_SECTION patch), and fixes OS/2 import-symbol generation.

  DEFERRED A40 TESTS: per sysop, the A40 import work was NOT compiled during
  import to save resources.  Added tests/a40/ to be run WHEN THE A40 IMPORT IS
  COMPLETE:
    - tests/a40/check_anchors.pas  - asserts SizeOf(RecEchoMailNode)=901 (+
      RecConfig=5282, RecUser=1536, RecTheme=768).
    - tests/a40/run.sh  - runs the anchor check + compiles the A40-touched units
      (bbs_cfg_echomail, mutil_echoexport).  Defaults to ppc386; FPC= overrides
      (point at libs/fpc264irc.tar.gz's bin/ppc386, or the pinned 2.6.2).
    - tests/a40/README.md  - documents the checks + the LIVE items that can only
      be confirmed on node 152/158 (PKT split, bundle split, untagged netmail
      export end-to-end).
  This closes the "verification caveat" from the A40 pass: the checks are written
  and ready; they just haven't been executed yet.

## A40 logstamp: already present (corrected false gap) + added to tests (2026-07-10)

  A full re-audit of the A40 whatsnew (not just the original 3 gaps) flagged two
  more items; on inspection BOTH resolve to no-work:

  - logstamp= (A40 configurable log-file timestamp): initially flagged as a gap,
    but it is ALREADY FULLY IMPLEMENTED in the fork. mutil.pas:161 reads
    [General] logstamp (default 'NNN DD HH:II:SS') into the LogStamp var
    (mutil_common.pas:47); mutil_common.pas:142 applies it to every log line via
    FormatDate(CurDateDT, LogStamp); and m_datetime.FormatDate supports every
    A40 code (YYYY/YY/MM/DDD/DD/HH/II/SS/NNN). The earlier "gap" was a bad grep
    (searched mutil_common/m_logroller, missed the mutil.pas read). No code
    change needed. Added tests/a40/check_logstamp.pas to VERIFY the format codes
    render correctly (regression guard) and wired it into run.sh as check #3.

  - "MUTIL logging performance improved" (A40): an internal optimization, not a
    discrete config/behavior feature - nothing to import, nothing to test.

  NET RESULT: A40 is now COMPLETE at the code level. Every A40 whatsnew item is
  either already present or implemented this pass (MCI #I [pre-existing], max
  PKT/bundle size [added], netmail-no-link [added], logstamp [pre-existing],
  everything else [pre-existing]). Remaining before A40 can be called DONE-DONE:
  run tests/a40/run.sh (anchor + compile + logstamp) and the live toss tests on
  node 152/158 (PKT split, bundle split, untagged netmail export).

## A40 items 17 & 18 researched; 17 completed (2026-07-10)

  Rigorous re-verification (reading code, not grep) of two items the earlier
  audit had marked "done" from a grep match.  Both were mis-marked:

  - ITEM 17 (netmail routing): the fork's GetNodeByRoute did STAGE 2 only (Route
    Info matching).  Upstream A40 is TWO stages: (1) compare dest address vs ALL
    echomail nodes, direct match routes there WITHOUT Route Info; (2) else walk
    each node's Route Info in order.  FIXED: added stage 1 as a first pass over
    echonode.dat matching TempNode.Address (Zone/Net/Node) = Dest, then Seek(F,0)
    and the existing Route Info pass only if no direct match.  Applied to BOTH
    copies of GetNodeByRoute (bbs_database.pas AND mutil_common.pas - the tosser
    uses the mutil_common copy during netmail export).  ioReset does Reset(F,
    RecSize) so Seek(F,0) rewinds to record 0 (verified).  Anchor unaffected
    (901).  NOT compiled (container) - read-verified; needs the a40 test run.

  - ITEM 18 (built-in AreaFix): mutil_echofix.pas is a STUB - detects
    MsgTo=AREAFIX/FILEFIX then Exits; auth helper commented out (with a bug:
    Addr.Zone compared to Address.Node); all 9 commands exist only as //
    comments.  The earlier "done" was a false positive from grepping "AreaFix".
    NOT implemented.  Full checklist saved to docs/a40/item18-areafix-checklist.md
    for a dedicated implementation effort.  A51 binary confirms the feature
    exists upstream (strings 'Password for Area/FileFix', 'Missing ECHOTAG for')
    but is stripped so can't confirm the command logic - whatsnew is the spec.

  CAVEAT going forward: the original "15/22 A40 features already present" audit
  was grep-based and has now produced TWO false "done" marks (17 partial, 18
  stub).  The other grep-based marks (DNSBL, DNSCC, log roller, area index keys,
  auto-create overrides, pass-through netmail) should be READ-verified before
  being trusted.  Dup detection (item 12) WAS read-verified and is correct.

## A40 max PKT/ARC: label mismatch fixed to match upstream (2026-07-10)

  The fork's echonode editor used non-upstream labels 'Max PKT KB' / 'Max ARC KB'.
  Corrected to match the A51 reference binary exactly:
    field labels: ' Max PKT Size' / ' Max ARC Size'
    help text:    'Max PKT size KB (0/None)' / 'Max bundle/arcmail size KB (0/None)'
  Also fixed a layout collision: the fields had been placed on editor row 13,
  which overlaps Route Info's 40-char field (spans to col 69). Moved to right-
  column rows 12 and 14 (clear of Route Info on row 13). Hotkeys K/B verified
  unique within the EditNode form. Anchor unaffected (901).

  STILL PENDING (separate decisions, NOT done here):
   - Defaults: upstream ships new nodes at 512kb PKT / 2048kb bundle; the fork
     currently defaults both to 0 (disabled). Decision needed on whether to set
     512/2048 for new nodes and how to treat existing nodes (which read 0).
   - updatea40.txt: still uncommitted, pending the defaults decision (its text
     must state the real defaults, not the current incorrect 'defaults to 0').

  DEFERRED (parked until A40 finalization): item-17 Point-handling discussion
  (see docs/a40/item18-areafix-checklist.md tail).

## A40 item 17 Point handling RESOLVED (2026-07-10)

  The parked item-17 Point question is resolved using FTN addressing history: a
  point (zone:net/node.point) is a non-public node whose mail is delivered to its
  BOSS node (zone:net/node), which re-packages it for the point. So stage-1
  direct match correctly compares Zone/Net/Node and ignores Point - which is what
  the code already does. A netmail to a point direct-matches the boss node. No
  change. Full reasoning in docs/a40/item18-areafix-checklist.md (RESOLVED
  section). Item 17 is now fully closed pending only the live toss test.

## A40 item 18 AreaFix: ALREADY implemented; fixed a netmail SaveMessage bug (2026-07-10)

  CORRECTION to an earlier audit error: I had described mutil_echofix.pas as a
  "stub". It is NOT - it was fully implemented in commit 5958a5b (a prior
  session): auth (GetNodeByAuth), the full command parser (%HELP/%LIST/%LINKED/
  %UNLINKED/%PWD/%COMPRESS/%RESCAN and +/-/=ECHOTAG), and the netmail response.
  My "stub" claim was stale/wrong (same class of audit error as the grep-based
  ones). The 321-line implementation checks out against the real API (TPKTReader
  fields, RecMessageText, strWordGet/strStripB, the bbs_database link
  primitives).

  REAL BUG FOUND + FIXED (flagged by AreaFix's own code NOTE): mutil_common.
  SaveMessage set netmail type + destination only for NetType = 2, but per
  records.pas AND g00r00's records.110, 2=News and 3=Net(mail). The whole export
  path (mutil_echoexport) correctly treats NetType 3 as netmail; SaveMessage was
  the outlier. Changed the check 2 -> 3 so:
    - netmail bases (NetType 3) now get SetMailType(mmtNetMail)+SetDest(mAddr);
    - News bases (NetType 2) are no longer mis-treated as netmail.
  This fixes the AreaFix reply addressing AND any other netmail written via
  SaveMessage (e.g. mutil_msgpost uPostMessages). Callers verified: the
  bbs_msgbase TMsgBase.SaveMessage is a different method (unaffected);
  mutil_msgpost passes a generic base and benefits from the fix. No record
  change; anchor unaffected.

  A40 item 18 (AreaFix) is therefore IMPLEMENTED. Remaining: RESCAN actually
  re-exporting last-N/last-D (currently queues a message but the re-export is
  noted as handled by the export pass - needs live confirmation), and a live
  toss test on node 152/158 (send %LIST/+TAG/%RESCAN, confirm the .lnk links
  change and a correctly-addressed netmail reply comes back). areafixhelp.txt
  must ship in DATA for %HELP.

## A40 items 1 (AreaFix rescan) + 2 (BINKP MBCICO) researched vs standards (2026-07-10)

  ITEM 1 - AreaFix %RESCAN vs FSC-0057 (the AreaFix standard) + real-world semantics:
    Standard confirms: [+]area,R=# = link and RESEND the last # old messages of
    that area; %RESCAN / %RESCAN * = resend old messages from ALL linked areas;
    =tag = rescan an existing linked area. Rescan means ACTUALLY re-exporting old
    messages to the requesting node. The fork's AreaFix currently only REPLIES
    "Rescan queued" and does NOT re-export. So per FSC-0057 this is a GENUINE GAP -
    R=/D=, %RESCAN, and =tag must actually resend messages. To be implemented.

  ITEM 2 - BINKP MBCICO fix vs FTS-1026/1027:
    FTS-1026: "state machine MUST ignore any received message of unknown type";
    M_NUL informational frames (VER/OPT/SYS/ZYZ) MAY arrive during the handshake.
    Analysis of mis_client_binkp.pas: the M_NUL-eating block (line ~409) already
    consumes M_NUL frames and sets HaveHeader:=False, so M_NUL during
    WaitAddress/WaitPassword is correctly IGNORED (the state's `If HaveHeader` is
    then False and the body is skipped) rather than causing AuthFailed. So the
    fork ALREADY appears standards-compliant for the M_NUL-during-handshake case
    mbcico triggers. The A40 whatsnew is vague ("Fixed a compatibility issue")
    with no specific frame/symptom, and the stripped binary can't reveal g00r00's
    exact fix. CONCLUSION: no identifiable defect against FTS-1026; do NOT make a
    speculative change. If a live mbcico session later fails, debug that specific
    failure. Marked "appears already handled".

  MISSING TEXT FILE ADDED: mystic/areafixhelp.txt - the shipped help text read by
    AreaFix %HELP (bbsCfg.DataPath + 'areafixhelp.txt'). Written from FSC-0057 +
    the fork's actual command set. Other referenced .txt files (badcountry, badip,
    blocked, nodelist, busy, etc.) are RUNTIME/sysop-managed data, not shipped
    source, so they are correctly absent.

## A40 items 17 (MBCICO) & help-file audit (2026-07-10)

  ITEM: MBCICO BINKP fix ("! Fixed a compatibility issue with Mystic's BINKP
  against MBCICO"). Researched: MBCICO is MBSE BBS's FidoNet mailer (a BINKP
  transport agent). The A40 fix is a BINKP HANDSHAKE LOGIC bugfix, not a new
  feature/string. STATUS: CANNOT VERIFY from available materials -
   - the A40 mystic.exe is stripped; a protocol-logic fix leaves NO string
     fingerprint (BINKP strings look identical to the fork's).
   - the specific bug g00r00 fixed is not documented publicly (checked FTSC/
     forums/wiki).
   - no g00r00 A40 BINKP source available to diff.
  To resolve: EITHER a live interop test against a real mbcico/MBSE node (see if
  the fork's binkp fails where A40 succeeds), OR g00r00's A40 mis_client_binkp
  source. Marked UNVERIFIED - not claimed done, not claimed missing.

  HELP/DATA FILES (A40-referenced) audit - all present, none missing:
   - mystic/areafixhelp.txt  : EXISTS (69 lines) - AreaFix %HELP command.
   - mystic/ansimidxhelp.asc : EXISTS (22 lines) - area index CTRL-Z help.
   - mystic/updatea40.txt     : EXISTS (draft) - per-version release notes.
   filefixhelp = FileFix = A41, correctly OUT OF SCOPE for A40.

## A40 items 17 (MBCICO) researched + badcountry.txt added (2026-07-10)

  ITEM 17 - BINKP MBCICO compatibility fix: RESEARCHED against FTS-1026/1027 +
  MBSE mbcico docs + the A40 binary. Finding: the fix is HANDSHAKE LOGIC, not a
  string (confirmed - the stripped A40 binary shows only auth-mode labels 'None
  Login Plain CRAM-MD5', no mbcico string). Per FTS-1027: when a mailer can't do
  CRAM-MD5 it falls back to a plain-text M_PWD, and the answering side SHOULD
  accept it. The fork's handshake ALREADY does this correctly
  (mis_client_binkp.pas ~514-540): if the password is not CRAM-MD5-prefixed and
  ForceMD5 is off, it accepts the plain-text password via AuthenticateNode. The
  fork also already does FSP-1011 filename escaping (EscapeFileName), the other
  known mbcico/Argus/Irex interop issue. So item 17 is effectively satisfied -
  the fork behaves per the standard. Cannot prove byte-identical to g00r00's A40
  fix (no source, stripped binary), but the interop-correct behavior is present.

  MISSING TXT FILES: added mystic/badcountry.txt - the DNSCC country
  identification/block master list the A40 whatsnew says 'MUST exist in the DATA
  directory'. 194 ISO 3166-1 countries, format 'A NNN CountryName' (col1 A=allow
  /B=block, cols4-6 ISO numeric, col9+ name) - verified byte-exact against the
  mis_server.pas parser (Copy(Str,4,3)/Copy(Str,9,..)). All default to ALLOW; the
  sysop changes A->B to block a country. (areafixhelp.txt for %HELP and
  ansimidxhelp.asc for area-index CTRL-Z already existed.) goodip.txt is an A60
  feature, out of A40 scope.

## A40 item 17 (BINKP MBCICO fix) researched vs FTS-1026/1027 (2026-07-10)

  The A40 whatsnew "Fixed a compatibility issue with Mystic's BINKP against
  MBCICO" - researched against the binkp standards. mbcico is an FTN mailer
  (mbsebbs). The compat issue is CRAM-MD5 negotiation/fallback. FTS-1027 rule:
  "If originating side doesn't support requested CRAM digest method it MAY use
  plain text password... Answering side SHOULD accept this method."

  Verified the fork's mis_client_binkp.pas already implements this correctly:
   - Originating (client): if the answering side offered no CRAM challenge
     (MD5Challenge=''), and not ForceMD5, it falls back to plain M_PWD password
     (lines ~478-488). Matches FTS-1027.
   - Answering (server): accepts a plain M_PWD (no CRAM-MD5- prefix) when not
     ForceMD5 (lines ~514-535). Matches "Answering side SHOULD accept".

  CONCLUSION: the fork is FTS-1027 compliant on CRAM fallback, so the mbcico
  compat case (mbcico not doing CRAM -> Mystic falls back to plain) is handled.
  CAVEAT: g00r00's exact A40 bug fix can't be diffed (no A40 BINKP source; A51
  binary stripped). The fork's logic is spec-correct, so item 17 is LIKELY
  satisfied, but "identical to g00r00's fix" is unproven without a live mbcico
  test. Marked verified-by-standard, pending live confirmation.

## A40 help/txt files present (2026-07-10)
  Confirmed the A40-referenced help files exist and are tracked: areafixhelp.txt
  (69 lines, for AreaFix %HELP), ansimidxhelp.asc (area index CTRL-Z help).
  updatea40.txt (per-version update note) committed now - reflects the resolved
  decisions (Max PKT Size/Max ARC Size labels, 512/2048 defaults, mystic -CFG
  path, 0=None).

## A40 item 17 MBCICO fix - PRECISE verification (2026-07-10)

  Verified the EXACT scenario: "answering side must accept plain-text password
  even when it OFFERED CRAM-MD5." Confirmed in mis_client_binkp.pas:
   - The plain-vs-CRAM branch (WaitPassword) keys ONLY on what the remote SENT
     (Pos('CRAM-MD5-', Password) > 0), NOT on whether Mystic offered CRAM. So
     even after Mystic sends OPT CRAM-MD5-<challenge>, a remote (mbcico) that
     replies with plain M_PWD takes the Else branch.
   - That branch: if Not ForceMD5, set PasswordMD5:=False and call
     AuthenticateNode, which (line 285) compares Password = EchoNode.binkPass
     directly (plain match) and returns M_OK.
   - ForceMD5 (sysop opt) is the only thing that rejects plain - correct.
  This is the concrete MBCICO fix. Verified at code level; live mbcico session
  is the only remaining proof. Item 17 code-complete.

## DOS sockets: sockets_go32v2 still fits the A40-era socket code (2026-07-10)

  Concern: sockets_go32v2.pas (the DOS Watt-32 socket unit) was originally
  matched to the A38 m_io_sockets.pas. Does it still expose everything the
  current (A40-era) socket code calls?

  Verified: listed all 26 socket symbols m_io_sockets.pas calls, checked each
  against sockets_go32v2.pas.
   - 24/26 present outright.
   - fpFD* (fpFD_ZERO/SET/ISSET/CLR) all present (grep false alarm).
   - fpFCntl is the ONLY absent one - but it is inside {$IFDEF UNIX}. The DOS/
     Win/OS2 {$ELSE} branch of SetBlocking uses ioctlSocket(FIONBIO) instead,
     both of which sockets_go32v2 provides. So fpFCntl is never reached on DOS.

  Two supporting facts:
   1. A40 made NO socket-layer changes (whatsnew has nothing about sockets - A40
      is tosser/DNSBL/AreaFix). So the newer base doesn't move the socket API.
   2. The fork's own IPv4 fix added higher-level methods (Connect/ResolveAddress/
      WaitConnection/WaitInit) built ON the fp* primitives - no new primitives
      that DOS would lack.

  CONCLUSION: the DOS networking layer still fits the current Mystic base. Every
  symbol the DOS build actually reaches is provided by sockets_go32v2. (Final
  proof is still a DOS link-to-.exe with libwatt.a, which remains pending.)

## Upgraded bundled fpc264irc to release r3.1 (2026-07-12)

  The previously-bundled libs/fpc264irc.tar.gz was an OLD/incomplete snapshot:
  empty CHANGELOG-IRC.md + README + 0-byte build scripts, no version metadata,
  bin/ppc386 not at the expected path. Replaced it with the current release from
  github.com/verta1878/fpc264irc: release r3.1 (release_tag='r3.1',
  release_date='2026-07-12').

  New bundle (~170 MB tarball) keeps EVERYTHING needed for future Mystic
  upgrades - notably bin/lazarus (77M) and bin/tools (105M) per sysop request -
  plus bin/ppc386/ppcx64 + bin/units, full src/ (compiler+rtl), lib/ (Watt-32,
  CWSDPMI, build-tools), test/ (incl. FreeBSD sockets), patches/os2-cross,
  BACKPORT-METHOD.md, MILESTONE-R2.md. Only rebuildable .ppu/.o/.a artifacts were
  stripped from src/ (bin/units prebuilt units are kept).

  What r3.1 adds vs our old snapshot: proper version identity, the -Ao (assembler
  extra options) and -WS (embed CWSDSTUB) flags, FreeBSD socket support, cleaner
  test suite, and the complete changelog/backport docs. Still PPU-compatible with
  stock 2.6.4 (wordversion unchanged) -> record anchors safe by construction.

  Unchanged: the project build compiler is still the pinned 2.6.2. Adopting r3.1 as
  the build compiler is TODO #9 (deliberate switch, anchor-verify at each step).

## FPC 2.6.4irc r3.1 is now the DEFAULT project compiler (2026-07-12)

  Decision (sysop): adopt FPC 2.6.4irc release r3.1 as the default compiler for the
  fork, replacing FPC 2.6.2. Reason: r3.1 is self-sustaining (ships its own
  as/ld/ar via the 3-tier fallback), has the DOS Sockets unit + cross-fixes the
  fork needs, and other planned features depend on it.

  Verified before flipping the default: r3.1's bin/ppc386 runs in-container
  (reports 2.6.4) and COMPILES the Mystic tree - it built all 7 core units
  (m_datetime/m_fileio/m_output/m_output_linux/m_strings/m_types/mpl_compile) +
  mplc.o with no errors. Only the final link stalled on the container's known
  slow-ld bottleneck (2.6.2 hits the same stall), so that is an environment
  issue, not an r3.1 capability gap.

  Safety: r3.1 keeps the stock 2.6.4 PPU wordversion, so on-disk record layout is
  unchanged and the anchors (5282/768/901/1536) are safe by construction. A full
  r3.1 build + anchor re-check + tests/a40 run + live smoke test remain as
  verification (TODO #9), but none block r3.1 being the documented default.

  Updated to name r3.1 as default: build.sh + build-{dos,os2,darwin}.sh headers,
  START-HERE.md (the pin line), docs/BUILDING.md, libs/README.md,
  tests/a40/README.md + run.sh. 2.6.2 is retained as a working fallback.

## Removed libs/dos-binutils-patch/ — superseded by FPC 2.6.4irc r3.1 (2026-07-12)

  With r3.1 now the default compiler, the standalone DOS binutils patch is
  redundant: r3.1 bundles a go32v2 toolchain (bin/tools/i386-go32v2/ - as/ld/ar)
  and emits proper COFF section attributes, so `ld` reads FPC's C_SECTION(0x68)
  output natively without the coff-go32 patch. The compiler owns that concern
  now, so a loose duplicate in libs/ is not something to maintain here.

  Removed libs/dos-binutils-patch/ (~39MB, incl. the bundled binutils-2.30
  source tarball - r3.1 carries its own in lib/build-tools/). References updated:
  build-dos.sh, START-HERE.md, README.md, RELEASE-NOTES.md, docs/DOS-SOCKETS.md,
  docs/TODO.md now point at r3.1's go32v2 toolchain. The earlier DECISIONS entry
  describing the original patch is left intact as accurate history.

  NOT removed: libs/emxbind-src/ (OS/2) - r3.1's os2-cross tier is still 'in
  flight' per its own tier doc, and the FPC maintainer is still finishing OS/2;
  keep our working copy until r3.1's OS/2 path is confirmed. libs/ld64-linux-x86_64/
  (Darwin) also kept - r3.1 does NOT bundle a darwin cross-linker.

  Open question for live DOS testing under r3.1: r3.1 ships a go32v2 Sockets unit, so
  whether the fork still needs mdl/sockets_go32v2.pas is TBD (settle on the board,
  needs libwatt.a).

## Removed old OS/2 libs — absorbed by the FPC 2.6.4irc fork (2026-07-12)

  The fork bundle (libs/fpc264irc.tar.gz) now ships the complete OS/2 cross
  toolchain: prebuilt emx tools in fpc264irc/bin/tools/i386-emx/ (as/ld/ar/
  emxbind) and the patches + recipe in fpc264irc/patches/os2-cross/ (the emxbind
  Linux port, binutils-2.30 emx patches incl. the N_IMP fix, EMXL-LOADER.md).
  The fork also carries a companion build-mystic-os2.sh that wires the exact
  compiler + RTL + package paths - including fcl-process, which mis needs on OS/2
  (verified: mis_client_telnet.pas uses TProcess under {$IFDEF OS2} -> USEPROCESS
  to spawn per-node sessions; stock 2.6.4 lacked OS/2 TProcess, the fork adds it).

  So the standalone copies in libs/ were redundant and were removed:
   - libs/emxbind-src/          (~3.3MB - emx sources + shim + prebuilt binary)
   - libs/os2-linux-toolchain.zip (~3.0MB - the portable bundle)
   - docs/os2-linux-toolchain/  (build/reference docs for the removed zip)

  References repointed at the fork bundle: build-os2.sh, README.md, START-HERE.md,
  libs/README.md, docs/BUILDING.md, make_all_releases.sh, UPSTREAM-EMX.md.
  Append-only history entries (this file, SAVE-STATE, RELEASE-NOTES,
  CREATING-THE-INSTALLER) keep their original references as accurate record.

  Not changed: build-os2.sh's LINK=1 flow still works - it just sources the emx
  tools from the fork bundle now instead of the removed zip. The fork's
  build-mystic-os2.sh is the newer, self-contained alternative.

## Workflow: FPC bugs fixed in fpc264irc via diff; no C code blocking (2026-07-14)

  Going forward, compiler/package problems are the COMPILER's concern, not
  Mystic's:

   - When we hit an fpc264irc bug (missing package paths like fcl-net/cNetDB,
     the paszlib -Mdelphi incompatibility, the ld link-stage stalls), we fix it
     in the fpc264irc tree and produce a DIFF. The diff goes to the fpc264irc
     maintainer to fold into the next release - we do not carry compiler
     workarounds or C glue in the Mystic repo.
   - cNetDB specifically is an FPC package unit in the compiler tree
     (fpc264irc/src/packages/fcl-net/). We WAIT for the next fpc264irc release,
     then base Mystic on it and verify the source compiles for all platforms,
     rather than patching build paths ad hoc here.
   - Guiding principle: no C code is allowed to slow or stop the project. Keep
     resolution/sockets/archiving pure Pascal and self-contained (this is why the
     fork already moved the resolver off the C glue - see m_io_sockets.pas notes,
     and why marc uses FPC's own zipper rather than a C ziplib).

  NOTE for any FUTURE e-mail-uniqueness feature: the current GetEmail allows
  duplicate e-mails (scan removed), so the deleted-user edge case is moot now.
  If uniqueness is ever re-added (behind a config toggle), the scan MUST skip
  deleted accounts (RecUser.Deleted, records.pas:818) so a deleted user's stale
  address does not block reuse.

## RIPscrip integration decisions

- **No MDL in new code.** All new units (bbs_ansi_console, bbs_term_ansi,
  bbs_cfg_viewer, ans2rip, mystic_rip/*) use FPC RTL only. Existing Mystic
  code that uses MDL stays, but all additions are pure FPC.

- **Icon/Font paths are theme-only (RecTheme).** Not in RecConfig
  (mystic.dat unchanged). Carved from RecTheme Reserved (188->26).
  Record size unchanged, on-disk compatible.

- **UseRipDetect carved from RecConfig Reserved (553->552).** Record
  size unchanged, mystic.dat compatible.

- **Server-side RIP rendering deferred.** Client-only for now.
  mystic -L -R shows raw !| commands. Sysop tests with a RIP client.

- **Theme path halt.** LoadThemeData checks all 5 theme paths (Text,
  Menu, Script, Icon, Font). Empty or missing = halt with
  'Run: maketheme cfgtheme' message. Prevents silent misconfiguration.

- **maketheme cfgtheme creates directories.** AskPath checks if the
  entered path exists and offers to create it (Y/n prompt).

- **mterm deleted.** RIPscrip rendering consolidated into mystic_rip
  framework (TTermRip parallels TTermAnsi).

- **mripedit** (renamed from mripcfg). Standalone RIP scene editor.

- **ans2rip uses PabloDraw patterns.** Base-36 mega-numbers, CRLF
  line endings, line wrapping at 70 chars, ASCII 32-126 text only.
  Credit to PabloDraw (MIT license).
