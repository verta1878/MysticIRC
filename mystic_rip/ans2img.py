#!/usr/bin/env python3
"""Convert .ANS file to Mystic LoadScreenImage IMAGEDATA Pascal const."""
import sys, re

SGRtoEGA = [0, 4, 2, 6, 1, 5, 3, 7]

def parse_ansi(data):
    """Parse ANSI into 80x25 screen buffer of (char, attr) tuples."""
    screen = [[(32, 7)] * 80 for _ in range(25)]
    cx, cy = 0, 0
    attr = 7
    i = 0
    while i < len(data):
        b = data[i]
        if b == 0x1B and i + 1 < len(data) and data[i+1] == 0x5B:  # ESC[
            i += 2
            params = ''
            while i < len(data) and (data[i] in range(0x30, 0x3C) or data[i] == ord('?')):
                params += chr(data[i]); i += 1
            if i < len(data):
                cmd = chr(data[i]); i += 1
                nums = [int(x) if x else 0 for x in params.split(';')] if params else [0]
                if cmd == 'm':
                    for n in nums:
                        if n == 0: attr = 7
                        elif n == 1: attr |= 8
                        elif n == 5: attr |= 128
                        elif n == 7: attr = ((attr & 0x0F) << 4) | ((attr >> 4) & 0x0F)
                        elif n == 22: attr &= 0xF7
                        elif n == 25: attr &= 0x7F
                        elif 30 <= n <= 37: attr = (attr & 0xF8) | SGRtoEGA[n - 30]
                        elif 40 <= n <= 47: attr = (attr & 0x8F) | (SGRtoEGA[n - 40] << 4)
                elif cmd == 'H' or cmd == 'f':
                    cy = max(0, nums[0] - 1) if len(nums) > 0 and nums[0] > 0 else 0
                    cx = max(0, nums[1] - 1) if len(nums) > 1 and nums[1] > 0 else 0
                elif cmd == 'A': cy = max(0, cy - (nums[0] if nums[0] else 1))
                elif cmd == 'B': cy = min(24, cy + (nums[0] if nums[0] else 1))
                elif cmd == 'C': cx = min(79, cx + (nums[0] if nums[0] else 1))
                elif cmd == 'D': cx = max(0, cx - (nums[0] if nums[0] else 1))
                elif cmd == 'J':
                    if nums[0] == 2:
                        screen = [[(32, 7)] * 80 for _ in range(25)]
                        cx, cy = 0, 0
                elif cmd == 'K':
                    for x in range(cx, 80): screen[cy][x] = (32, attr)
                elif cmd == 's': pass  # save cursor
                elif cmd == 'u': pass  # restore cursor
            continue
        elif b == 13:  # CR
            cx = 0
        elif b == 10:  # LF
            cy += 1
            if cy >= 25: cy = 24
        elif b == 9:   # TAB
            cx = min(79, (cx // 8 + 1) * 8)
        else:
            if 0 <= cy < 25 and 0 <= cx < 80:
                screen[cy][cx] = (b, attr)
            cx += 1
            if cx >= 80:
                cx = 0; cy += 1
                if cy >= 25: cy = 24
        i += 1
    return screen

def screen_to_imagedata(screen):
    """Convert screen buffer to Mystic LoadScreenImage format."""
    out = []
    cur_attr = 7
    for row in range(25):
        # Set initial attribute
        fg = cur_attr & 0x0F
        bg = (cur_attr >> 4) & 0x07
        
        col = 0
        while col < 80:
            ch, attr = screen[row][col]
            new_fg = attr & 0x0F
            new_bg = (attr >> 4) & 0x07
            
            # Emit attribute changes
            if new_fg != (cur_attr & 0x0F):
                out.append(new_fg)
                cur_attr = (cur_attr & 0xF0) | new_fg
            if new_bg != ((cur_attr >> 4) & 0x07):
                out.append(16 + new_bg)
                cur_attr = (cur_attr & 0x8F) | (new_bg << 4)
            
            # Check for space runs
            if ch == 32:
                run = 0
                while col + run < 80 and screen[row][col + run][0] == 32 and \
                      screen[row][col + run][1] == attr:
                    run += 1
                if run > 1:
                    out.extend([25, run - 1])
                    col += run
                    continue
                else:
                    out.append(32)
            elif ch < 32:
                out.append(32)  # control chars as space
            else:
                # Check for char runs
                run = 0
                while col + run < 80 and screen[row][col + run][0] == ch and \
                      screen[row][col + run][1] == attr:
                    run += 1
                if run > 2:
                    out.extend([26, run - 1, ch])
                    col += run
                    continue
                else:
                    out.append(ch)
            col += 1
        
        if row < 24:
            out.append(24)  # newline
    
    return bytes(out)

def to_pascal_const(data, name, width=80, depth=25):
    """Format as Pascal const declaration."""
    lines = []
    lines.append(f'  {name}_WIDTH={width};')
    lines.append(f'  {name}_DEPTH={depth};')
    lines.append(f'  {name}_LENGTH={len(data)};')
    lines.append(f'  {name} : array [1..{len(data)}] of Char = (')
    
    row = '    '
    for i, b in enumerate(data):
        if 32 <= b <= 126 and b != 39:  # printable, not quote
            row += f"'{chr(b)}'"
        else:
            row += f'#{b}'
        if i < len(data) - 1:
            row += ','
        if len(row) > 70:
            lines.append(row)
            row = '    '
    if row.strip():
        lines.append(row)
    lines.append('  );')
    return '\n'.join(lines)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f'Usage: {sys.argv[0]} input.ans CONST_NAME')
        sys.exit(1)
    
    with open(sys.argv[1], 'rb') as f:
        data = f.read()
    
    # Strip SAUCE
    if len(data) > 128 and data[-128:-123] == b'SAUCE':
        data = data[:-128]
    
    screen = parse_ansi(data)
    imgdata = screen_to_imagedata(screen)
    print(to_pascal_const(imgdata, sys.argv[2]))
