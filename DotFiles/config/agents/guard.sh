#!/usr/bin/perl
# -----------------------------------------------------------------------------
# guard.sh — Claude Code PreToolUse hook (matcher: Bash)
#
# Blocks shell commands that match the agents blocklist (the same list the
# toolshelf MCP `run` tool enforces). Exit 2 blocks the call; stderr is shown
# to Claude so it can explain or use request_component instead.
#
# Heredoc bodies (file content written with cat <<EOF etc.) are not matched,
# so writing docs that mention `brew install` is fine. A heredoc fed to a
# shell or interpreter (bash <<EOF, cat <<EOF | sh) is matched as code.
#
# Blocklist: $TOOLSHELF_BLOCKLIST or ~/.config/agents/blocklist.txt
# Fails closed: a missing or unreadable blocklist blocks every Bash command.
# Deployed to ~/.config/agents/guard.sh. Design: Docs/AgentComponents.md
# -----------------------------------------------------------------------------
use strict;
use warnings;
use JSON::PP;

binmode(STDERR, ':encoding(UTF-8)');

my $blocklist = $ENV{TOOLSHELF_BLOCKLIST}
  || ($ENV{XDG_CONFIG_HOME} || "$ENV{HOME}/.config") . "/agents/blocklist.txt";

my $input = do { local $/; <STDIN> } // '';
my $cmd = eval { JSON::PP->new->utf8->decode($input)->{tool_input}{command} } // '';
exit 0 if $cmd eq '';

# Drop heredoc bodies that are data, keep ones that are executed.
my $shell_rx = qr/(?:^|[\s;&|(`])(?:sh|bash|zsh|python3?|perl|ruby|node|eval|source|\.)(?:\s|$)|\|\s*(?:sudo\s+)?(?:sh|bash|zsh)\b/;
my @out;
my @lines = split /\n/, $cmd, -1;
for (my $i = 0; $i < @lines; $i++) {
  my $line = $lines[$i];
  push @out, $line;
  while ($line =~ /<<-?\s*(['"]?)(\w+)\1/g) {
    my $tag = $2;
    next if $line =~ $shell_rx;        # executed heredoc: keep its body
    my $j = $i + 1;
    $j++ while $j < @lines && $lines[$j] !~ /^\s*\Q$tag\E\s*$/;
    $i = $j;                           # skip body through terminator
    last;
  }
}
my $code = join "\n", @out;

open(my $fh, '<:encoding(UTF-8)', $blocklist) or do {
  print STDERR "toolshelf guard: blocklist $blocklist is missing; refusing Bash "
    . "commands until it is deployed (install_copy.sh deploy).\n";
  exit 2;
};

while (my $line = <$fh>) {
  chomp $line;
  next if $line =~ /^\s*(#|$)/;
  my ($re, $reason) = split / ## /, $line, 2;
  $re =~ s/\s+$//;
  $reason //= 'blocked by policy';
  my $rx = eval { qr/$re/ } or next;
  if ($code =~ $rx) {
    print STDERR "Blocked by toolshelf guard: $reason.\n"
      . "Matched: $&\n"
      . "If it is really needed, ask the user to run it themselves. For a missing "
      . "tool version, use the toolshelf request_component tool.\n";
    exit 2;
  }
}
exit 0;
