package SQL::Abstract::FromQuery::FR;

use strict;
use warnings;
use parent 'SQL::Abstract::FromQuery';


# redefine rules 'null' and 'bool' from the root grammar
{
  use Regexp::Grammars;

  return qr{
    <grammar: SQL::Abstract::FromQuery::FR>

    <extends: SQL::Abstract::FromQuery>

    <rule: null>
      NULL?

    <rule: bool>
       O(?:UI)?     (?{ $MATCH = 1 })
     | V(?:RAI)?    (?{ $MATCH = 1 })
     | N(?:ON)?     (?{ $MATCH = 0 })
     | F(?:AUX)?    (?{ $MATCH = 0 })

  }xms;
};


sub sub_grammar {
  my $class = shift;
  return 'SQL::Abstract::FromQuery::FR';
}


1; # End of SQL::Abstract::FromQuery::FR

__END__


=head1 NAME

SQL::Abstract::FromQuery::FR - SQL::Abstract::FromQuery extension for French dates and times


=head1 SYNOPSIS

=head1 EXPORT



=head1 AUTHOR

Laurent Dami, C<< <laurent.dami AT justice.ge.ch> >>

=cut


