# Copyright (C) 2019 SUSE Linux GmbH
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

package Cavil::Model::Snippets;
use Mojo::Base -base, -signatures;

use Mojo::File 'path';

has [qw(pg)];

sub find ($self, $id) {
  return $self->pg->db->select('snippets', '*', {id => $id})->hash;
}

sub find_or_create ($self, $hash, $text) {
  my $db = $self->pg->db;

  my $snip = $db->select('snippets', 'id', {hash => $hash})->hash;
  return $snip->{id} if $snip;

  $db->query(
    'insert into snippets (hash, text) values (?, ?)
   on conflict do nothing', $hash, $text
  );
  return $db->select('snippets', 'id', {hash => $hash})->hash->{id};
}

sub random ($self, $limit) {
  return $self->pg->db->query(
    'select id, text, classified,
    license, confidence from snippets where approved=FALSE
    order by hash limit ?', $limit
  )->hashes;
}

sub mark_non_license ($self, $id) {
  $self->pg->db->update('snippets', {license => 0, approved => 1, classified => 1}, {id => $id});
}
1;
