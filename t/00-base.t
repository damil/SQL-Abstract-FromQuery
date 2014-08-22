use strict;
use warnings;
use Test::More;

use lib "../lib";

use SQL::Abstract::FromQuery;

diag( "Testing SQL::Abstract::FromQuery "
    . "$SQL::Abstract::FromQuery::VERSION, Perl $], $^X" );

my $parser = SQL::Abstract::FromQuery->new(
  -fields => {IGNORE => qr/^foo/},
);

my %tests = (
# test_name      => [$given, $expected]
# =========         ===================
  regular        => ['foo',
                     'foo'],
  list           => ['foo,bar, buz',
                     {-in => [qw/foo bar buz/]}],
  neg            => ['!foo',
                     {'<>' => 'foo'}],
  neg_list       => ['!foo,bar,buz',
                     {-not_in => [qw/foo bar buz/]}],
  neg_minus      => ['-foo',
                     {'<>' => 'foo'}],
  num            => ['-123',
                     -123],
  between        => ['BETWEEN a AND z',
                     {-between => [qw/a z/]}],
  pattern        => ['foo*',
                     {-like => 'foo%'}],
  greater        => ['> foo',
                     {'>' => 'foo'}],
  greater_or_eq  => ['>= foo',
                     {'>=' => 'foo'}],
  null           => ['NULL',
                     {'=' => undef}
                    ],
  not_null       => ['!NULL',
                     {'<>' => undef}
                    ],
  date_dash      => ['03-2-1',
                     '2003-02-01'],
  date_dot       => ['1.2.03',
                     '2003-02-01'],
  time           => ['1:02',
                     '01:02:00'],
  quoted         => ['"foo  bar"',
                     'foo  bar'],

  foo1           => ['BETWEEN ! - %*"', # will be IGNOREd
                     undef],

);

my %data = map {$_ => $tests{$_}[0]} keys %tests;

plan tests => scalar keys %data;


my $where = $parser->parse(\%data);

while (my ($test_name, $test_data) = each %tests) {
  is_deeply($where->{$test_name}, $test_data->[1], $test_name);
}




