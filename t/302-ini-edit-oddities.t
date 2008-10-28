#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 6;

use Config::Ini::Edit;

my $data = <<'__';
[section]
name1 = "value1" # "comment1"
'name2=abc' = "value2" # "comment2"
' name3 = ''xyz'' ' = "value3" # "comment3"
"name4\n=abc\t" = "value4" # "comment4"
" \tname5 = \"xyz\"\n " = "value5" # "comment5"
__

my $ini = Config::Ini::Edit->new(
    string => $data );

is( $ini->as_string(), $data, 
    'as_string() ('.__LINE__.')' );

is( $ini->get( section=>'name1' ), 'value1',
    'unquoted ('.__LINE__.')' );

is( $ini->get( section=>'name2=abc' ), 'value2',
    'single quoted ('.__LINE__.')' );

is( $ini->get( section=>' name3 = \'xyz\' ' ), 'value3',
    'single quoted, more ('.__LINE__.')' );

is( $ini->get( section=>"name4\n=abc\t" ), 'value4',
    'double quoted ('.__LINE__.')' );

is( $ini->get( section=>qq' \tname5 = "xyz"\n ' ), 'value5',
    'double quoted, more ('.__LINE__.')' );

