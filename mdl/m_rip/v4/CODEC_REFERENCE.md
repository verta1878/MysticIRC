# FPC Codecs — Complete Reference

Pure Pascal decoders and multimedia units for FPC 2.6.4irc.
Zero external C dependencies. All platforms supported.

---

## Image Decoders

### jpegdecraw.pas (308 lines)
Baseline JPEG decoder. Outputs 24-bit RGB pixel buffer.

```pascal
uses jpegdecraw;
var Pixels: PByte; W, H: Integer;
begin
  if JPEGLoadFileRaw('photo.jpg', Pixels, W, H) then begin
    // Pixels = W * H * 3 bytes (RGB)
    FreeMem(Pixels);
  end;
end.
```

**Supports:** Baseline JPEG (DCT, Huffman), 8-bit, YCbCr to RGB conversion.
**Does not support:** Progressive JPEG, CMYK, 12-bit.
**Dependencies:** None.
**Mode:** {$H-} compatible.

---

### pngcodec.pas (393 lines)
PNG decoder with full color type support. Outputs RGB or RGBA.

```pascal
uses pngcodec;
var Pixels: PByte; W, H: LongInt; Alpha: Boolean;
begin
  if PNGDecodeFile('icon.png', Pixels, W, H, Alpha) then begin
    // Alpha=True: 4 bytes/pixel (RGBA)
    // Alpha=False: 3 bytes/pixel (RGB)
    FreeMem(Pixels);
  end;
end.
```

**Supports:** Color types 0 (gray), 2 (RGB), 3 (palette), 4 (gray+alpha),
6 (RGBA). Bit depths 1, 2, 4, 8, 16. All 5 filter types. tRNS transparency.
**Does not support:** Adam7 interlacing, APNG animation.
**Dependencies:** paszlib (inflate decompression, included with FPC).
**APIs:** PNGDecodeFile (disk), PNGDecodeMem (memory buffer).

---

### pngdecraw.pas (571 lines)
Alternate PNG decoder. Same capability, different internal structure.

**Dependencies:** paszlib.
**Mode:** {$H-} compatible.

---

### gifdecraw.pas (510 lines)
GIF decoder with LZW decompression and animation support.

```pascal
uses gifdecraw;
var Pixels: PByte; W, H: Integer;
begin
  if GIFLoadFileRaw('image.gif', Pixels, W, H) then begin
    // Pixels = W * H * 3 bytes (RGB), first frame
    FreeMem(Pixels);
  end;
end.
```

**Supports:** GIF87a/89a, LZW decompression, 256-color palette,
transparency, interlaced images, animation (first frame extraction).
**Dependencies:** None.
**Mode:** {$H-} compatible.

---

### pasjpeg/ (58 files)
Full JPEG library — Borland Pascal compatible. Supports both
encoding and decoding. Port of IJG libjpeg to Pascal.

```pascal
uses pasjpeg;
// Full encoder/decoder API — see jpeglib.pas for interface
```

**Supports:** Baseline + progressive JPEG, encode + decode,
multiple color spaces, quality control, markers.
**Dependencies:** None.

---

## Audio Decoders

### wavdec.pas (294 lines)
WAV (RIFF/WAVE) file parser. Extracts PCM sample data.

```pascal
uses wavdec;
var W: TWAVInfo;
begin
  if WAVLoadFile('sound.wav', W) then begin
    // W.Data, W.DataSize, W.SampleRate, W.BitsPerSample, W.Channels
    WAVFree(W);
  end;
end.
```

**Supports:** PCM format (format tag 1), 8/16-bit, mono/stereo,
any sample rate.
**Does not support:** Compressed WAV (ADPCM, MP3-in-WAV, etc).
**Dependencies:** None.
**Mode:** {$H-} compatible.

---

### vocdec.pas (418 lines)
Creative Voice File (.VOC) decoder — Sound Blaster native format.

```pascal
uses vocdec;
var V: TVOCInfo;
begin
  if VOCLoadFile('sound.voc', V) then begin
    // V.Data, V.DataSize, V.SampleRate, V.BitsPerSample, V.Channels
    VOCFree(V);
  end;
end.
```

**Supports:** Block types 0x01-0x09: sound data (8-bit PCM, 16-bit PCM),
continuation, silence, markers, text, repeat loops, extended info
(stereo, high sample rates), new format block.
**Does not support:** ADPCM codecs (0x01-0x03 detected but raw-passed).
**Dependencies:** None.
**Mode:** {$H-} compatible.
**APIs:** VOCLoadFile (disk), VOCLoadMem (memory buffer), VOCFree.

---

### pcmdec.pas (310 lines)
PCM audio decoder with automatic format detection from WAV headers.

**Dependencies:** None.

---

### pcmdecraw.pas (197 lines)
Raw PCM decoder — reads headerless PCM sample data with explicit
format parameters (sample rate, bits, channels).

```pascal
uses pcmdecraw;
var P: TPCMRawInfo;
begin
  if PCMRawLoadFile('raw.pcm', P, 22050, 8, 1) then begin
    // P.Data = unsigned 8-bit mono at 22050 Hz
    PCMRawFree(P);
  end;
end.
```

**Dependencies:** None.
**Mode:** {$H-} compatible.

---

### mididec.pas (378 lines)
Standard MIDI File (SMF) decoder. Parses format 0 and format 1 files
into track/event structures.

```pascal
uses mididec;
var M: TMIDIInfo;
begin
  if MIDILoadFile('music.mid', M) then begin
    // M.Tracks[0..M.TrackCount-1].Events[0..N]
    // Each event: DeltaTime, Status, Data1, Data2
    MIDIFree(M);
  end;
end.
```

**Supports:** Format 0 (single track), Format 1 (multi-track),
note on/off, program change, control change, pitch bend,
meta events (tempo, time signature, key signature, text).
**Dependencies:** None.

---

### ansimusic.pas (500 lines)
ANSI music / MML (Music Macro Language) decoder for BBS content.
Parses ESC[M sequences from ANSI art files into note events.

```pascal
uses ansimusic;
var Events: PAMEvent; Count: Integer;
    PCM: PByte; PCMSize: LongWord;
begin
  if AMParseMML('T120 O4 L4 C D E F G A B > C', Events, Count) then begin
    // Events^[0..Count-1] = note/rest events with freq + duration
    AMSynthPCM(Events, Count, 11025, PCM, PCMSize);
    // PCM = 8-bit unsigned square wave
    FreeMem(PCM);
    FreeMem(Events);
  end;
end.
```

**MML Commands:**
  T<tempo> (32-255 BPM), L<length> (1-64, default note length),
  O<octave> (0-7), V<volume> (0-15),
  Notes: C D E F G A B with # + - (sharp/flat) and . (dotted),
  N<num> (note by number 0-84), P/R (rest),
  < > (octave down/up), MF/MB (foreground/background),
  MN/MS/ML (normal/staccato/legato).

**APIs:** AMParseMML (parse MML string), AMParseANSI (parse ESC[M from buffer),
AMExtractFromANSI (find MML in ANSI file), AMSynthPCM (render to 8-bit PCM),
AMPlayEvents (PC speaker on DOS, no-op elsewhere), AMNoteFreq (note to Hz).
**Dependencies:** None.
**Mode:** {$H-} compatible.
**Playback:** PC speaker on DOS (direct PIT), PCM synthesis on all platforms.

---

## Audio Playback

### wavplay.pas (451 lines)
Cross-platform WAV file playback.

```pascal
uses wavplay;
begin
  if AudioAvailable then
    PlayWAV('sound.wav');
end.
```

| Platform | Backend |
|----------|---------|
| Win32 | winmm.dll sndPlaySound |
| Linux | aplay (ALSA) / paplay (PulseAudio) / sox |
| FreeBSD | aplay / sox |
| Darwin | afplay |
| DOS | Sound Blaster via dosplay.pas |
| OS/2 | MMPM/2 mciSendString |

**APIs:** PlayWAV (sync), PlayWAVAsync (async), StopWAV, PlayPCMBuffer,
AudioAvailable.
**Dependencies:** SysUtils, Classes, PCMDec, DOSPlay (DOS only).

---

### dosplay.pas (481 lines)
Sound Blaster DMA playback for DOS (go32v2). IRQ-driven async.

```pascal
uses dosplay;
begin
  if SB_Init then begin
    SB_PlayPCM(Data, Size, 22050, 8, 1);
    SB_WaitDone;
    SB_Done;
  end;
end.
```

**Supports:** Sound Blaster / SB16 detection (BLASTER env var),
DSP version detection, 8-bit DMA single-cycle and double-buffer
streaming, PC speaker tone generation.
**APIs:** SB_Init/SB_Done, SB_PlayPCM, SB_Stop, SB_IsPlaying, SB_WaitDone,
SB_StreamStart/Feed/Stop/NeedsData, SB_Beep, Speaker_Tone/Speaker_Off.
**Non-DOS:** Compiles as empty stubs (all functions return False/no-op).

---

### pcmmix.pas (342 lines)
16-stream PCM audio mixer. Mixes multiple audio sources into a
single output buffer for playback.

```pascal
uses pcmmix;
var Mixer: TPCMMixer;
begin
  MixerInit(Mixer, 22050, 8, 1);
  MixerAddStream(Mixer, 0, Data1, Size1);
  MixerAddStream(Mixer, 1, Data2, Size2);
  MixerMix(Mixer, OutputBuf, OutputSize);
  MixerDone(Mixer);
end.
```

**Supports:** Up to 16 simultaneous streams, volume per stream,
8-bit unsigned mixing with clipping.
**Dependencies:** None.

---

## Compression

### lzmadecpas.pas (652 lines)
LZMA1/LZMA2 decompressor. Compatible with 7-Zip .lzma files.

```pascal
uses lzmadecpas;
var Out: PByte; OutSize: LongWord;
begin
  if LZMADecompress(CompData, CompSize, Out, OutSize) then begin
    // Out = decompressed data
    FreeMem(Out);
  end;
end.
```

**Supports:** LZMA1 (standalone .lzma), LZMA2 (used in .xz and .7z).
**Dependencies:** None.

---

## Math & Tools

### fixedmath.pas (264 lines)
16.16 fixed-point arithmetic library. No FPU required — works on
i8086, i386, and all targets including DOS real mode.

```pascal
uses fixedmath;
var A, B, C: TFixed;
begin
  A := IntToFix(3);          // 3.0
  B := FixDiv(IntToFix(1), IntToFix(3));  // 0.333...
  C := FixMul(A, B);         // ~1.0
  WriteLn(FixToStr(C));      // "1.0000"
end.
```

**Operations:** Add, Sub, Mul, Div, Sqrt, Sin, Cos, IntToFix, FixToInt,
FixToStr, comparisons.
**Dependencies:** None.

---

### dfm2lfm.pas (257 lines)
Converts Delphi DFM (Design Form) files to Lazarus LFM format.
Handles binary and text DFM files.

```pascal
uses dfm2lfm;
begin
  ConvertDFMtoLFM('form.dfm', 'form.lfm');
end.
```

**Dependencies:** None.

---

## Platform Support Matrix

| Unit | Win32 | Linux | FreeBSD | Darwin | DOS | OS/2 | i8086 |
|------|-------|-------|---------|--------|-----|------|-------|
| jpegdecraw | Y | Y | Y | Y | Y | Y | Y |
| pngcodec | Y | Y | Y | Y | Y | Y | ? |
| gifdecraw | Y | Y | Y | Y | Y | Y | Y |
| vocdec | Y | Y | Y | Y | Y | Y | Y |
| pcmdec/raw | Y | Y | Y | Y | Y | Y | Y |
| wavdec | Y | Y | Y | Y | Y | Y | Y |
| mididec | Y | Y | Y | Y | Y | Y | Y |
| ansimusic | Y | Y | Y | Y | Y | Y | Y |
| pcmmix | Y | Y | Y | Y | Y | Y | Y |
| lzmadecpas | Y | Y | Y | Y | Y | Y | Y |
| fixedmath | Y | Y | Y | Y | Y | Y | Y |
| wavplay | Y | Y | Y | Y | Y | Y | - |
| dosplay | stub | stub | stub | stub | Y | stub | - |
| pasjpeg | Y | Y | Y | Y | Y | Y | ? |

Y = compiles and functional
stub = compiles, returns False/no-op
? = untested but should work
- = not applicable

---

## Build

All units compile with FPC 2.6.4irc r3.1+ using:
```bash
fpc -Mdelphi your_program.pas
```

pngcodec.pas additionally needs paszlib on the unit path:
```bash
fpc -Mdelphi -Fu<path-to-paszlib> your_program.pas
```

## License

GNU General Public License v3

Part of FPC 2.6.4irc r3.1 — Mystic BBS IRC Fork
July 21, 2026

---

### vocdec.pas (418 lines)
Creative Voice File (.VOC) decoder - Sound Blaster native format.

```pascal
uses vocdec;
var V: TVOCInfo;
begin
  if VOCLoadFile('sound.voc', V) then begin
    // V.Data, V.DataSize, V.SampleRate, V.BitsPerSample, V.Channels
    VOCFree(V);
  end;
end.
```

**Supports:** Block types 0x01-0x09: 8-bit/16-bit PCM, continuation,
silence, markers, text, repeat loops, extended (stereo, high rates),
new format block.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### audec.pas (286 lines)
Sun/NeXT AU (.au/.snd) audio decoder. Big-endian format.

```pascal
uses audec;
var A: TAUInfo;
begin
  if AULoadFile('sound.au', A) then begin
    // A.Data = 16-bit signed PCM (native endian)
    AUFree(A);
  end;
end.
```

**Supports:** mu-law (enc 1), linear 8/16/24/32-bit (enc 2-5),
A-law (enc 27). Annotation text. Any sample rate, multi-channel.
**Bonus:** Standalone MuLawDecode() and ALawDecode() functions.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### aiffdec.pas (373 lines)
Apple AIFF/AIFF-C audio decoder. IFF-based big-endian format.

```pascal
uses aiffdec;
var A: TAIFFInfo;
begin
  if AIFFLoadFile('sound.aiff', A) then begin
    // A.Data = 16-bit signed PCM, A.Name, A.Author
    AIFFFree(A);
  end;
end.
```

**Supports:** AIFF uncompressed PCM (8/16/24/32-bit), AIFF-C with
NONE/twos (big-endian), sowt (little-endian), ulaw, alaw compression.
80-bit IEEE extended sample rate parsing. NAME/AUTH/ANNO metadata.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### adpcmdec.pas (419 lines)
IMA ADPCM and MS ADPCM decoder. 4:1 compressed audio from WAV files.

```pascal
uses adpcmdec;
var OutPCM: PSmallInt; OutSamples: LongInt;
begin
  // IMA ADPCM (WAV format tag 0x0011)
  if IMADecode(Data, Size, 1, 512, OutPCM, OutSamples) then begin
    // OutPCM = 16-bit signed, OutSamples per channel
    FreeMem(OutPCM);
  end;
end.
```

**Supports:** IMA ADPCM (DVI) with 89-entry step table, MS ADPCM with
7 default coefficient pairs + custom coefficients. Mono + stereo.
Block-based decoding. Individual nibble decode APIs.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### ansimusic.pas (500 lines)
ANSI Music / MML (Music Macro Language) decoder for BBS content.

```pascal
uses ansimusic;
var Events: PAMEvent; Count: Integer;
    PCM: PByte; PCMSize: LongWord;
begin
  if AMParseMML('T120 O4 L4 C D E F G A B > C', Events, Count) then begin
    AMSynthPCM(Events, Count, 11025, PCM, PCMSize);
    // PCM = 8-bit unsigned square wave
    FreeMem(PCM); FreeMem(Events);
  end;
end.
```

**MML Commands:** T (tempo), L (length), O (octave), V (volume),
C D E F G A B (notes with # + - . modifiers), N (note by number),
P/R (rest), < > (octave shift), MF/MB/MN/MS/ML (mode).
**APIs:** AMParseMML, AMParseANSI, AMExtractFromANSI, AMSynthPCM,
AMPlayEvents (PC speaker on DOS), AMNoteFreq.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### moddec.pas (521 lines)
ProTracker MOD file decoder and renderer. 4-8 channel tracker music.

```pascal
uses moddec;
var M: TMODFile; PCM: PSmallInt; Len: LongInt;
begin
  if MODLoadFile('song.mod', M) then begin
    Len := MODRender(M, 44100, PCM);
    // PCM = interleaved stereo 16-bit signed
    FreeMem(PCM); MODFree(M);
  end;
end.
```

**Supports:** M.K./M!K!/FLT4 (4-ch), 4CHN/6CHN/8CHN, 15-instrument
Soundtracker. 31 instruments, 128 patterns, sample looping, Amiga
stereo panning. Effects: portamento, volume slide, arpeggio, speed/tempo,
position jump, pattern break.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### s3mdec.pas (581 lines)
Scream Tracker 3 S3M file decoder and renderer. Up to 32 channels.

```pascal
uses s3mdec;
var S: TS3MFile; PCM: PSmallInt; Len: LongInt;
begin
  if S3MLoadFile('song.s3m', S) then begin
    Len := S3MRender(S, 44100, PCM);
    // PCM = interleaved stereo 16-bit signed
    FreeMem(PCM); S3MFree(S);
  end;
end.
```

**Supports:** Up to 32 channels, 99 instruments, 256 patterns.
SCRM signature validation. Stereo panning (0-15). Effects: speed,
tempo, volume slide, portamento. C4Speed per-instrument tuning.
Packed pattern format with channel masking.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### mp3dec.pas (610 lines)
MPEG-1/2 Audio Layer III (MP3) decoder. Frame-level parsing with
format detection and duration calculation.

```pascal
uses mp3dec;
var M: TMP3Info;
begin
  if MP3LoadFile('song.mp3', M) then begin
    WriteLn('Rate: ', M.SampleRate, ' Channels: ', M.Channels);
    WriteLn('Duration: ', M.DurationMS, 'ms');
    WriteLn('Bitrate: ', M.Bitrate, ' kbps');
    MP3Free(M);
  end;
end.
```

**Supports:** MPEG-1/2 Layer III, 32-320 kbps, stereo/joint/dual/mono,
ID3v2 tag skipping, frame sync, side information decoding, bit reservoir,
CBR/VBR detection, duration calculation.
**Deferred (v2):** Full Huffman decode (32 tables), requantization,
IMDCT (36/12-point), subband synthesis polyphase filter. See C9b-C9f
in CODEC_PHASES.md.
**Dependencies:** None. **Mode:** {$H-} compatible.

---

### ripscript.pas (4041 lines)
RIPscript v1.54 server-side rendering engine. 51/51 commands, 640x350
EGA pixel buffer, CHR vector fonts, ICN/MSK/HIC icons, PCX/BMP images,
button system, mouse fields, text variables.

### rip2api.pas (5160 lines)
RIPscript v2.0 engine. 67 commands, resolution independence up to
1280x1024, 256 colors, RFF vector fonts, JPEG loading, sprites,
animation, 3D transforms, WAV audio hooks.
