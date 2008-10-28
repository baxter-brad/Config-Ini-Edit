#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 17;
use Config::Ini::Edit;

# POD Examples

Terminology: {

    my $data = <<__;
# comment
[section]
name = value
__
    my $ini = Config::Ini::Edit->new( string => $data );
    my @sections = $ini->get_sections();
    my @values = $ini->get( 'section', 'name' );
    is( "@sections", 'section', 'terminology' );
    is( "@values", 'value', 'terminology' );
}

Syntax_general: {

    my $data = <<__;
# comments may begin with # or ;, i.e.,
; semicolon is valid comment character
[section]
# spaces/tabs around '=' are stripped
# use heredoc to give a value with leading spaces
# trailing spaces are left intact
name=value
name= value
name =value
name = value
name    =    value
__
    my $ini = Config::Ini::Edit->new( string => $data );
    my @sections = $ini->get_sections();
    my @values = $ini->get( 'section', 'name' );
    is( "@sections", 'section', 'syntax, general' );
    is( "@values", 'value value value value value',
        'syntax, general' );

    $data = <<__;
# this is a comment
[section] # this is a comment
name = value # this is NOT a comment

# colon is valid assignment character, too.
name:value
name: value
name :value
name : value
name    :    value
__

    $ini = Config::Ini::Edit->new( string => $data );
    @sections = $ini->get_sections();
    my $values = $ini->get( 'section', 'name' );
    is( "@sections", 'section', 'syntax, general' );
    is( $values,
        'value # this is NOT a comment value value value value value',
        'syntax, general' );
}

Syntax_heredocs: {

    my $data = <<__;
# classic
name = <<heredoc
Heredocs are supported several ways.
heredoc

# and because I kept doing this
name = <<heredoc
value
<<heredoc

# and because who cares what it's called
name = <<
value
<<

# and "block style" (for vi % support)
name = {
value
}

# and obscure variations, e.g.,
name = {heredoc
value
heredoc
__

    my $ini = Config::Ini::Edit->new( string => $data );
    my @values = $ini->get( 'name' );
    is( join('',@values),
        "Heredocs are supported several ways.\n" .
        "value\nvalue\nvalue\nvalue\n",
        'syntax, heredocs' );
}

Heredoc_chomp_join: {

    my $data = <<'__';
# $value == "Line1\nLine2\n" (unmodified)
name = <<
Line1
Line2
<<

# $value == "Line1\nLine2"
name = <<:chomp
Line1
Line2
<<

# $value == "Line1Line2\n"
name = <<:join
Line1
Line2
<<

# $value == "Line1Line2"
name = <<:chomp:join
Line1
Line2
<<
__
    my $ini = Config::Ini::Edit->new( string => $data );
    my @values = $ini->get( 'name' );
    is( join('',@values),
        "Line1\nLine2\n" .
        "Line1\nLine2" .
        "Line1Line2\n" .
        "Line1Line2",
        'heredoc modifiers, :chomp :join' );
}

Heredoc_indented: {

    my $data = <<'__';
# $value == "  Line1\n  Line2\n" (unmodified)
name = <<
  Line1
  Line2
<<

# - indentations do NOT have to be regular to be unindented
# - any leading spaces/tabs on every line will be stripped
# - trailing spaces are left intact, as usual
# $value == "Line1\nLine2\n"
name = <<:indented
  Line1
  Line2
<<

# modifiers may have spaces between
# $value == "Line1Line2"
name = << :chomp :join :indented
  Line1
  Line2
<<


# with heredoc "tag"
# $value == "Line1Line2"
name = <<heredoc :chomp :join :indented
  Line1
  Line2
heredoc
__

    my $ini = Config::Ini::Edit->new( string => $data );
    my @values = $ini->get( 'name' );
    is( join('',@values),
        "  Line1\n  Line2\n" .
        "Line1\nLine2\n" .
        "Line1Line2" .
        "Line1Line2",
        'heredoc modifiers, :chomp :join :indented' );
}

Heredoc_parse: {

    my $data = <<'__';
# :parse is same as :parse(\n)
name = <<:parse
value1
value2
<<

name = value1
name = value2

name = <<:parse(/,\s+/)
"Tom, Dick, and Harry", Fred and Wilma
<<

name = Tom, Dick, and Harry
name = Fred and Wilma

# liberal separators
name = <<:parse([,\s\n]+)
"Tom, Dick, and Harry" "Fred and Wilma"
Martha George, 'Hillary and Bill'
<<

name = Tom, Dick, and Harry
name = Fred and Wilma
name = Martha
name = George
name = Hillary and Bill
__
    my $ini = Config::Ini::Edit->new( string => $data );
    my @values = $ini->get( 'name' );
    is( join( '', @values ),
        'value1' .
        'value2' .
        'value1' .
        'value2' .

        'Tom, Dick, and Harry' .
        'Fred and Wilma' .
        'Tom, Dick, and Harry' .
        'Fred and Wilma' .

        'Tom, Dick, and Harry' .
        'Fred and Wilma' .
        'Martha' .
        'George' .
        'Hillary and Bill' .
        'Tom, Dick, and Harry' .
        'Fred and Wilma' .
        'Martha' .
        'George' .
        'Hillary and Bill',
        'heredoc modifiers, :parse' );
}

Get: {

    my $data = <<__;
[section]
name = value1
name = value2
name = value3
__
    my $ini = Config::Ini::Edit->new( string => $data );
    my $section = 'section';
    my $name = 'name';
    {
    my @values = $ini->get( $section, $name );
    is( join('',@values), 'value1value2value3', 'get(section,name)' );
    }{
    my $value = $ini->get( $section, $name, 0 ); # get first one
    is( $value, 'value1', 'get(section,name,0)' );
    }{
    my $value = $ini->get( $section, $name, 1 ); # get second one
    is( $value, 'value2', 'get(section,name,1)' );
    }{
    my $value = $ini->get( $section, $name, -1 ); # get last one
    is( $value, 'value3', 'get(section,name,-1)' );
    }

    $data = <<__;
    title = Hello World
    color: blue
    margin: 0
__
    $ini = Config::Ini::Edit->new( string => $data );
    $name = 'color';
    my @values = $ini->get( $name );         # assumes $section==''
    is( "@values", 'blue', 'get(name)' );
    my $value  = $ini->get( '', $name, 0 );  # get first occurrence
    is( $value, 'blue', "get('',name,0)" );
    {
    my $value  = $ini->get( '', $name, -1 ); # get last occurrence
    is( $value, 'blue', "get('',name,-1)" );
    }

}


