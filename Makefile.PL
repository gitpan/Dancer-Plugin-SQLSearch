use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Dancer::Plugin::SQLSearch',
    AUTHOR              => q{Julio Fraire <julio.fraire@gmail.com>},
    VERSION_FROM        => 'lib/Dancer/Plugin/SQLSearch.pm',
    ABSTRACT_FROM       => 'lib/Dancer/Plugin/SQLSearch.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Dancer'     => '1.3080',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Dancer-Plugin-SQLSearch-*' },
);
