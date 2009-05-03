use strict;
use warnings;
use inc::Module::Install;

if ($Module::Install::AUTHOR) {
    system "pod2text lib/Perl6/Perldoc/To/Ansi.pm > README";
}
clean_files('README');

name          ('Perl6-Perldoc-To-Ansi');
author_from   ('lib/Perl6/Perldoc/To/Ansi.pm');
abstract_from ('lib/Perl6/Perldoc/To/Ansi.pm');
version_from  ('lib/Perl6/Perldoc/To/Ansi.pm');
license       ('artistic');
requires      ('Perl6::Perldoc' => '0.0.5');
WriteAll();
