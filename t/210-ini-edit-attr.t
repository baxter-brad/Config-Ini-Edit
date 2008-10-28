#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 11;

use Config::Ini::Edit;

my $data = do{ local $/; <DATA> };

my %defaults = (
    file          => undef,  # because we used string => ...
    keep_comments => 1,
    heredoc_style => '<<',
);

for my $attr ( qw( file keep_comments heredoc_style ) ) {

    my $ini = Config::Ini::Edit->new( string => $data );
    is( $ini->_attr( $attr ), $defaults{ $attr },
        "_attr( $attr ) (default)" );

    is( $ini->_attr( $attr, 1 ), 1, "_attr( $attr, 1 ) (set)" );
    is( $ini->_attr( $attr    ), 1, "_attr( $attr ) (get)" );

    next if $attr eq 'file'; # can't preset

    no strict 'refs';
    ${"Config::Ini::Edit::$attr"} = 1;
    $ini = Config::Ini::Edit->new( string => $data );

    is( $ini->_attr( $attr ), 1, "_attr( $attr ) (preset)" );
}

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

