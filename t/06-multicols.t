use strict;
use warnings;
use Test::More;

use SQL::Abstract::FromQuery;

my $parser = SQL::Abstract::FromQuery->new(
  -multicols_sep => '/',
);

my $criteria = $parser->parse({
  'a/b/c' => '1/2/3, 4/5/6',
  'd/e'   => '7/8',
  'foo'   => 'bar',
});

my $expected = {foo  => 'bar',
                -and => [ {-or => [ {a => 1, b => 2, c => 3},
                                    {a => 4, b => 5, c => 6} ]},
                          {d => 7, e => 8},
                         ]};

# note explain $criteria;
is_deeply($criteria, $expected, 'multicols');

# test that a regular request (without multicols) works normally
$criteria = $parser->parse({
  foo => 123,
  bar => 456,
 });
$expected = {
  foo => 123,
  bar => 456,
 };
is_deeply($criteria, $expected, 'regular');

done_testing;



