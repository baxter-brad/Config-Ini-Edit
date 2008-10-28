#!/usr/local/bin/perl
use warnings;
use strict;

use Test::More tests => 19;

use Config::Ini::Edit;

my $data = <<'__';
name = value
name = 'value'
name = "value"
[section1]
name1 = value\n
name2 = 'value\n'
name3 = "value\n"
[section2]
name1 = '''value'''
name2 = "\"value\""
[section3]
name1 = "\v\e\n\t\\\P\0\r\N\_\f\L\a\b";
name2 = "\x11\x2222\u3333"
[section4]
name = <<
value
<<
name = <<''
value
<<
name = <<""
value
<<
[section5]
name1 = <<
value\n
<<
name2 = <<''
value\n
<<
name3 = <<""
value\n
<<
[section6]
name1 = <<''
'value'
<<
name2 = <<""
"value"
<<
[section7]
name1 = <<":chomp"
\v\e\n\t\\\P\0\r\N\_\f\L\a\b
<<
name2 = <<":chomp"
\x11\x2222\u3333
<<
[section8]
name1 = <<":html:chomp"
\_&pound;&nbsp;&amp;&nbsp;&yen;\_
<<
name2 = <<":slash:chomp"
\_&pound;&nbsp;&amp;&nbsp;&yen;\_
<<
name3 = <<":html:slash:chomp"
\_&pound;&nbsp;&amp;&nbsp;&yen;\_
<<
__

my $ini = Config::Ini::Edit->new( string => $data );

is( $ini->get( 'name' ), 'value value value',
    'simple value ('.__LINE__.')' );

is( $ini->get( section1=>'name1' ), 'value\n',
    'no quotes ('.__LINE__.')' );

is( $ini->get( section1=>'name2' ), 'value\n',
    'single quotes ('.__LINE__.')' );

is( $ini->get( section1=>'name3' ), "value\n",
    'double quotes ('.__LINE__.')' );

is( $ini->get( section2=>'name1' ), "'value'",
    'embedded single quotes ('.__LINE__.')' );

is( $ini->get( section2=>'name2' ), '"value"',
    'embedded double quotes ('.__LINE__.')' );

# escapes:
# 0 => "\x00", a    => "\x07", b => "\x08", t => "\x09",
# n => "\x0a", v    => "\x0b", f => "\x0c", r => "\x0d",
# e => "\x1b", '\\' => '\\',   N => "\x85", _ => "\xa0",
# L => "\x{2028}",  P => "\x{2029}",
is( $ini->get( section3=>'name1' ),
    "\x0b\x1b\x0a\x09\\\x{2029}\x00\x0d\x85\xa0\x0c\x{2028}\x07\x08",
    'escapes ('.__LINE__.')' );

is( $ini->get( section3=>'name2' ),
    "\x11\x{2222}\x{3333}",
    'slash \x escapes ('.__LINE__.')' );

is( $ini->get( section4=>'name' ),
    "value\n value\n value\n",
    'heredoc simple values ('.__LINE__.')' );

is( $ini->get( section5=>'name1' ), "value\\n\n",
    'no quotes ('.__LINE__.')' );

is( $ini->get( section5=>'name2' ), "value\\n\n",
    'single quotes ('.__LINE__.')' );

is( $ini->get( section5=>'name3' ), "value\n\n",
    'double quotes ('.__LINE__.')' );

is( $ini->get( section6=>'name1' ), "'value'\n",
    'single quotes ('.__LINE__.')' );

is( $ini->get( section6=>'name2' ), qq{"value"\n},
    'double quotes ('.__LINE__.')' );

is( $ini->get( section7=>'name1' ),
    "\x0b\x1b\x0a\x09\\\x{2029}\x00\x0d\x85\xa0\x0c\x{2028}\x07\x08",
    'escapes ('.__LINE__.')' );

is( $ini->get( section7=>'name2' ),
    "\x11\x{2222}\x{3333}",
    'slash \x escapes ('.__LINE__.')' );

is( $ini->get( section8=>'name1' ),
    "\\_\xA3\xA0\x26\xA0\xA5\\_",
    'html(!slash) escapes ('.__LINE__.')' );

is( $ini->get( section8=>'name2' ),
    "\xA0&pound;&nbsp;&amp;&nbsp;&yen;\xA0",
    'slash(!html) escapes ('.__LINE__.')' );

is( $ini->get( section8=>'name3' ),
    "\xA0\xA3\xA0\x26\xA0\xA5\xA0",
    'html+slash escapes ('.__LINE__.')' );

