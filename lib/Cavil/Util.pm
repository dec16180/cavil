# Copyright (C) 2018 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package Cavil::Util;
use Mojo::Base -strict, -signatures;

use Carp 'croak';
use Exporter 'import';
use Mojo::Util 'decode';
use Mojo::File qw(path);
use POSIX 'ceil';
use Text::Glob 'glob_to_regex';
$Text::Glob::strict_wildcard_slash = 0;

our @EXPORT_OK = qw(buckets slurp_and_decode load_ignored_files lines_context paginate parse_exclude_file);

my $MAX_FILE_SIZE = 30000;

sub buckets ($things, $size) {

  my $buckets    = int(@$things / $size) || 1;
  my $per_bucket = ceil @$things / $buckets;
  my @buckets;
  for my $thing (@$things) {
    push @buckets,        [] unless @buckets;
    push @buckets,        [] if @{$buckets[-1]} >= $per_bucket;
    push @{$buckets[-1]}, $thing;
  }

  return \@buckets;
}

sub slurp_and_decode ($path) {

  open my $file, '<', $path or croak qq{Can't open file "$path": $!};
  croak qq{Can't read from file "$path": $!} unless defined(my $ret = $file->sysread(my $content, $MAX_FILE_SIZE, 0));

  return $content if -s $path > $MAX_FILE_SIZE;
  return decode('UTF-8', $content) // $content;
}

sub _line_tag ($line) {
  return $line->[1]->{pid} if defined $line->[1]->{pid};

  # the actual value does not matter - as long as it differs between snippets
  return -1 - $line->[1]->{snippet} if defined $line->[1]->{snippet};
  return 0;
}

# small helper to simplifying the view code
# this adds to the line infos where the matches end and
# what's next
sub lines_context ($lines) {
  my $last;
  my $currentstart;
  my @starts;
  for my $line (@$lines) {
    if ($last && ($line->[0] - $last->[0]) > 1) {
      $line->[1]->{withgap} = 1;
    }
    my $linetag = _line_tag($line);
    if (_line_tag($last) != $linetag) {
      $currentstart->[1]->{end} = $last->[0] if $currentstart;
      if ($linetag) {
        push(@starts, $line);
        $currentstart = $line;
      }
      else {
        $currentstart = undef;
      }
    }
    $last = $line;
  }
  $currentstart->[1]->{end} = $last->[0] if $currentstart && $last;
  my $prevstart;
  for my $start (@starts) {
    if ($prevstart) {
      $prevstart->[1]->{nextend} = $start->[1]->{end};
      $start->[1]->{prevstart}   = $prevstart->[0];
    }
    $prevstart = $start;
  }

  return $lines;
}

sub load_ignored_files ($db) {
  my %ignored_file_res = map { glob_to_regex($_->[0]) => $_->[0] } @{$db->select('ignored_files', 'glob')->arrays};
  return \%ignored_file_res;
}

sub paginate ($results, $options) {
  my $total = @$results ? $results->[0]{total} : 0;
  delete $_->{total} for @$results;
  return {total => $total, start => $options->{offset} + 1, end => $options->{offset} + @$results, page => $results};
}

sub parse_exclude_file ($path, $name) {
  my $content = path($path)->slurp;
  my $exclude = [];

  for my $line (split "\n", $content) {
    next unless $line =~ /^\s*([^\s\#]\S+)\s*:\s*(\S+)(?:\s.*)?$/;
    my ($pattern, $file) = ($1, $2);

    next unless $name =~ glob_to_regex($pattern);

    push @$exclude, $file;
  }

  return $exclude;
}

1;
