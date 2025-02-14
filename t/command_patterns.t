# Copyright (C) 2023 SUSE LLC
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

use Mojo::Base -strict;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
use Test::Mojo;
use Cavil::Test;
use Cavil::Command::patterns;

plan skip_all => 'set TEST_ONLINE to enable this test' unless $ENV{TEST_ONLINE};

my $cavil_test = Cavil::Test->new(online => $ENV{TEST_ONLINE}, schema => 'command_patterns_test');
my $config     = $cavil_test->default_config;
my $t          = Test::Mojo->new(Cavil => $config);
my $app        = $t->app;
$cavil_test->no_fixtures($app);

subtest 'Empty database' => sub {
  my $buffer = '';
  {
    open my $handle, '>', \$buffer;
    local *STDOUT = $handle;
    $app->start('patterns');
  }
  like $buffer, qr/0 licenses with 0 patterns/, 'no patterns';
};

subtest 'Patterns added' => sub {
  $cavil_test->mojo_fixtures($app);

  subtest 'All licenses' => sub {
    my $buffer = '';
    {
      open my $handle, '>', \$buffer;
      local *STDOUT = $handle;
      $app->start('patterns');
    }
    like $buffer, qr/4 licenses with 6 patterns/, 'mojo fixture patterns';
  };

  subtest 'Specific license' => sub {
    my $buffer = '';
    {
      open my $handle, '>', \$buffer;
      local *STDOUT = $handle;
      $app->start('patterns', '-l', 'Apache-2.0');
    }
    like $buffer, qr/Apache-2.0 has 2 patterns/, 'Apache-2.0 patterns';
  };
};

subtest 'Check risks' => sub {
  subtest 'Consistent risk assessments' => sub {
    my $buffer = '';
    {
      open my $handle, '>', \$buffer;
      local *STDOUT = $handle;
      $app->start('patterns', '--check-risks');
    }
    is $buffer, '', 'no noteworthy risk assessments';
  };

  subtest 'License with multiple risk assessments' => sub {
    my $patterns = $app->patterns;
    $patterns->create(pattern => 'My test license 1.0', license => 'MyTestLicense-1.0', risk => 7);
    $patterns->create(pattern => 'My license',          license => 'MyTestLicense-1.0', risk => 9);

    my $buffer = '';
    {
      open my $handle, '>', \$buffer;
      local *STDOUT = $handle;
      $app->start('patterns', '--check-risks');
    }
    like $buffer, qr/MyTestLicense-1.0: 7, 9/, 'multiple risk assessments detected';
  };

  subtest 'Fix risk assessment for license' => sub {
    my $buffer = '';
    {
      open my $handle, '>', \$buffer;
      local *STDOUT = $handle;
      $app->start('patterns', '-l', 'MyTestLicense-1.0', '--fix-risk', '8');
    }
    like $buffer, qr/2 patterns fixed/, 'two patterns fixed';

    $buffer = '';
    {
      open my $handle, '>', \$buffer;
      local *STDOUT = $handle;
      $app->start('patterns', '--check-risks');
    }
    is $buffer, '', 'no noteworthy risk assessments anymore';
  };
};

done_testing();
