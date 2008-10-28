#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 2;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

my $ini2 = Config::Ini::Edit->new();
$ini2->init( string => $data );

is( $ini->as_string(), $ini2->as_string(),
    'init() vs new()' );

# should match __DATA__ ...

is(  $ini->as_string(), <<'__', 'as_string() (w/comments)' );
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
name2.3 = {here
value2.3value2.3
}here
name2.4 = value2.4
name2.4 = value2.4

__

__DATA__
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

