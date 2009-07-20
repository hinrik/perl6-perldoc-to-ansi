package Perl6::Perldoc::To::Ansi;

use warnings;
use strict;

our $VERSION = '0.08';

# add fake opening/closing tags, to be processed later
sub add_ansi {
    my ($text, $new) = @_;
    return "\e[OPEN${new}m" . $text . "\e[CLOSE${new}m";
}

# same, but only if the entire text is not already colored
sub add_ansi_only {
    my ($text, $new) = @_;
    return $text if $text =~ /^\e\[/ && $text =~ /\e\[0?m$/;
    return add_ansi($text, $new);
}

sub rewrite_ansi {
    my ($text) = @_;
    #$text = "\e[${new}m$text";
    #$text =~ s/(?:\e\[m)*$//;

    my @code_stack;
    my $current = sub {
        my $ret = '';
        $ret .= "\e[${_}m" for @code_stack;
        return $ret;
    };
    
    $text =~ s{( \e\[.+?m | \n )}{
        my $match = $1;
        #$match =~ s/(?:\e\[m)+//g;
        #$match =~ s/^\e\[|m$//g;
        my $subst = '';

        if ($match eq "\n") {
            # re-apply codes because newline resets them
            $subst = "\n" . $current->();
        }
        elsif (my ($add) = $match =~ /\e\[OPEN(.+?)m/) {
            #print "add: $add\n";
            # keep track of a new code
            push @code_stack, $add;
            $subst = "\e[${add}m";
        }
        elsif (my ($remove) = $match =~ /\e\[CLOSE(.+?)m/) {
            #print "remove: $remove\n";
            # remove this code and re-apply the rest
            pop @code_stack;
            for (my $i = $#code_stack; $i >= 0; $i--) {
                if ($code_stack[$i] eq $remove) {
                    splice @code_stack, $i, 1 if $code_stack[$i];
                    last;
                }
            }
            $subst = "\e[m" . $current->();
        }
        
        $subst;
    }egmx;

    $text .= "\e[m" x scalar @code_stack;
    return $text;
}

package Perl6::Perldoc::Parser::ReturnVal;

sub to_ansi {
    my ($self, $internal_state) = @_;

    $internal_state ||= {};

    my $text_rep = $self->{tree}->to_ansi($internal_state);

    if (($internal_state->{note_count}||0) > 0) {
        $text_rep .= "\nNotes\n\n$internal_state->{notes}";
    }

    return Perl6::Perldoc::To::Ansi::rewrite_ansi($text_rep);
}

package Perl6::Perldoc::Root;  

my $INDENT = 4;

sub add_ansi_nesting {
    my ($self, $text, $depth) = @_;

    # Nest according to the specified nestedness of the block...
    if (my $nesting = $self->option('nested')) {
        $depth = $nesting * $INDENT;
    }

    # Or else default to one indent...
    elsif (!defined $depth) {
        $depth = $INDENT;
    }

    my $indent = q{ } x $depth;
    $text =~ s{^}{$indent}gxms;
    return $text;
}

sub _list_to_ansi {
    my ($list_ref, $state_ref) = @_;
    my $text = q{};
    for my $content ( @{$list_ref} ) {
        next if ! defined $content;
        if (ref $content) {
            $text .= $content->to_ansi($state_ref);
        }
        else {
            $text .= $content;
        }
    }
    $text =~ s{\A \n+}{}xms;
    $text =~ s{\n+ \z}{\n}xms;
    return $text;
}

sub to_ansi {
    my $self = shift;
    return $self->add_ansi_nesting(_list_to_ansi([$self->content], @_),0);
}

# Representation of file itself...
package Perl6::Perldoc::Document;  
    use base 'Perl6::Perldoc::Root';

# Ambient text around the Pod...
package Perl6::Perldoc::Ambient;  

sub to_ansi {
    return q{};
}

# Pod blocks...
package Perl6::Perldoc::Block;    

# Standard =pod block...
package Perl6::Perldoc::Block::pod;    

# Standard =para block (may be implicit)...
package Perl6::Perldoc::Block::para;   

sub to_ansi {
    my $self = shift;
    return "\n" . $self->SUPER::to_ansi(@_);
}

# Standard =code block (may be implicit)...
package Perl6::Perldoc::Block::code;   

sub ansi_min {
    my $min = shift;
    for my $next (@_) {
        $min = $next if $next < $min;
    }
    return $min;
}

sub to_ansi {
    my $self = shift;
    my $text = Perl6::Perldoc::Root::_list_to_ansi([$self->content],@_);
    my $left_space = ansi_min map { length } $text =~ m{^ [^\S\n]* (?= \S) }gxms;
    $text =~ s{^ [^\S\n]{$left_space} }{}gxms;
    $text = Perl6::Perldoc::To::Ansi::add_ansi($text, '33');
    return "\n" . $self->add_ansi_nesting($text, $INDENT);
}


# Standard =input block
package Perl6::Perldoc::Block::input;   

sub to_ansi {
    my $self = shift;
    my $text = Perl6::Perldoc::Root::_list_to_ansi([$self->content],@_);
    $text = Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '36');
    return "\n" . $self->add_ansi_nesting($text, $INDENT);
}


# Standard =output block
package Perl6::Perldoc::Block::output;   

sub to_ansi {
    my $self = shift;
    my $text = Perl6::Perldoc::Root::_list_to_ansi([$self->content],@_);
    $text = Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '36');
    return "\n" . $self->add_ansi_nesting($text, $INDENT);
}

# Standard =config block...
package Perl6::Perldoc::Config; 

sub to_ansi {
    return q{};
}

# Standard =table block...
package Perl6::Perldoc::Block::table; 

sub to_ansi {
    my $self = shift;
    my ($text) = $self->content;
    return "\n" . $self->add_ansi_nesting($text, $INDENT);
}


# Standard =head1 block...
package Perl6::Perldoc::Block::head1;  

sub to_ansi {
    my $self = shift;
    my $title = $self->SUPER::to_ansi(@_);
    $title =~ s{\A\s+|\s+\Z}{}gxms;
    $title =~ s{\s+}{ }gxms;
    my $number = $self->number;
    if (defined $number) {
        $title = "$number. $title";
    }
    return "\n" . Perl6::Perldoc::To::Ansi::add_ansi_only($title, '1') ."\n";
}

# Standard =head2 block...
package Perl6::Perldoc::Block::head2;  

sub to_ansi {
    my $self = shift;
    my $title = $self->SUPER::to_ansi(@_);
    $title =~ s{\A\s+|\s+\Z}{}gxms;
    $title =~ s{\s+}{ }gxms;
    my $number = $self->number;
    if (defined $number) {
        $title = "$number. $title";
    }
    return "\n" . Perl6::Perldoc::To::Ansi::add_ansi_only($title, '1') ."\n";
}

# Standard =head3 block...
package Perl6::Perldoc::Block::head3;  

sub to_ansi {
    my $self = shift;
    my $title = $self->SUPER::to_ansi(@_);
    $title =~ s{\A\s+|\s+\Z}{}gxms;
    $title =~ s{\s+}{ }gxms;
    my $number = $self->number;
    if (defined $number) {
        $title = "$number. $title";
    }
    return "\n" . Perl6::Perldoc::To::Ansi::add_ansi_only($title, '1') ."\n";
}

# Standard =head4 block...
package Perl6::Perldoc::Block::head4;  

sub to_ansi {
    my $self = shift;
    my $title = $self->SUPER::to_ansi(@_);
    $title =~ s{\A\s+|\s+\Z}{}gxms;
    $title =~ s{\s+}{ }gxms;
    my $number = $self->number;
    if (defined $number) {
        $title = "$number. $title";
    }
    return "\n" . Perl6::Perldoc::To::Ansi::add_ansi_only($title, '1') ."\n";
}

# Implicit list block...
package Perl6::Perldoc::Block::list;   
    use base 'Perl6::Perldoc::Root';

sub to_ansi {
    my $self = shift;
    return "\n" . $self->add_ansi_nesting($self->SUPER::to_ansi(@_));
}


# Standard =item block...
package Perl6::Perldoc::Block::item;   

sub to_ansi {
    my $self = shift;

    my $counter = $self->number;
    $counter = $counter ? qq{$counter.} : q{*};

    my $body = $self->SUPER::to_ansi(@_);

    if (my $term = $self->term()) {
        $term = $self->term( {as_objects=>1} )->to_ansi(@_);
        if (length $counter) {
            $term =~ s{\A (\s* <[^>]+>)}{$1$counter. }xms;
        }
        my $body = $self->add_ansi_nesting($body);
        $body =~ s{\A \n+}{}xms;
        return "\n$term\n$body";
    }

    $body = $self->add_ansi_nesting($body, 1 + length $counter);
    $body =~ s{\A \n+}{}xms;
    $body =~ s{\A \s*}{$counter }xms;

    return $body;
}

# Implicit toclist block...
package Perl6::Perldoc::Block::toclist;   
    use base 'Perl6::Perldoc::Root';

sub to_ansi {
    my $self = shift;
    
    # Convert list items to text, and return in an text list...
    my $text = join q{}, map {$_->to_ansi(@_)}  $self->content;

    return $self->add_ansi_nesting($text);
}


# Standard =tocitem block...
package Perl6::Perldoc::Block::tocitem;   

sub to_ansi {
    my $self = shift;

    my @title = $self->title;
    return "" if ! @title;
    
    my $title = Perl6::Perldoc::Root::_list_to_ansi(\@title, @_);

    return "* $title\n";
}

# Handle headN's and itemN's and tocitemN's...
for my $depth (1..100) {
    no strict qw< refs >;

    @{'Perl6::Perldoc::Block::item'.$depth.'::ISA'}
        = 'Perl6::Perldoc::Block::item';

    @{'Perl6::Perldoc::Block::tocitem'.$depth.'::ISA'}
        = 'Perl6::Perldoc::Block::tocitem';

    next if $depth < 5;
    @{'Perl6::Perldoc::Block::head'.$depth.'::ISA'}
        = 'Perl6::Perldoc::Block::head4';
}
# Handle headN's and itemN's
for my $depth (1..100) {
    no strict qw< refs >;
    @{'Perl6::Perldoc::Block::item'.$depth.'::ISA'}
        = 'Perl6::Perldoc::Block::item';
}

# Standard =nested block...
package Perl6::Perldoc::Block::nested;   

sub to_ansi {
    my $self = shift;
    return "\n" . $self->add_ansi_nesting($self->SUPER::to_ansi(@_));
}

# Standard =comment block...
package Perl6::Perldoc::Block::comment;   

sub to_ansi {
    return q{};
}

# Standard SEMANTIC blocks...
package Perl6::Perldoc::Block::Semantic;
BEGIN {
    my @semantic_blocks = qw(
        NAME              NAMES
        VERSION           VERSIONS
        SYNOPSIS          SYNOPSES
        DESCRIPTION       DESCRIPTIONS
        USAGE             USAGES
        INTERFACE         INTERFACES
        METHOD            METHODS
        SUBROUTINE        SUBROUTINES
        OPTION            OPTIONS
        DIAGNOSTIC        DIAGNOSTICS
        ERROR             ERRORS
        WARNING           WARNINGS
        DEPENDENCY        DEPENDENCIES
        BUG               BUGS
        SEEALSO           SEEALSOS
        ACKNOWLEDGEMENT   ACKNOWLEDGEMENTS
        AUTHOR            AUTHORS
        COPYRIGHT         COPYRIGHTS
        DISCLAIMER        DISCLAIMERS
        LICENCE           LICENCES
        LICENSE           LICENSES
        TITLE             TITLES
        SECTION           SECTIONS
        CHAPTER           CHAPTERS
        APPENDIX          APPENDIXES       APPENDICES
        TOC               TOCS
        INDEX             INDEXES          INDICES
        FOREWORD          FOREWORDS
        SUMMARY           SUMMARIES
    );

    # Reuse content-to-text converter
    *_list_to_ansi = *Perl6::Perldoc::Root::_list_to_ansi;

    for my $blockname (@semantic_blocks) {
        no strict qw< refs >;

        *{ "Perl6::Perldoc::Block::${blockname}::to_ansi" }
            = sub {
                my $self = shift;

                my @title = $self->title();

                return "" if !@title;
                my $title = _list_to_ansi(\@title, @_);

                return "\n" . Perl6::Perldoc::To::Ansi::add_ansi(uc $title, '1') ."\n\n"
                     . _list_to_ansi([$self->content], @_);
            };
    }
}


# Base class for formatting codes...

package Perl6::Perldoc::FormattingCode; 

package Perl6::Perldoc::FormattingCode::Named; 

# Basis formatter...
package Perl6::Perldoc::FormattingCode::B;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '1');
}

# Code formatter...
package Perl6::Perldoc::FormattingCode::C;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '33');
}

# Definition formatter...
package Perl6::Perldoc::FormattingCode::D;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '1');
}


# Entity formatter...
package Perl6::Perldoc::FormattingCode::E;

my %is_break_entity = (
    'LINE FEED (LF)'       => 1,     LF  => 1,
    'CARRIAGE RETURN (CR)' => 1,     CR  => 1,
    'NEXT LINE (NEL)'      => 1,     NEL => 1,

    'FORM FEED (FF)'       => 10,    FF  => 10, 
);

my %is_translatable = (
    nbsp  => q{ },
    bull  => q{*},
    mdash => q{--},
    ndash => q{--},
);

# Convert E<> contents to text named or numeric entity...
sub _to_ansi_entity {
    my ($spec) = @_;
    # Is it a line break?
    if (my $BR_count = $is_break_entity{$spec}) {
        return "\n" x $BR_count;
    }
    # Is it a numeric codepoint in some base...
    if ($spec =~ m{\A \d}xms) {
        # Convert Perl 6 octals and decimals to Perl 5 notation...
        if ($spec !~ s{\A 0o}{0}xms) {       # Convert octal
            $spec =~ s{\A 0d}{}xms;          # Convert explicit decimal
            $spec =~ s{\A 0+ (?=\d)}{}xms;   # Convert implicit decimal
        }

        # Then return the Xtext numeric code...
        use charnames ':full';
        $spec = charnames::viacode(eval $spec);
    }
    if (my $replacement = $is_translatable{$spec}) {
        return $replacement;
    }
    else {
        return "[$spec]";
    }
}

sub to_ansi {
    my $self = shift;
    my $entities = $self->content;
    return join q{}, map {_to_ansi_entity($_)} split /\s*;\s*/, $entities;
}

# Important formatter...
package Perl6::Perldoc::FormattingCode::I;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '32');
}

# Keyboard input formatter...
package Perl6::Perldoc::FormattingCode::K;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '36');
}

# Link formatter...
package Perl6::Perldoc::FormattingCode::L;

my $PERLDOC_ORG = 'http://perldoc.perl.org/';
my $SEARCH      = 'http://www.google.com/search?q=';

sub to_ansi {
    my $self = shift;
    my $target = $self->target();
    my $text = $self->has_distinct_text ? $self->SUPER::to_ansi(@_) : undef;
    my $add_color = sub {
        $target = Perl6::Perldoc::To::Ansi::add_ansi($target, '34');
    };
    
    # Link within this document...
    if ($target =~ s{\A (?:doc:\s*)? [#] }{}xms ) {
        $add_color->();
        return defined $text ? qq{$text (see the $target section)}
                             : qq{the $target section}
    }

    # Link to other documentation...
    if ($target =~ s{\A doc: }{}xms) {
        $add_color->();
        return defined $text ? qq{$text (see the documentation for $target)} 
                             : qq{the documentation for $target}
    }

    # Link to manpage...
    if ($target =~ s{\A man: }{}xms) {
        $add_color->();
        return defined $text ? qq{$text (see the $target manpage)}
                             : qq{the $target manpage}
    }

    # Link back to definition in this document...
    if ($target =~ s{\A (?:defn) : }{}xms) {
        $add_color->();
        return defined $text ? qq{$text (see the definition of $target)}
                             : $target
    }

    # Link to an email address
    if ($target =~ s{\A (?:mailto) : }{}xms) {
        $add_color->();
        return defined $text ? qq{$text ($target)}
                             : $target
    }

    # Anything else...
    $add_color->();
    return defined $text ? qq{$text $target}
                         : $target;
}

# Meta-formatter...
package Perl6::Perldoc::FormattingCode::M;


# Note formatter...
package Perl6::Perldoc::FormattingCode::N;

sub to_ansi {
    my $self = shift;
    my $count = ++$_[0]{note_count};
    my $marker = "[$count]";
    $_[0]{notes} .= qq{$marker } . $self->SUPER::to_ansi(@_) . "\n";
    return qq{$marker};
}

# Placement link formatter...
package Perl6::Perldoc::FormattingCode::P;

sub to_ansi {
    my $self = shift;
    my $target = $self->target();

    # Link within this document...
    if ($target =~ s{\A (?:doc:\s*)? [#] }{}xms ) {
        return qq{(See the "$target" section)};
    }

    # Link to other documentation...
    if ($target =~ s{\A doc: }{}xms) {
        return qq{(See the documentation for $target)};
    }

    # Link to manpage...
    if ($target =~ s{\A man: }{}xms) {
        return qq{(See the $target manpage)};
    }

    # TOC insertion...
    if ($target =~ s{\A toc: }{}xms) {
        return Perl6::Perldoc::Root::_list_to_ansi([$self->content],@_);
    }

    # Anything else...
    $target =~ s{\A (?:defn) : }{}xms;
    return qq{(See $target)};
}

# Replacable item formatter...
package Perl6::Perldoc::FormattingCode::R;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '32');
}

# Space-preserving formatter...
package Perl6::Perldoc::FormattingCode::S;

sub to_ansi {
    my $self = shift;
    return $self->SUPER::to_ansi(@_);
}


# Terminal output formatter...
package Perl6::Perldoc::FormattingCode::T;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '36');
}

# Unusual formatter...
package Perl6::Perldoc::FormattingCode::U;

sub to_ansi {
    my $self = shift;
    return Perl6::Perldoc::To::Ansi::add_ansi($self->SUPER::to_ansi(@_), '4');
}

# Verbatim formatter...
package Perl6::Perldoc::FormattingCode::V;

# indeX formatter...
package Perl6::Perldoc::FormattingCode::X;

# Zero-width formatter...
package Perl6::Perldoc::FormattingCode::Z;

sub to_ansi {
    return q{};
}


# Standard =table block...
package Perl6::Perldoc::Block::table;   


1; # Magic true value required at end of module
__END__

=encoding UTF-8

=head1 NAME

Perl6::Perldoc::To::Ansi - ANSI-colored text renderer for Perl6::Perldoc

=head1 SYNOPSIS

    use Perl6::Perldoc::Parser;
    use Perl6::Perldoc::To::Ansi;

    # All Perl6::Perldoc::Parser DOM classes now have a to_ansi() method

=head1 DESCRIPTION

This module is almost identical to the Text renderer, except that many
constructs are highlighted with ANSI terminal codes. See
L<Perl6::Perldoc::To::Text> for more information.

=head1 AUTHOR

Hinrik Örn Sigurðsson, L<hinrik.sig@gmail.com>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Damian Conway L<DCONWAY@cpan.org>. All rights reserved.

Copyright (c) 2009, Hinrik Örn Sigurðsson L<hinrik.sig@gmail.com>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
