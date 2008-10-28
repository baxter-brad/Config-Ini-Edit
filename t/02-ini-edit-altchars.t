#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 14;
use Data::Dumper;
use Config::Ini::Edit;

my $ini_data = do{ local $/; <DATA> };

Init_vs_New: {

    my $data = $ini_data;

    my $ini1 = Config::Ini::Edit->new( string => $data );
    my $dump1 = Dumper $ini1;

    my $ini2 = Config::Ini::Edit->new();
    $ini2->init( string => $data );
    my $dump2 = Dumper $ini2;

    is( $dump1, $dump2, 'init() vs new()' );

}

Get_Methods: {

    my $data = $ini_data;

    my $ini = Config::Ini::Edit->new( string => $data );

    my @sections = $ini->get_sections();
    is( "@sections", 'section1 section2',
        'get_sections()' );

    my @names = map { $ini->get_names( $_ ) } @sections;
    is( "@names", 'name1.1 name1.2 name2.1 name2.2 name2.3 name2.4',
        'get_names()' );

    is( $ini->get( section1 => 'name1.1' ), 'value1.1',
        'get( section, name )' );

    is( $ini->get( section1 => 'name1.2', 1 ), 'value1.2b',
        'get( section, name, i )' );

    my @values = $ini->get( section2 => 'name2.1' );
    is( "@values", "value2.1\n",
        'get( section, name ) (heredoc)' );

    @values = $ini->get( section2 => 'name2.2' );
    is( "@values", "value2.2\nvalue2.2",
        'get( section, name ) (heredoc :chomp)' );

    @values = $ini->get( section2 => 'name2.3' );
    is( "@values", "value2.3value2.3\n",
        'get( section, name ) (heredoc :join)' );

    @values = $ini->get( section2 => 'name2.4' );
    is( "@values", "value2.4 value2.4",
        'get( section, name ) (heredoc :parse)' );


}

Add_Methods: {

    my $data = $ini_data;
    my $ini = Config::Ini::Edit->new( string => $data );

    $ini->add( section3 => 'name3.1', 'value3.1' );
    is( $ini->get( section3 => 'name3.1' ), 'value3.1',
        'add( section, name, value )' );

    $ini->add( section4 => 'name4.1', 'value4.1' );
    is( $ini->get( section4 => 'name4.1' ), 'value4.1',
        'add( section(new), name, value )' );

}

Attributes: {

    my $data = $ini_data;
    my %defaults = (
        file => undef,
    );

    for my $attr ( keys %defaults ) {

        my $ini = Config::Ini::Edit->new( string => $ini_data );
        is( $ini->_attr( $attr ), $defaults{ $attr },
            "_attr( $attr ) (default)" );

        is( $ini->_attr( $attr, 1 ), 1, "_attr( $attr, 1 ) (set)" );
        is( $ini->_attr( $attr    ), 1, "_attr( $attr ) (get)" );

    }
}

__DATA__
; Section 1

[section1]

; Name 1.1
name1.1 : value1.1

; Name 1.2a
name1.2 : value1.2a
; Name 1.2b
name1.2 : value1.2b

; Section 2

[section2]

; Name 2.1

name2.1 : {
value2.1
}
name2.2 : <<:chomp
value2.2
value2.2
<<
name2.3 : {here :join
value2.3
value2.3
}here
name2.4 : <<here :parse(\n)
value2.4
value2.4
<<here
