use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'DaemonToolKit',
    AUTHOR              => q{Andre Tomt <andre@tomt.net>},
    VERSION_FROM        => 'lib/DaemonToolKit.pm',
    ABSTRACT_FROM       => 'lib/DaemonToolKit.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'DaemonToolKit-*' },
);
