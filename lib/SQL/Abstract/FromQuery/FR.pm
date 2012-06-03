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

    <rule: between>
        <SQL::Abstract::FromQuery::between> 
      | ENTRE (*COMMIT) (?: <min=value> ET <max=value>  | <error:> )

    <rule: bool>
       O(?:UI)?        (?{ $MATCH = 1 })
     | V(?:RAI)?       (?{ $MATCH = 1 })
     | NO?N?           (?{ $MATCH = 0 })
     | F(?:AUX|ALSE)?  (?{ $MATCH = 0 })
     | Y(?:ES)?        (?{ $MATCH = 1 })

  }xms;
};


#======================================================================
# CLASS METHODS
#======================================================================

sub sub_grammar {
  my $class = shift;
  return ('SQL::Abstract::FromQuery::FR');
}


sub _error_handler {
  my $class = shift;
  return 'SAISIE INCORRECTE', sub {
    my ($error, $rule, $context)  = @_;

    my $msg = {
      negated_values => 'Aucune valeur apr�s la n�gation',
      op_and_value   => "Aucune valeur apr�s l'op�rateur de comparaison",
      between        => 'Pas de valeurs min/max apr�s "ENTRE/BETWEEN"',
      standard       => 'Texte inattendu apr�s la valeur initiale',
    }->{$rule};
    $msg //= "Impossible d'appliquer la r�gle '$rule'";
    $msg  .= " ('$context')" if $context;
    return $msg;
  };
}

#======================================================================
# ACTIONS HOOKED TO THE GRAMMAR
#======================================================================

sub between {
  my ($self, $h) = @_;

  return
    # if parent method was already invoked through grammar inheritance
       $h->{'SQL::Abstract::FromQuery::between'}
    # otherwise, call parent explicitly with data from the present grammar
    || $self->next::method($h);
}


#======================================================================
1; # End of SQL::Abstract::FromQuery::FR
#======================================================================

__END__


=head1 NAME

SQL::Abstract::FromQuery::FR - SQL::Abstract::FromQuery extension for French dates and times


=head1 SYNOPSIS

  my $parser = SQL::Abstract::FromQuery->new(-components => [qw/FR/]);


=head1 EXPORT



=head1 AUTHOR

Laurent Dami, C<< <laurent.dami AT justice.ge.ch> >>

=cut


