#!/usr/bin/perl
# usage: guard-test.pl <guard> <cases-file>   (case lines: EXPECT<TAB>command, \n = newline)
# Blocks are logged to a temporary TOOLSHELF_STATE, never your real one; the
# test checks that every BLOCK wrote exactly one log line.
use strict; use warnings; use JSON::PP; use IPC::Open3; use Symbol 'gensym'; use File::Temp 'tempdir';
my ($guard, $cases) = @ARGV;
$ENV{TOOLSHELF_STATE} = tempdir(CLEANUP => 1);
open my $fh, '<', $cases or die $!;
my ($ok, $bad, $blocks) = (0, 0, 0);
while (<$fh>) {
  chomp; next unless /\S/;
  my ($want, $cmd) = split /\t/, $_, 2;
  $cmd =~ s/\\n/\n/g;
  my $pid = open3(my $in, my $out, my $err = gensym, $guard);
  print $in encode_json({ tool_name => 'Bash', tool_input => { command => $cmd }, cwd => '/test' }); close $in;
  my $e = do { local $/; <$err> } // ''; waitpid $pid, 0; my $rc = $? >> 8;
  my $got = $rc == 2 ? 'BLOCK' : 'PASS';
  $blocks++ if $got eq 'BLOCK';
  my $mark = $got eq $want ? 'ok ' : 'XX '; $got eq $want ? $ok++ : $bad++;
  (my $show = $cmd) =~ s/\n/⏎/g;
  my ($why) = $e =~ /guard: (.*?)\.\n/;
  printf "%s %-5s %-62s %s\n", $mark, $got, substr($show, 0, 62), $got eq 'BLOCK' ? ($why // $e) : '';
}

# blocked.jsonl: one valid record per block
my $log = "$ENV{TOOLSHELF_STATE}/blocked.jsonl";
my @recs = -e $log ? do { open my $l, '<', $log or die $!; map { decode_json($_) } <$l> } : ();
my $logged = grep { $_->{source} eq 'guard' && $_->{reason} && $_->{command} && $_->{cwd} eq '/test' } @recs;
if ($logged == $blocks) { $ok++; printf "ok  LOG   %d blocks logged to blocked.jsonl\n", $logged }
else { $bad++; printf "XX  LOG   %d blocks, but %d valid log records\n", $blocks, $logged }

print "\n$ok passed, $bad failed\n";
exit($bad ? 1 : 0);
