#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

# comments include blank lines (and newlines)

my $comments = $ini->get_comments( section1 => 'name1.1' );
is( $comments, "\n# Name 1.1\n",
    'get_comments( section, name ) ('.__LINE__.')' );

$comments = $ini->get_comments( section1 => 'name1.2' );
is( $comments, "\n# Name 1.2a\n",
    'get_comments( section, name ) ('.__LINE__.')' );
        
$comments = $ini->get_comments( section1 => 'name1.2', 0 );
is( $comments, "\n# Name 1.2a\n",
    'get_comments( section, name ) ('.__LINE__.')' );
        
$comments = $ini->get_comments( section1 => 'name1.2', 1 );
is( $comments, "# Name 1.2b\n",
    'get_comments( section, name ) ('.__LINE__.')' );
        

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

