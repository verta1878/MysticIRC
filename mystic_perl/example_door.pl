#!/usr/bin/perl
# ====================================================================
# Example: Mystic BBS Perl Door
# ====================================================================
#
# This script runs inside Mystic BBS via the PERL menu command.
# The mystic_bbs module is provided by Mystic at runtime.
#
# Menu setup: Command = PERL, Data = example_door
#
# ====================================================================

use strict;
use warnings;
use mystic_bbs;

# Clear screen
mystic_bbs::write("\x1b[2J\x1b[1;1H");

# Header
mystic_bbs::writeln("|15|17  Perl Door Example  |00|16");
mystic_bbs::writeln("");
mystic_bbs::writeln("|07This door is written in Perl and running");
mystic_bbs::writeln("inside Mystic BBS via the embedded interpreter.");
mystic_bbs::writeln("");

# Get user info
my $user = mystic_bbs::getuser();
mystic_bbs::writeln("|11Hello, |15" . $user . "|11!");
mystic_bbs::writeln("");

# Simple menu loop
my $running = 1;
while ($running && !mystic_bbs::shutdown()) {
    mystic_bbs::writeln("|14[|151|14] |07Fortune Cookie");
    mystic_bbs::writeln("|14[|152|14] |07System Info");
    mystic_bbs::writeln("|14[|15Q|14] |07Quit");
    mystic_bbs::writeln("");
    mystic_bbs::write("|11Choice: |15");

    my $key = mystic_bbs::onekey("12Qq", 1);
    mystic_bbs::writeln("");

    if ($key eq "1") {
        my @fortunes = (
            "A BBS sysop's work is never done.",
            "ANSI art is the highest form of art.",
            "The modem you seek is already within you.",
            "FidoNet: because email was too easy.",
            "640K ought to be enough for anybody.",
        );
        my $fortune = $fortunes[int(rand(scalar @fortunes))];
        mystic_bbs::writeln("|13> |07$fortune");
        mystic_bbs::writeln("");
    }
    elsif ($key eq "2") {
        mystic_bbs::writeln("|09System: |15Mystic BBS");
        mystic_bbs::writeln("|09Perl:   |15$^V");
        mystic_bbs::writeln("|09OS:     |15$^O");
        mystic_bbs::writeln("");
    }
    elsif ($key eq "Q" || $key eq "q") {
        $running = 0;
    }
}

mystic_bbs::writeln("|07Thanks for visiting! Press a key...");
mystic_bbs::getkey();
