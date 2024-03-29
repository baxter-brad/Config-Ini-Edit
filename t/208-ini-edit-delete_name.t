#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 3;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

$ini->delete_name( section1 => 'name1.1' );
my @names = $ini->get_names( 'section1' );
is( "@names", 'name1.2', 'delete_name( s, n )' );

$ini->delete_name( '' => 'name0.1' );
@names = $ini->get_names( '' );
is( "@names", 'name0.2 name0.3', "delete_name( '', n )" );

$ini->delete_name( 'name0.2' );
@names = $ini->get_names();
is( "@names", 'name0.3', 'delete_name( n )' );

__DATA__
# null section

name0.1 = value0.1
name0.2 = value0.2
name0.3 = value0.3

# Section 1

[section1]

# Name 1.1
name1.1 = value1.1

# Name 1.2a
name1.2 = value1.2a
# Name 1.2b
name1.2 = value1.2b

# Section 2

[section2]

# Name 2.1

name2.1 = {
value2.1
}
name2.2 = <<:chomp
value2.2
value2.2
<<
name2.3 = {here :join
value2.3
value2.3
}here
name2.4 = <<here :parse(/\n/)
value2.4
value2.4
<<here

