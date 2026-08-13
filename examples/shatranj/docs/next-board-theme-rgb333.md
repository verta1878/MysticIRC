# Next board theme colours (RGB333)

Conversion to the nearest RGB333 level:

```text
round(channel * 7 / 255)
```

| Theme | Colour | Original RGB | RGB333 | Bits `RRR GGG BBB` | 9-bit value | Next `0x44` bytes | Representable RGB |
|---:|---|---|---|---|---:|---|---|
| 2 | COLOR1 | `#BAD9D9` | `(5,6,6)` | `101 110 110` | `0x176` | `0xBB, 0x00` | `#B6DADA` |
| 2 | COLOR2 | `#546AB6` | `(2,3,5)` | `010 011 101` | `0x09D` | `0x4E, 0x01` | `#486DB6` |
| 3 | COLOR1 | `#FEFFD7` | `(7,7,6)` | `111 111 110` | `0x1FE` | `0xFF, 0x00` | `#FFFFDA` |
| 3 | COLOR2 | `#92B569` | `(4,5,3)` | `100 101 011` | `0x12B` | `0x95, 0x01` | `#91B66D` |
| 4 | COLOR1 | `#F9D9B3` | `(7,6,5)` | `111 110 101` | `0x1F5` | `0xFA, 0x01` | `#FFDAB6` |
| 4 | COLOR2 | `#AE8F6A` | `(5,4,3)` | `101 100 011` | `0x163` | `0xB1, 0x01` | `#B6916D` |
| 5 | COLOR1 | `#CF8F45` | `(6,4,2)` | `110 100 010` | `0x1A2` | `0xD1, 0x00` | `#DA9148` |
| 5 | COLOR2 | `#874826` | `(4,2,1)` | `100 010 001` | `0x111` | `0x88, 0x01` | `#914824` |

The representable RGB column is authoritative for hardware. For themes 2-5,
COLOR1 is the unselected coordinate ink, selected coordinate paper and 1 px
board frame; COLOR2 is the selected coordinate ink. Theme 1 remains classic.

## ZEsarUX 13.0

Stock ZEsarUX 13.0 can render the valid private attributes `0x81` and `0x8A`
as blue with FLASH because its TBBlue path does not distinguish ULA+ enable
(`NextReg 0x68` bit 3) from ULANext enable (`NextReg 0x43` bit 0).

The prepared sibling `../ZXESPEmu` applies
`patches/zesarux-13-tbblue-ulaplus.patch`, which selects the private ULA+
palette group from attribute bits 6-7. The patch is reported upstream at
<https://github.com/chernandezba/zesarux/pull/12>. Emulator output remains
supporting evidence; real Next hardware is authoritative.
