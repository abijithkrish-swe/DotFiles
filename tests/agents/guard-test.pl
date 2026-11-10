#!/usr/bin/perl
# usage: guard-test.pl <guard> <cases-file>   (case lines: EXPECT<TAB>command, \n = newline)
use strict; use warnings; use JSON::PP; use IPC::Open3; use Symbol 'gensym';
my ($guard, $cases) = @ARGV;
open my $fh, '<', $cases or die $!;
my ($ok, $bad) = (0, 0);
while (<$fh>) {
  chomp; next unless /\S/;
  my ($want, $cmd) = split /\t/, $_, 2;
  $cmd =~ s/\\n/\n/g;
  my $pid = open3(my $in, my $out, my $err = gensym, $guard);
  print $in encode_json({ tool_name => 'Bash', tool_input => { command => $cmd } }); close $in;
  my $e = do { local $/; <$err> } // ''; waitpid $pid, 0; my $rc = $? >> 8;
  my $got = $rc == 2 ? 'BLOCK' : 'PASS';
  my $mark = $got eq $want ? 'ok ' : 'XX '; $got eq $want ? $ok++ : $bad++;
  (my $show = $cmd) =~ s/\n/⏎/g;
  my ($why) = $e =~ /guard: (.*?)\.\n/;
  printf "%s %-5s %-62s %s\n", $mark, $got, substr($show, 0, 62), $got eq 'BLOCK' ? ($why // $e) : '';
}
print "\n$ok passed, $bad failed\n";
exit($bad ? 1 : 0);
