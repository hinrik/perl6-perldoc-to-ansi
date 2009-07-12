use strict;
use warnings;
use inc::Module::Install;

# we tell PAUSE not to index these packages, since they're not mine
my @packages = qw<
    Perl6::Perldoc::Ambient
    Perl6::Perldoc::Block
    Perl6::Perldoc::Config
    Perl6::Perldoc::Document
    Perl6::Perldoc::FormattingCode
    Perl6::Perldoc::Parser::ReturnVal
    Perl6::Perldoc::Root
>;
push @packages, map { "Perl6::Perldoc::Block::$_" } qw<
    Semantic code comment head1 head2 head3 head4 input
    item list nested output para pod table tocitem toclist
>;
push @packages, map { "Perl6::Perldoc::FormattingCode::$_"} qw<
    B C D E I K L M N Named P R S T U V X Z
>;

name          ('Perl6-Perldoc-To-Ansi');
author_from   ('lib/Perl6/Perldoc/To/Ansi.pm');
abstract_from ('lib/Perl6/Perldoc/To/Ansi.pm');
version_from  ('lib/Perl6/Perldoc/To/Ansi.pm');
license       ('artistic');
requires      ('Perl6::Perldoc' => '0.0.5');
test_requires ('Test::More'     => '0');
tests_recursive();
no_index      (package => $_) for @packages;
WriteAll();
