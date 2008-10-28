#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 4;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my $ini = Config::Ini::Edit->new( string => $data );

$ini->set_comments( section4 => 'name4.1', 0, 'Comment' );
my @comments = $ini->get_comments( section4 => 'name4.1' );
is( "@comments", "# Comment\n",
    'set_comments( section, name, comments(no#...\n) )' );

$ini->set_comments( section4 => 'name4.1', 0, '# Comment' );
my $comments = join '', $ini->get_comments( section4 => 'name4.1' );
is( $comments, "# Comment\n",
    'set_comments( section, name, comments(no...\n) )' );

$ini->set_comments( section4 => 'name4.1', 0, "# Comment\n" );
$comments = join '', $ini->get_comments( section4 => 'name4.1' );
is( $comments, "# Comment\n",
    'set_comments( section, name, comments(w/#...\n) )' );

$ini->set_comments( section4 => 'name4.1', 0, "abc\ndef\nghi" );
$comments = join '', $ini->get_comments( section4 => 'name4.1' );
is( $comments, "# abc\n# def\n# ghi\n",
    'set_comments( section, name, comments(multiline) )' );

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

