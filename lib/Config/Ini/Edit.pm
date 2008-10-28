#---------------------------------------------------------------------
package Config::Ini::Edit;

use 5.008000;
use strict;
use warnings;
use Carp;

=head1 NAME

Config::Ini::Edit - ini style configuration file reader/writer

=head1 SYNOPSIS

 use Config::Ini::Edit;
 
 my $ini = Config::Ini::Edit->new( 'file.ini' );
 
 # traverse the values
 for my $section ( $ini->get_sections() ) {
     print "$section\n";
 
     for my $name ( $ini->get_names( $section ) {
         print "  $name\n";
 
         for my $value ( $ini->get( $section, $name ) ) {
             print "    $value\n";
         }
     }
 }
 
 # rewrite the file
 my $inifile = $ini->file();
 open INI, '>', $inifile or die "Can't open $inifile: $!";
 print INI $ini->as_string();
 close INI;

=head1 VERSION

    VERSION: 0.10

=cut

# more POD follows the __END__

our $VERSION = '0.10';

our @ISA = qw( Config::Ini );
use Config::Ini;
use Config::Ini::Quote ':all';
use Text::ParseWords;
use JSON;
$JSON::Pretty  = 1;
$JSON::BareKey = 1;  # *accepts* bare keys
$JSON::KeySort = 1;

our $keep_comments = 1;     # boolean, user may set to 0
our $heredoc_style = '<<';  # for as_string()

use constant SECTIONS => 0;
use constant SHASH    => 1;
use constant ATTRS    => 2;
use constant NAMES  => 0;
use constant NHASH  => 1;
use constant SCMTS  => 2;
use constant VALS  => 0;
use constant CMTS  => 1;
use constant VATTR => 2;
# VATTR: {
#     quote     => [',"],
#     nquote    => [',"],
#     equals    => ' = ',
#     comment   => 'string',
#     herestyle => [{,{},<<,<<<<],
#     heretag   => 'string',
#     escape    => ':slash' and/or ':html',
#     indented  => indented value
#     json      => ':json',
# }

# object structure summary:
#           [
# SECTIONS:     [ 'section1', ],
# SHASH:        {
#                   section1 => [
#     NAMES:            [ 'name1', ],
#     NHASH:            {
#                           name1 => [
#         VALS:                 [ $value1, ],
#         CMTS:                 [ $comments, ],
#         VATTR:                [ $val_attrs, ],
#                           ],
#                       },
#     SCMTS:            [ $comments, $comment ],
#                   ],
#               },
# ATTRS:        { ... },
#           ],

# A note about the object structure:
# 
# I debated making the section comments and the value
# comments more parallel, i.e., either have 'comments' and
# 'comment' section and value attributes, or have the
# value comments be CMTS: [ [ $comments, $comment], ],
# 
# I decided to leave them as is for a couple of reasons: 1) I
# think adding a hash of section attributes just for comments
# is too much, and 2) treating the value 'comment' as an
# attribute makes sense, because it can affect the quote
# attribute (the value must be quoted if there's a 'comment')
# 
# The fact that this note is here indicates that I'm not 100%
# happy with either choice.

# autoloaded accessors
use subs qw( file keep_comments heredoc_style );

#---------------------------------------------------------------------
# inherited methods
## new()                                    see Config::Ini
## $ini->get_names( $section )              see Config::Ini
## $ini->get( $section, $name, $i )         see Config::Ini
## $ini->add( $section, $name, @values )    see Config::Ini
## $ini->set( $section, $name, $i, $value ) see Config::Ini
## $ini->put( $section, $name, @values )    see Config::Ini
## $ini->delete_section( $section )         see Config::Ini
## $ini->delete_name( $section, $name )     see Config::Ini
## $ini->_attr( $attribute, $value )        see Config::Ini
## $ini->_autovivify( $section, $name )     see Config::Ini

#---------------------------------------------------------------------
## $ini->init( $file )            or
## $ini->init( file   =>$file   ) or
## $ini->init( fh     =>$fh     ) or
## $ini->init( string =>$string )
sub init {
    my ( $self, @parms ) = @_;

    my ( $file, $fh, $string );
    my ( $keep, $style );
    my %parms;
    if( @parms == 1 ) { %parms = ( file => $parms[0] ) }
    else              { %parms = @parms }
    $file   = $parms{'file'};
    $fh     = $parms{'fh'};
    $string = $parms{'string'};
    for( qw( keep_comments heredoc_style ) ) {
        no strict 'refs';
        $self->_attr( $_ => $parms{ $_ } || $$_ );
    }
    $self->_attr( file => $file ) if $file;

    my $keep_comments =
        $self->_attr( 'keep_comments' ) || $keep_comments;

    unless( $fh ) {
        if( $string ) {
            open $fh, '<', \$string
                or croak "Can't open string: $!"; }
        elsif( $file ) {
            open $fh, '<', $file
                or croak "Can't open $file: $!"; }
        else { croak "Invalid parms" }
    }

    my $section = '';
    my $name = '';
    my $value;
    my %vattr;
    my $comment;
    my $pending_comments = '';
    my %i;
    my $resingle = qr/' (?:  '' | [^'] )* '/x;
    my $redouble = qr/" (?: \\" | [^"] )* "/x;
    my $requoted = qr/ $resingle|$redouble /x;

    local *_;
    while( <$fh> ) {
        my $parse  = '';
        my $escape = '';
        my $json   = '';
        my $heredoc = '';
        my $q = '';

        # comment or blank line
        if( /^\s*[#;]/ or /^\s*$/ ) {
            next unless $keep_comments;
            $pending_comments .= $_;
            next;
        }

        # [section]
        if( /^\[([^\]]+)\](\s*[#;].*\s*)?/ ) {
            $section = $1;
            my $comment = $2;
            $self->_autovivify( $section );
            next unless $keep_comments;
            if( $pending_comments ) {
                $self->set_section_comments( $section, $pending_comments );
                $pending_comments = '';
            }
            $self->set_section_comment( $section, $comment ) if $comment;
            next;
        }  # if

        # <<heredoc
        # Note: name = {xyz} <<xyz>> must not be seen as a heredoc
        elsif(
            /^\s*($requoted)(\s*[=:]\s*)(<<|{)\s*([^}>]*?)\s*$/ or
            /^\s*(.+?)(\s*[=:]\s*)(<<|{)\s*([^}>]*?)\s*$/ ) {
            $name       = $1;
            $vattr{'equals'} = $2;
            my $style   = $3;
            my $heretag = $4;

            $value = '';

            my $endtag = $style eq '{' ? '}' : '<<';

            ( $q, $heretag, $comment ) = ( $1, $2, $3 )
                if $heretag =~ /^(['"])(.*)\1(\s*[#;].*)?/;
            my $indented = ($heretag =~ s/\s*:indented\s*//i ) ? 1 : '';
            my $join     = ($heretag =~ s/\s*:join\s*//i )     ? 1 : '';
            my $chomp    = ($heretag =~ s/\s*:chomp\s*//i)     ? 1 : '';
            $json   = ($heretag =~ s/\s*(:json)\s*//i)  ? $1 : '';
            $escape .= ($heretag =~ s/\s*(:html)\s*//i)  ? $1 : '';
            $escape .= ($heretag =~ s/\s*(:slash)\s*//i) ? $1 : '';
            $parse = $1   if $heretag =~ s/\s*:parse\s*\(\s*(.*?)\s*\)\s*//;
            $parse = '\n' if $heretag =~ s/\s*:parse\s*//;
            my $extra = '';  # strip unrecognized (future?) modifiers
            $extra .= $1 while $heretag =~ s/\s*(:\w+)\s*//;

            my $found_end;
            while( <$fh> ) {
                if( $heretag eq '' ) {
                    if( /^\s*$endtag\s*$/ ) {
                        $style .= $endtag;
                        ++$found_end;
                    }
                }
                else {
                    if( ( /^\s*\Q$heretag\E\s*$/ ||
                        /^\s*$q\Q$heretag\E$q\s*$/ ) ) {
                        ++$found_end;
                    }
                    elsif( ( /^\s*$endtag\s*\Q$heretag\E\s*$/ ||
                        /^\s*$endtag\s*$q\Q$heretag\E$q\s*$/ ) ) {
                        $style .= $endtag;
                        ++$found_end;
                    }
                }

                last         if $found_end;
                chomp $value if $join;
                if( $indented ) {
                    if( s/^(\s+)// ) {
                        $indented = $1 if $indented !~ /^\s+$/;
                    }
                }
                $value .= $_;

            }  # while

            die "Didn't find heredoc end tag ($heretag) " .
                "for $section:$name" unless $found_end;

            # ':parse' enables ':chomp', too
            chomp $value if $chomp or $parse ne '';

            # value attributes (n/a if value parsed)
            if( $parse eq '' ) {
                $vattr{'quote'    } = $q        if $q;
                $vattr{'heretag'  } = $heretag  if $heretag;
                $vattr{'herestyle'} = $style    if $style;
                $vattr{'json'     } = $json     if $json;
                $vattr{'escape'   } = $escape   if $escape;
                $vattr{'indented' } = $indented if $indented;
                $vattr{'extra'    } = $extra    if $extra;
            }

            $heredoc = 1;

        }  # elsif (heredoc)

        # "name" = value
        elsif( /^\s*($requoted)(\s*[=:]\s*)(.*)$/ ) {
            $name = $1;
            $vattr{'equals'} = $2;
            $value = $3;
            $vattr{'nquote'} = substr $name, 0, 1;
        }

        # name = value
        elsif( /^\s*(.+?)(\s*[=:]\s*)(.*)$/ ) {
            $name = $1;
            $vattr{'equals'} = $2;
            $value = $3;
        }

        # "bare word" (treated as boolean set to true(1))
        else {
            s/^\s+//g; s/\s+$//g;
            $name = $_;
            $value = 1;
        }

        my $quote = sub {
            my( $v, $q, $escape ) = @_;
            return $q eq "'"?
                &parse_single_quoted:
                &parse_double_quoted;
            };

        if( $heredoc ) {
            $value = parse_double_quoted( $value, '', $escape )
                if $q eq '"';
        }
        elsif( $value =~ /^($requoted)(\s*[#;].*)?$/ ) {
            my $q = substr $1, 0, 1;
            $value = $quote->( $1, $q, $escape );
            $vattr{'quote'} = $q;
            $comment = $2 if $2 and $keep_comments;
        }

        # to allow "{INI:general:self}" = some value
        # or "A rose,\n\tby another name,\n" = smells as sweet
        if( $name =~ /^(['"]).*\1$/sm ) {
            $name = $quote->( $name, $1 );
        }

        $vattr{'comment'} = $comment if $comment;
        $comment = '';

        if( $parse ne '' ) {
            $parse = $quote->( $parse, $1 )
                if $parse =~ m,^(['"/]).*\1$,;
            $self->add( $section, $name,
                map { (defined $_) ? $_ : '' }
                parse_line( $parse, 0, $value ) );
        }
        else {
            $value = jsonToObj $value if $json;
            $self->add( $section, $name, $value );
            $self->vattr( $section, $name, $i{ $section }{ $name },
                %vattr ) if %vattr;
        }

        %vattr = ();

        if( $pending_comments ) {
            $self->set_comments( $section, $name,
                $i{ $section }{ $name }, $pending_comments );
            $pending_comments = '';
        }

        $i{ $section }{ $name }++;

    }  # while

    if( $pending_comments ) {
        $self->set_section_comments( '__END__', $pending_comments );
    }

}  # end sub init

#---------------------------------------------------------------------
## $ini->get_sections( $all )
sub get_sections {
    my ( $self, $all ) = @_;

    return unless defined $self->[SECTIONS];
    return @{$self->[SECTIONS]} if $all;
    return grep $_ ne '__END__', @{$self->[SECTIONS]};
}

#---------------------------------------------------------------------
## $ini->get_comments( $section, $name, $i )
sub get_comments {
    my ( $self, $section, $name, $i ) = @_;
    return unless defined $section and defined $name;
    $i = 0 unless defined $i;

    my $aref = $self->[SHASH]{ $section }[NHASH]{ $name }[CMTS];
    return unless $aref;
    return $aref->[ $i ];
}

#---------------------------------------------------------------------
## $ini->set_comments( $section, $name, $i, @comments )
sub set_comments {
    return unless @_ >= 5;
    my ( $self, $section, $name, $i, @comments ) = @_;
    $i = 0 unless defined $i;

    for( @comments ) {
        s/^(?!\s*[#;\n])/# /mg;
        s/$/\n/ unless /\n$/;
    }

    $self->_autovivify( $section, $name );
    $self->[SHASH]{ $section }[NHASH]{ $name }[CMTS][ $i ] =
        join '', @comments;
}

#---------------------------------------------------------------------
## $ini->get_comment( $section, $name, $i )
sub get_comment {
    my ( $self, $section, $name, $i ) = @_;
    return unless defined $section and defined $name;
    $i = 0 unless defined $i;

    return $self->vattr( $section, $name, $i, 'comment' );
}

#---------------------------------------------------------------------
## $ini->set_comment( $section, $name, $i, @comments )
sub set_comment {
    return unless @_ >= 5;
    my ( $self, $section, $name, $i, @comments ) = @_;

    my $comment = join( "\n", @comments );
    for( $comment ) {
        s/\n+$//;
        s/\n/ /g;
        s/^(?!\s*[#;])/ # /;
    }

    $self->vattr( $section, $name, $i, comment => $comment );
}

#---------------------------------------------------------------------
## $ini->get_section_comments( $section )
sub get_section_comments {
    my ( $self, $section ) = @_;
    return unless defined $section;

    return $self->[SHASH]{ $section }[SCMTS][0]
        if $self->[SHASH]{ $section }[SCMTS];
}

#---------------------------------------------------------------------
## $ini->set_section_comments( $section, @comments )
sub set_section_comments {
    return unless @_ >= 3;
    my ( $self, $section, @comments ) = @_;

    for( @comments ) {
        s/^(?!\s*[#;\n])/# /mg;
        s/$/\n/ unless /\n$/;
    }

    $self->_autovivify( $section );
    $self->[SHASH]{ $section }[SCMTS][0] = join( '', @comments );
}

#---------------------------------------------------------------------
## $ini->get_section_comment( $section )
sub get_section_comment {
    my ( $self, $section ) = @_;
    return unless defined $section;

    return $self->[SHASH]{ $section }[SCMTS][1]
        if $self->[SHASH]{ $section }[SCMTS];
}

#---------------------------------------------------------------------
## $ini->set_section_comment( $section, @comments )
sub set_section_comment {
    return unless @_ >= 3;
    my ( $self, $section, @comments ) = @_;

    my $comment = join( "\n", @comments );
    for( $comment ) {
        s/\n+$//;
        s/\n/ /g;
        s/^(?!\s*[#;])/ # /;
    }

    $self->_autovivify( $section );
    $self->[SHASH]{ $section }[SCMTS][1] = $comment;

}

#---------------------------------------------------------------------
## $ini->vattr( $section, $name, $i, $attribute, $value )
sub vattr {
    my( $self, $section, $name, $i, @parms ) = @_;
    return unless defined $section and defined $name;
    $i = 0 unless defined $i;

    # return all attributes
    unless( @parms ) {
        return unless $self->[SHASH]{ $section }[NHASH]{ $name }
            [VATTR][ $i ];
        return %{$self->[SHASH]{ $section }[NHASH]{ $name }
            [VATTR][ $i ]};
    }

    my %parms;
    if( @parms == 1 ) {

        if( ref $parms[0] eq 'HASH' ) {
            %parms = %{$parms[0]};
        }

        # return the one attribute's value
        else {
            return $self->[SHASH]{ $section }[NHASH]{ $name }
                [VATTR][ $i ]{ $parms[0] };
        }
    }
    else {
        %parms = @parms;
    }

    $self->_autovivify( $section, $name );

    # set or delete attributes (if $value is undef)
    while( my( $k, $v ) = each %parms ) {
        if( defined $v ) {
            $self->[SHASH]{ $section }[NHASH]{ $name }
                [VATTR][ $i ]{ $k } = $v;
        }
        else {
            delete $self->[SHASH]{ $section }[NHASH]{ $name }
                [VATTR][ $i ]{ $k };
        }
    }
    return;
}

#---------------------------------------------------------------------
## AUTOLOAD() (wrapper for _attr())
## file( 'filename' )
## keep_comments( 1 )
## heredoc_style( '<<' )
our $AUTOLOAD;
sub AUTOLOAD {
    my $attribute = $AUTOLOAD;
    $attribute =~ s/.*:://;
    die "Undefined: $attribute()" unless $attribute =~ /^(?:
        file | keep_comments | heredoc_style
        )$/x;
    my $self = shift;
    $self->_attr( $attribute, @_ );
}

sub DESTROY {}

#---------------------------------------------------------------------
## $ini->as_string()
sub as_string {
    my $self = shift;
    my $heredoc_style = defined $self->_attr('heredoc_style') ?
        $self->_attr('heredoc_style') : $heredoc_style,
    my $keep_comments = defined $self->_attr('keep_comments') ?
        $self->_attr('keep_comments') : $keep_comments,

    my $output = '';

    my @sections = $self->get_sections( 'all' );
    foreach my $section ( @sections ) {

        if( $keep_comments and defined( my $comments =
                $self->get_section_comments( $section ) ) ) {
            $output .= $comments;
        }
        else {
            # blank line between sections
            $output .= "\n" if $output;
        }

        unless( $section eq '' or $section eq '__END__' ) {
            $output .= "[$section]";
            if( $keep_comments and defined( my $comment =
                    $self->get_section_comment( $section ) ) ) {
                $output .= "$comment\n" if $comment;
            }
            else { $output .= "\n"; }
        }

        my @names = $self->get_names( $section );
        foreach my $name ( @names ) {

            my @values = $self->get( $section, $name );
            my $i = 0;
            foreach my $value ( @values ) {

                if( $keep_comments and defined( my $comments =
                    $self->get_comments( $section, $name, $i ) ) ) {
                    $output .= $comments;
                }

                my %vattr = $self->vattr( $section, $name, $i );
                my $style    = $vattr{'herestyle'} ||'';
                my $tag      = $vattr{'heretag'}   ||'';
                my $escape   = $vattr{'escape'}    ||'';
                my $indented = $vattr{'indented'}  ||'';
                my $extra    = $vattr{'extra'}     ||'';
                my $json     = $vattr{'json'}      ||'';
                my $equals   = $vattr{'equals'}    ||' = ';
                my $q        = $vattr{'quote'}     ||'';
                my $nq       = $vattr{'nquote'}    ||'';
                my $comment  = $vattr{'comment'}   ||'';
                $comment = '' unless $keep_comments;

                # if name was in quotes
                if( $nq ) {
                    $name = $nq eq '"' ?
	       as_double_quoted( $name, '"', $escape ) :
	       as_single_quoted( $name, "'" );
                }

                # need heredoc if:
                # value has a heretag or herestyle attribute
                # value has an escape, indented, json, or extra attribute
                # quote != double and value contains \n
                my $need_heredoc = 1 if
                    ( $tag||$style||$escape||$indented||$json||$extra ) or
                    ( $value =~ /\n/ and $q !~ /^("|d)/ );

                if( $need_heredoc ) {
                    # append "\n" here to avoid :chomp ...
                    $value = objToJson($value)."\n" if $json;
                    $output .= "$name$equals" .
                        as_heredoc(
	           value     => $value,
	           heretag   => $tag,
	           quote     => $q,
	           escape    => $escape,
	           indented  => $indented,
	           extra     => "$json$extra",
	           comment   => $comment,
	           herestyle => $style||$heredoc_style,
	           );
                }

                else {
                    # need quotes if:
                    # value has a quote attribute
                    # value has a comment attribute
                    my $need_quotes =
                        $q ? $q : $comment ? "'" : '';
                    $output .= "$name$equals" . (
                        $need_quotes eq '"'                          ?
	           as_double_quoted( $value, '"', $escape ) :
                        $need_quotes                                 ?
	           as_single_quoted( $value, "'" )          :
                        $value );
                    $output .= "$comment\n";
                }
                $i++;
            }
        }
    }
    return $output;
}

#---------------------------------------------------------------------
1;

__END__

=head1 DESCRIPTION

This is an ini-style configuration file processor.  This class
inherits from Config::Ini.  It uses that module as well as
Config::Ini::Quote, Text::ParseWords and JSON;

=head2 Terminology

 # comment
 [section]
 name = value

In particular 'name' is the term used to refer to the named
options within the sections.

=head2 Syntax

 # before any sections are defined,
 ; assume section eq ''--the "null section"
 name = value
 name: value

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

 # this is a comment
 [section] # this is a comment
 name = value # this is NOT a comment

 # however, comments are allowed after quoted values
 name = 'value' # this is a comment
 name = "value" # this is a comment

 # colon is valid assignment character, too.
 name:value
 name: value
 name :value
 name : value
 name    :    value

 # heredocs are supported several ways:
 
 # classic heredoc
 name = <<heredoc
 value
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

=head2 Quoted Values

Values may be put in single or double quotes.

Single-quoted values will be parsed literally, except that
imbedded single quotes must be escaped by doubling them,
e.g.,

 name = 'The ties that bind.'

 $name = $ini->get( section => 'name' );
 # $name eq "The ties that bind."

 name = 'The ''ties'' that ''bind.'''

 $name = $ini->get( section => 'name' );
 # $name eq "The 'ties' that 'bind.'"

This uses $Config::Ini::Quote::parse_single_quoted().

Double-quoted values may be parsed a couple of different
ways.  By default, backslash-escaped unprintable characters
will be unescaped to their actual Unicode character.  This
includes ascii control characters like \n, \t, etc.,
Unicode character codes like \N (Unicode next line), \P
(Unicode paragraph separator), and hex-value escape
sequences like \x86 and \u263A.

If the ':html' heredoc modifier is used (see Heredoc
Modifiers below), then HTML entities will be decoded (using
HTML::Entities) to their actual Unicode characters.

This uses $Config::Ini::Quote::parse_double_quoted(),

See also Config::Ini:Quote.

=head2 Heredoc Modifiers

There are several ways to modify the value in a heredoc as
the ini file is read in (i.e., as the object is
initialized):

 :chomp    - chomps the last line
 :join     - chomps every line BUT the last one
 :indented - unindents every line (strips leading whitespace)
 :parse    - splits on newline (chomps last line)
 :parse(regex) - splits on regex (still chomps last line)
 :slash    - unescapes backslash-escaped characters in double quotes (default)
 :html     - decodes HTML entities in double quotes
 :json     - parses javascript object notation (complex data types)

The :parse modifier uses Text::ParseWords::parse_line(), so
CSV-like parsing is possible.

The :json modifier uses the JSON module to parse and dump
complex data types (combinations of hashes, arrays,
scalars).  The value of the heredoc must be valid
JavaScript Object Notation.

The :slash and :html modifiers are only valid when double
quotes are used (surrounding the heredoc tag and
modifiers).

Modifiers may be stacked, e.g., <<:chomp:join:indented, in
any order (but :parse and :json are performed last).

 # value is "Line1\nLine2\n"
 name = <<
 Line1
 Line2
 <<

 # value is "Line1\nLine2"
 name = <<:chomp
 Line1
 Line2
 <<

 # value is "Line1Line2\n"
 name = <<:join
 Line1
 Line2
 <<

 # value is "Line1Line2"
 name = <<:chomp:join
 Line1
 Line2
 <<

 # value is "  Line1\n  Line2\n"
 name = <<
   Line1
   Line2
 <<

 # - indentations do NOT have to be regular to be unindented
 # - any leading spaces/tabs on every line will be stripped
 # - trailing spaces are left intact, as usual
 # value is "Line1\nLine2\n"
 name = <<:indented
   Line1
   Line2
 <<

 # modifiers may have spaces between them
 # value is "Line1Line2"
 name = << :chomp :join :indented
   Line1
   Line2
 <<

 # with heredoc "tag"
 # value is "Line1Line2"
 name = <<heredoc :chomp :join :indented
   Line1
   Line2
 heredoc

The :parse modifier turns a single value into multiple
values, e.g.,

 # :parse is same as :parse(\n)
 name = <<:parse
 value1
 value2
 <<

is the same as,

 name = value1
 name = value2

and

 name = <<:parse(/,\s+/)
 "Tom, Dick, and Harry", Fred and Wilma
 <<

is the same as,

 name = Tom, Dick, and Harry
 name = Fred and Wilma

The :parse modifier chomps only the last line by default,
so include '\n' to parse multiple lines.

 # liberal separators
 name = <<:parse([,\s\n]+)
 "Tom, Dick, and Harry" "Fred and Wilma"
 Martha George, 'Hillary and Bill'
 <<

is the same as,

 name = Tom, Dick, and Harry
 name = Fred and Wilma
 name = Martha
 name = George
 name = Hillary and Bill

 name = <<:json
 { a: 1, b: 2, c: 3 }
 <<

Given the above :json example, $ini->get( 'name' ) should
return a hashref.  Note that we accept bare hash keys
($JSON::BareKey = 1;).

Modifiers must follow the heredoc characters '<<' (or
'{').  If there is a heredoc tag, e.g., EOT, the modifiers
typically follow it, too.

 name = <<EOT:json
 { a: 1, b: 2, c: 3 }
 EOT

If you want to use single or double quotes, surround the
heredoc tag and modifiers with the appropriate quotes:

 name = <<'EOT :indented'
     line1
     line2
 EOT

 name = <<"EOT :html"
 vis-&agrave;-vis
 EOT

Note, in heredocs, embedded single and double quotes do not
have to be (and should not be) escaped.  In other words
leave single quotes as "'" (not "''"), and leave double
quotes as '"' (not '\"').

 name = <<'EOT :indented'
     'line1'
     'line2'
 EOT
 
 # $name eq "'line1'\n'line2'\n"
 $name = $ini->get( 'name' );

 name = <<"EOT :html"
 "vis-&agrave;-vis"
 EOT
 
 # $name eq qq{"vis-\xE0-vis"}
 $name = $ini->get( 'name' );

If no heredoc tag is used, put the quotes around
the modifiers.

 name = <<":html"
 vis-&agrave;-vis
 <<

If no modifiers, just use empty quotes.

 name = <<""
 vis-\xE0-vis
 <<

Comments are allowed on the assignment line if
quotes are used.

 name = <<'EOT :indented' # this is a comment
     line1
     line2
 EOT

=head1 GLOBAL SETTINGS

Note, the global settings below are stored in the
object during init(), so if they are changed,
any existing objects will not be affected.

=over 8

=item $Config::Ini::Edit::keep_comments

This boolean value will determine if comments are
kept when an ini file is loaded or when an ini
object is written out.  The default is true--comments
are kept.  The rationalization is this: The "Edit"
module is designed to allow you to read, edit, and
rewrite Ini files.  If a file contains comments to
start with, you probably want to keep them.

=item $Config::Ini::Edit::heredoc_style

This string can be one of '<<', '<<<<', '{', or '{}'.
This determines the default heredoc style, respectively:

 # '<<'
 name = <<EOT
 Hey
 EOT

 # '<<<<'
 name = <<EOT
 Hey
 <<EOT

 # '{'
 name = {EOT
 Hey
 EOT

 # '{}'
 name = {EOT
 Hey
 }EOT

=back

=head1 METHODS

=head2 Initialization Methods

=over 8

=item new()

=item new( 'filename' )

=item new( file => 'filename' )

=item new( fh => $filehandle )

=item new( string => $string )

=item new( file => 'filename', keep_comments => 0 )

=item new( file => 'filename', heredoc_style => '{}' ), etc.

Use new() to create an object, e.g.,

  my $ini = Config::Ini::Edit->new( 'inifile' );

If you pass any parameters, the init() object will be called.
If you pass only one parameter, it's assumed to be the ini file
name.  Otherwise, use the named parameters, C<file>, C<fh>,
or C<string> to pass a filename, filehandle (already open),
or string.  The string is assumed to look like the contents
of an ini file.

Other parameters are C<keep_comments> and C<heredoc_style>
to override the defaults, true and '<<', respectively.
The values accepted for heredoc_style are '<<', '<<<<',
'{', or '{}'.

If you do not pass any parameters to new(), you can later
call init() with the same parameters described above.

=item init( 'filename' )

=item init( file => 'filename' )

=item init( fh => $filehandle )

=item init( string => $string )

=item init( file => 'filename', keep_comments => 0 )

=item init( file => 'filename', heredoc_style => '{}' ), etc.

 my $ini = Config::Ini::Edit->new();
 $ini->init( 'filename' );

=back

=head2 Get Methods

=over 8

=item get_sections()

Use get_sections() to retrieve a list of the sections in the
ini file.  They are returned in the order they appear in the
file.

 my @sections = $ini->get_sections();

If there is a "null section", it will be the first in the
list.  If a section appears twice in a file, it only appears
once in this list.  This implies that ...

 [section1]
 name1 = value
 [section2]
 name2 = value
 [section1]
 name3 = value

is the same as ...

 [section1]
 name1 = value
 name3 = value
 [section2]
 name2 = value

The method, as_string(), will output the latter.

=item get_names( $section )

Use get_names() to retrieve a list of the names in a given
section.

 my @names = $ini->get_names( $section );

They are returned in the order they appear in the
section.

If a name appears twice in a section, it only
appears once in this list.  This implies that ...

 [section]
 name1 = value1
 name2 = value2
 name1 = another

is the same as

 [section]
 name1 = value1
 name1 = another
 name2 = value2

The method, as_string(), will output the latter.

=item get( $section, $name )

=item get( $section, $name, $i )

=item get( $name )  (assumes $section eq '')

Use get() to retrieve the value(s) for a given name.
If a name appears more than once in a section, the
values are pushed onto an array, and get() will return
this array of values.

 my @values = $ini->get( $section, $name );

Pass an array subscript as the third parameter to
return only one of the values in this array.

 my $value = $ini->get( $section, $name, 0 ); # get first one
 my $value = $ini->get( $section, $name, 1 ); # get second one
 my $value = $ini->get( $section, $name, -1 ); # get last one

If the ini file lists names at the beginning, before
any sections are given, the section name is assumed to
be the null string ('').  If you call get() with just
one parameter, it is assumed to be a name in this "null
section".  If you want to pass an array subscript, then
you must also pass a null string as the first parameter.

 my @values = $ini->get( $name );         # assumes $section eq ''
 my $value  = $ini->get( '', $name, 0 );  # get first occurrence
 my $value  = $ini->get( '', $name, -1 ); # get last occurrence

This "null section" concept allows for very simple
configuration files like:

 title = Hello World
 color: blue
 margin: 0

=back

=head2 Add/Set/Put Methods

Here, 'add' implies pushing values onto the end,
'set', modifying a single value, and 'put', replacing
all values at once.

=over 8

=item add( $section, $name, @values )

Use add() to add to the value(s) of an option.  If
the option already has values, the new values will
be added to the end (pushed onto the array).

 $ini->add( $section, $name, @values );

To add to the "null section", pass a null string.

 $ini->add( '', $name, @values );

=item set( $section, $name, $i, $value )

Use set() to assign a single value.  Pass undef to
remove a value altogether.  The $i parameter is the
subscript of the values array to assign to (or remove).

 $ini->set( $section, $name, -1, $value ); # set last value
 $ini->set( $section, $name, 0, undef ); # remove first value

To set a value in the "null section", pass a null
string.

 $ini->set( '', $name, 1, $value ); # set second value

=item put( $section, $name, @values )

Use put() to assign all values at once.  Any
existing values are overwritten.

 $ini->put( $section, $name, @values );

To put values in the "null section", pass a null
string.

 $ini->put( '', $name, @values );

=back

=head2 Delete Methods

=over 8

=item delete_section( $section )

Use delete_section() to delete an entire section,
including all of its options and their values.

 $ini->delete_section( $section )

To delete the "null section", don't
pass any parameters (or pass a null string).

 $ini->delete_section();
 $ini->delete_section( '' );

=item delete_name( $section, $name )

Use delete_name() to delete a named option and all
of its values from a section.

 $ini->delete_name( $section, $name );

To delete an option from the "null section",
pass just the name, or pass a null string.

 $ini->delete_name( $name );
 $ini->delete_name( '', $name );

To delete just some of the values, you can use set() with a
subscript, passing undef to delete that one, or you can
first get them using get(), then modify them (e.g., delete
some).  Finally, use put() to replace the old values with
the modified ones.

=back

=head2 Other Accessor Methods

=over 8

=item file( $filename )

Use file() to get or set the name of the object's
ini file.  Pass the file name to set the value.
Pass undef to remove the C<file> attribute altogether.

 $inifile_name = $ini->file();  # get
 $ini->file( $inifile_name );  # set
 $ini->file( undef );  # remove

=item keep_comments( $boolean )

Use keep_comments() to get or set the object's C<keep_comments>
attribute.  The default for this attribute is true, i.e.,
do keep comments.  Pass a false value to turn comments off.

 $boolean = $ini->keep_comments();  # get
 $ini->keep_comments( $boolean );  # set

=item heredoc_style( $style )

Use heredoc_style() to get or set the default style
used when heredocs are rendered by as_string().

 $style = $ini->heredoc_style();  # get
 $ini->heredoc_style( $style );  # set

The value passed should be one of '<<', '<<<<',
'{', or '{}'.  The default is '<<'.

See also init() and GLOBAL SETTINGS above.

=item vattr( $section, $name, $i, $attribute, $value, ... )

Use vattr() to get or set value-level attributes,
which include:

 heretag   : 'string'
 herestyle : ( {, {}, <<, or <<<< )
 quote     : ( ', ", s, d, single, or double )
 nquote    : ( ', ", s, d, single, or double )
 equals    : ( '=', ':', ' = ', ': ', etc. )
 escape    : ( :slash and/or :html )
 indented  : indentation value (white space)
 json      : boolean
 comment   : 'string'

If $i is undefined, 0 is assumed.  If there's
an $attribute, but no $value, the value of that
attribute is returned.

 $value = vattr( $section, $name, 0, 'heretag' );  # get one

If no $attribute is given, vattr() returns all of the
attribute names and values as a list (in pairs).

 %attrs = vattr( $section, $name, 1 ); # get all

If $attribute is a hashref, values are set from that hash.

 %ah = ( heretag=>'EOT', herestyle=>'{}' );
 vattr( $section, $name, 1, \%ah );

Otherwise, attributes and values may be passed as
named parameters.

 vattr( $section, $name, 1, heretag=>'EOT', herestyle=>'{}' );

These value attributes are used to replicate the ini
file when as_string() is called.

C<escape>, C<indented>, and C<json> correspond to the
corresponding heredoc modifiers; see C<Heredoc Modifiers>
above.  C<heretag>, C<herestyle>, and C<quote> are used to
begin and end the heredoc.  Additionally, if double quotes
are called for, characters in the value will be escaped
according to the C<escape> modifier.

C<comment> will be appended after the value, or if a
heredoc, after the beginning of the heredoc.  Note, the
comment may also be accessed using set_comment() and
get_comment().  See below.

The value of C<equals> will be output between the name
and value, e.g., ' = ' between "name = value".  C<nquote>
is to the name what C<quote> is to the value, i.e., if
"'", the name will be single quoted, if '"', double.


=back

=head2 Comments Accessor Methods

An ini file may contain comments.  Normally, when your
program reads an ini file, it doesn't care about comments.
But if you want to edit an ini file using the Config::Ini::Edit
module, you will want to keep the comments.

Set $Config::Ini::Edit::keep_comments to 0 if you do not
want the Config::Ini::Edit object to retain the comments
that are in the file.  The default is 1--comments are
kept.  This applies to new(), init(), and as_string(),
i.e., new() and init() will load the comments into the
object, and as_string() will output these comments.

Or you can pass the C<keep_comments> parameter
to the new() or init() methods as described above.

=over 8

=item get_comments( $section, $name, $i )

Use get_comments() to return the comments that appear ABOVE
a certain name.  Since names may be repeated (forming an
array of values), pass an array index ($i) to identify the
comment desired.  If $i is undefined, 0 is assumed.

 my $comments = get_comments( $section, $name );

=item get_comment( $section, $name, $i )

Use get_comment() (singular) to return the comments that
appear ON the same line as a certain name's assignment.
Pass an array index ($i) to identify the comment desired.
If $i is undefined, 0 is assumed.

 $comment = get_comment( $section, $name );

=item set_comments( $section, $name, $i, @comments )

Use set_comments() to specify comments for a given
occurrence of a name.  When as_string() is called,
these comments will appear ABOVE the name.

  $ini->set_comments( $section, $name, 0, 'Hello World' );

In an ini file, comments must begin with '#' or ';' and end
with a newline.  If your comments don't, '# ' and "\n" will
be added.

=item set_comment( $section, $name, $i, @comments )

Use set_comment() to specify comments for a given
occurrence of a name.  When as_string() is called, these
comments will appear ON the same line as the name's
assignment.

  $ini->set_comment( $section, $name, 0, 'Hello World' );

In an ini file, comments must begin with '#' or ';'.  If
your comments don't, '# ' will be added.  If you pass an
array of comments, they will be strung together on one
line.

=item get_section_comments( $section )

Use get_section_comments() to retrieve the comments
that appear ABOVE the [section] line, e.g.,

 # Comment 1
 [section] # Comment 2
 
 my $comments = $ini->get_section_comments( $section );

In the above example, $comments eq "# Comment 1\n";

=item get_section_comment( $section )

Use get_section_comment() (note: singular 'comment') to
retrieve the comment that appears ON the same line as
the [section] line.

 # Comment 1
 [section] # Comment 2
 
 my $comment = $ini->get_section_comment( $section );

In the above example, $comment eq " # Comment 2\n";

=item set_section_comments( $section, @comments )

Use set_section_comments() to set the value of the
comments above the [section] line.

 $ini->set_section_comments( $section, $comments );

=item set_section_comment( $section, @comments )

Use set_section_comment() (singular) to set the value of the
comment at the end of the [section] line.

 $ini->set_section_comment( $section, $comment );

=back

=head2 Recreating the Ini File Structure

=over 8

=item as_string()

Use as_string() to dump the Config::Ini::Edit object in an ini file
format.  If $Config::Ini::Edit::keep_comments is true, the comments
will be included.

 print INIFILE $ini->as_string();

The value as_string() returns is not guaranteed to be
exactly what was in the original ini file.  But you can
expect the following:

- All sections and names will be retained.

- All values will resolve correctly, i.e., a call to
get() will return the expected value.

- All comments will be present (if keep_comments is true).

- As many value attributes as possible will be retained, e.g.,
quotes, escapes, indents, etc.  But the :parse modifier will
NOT be retained.

- If the same section appears multiple times in a file,
all of its options will be output in only one occurrence
of that section, in the position of the original first
occurrence.  E.g.,

 [section1]
 name1 = value
 [section2]
 name2 = value
 [section1]
 name3 = value

will be output as,

 [section1]
 name1 = value
 name3 = value
 [section2]
 name2 = value

- If the same name appears multiple times in a section,
all of its occurrences will be grouped together, at the
same position as the first occurrence.  E.g.,

 [section]
 name1 = value1
 name2 = value2
 name1 = another

will be output as,

 [section]
 name1 = value1
 name1 = another
 name2 = value2

=back


=head1 SEE ALSO

Config::Ini,
Config::Ini::Quote,
Config::Ini::Expanded,
Config::IniFiles,
Config:: ... (many others)

=head1 AUTHOR

Brad Baxter, E<lt>bmb@mail.libs.uga.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Brad Baxter

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
