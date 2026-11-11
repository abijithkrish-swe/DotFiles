#!/usr/bin/perl
# agents-md-test.pl [AGENTS.md] — checks for the agent rules file.
# It is the single source: Claude Code imports it, and toolshelf sends it to
# every MCP client as server instructions, so every byte costs tokens in every
# session. Style: ASD-STE100 writing rules (short imperative sentences, one
# instruction each, conditions first; see Docs/AgentComponents.md).
use strict; use warnings;
my $file = shift // 'DotFiles/config/agents/AGENTS.md';
open my $fh, '<:raw', $file or die "$file: $!";
my $raw = do { local $/; <$fh> };
my ($ok, $bad) = (0, 0);
sub check { my ($cond, $what) = @_; if ($cond) { $ok++; print "ok  $what\n" } else { $bad++; print "XX  $what\n" } }

my $max = 1600;
check(length($raw) <= $max, sprintf "size %d bytes (max %d: sent in every session)", length($raw), $max);

# Rules that must not get lost in an edit
for my $must (
  ['list_components',                              'rule: approved versions via toolshelf'],
  ['use_\*` shell functions',                      'rule: not the use_* functions'],
  ['Do not install, upgrade or remove tools',      'rule: never install'],
  ['request_component',                            'rule: missing version → request_component'],
  ['`mode` to "docker"',                           'rule: docker mode for untrusted code'],
  ['`network` to "proxy"',                         'rule: network only via proxy'],
  ['Do not use `run` to edit files',               'rule: run is not for edits'],
  ['\$TMPDIR',                                     'rule: temp files in $TMPDIR'],
  ['Do not change toolchain versions',             'rule: no toolchain changes'],
  ['add or upgrade a project dependency, ask',     'rule: ask before dependencies'],
  ['Do not read or show secrets',                  'rule: no secrets'],
) {
  my ($re, $what) = @$must;
  check(scalar($raw =~ /$re/), $what);   # scalar: a failed match in list context is ()
}

# STE: at most 25 words in a sentence (lists, i.e. 4+ commas, are exempt)
(my $text = $raw) =~ s/^#.*$//mg;
$text =~ s/^\s*\d+\.\s+//mg;
$text =~ s/\s+/ /g;
my @long;
for my $s (split /(?<=[.;])\s+(?=[A-Z`])/, $text) {
  my $commas = () = $s =~ /,/g;
  my $words = () = $s =~ /\S+/g;
  push @long, "$words words: $s" if $words > 25 && $commas < 4;
}
check(!@long, "STE: no sentence over 25 words" . (@long ? "\n      " . join("\n      ", @long) : ''));

print "\n$ok passed, $bad failed\n";
exit($bad ? 1 : 0);
