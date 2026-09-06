#!/usr/bin/env python3
# Generate wfc.ans - the Waiting-For-Caller screen shared by the modem and
# binkp examples, reconstructed from the Mystic 1.06 WFC screenshot.
#
# 80x25, CP437, ANSI colour.  Layout (from the screenshot):
#   row 0  : title bar  " Mystic BBS v1.06 ...            Fluph/2 "
#   rows 2-10 : two panels side by side - "Node Listing" (left, nodes 001-008)
#               and "Modem Info" (right); a "Local Mode" tab between them
#   rows 12-24: "System Commands" panel - three columns of hot-keys plus a
#               status column (Node/OS/Overlay/Next Event); clock + date row.
#
# Colours: blue background (44), bright cyan/white double-line frames, yellow
# (1;33) panel titles, bright-white command letters in parens, cyan labels.
# MCI-style @-codes are left as literal text the host can overwrite at runtime
# (the modem/binkp examples fill Node Listing / Modem Info / clock live).

import sys

ESC = "\x1b"
def sgr(*a): return ESC + "[" + ";".join(str(x) for x in a) + "m"
def cup(r, c): return ESC + "[" + str(r) + ";" + str(c) + "H"   # 1-based

# CP437 box-drawing (emitted as raw bytes 0xB0..0xDB range)
DHL = "\xcd"   # double horizontal
DVL = "\xba"   # double vertical
DTL = "\xc9"; DTR = "\xbb"; DBL = "\xc8"; DBR = "\xbc"  # double corners
SHADE = "\xb1"  # light shade (the hatched border in the shot)

BG = 44          # blue background
def C(fg, bold=0, bg=BG):
    return sgr(*( ([1] if bold else [0]) + [fg, bg] ))

out = []
def w(s): out.append(s)

# clear to blue background, home
w(sgr(0, 37, BG)); w(ESC + "[2J"); w(cup(1,1))

# ---- title bar (row 1) : bright white on blue, hatched edges -------------
w(cup(1,1)); w(C(37,1))
title = " Mystic BBS v1.06 "
right = "Fluph/2 "
bar = title + " " * (80 - len(title) - len(right)) + right
w(bar[:80])

# ---- Node Listing panel (left)  rows 3-11, cols 4-40 ---------------------
def dbox(r0, c0, r1, c1, title_txt, title_col):
    w(cup(r0, c0)); w(C(36,1)); w(DTL + DHL*(c1-c0-1) + DTR)
    for r in range(r0+1, r1):
        w(cup(r, c0)); w(C(36,1)); w(DVL)
        w(cup(r, c1)); w(C(36,1)); w(DVL)
    w(cup(r1, c0)); w(C(36,1)); w(DBL + DHL*(c1-c0-1) + DBR)
    # title sits on the top border, a couple cols in
    w(cup(r0, c0+2)); w(title_col); w(" " + title_txt + " ")

dbox(3, 4, 11, 40, "Node Listing \x18\x19", C(33,1))
for i in range(8):
    w(cup(4+i, 6)); w(C(37,1)); w("%03d" % (i+1)); w(C(36)); w(" -")
    w(cup(4+i, 38)); w(C(36)); w("-")

# ---- Modem Info panel (right) rows 3-11, cols 44-77 ----------------------
dbox(3, 44, 11, 77, "Modem Info", C(33,1))
w(cup(4, 46)); w(C(37,1)); w("-")

# ---- "Local Mode" tab centred on the frame gap (row 12, below panels) ----
w(cup(12, 35)); w(C(37,1)); w(" Local Mode ")

# ---- System Commands panel  rows 13-25, cols 4-77 ------------------------
dbox(13, 4, 25, 77, "System Commands", C(33,1))

def cmd(r, c, key, label):
    w(cup(r, c)); w(C(37,1)); w("(" + key + ")"); w(C(37)); w(" " + label)

# left column
cmd(15, 6,  "U", "User Editor")
cmd(16, 6,  "S", "System Configuration")
cmd(17, 6,  "P", "Protocol Editor")
cmd(18, 6,  "E", "Event Editor")
cmd(19, 6,  "#", "Menu Editor")
cmd(20, 6,  "M", "Message Base Editor")
cmd(21, 6,  "Q", "Quit to DOS")
# middle column
cmd(15, 34, "G", "Group Editor")
cmd(16, 34, "A", "Archive Editor")
cmd(17, 34, "V", "Voting Booth Editor")
cmd(18, 34, "F", "File Base Editor")
cmd(19, 34, "L", "Security Levels")
cmd(20, 34, "X", "Answer Modem")
cmd(21, 34, "D", "Drop to DOS")
# status column (right)
def stat(r, lbl, val):
    w(cup(r, 58)); w(C(36,1)); w(lbl); w(cup(r, 70)); w(C(37,1)); w(val)
stat(15, "Node",       "1")
stat(16, "OS",         "DOS")
stat(17, "Overlay",    "Disk")
stat(18, "Next Event", "None")
# local login hint
w(cup(21, 56)); w(C(37,1)); w("(SPACE)"); w(C(37)); w(" Local Login")

# ---- clock + date (bottom, row 24 inside frame) --------------------------
w(cup(24, 6));  w(C(33,1)); w("@TIME@")      # host overwrites (e.g. 01:17p)
w(cup(24, 70)); w(C(33,1)); w("@DATE@")      # host overwrites (07/08/26)

# reset + park cursor
w(sgr(0)); w(cup(25,1))

data = "".join(out).encode("cp437", errors="replace")
sys.stdout.buffer.write(data)
