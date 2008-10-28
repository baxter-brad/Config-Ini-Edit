#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 2;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

my $comments = $ini->get_section_comments( 'section1' );
is( $comments, "# Section 1\n\n",
    'get_section_comments( section ) ('.__LINE__.')' );
        
my $comment = $ini->get_section_comment( 'section1' );
is( $comment, " # I'm a section",
    'get_section_comment( section ) ('.__LINE__.')' );
        

__DATA__
# Section 1

[section1] # I'm a section

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

