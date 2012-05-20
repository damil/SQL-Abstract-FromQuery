use strict;
use warnings;
use Test::More;

use lib "../lib";

use Module::Load;
load 'SQL::Abstract::FromQuery::FR';


diag( "Testing SQL::Abstract::FromQuery $SQL::Abstract::FromQuery::VERSION, Perl $], $^X" );

my $parser = SQL::Abstract::FromQuery->new(-components => [qw/FR/]);


my %tests = (
# test_name      => [$given, $expected]
# =========         ===================

  null           => ['NUL',
                     undef],
  bool_oui       => ['OUI',
                     1],
  bool_non       => ['N',
                     0],

);

my %data = map {$_ => $tests{$_}[0]} keys %tests;

plan tests => scalar keys %data;


my $where = $parser->parse(\%data);

while (my ($test_name, $test_data) = each %tests) {
  is_deeply($where->{$test_name}, $test_data->[1], $test_name);
}



