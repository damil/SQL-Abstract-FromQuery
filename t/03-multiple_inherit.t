use strict;
use warnings;
use Test::More;

use lib "../lib";

use Module::Load;
load 'SQL::Abstract::FromQuery::Oracle';

my $parser = SQL::Abstract::FromQuery->new(-components => [qw/FR Oracle/]);

my %tests = (
# test_name      => [$given, $expected]
# =========         ===================

  date           => ['1.2.03',
                     \ ["to_date(?, 'YYYY-MM-DD')", '2003-02-01']
                    ],
  bool_oui       => ['OUI',
                     1],

);

my %data = map {$_ => $tests{$_}[0]} keys %tests;

plan tests => scalar keys %data;


my $where = $parser->parse(\%data);

while (my ($test_name, $test_data) = each %tests) {
  is_deeply($where->{$test_name}, $test_data->[1], $test_name);
}



