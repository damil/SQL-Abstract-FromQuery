package SQL::Abstract::FromQuery;

use 5.010;
use strict;
use warnings;
use Scalar::Util qw/refaddr/;
use Module::Load qw/load/;
use mro 'c3';

our $VERSION = '0.01';

# root grammar (will be inherited by subclasses)
my $root_grammar = do {
  use Regexp::Grammars;
  qr{
    # <logfile: - >

    <grammar: SQL::Abstract::FromQuery>

    <rule: criterion>
       <MATCH=between>
     | <MATCH=op_and_value>
     | <MATCH=negated_values>
     | <MATCH=values>

    <rule: negated_values>
        <negate> <values>

    <rule: op_and_value>
        <compare> <value>

    <rule: values>
        <[value]>+ % ,

    <rule: between>
      BETWEEN <min=value> AND <max=value>

    <token: compare>
       <= | < | >= | >

    <token: negate>
        <> | -(?!\d) | != | !

    <rule: value>
        <MATCH=null>
      | <MATCH=date>
      | <MATCH=time>
      | <MATCH=bool>
      | <MATCH=string>

    <rule: null>
      NULL

    <rule: date>
        <day=(\d\d?)>\.<month=(\d\d?)>\.<year=(\d\d\d?\d?)>
      | <year=(\d\d\d?\d?)>-<month=(\d\d?)>-<day=(\d\d?)>

    <rule: time>
      <hour=(\d\d?)>:<minutes=(\d\d)>(?::<seconds=(\d\d)>)?

    <rule: bool>
       Y(?:ES)?     (?{ $MATCH = 1 })
     | T(?:RUE)?    (?{ $MATCH = 1 })
     | N(?:O)?      (?{ $MATCH = 0 })
     | F(?:ALSE)?   (?{ $MATCH = 0 })

    <rule: string>
        <MATCH=quoted_string>
      | <MATCH=unquoted_string>

    <rule: quoted_string>
       '(.*?)'      (?{ $MATCH = $CAPTURE })
     | "(.*?)"      (?{ $MATCH = $CAPTURE })

    <rule: unquoted_string>
       [^\s,]+

  }xms;
};





#}

#======================================================================
# CLASS METHODS
#======================================================================
sub sub_grammar {
  my $class = shift;
  return ''; # should redefine method in subclasses that refine the root grammar
}



sub new {
  my ($class, %args) = @_;

  my $self = {};
  if ($args{-components}) {
    # deactivate strict refs because we'll be playing with symbol tables
    no strict 'refs';

    # dynamically create a new anonymous class
    $class .= "::_ANON_::" . refaddr $self;
    foreach my $component (@{$args{-components}}) {
      $component =~ s/^\+//
        or $component = __PACKAGE__ . "::$component";
      load $component;
      push @{$class . "::ISA"}, $component;
      my $sub_grammar = $component->sub_grammar;
      push @{$self->{grammar_ISA}}, $sub_grammar if $sub_grammar;
    }

    # use 'c3' inheritance in that package
    mro::set_mro($class, 'c3');
  }

  # use root grammar if no derived grammar installed by components
  $self->{grammar_ISA} ||= [ 'SQL::Abstract::FromQuery' ];

  bless $self, $class;

  return $self;
}





#======================================================================
# INSTANCE METHODS
#======================================================================


sub _grammar {
  my ($self, $rule) = @_;

  my $extends = join "", map {"<extends: $_>\n"} @{$self->{grammar_ISA}};
  my $grammar = "<$rule>\n$extends";

  # compile this grammar. NOTE : since Regexp::Grammars uses a very
  # special form of operator overloading, we must go through an eval
  # so that qr/../ receives a string without variable interpolation;
  # do {use Regexp::Grammars; qr{$grammar}x;} would seem logical but won't work.
  local $@;
  my $compiled_grammar = eval "use Regexp::Grammars; qr{$grammar}x"
    or die "INVALID GRAMMAR: $@";

  return $compiled_grammar;
}




sub parse {
  my ($self, $data, $rule) = @_;
  my $class = ref $self;
  $rule ||= 'criterion';

  my %result;
  my %errors;

  my $grammar = $self->_grammar($rule);

 FIELD:
  foreach my $k (keys %$data) {
    my $val = $data->{$k} or next FIELD;

    # invoke grammar on field content
    $val =~ $grammar->with_actions($self)
      or $errors{$k} = [@!] and next FIELD;

    my $r = $/{$rule};

    $result{$k} = $r;
  }

  die \%errors if %errors;

  return \%result;
}





#======================================================================
# ACTIONS HOOKED TO THE GRAMMAR
#======================================================================

sub negated_values {
  my ($self, $h) = @_;

  my $vals = $h->{values};

  if (ref $vals) {
    ref $vals eq 'HASH' or die 'unexpected reference in negation';
    my ($op, $val, @others) = %$vals;
    not @others        or die 'unexpected hash size in negation';
    given ($op) {
      when ('-in') {return {-not_in => $val}                   }
      when ('=')   {return {'<>'    => $val}                   }
      default      {die "unexpected operator '$op' in negation"}
    }
  }
  else {
    return {'<>' => $vals};
  }
}


sub null {
  my ($self, $h) = @_;

  return {'=' => undef};
  # Note: unfortunately, can't return just undef at this stage,
  # because Regex::Grammars would interpret it as a parse failure.
}


sub op_and_value {
  my ($self, $h) = @_;

  return {$h->{compare} => $h->{value}};
}


sub between {
  my ($self, $h) = @_;

  return {-between => [$h->{min}, $h->{max}]};
}



sub values {
  my ($self, $h) = @_;

  my $n_values = @{$h->{value}};
  return $n_values > 1 ? {-in => $h->{value}}
                       : $h->{value}[0];
}


sub date {
  my ($self, $h) = @_;

  $h->{year} += 2000 if length($h->{year}) < 3;
  return sprintf "%04d-%02d-%02d", @{$h}{qw/year month day/};
}


sub time {
  my ($self, $h) = @_;
  $h->{seconds} ||= 0;
  return sprintf "%02d:%02d:%02d", @{$h}{qw/hour minutes seconds/};
}


sub string {
  my ($self, $s) = @_;

  my $is_pattern;

  while ((my $i = index($s, '*')) >= 0) {

    # substitute '*' by '%', without calling a reentrant regex
    substr($s, $i, 1, '%'); 

    $is_pattern = 1;
  }

  return $is_pattern ? {-like => $s} : $s;
}


1; # End of SQL::Abstract::FromQuery


__END__


=head1 NAME

SQL::Abstract::FromQuery - Translating an HTTP Query into SQL::Abstract structure

=head1 SYNOPSIS

  use SQL::Abstract::FromQuery;
  use SQL::Abstract; # or SQL::Abstract::More

  # instantiate
  my $parser = SQL::Abstract::FromQuery->new(
    -components => [qw/FR Oracle/],
  );

  # initial configuration
  $parser->add_type(T1 => ??);
  $parser->add_type(T2 => ??);
  $parser->declare_fields(STANDARD => qw/c1 c2 .../);
  $parser->declare_fields(T1       => qw/.../);

  # parse user input into a datastructure for SQLA "where" clause
  my $http_query = acquire_some_object_with_a_param_method();
  my $criteria   = $parser->parse($http_query);

  # build the database query
  my $sqla = SQL::Abstract->new(@sqla_parameters);
  my ($sql, @bind) = $sqla->select($datasource, \@columns, $criteria);

  # or, using SQL::Abstract::More
  my $sqlam = SQL::Abstract::More->new(@sqla_parameters);
  my ($sql, @bind) = $sqlam->select(
    -columns => \@columns,
    -from    => $datasource,
    -where   => $criteria,
   );


=head1 DESCRIPTION

This module is intended to help building Web applications with complex search forms.
It translates user input, as obtained from an HTML form, into a datastructure
suitable as a C<%where> clause for the L<SQL::Abstract> module; that module
will in turn produce the SQL statement and bind parameters to query the database.

Search criteria entered by the user can be plain values, lists of values, comparison
operators, etc. So for example if the form filled by the user looks like this :

   Name   : Smi*              Gender  : M
   Salary : > 4000            Job     : ! programmer, analyst
   Birth  : BETWEEN 01.01.1970 AND 31.12.1990

the module would produce a hashref like

   { Name      => {-like => 'Smi%'},
     Gender    => 'M',
     Salary    => {'>' => 4000},
     Job       => {-not_in => [qw/programmer analyst/]},
     Birth     => {-between => [qw/1970-01-01 1990-12-31/]},
 }

which, when fed to L<SQL::Abstract>, would produce SQL more or less
like this

  SELECT * FROM people
  WHERE Name LIKE 'Smi%'
    AND Gender = 'M'
    AND Salary > 4000
    AND Job NOT IN ('programmer', 'analyst')
    AND Birth BETWEEN 1970-01-01 AND 1990-12-31

Form fields can be associated to "types" that specify the
admissible syntax and may implement security checks.

B<Note> : this module is in alpha state. Many features still need further study;
the API and/or behaviour may change in future releases.

=head1 INPUT GRAMMAR

Input accepted in a form field can be 

=over

=item *

a plain value (number, string or date).
Strings may be optionally included in single or double quotes.
Characters C<'*'> are translated into C<'%'> because this is the 
wildcard character for SQL queries with 'LIKE'.

=item *

a list of values, separated by ','.
This will be generated a SQL clause of the form C<IN (val1, val2, ...)>.

=item *

a negated value or list of values; 
negation is expressed by C<!> or C<!=> or C<-> or C<< <> >>

=item *

a comparison operator C<< <= >>, C<< < >>, C<< >= >>, C<< >
followed by a plain value

=item *

the special word C<NULL>

=item *

C<BETWEEN> I<val1> AND I<val2>

=item *

boolean values C<YES>, C<NO>, C<TRUE> or C<FALSE>

=back

Look at the source code of this module to see the precise
syntax, expressed in L<Regexp::Grammars> format.
Syntax rules can be augmented or modified in subclasses --
see L<INHERITANCE> below.



=head1 METHODS

=head2 new

Constructs an instance. 


=head1 INHERITANCE

Subclasses may override or augment not only the methods,
but also the parsing grammar.

[explain].

See L<SQL::Abstract::FromQuery::FR> for an example.



=head1 AUTHOR

Laurent Dami, C<< <laurent.dami AT justice.ge.ch> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sql-abstract-fromquery at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SQL-Abstract-FromQuery>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SQL::Abstract::FromQuery


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SQL-Abstract-FromQuery>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SQL-Abstract-FromQuery>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SQL-Abstract-FromQuery>

=item * Search CPAN

L<http://search.cpan.org/dist/SQL-Abstract-FromQuery/>

=back





=head1 SEE ALSO

L<Class::C3::Componentised> -- similar way to load plugins in.




=head1 LICENSE AND COPYRIGHT

Copyright 2012 Laurent Dami.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.



=head1 TODO


Parameterized syntax:
  - bool
  - date
  - time
  - multi
  - pattern


  field : foo*  => -like
  field : foo*  => -contains
  field : foo   => -anyval

  field : 01.02.2003   => { \"TO_DATE()}",  }
  field : 12:10        => { \"TO_DATE()}",  }
  field : NULL
  field : !NULL
  field : =~
  mixed : foo:junk AND bar>234 OR (...)

  boolean : maybe undef should become FALSE instead of being ignored
  (think of an unchecked checkbox)


    Q: - should use $q->param(...) ? should use hash ?


=cut


