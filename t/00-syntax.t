#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

# Syntax-check all .pm files with the base dir in @INC
my $base = "$FindBin::Bin/..";

my @files;
push @files, glob("$base/*.pm");
push @files, glob("$base/commands/*.pm");

plan tests => scalar @files;

for my $file (sort @files) {
    my $output = `perl -I"$base" -c "$file" 2>&1`;
    if ($? == 0) {
        ok(1, "syntax ok: $file");
    }
    elsif ($output =~ /Can't locate .+ in \@INC/) {
        # Missing optional CPAN dependency - skip rather than fail
        # These will be caught in CI where all deps are installed
      SKIP: {
            skip "missing dependency for $file: $output", 1;
        }
    }
    else {
        ok(0, "syntax ok: $file");
        diag($output);
    }
}
