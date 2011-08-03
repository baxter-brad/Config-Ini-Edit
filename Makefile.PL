use 5.008000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Config::Ini::Edit',
    VERSION_FROM      => 'lib/Config/Ini/Edit.pm', # finds $VERSION
    PREREQ_PM         => {
        'JSON'               => 2.51,
        'Config::Ini'        => 1.04,
        'Config::Ini::Quote' => 1.01,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Config/Ini/Edit.pm', # retrieve abstract from module
       AUTHOR         => 'Brad Baxter <bbaxter@cpan.org>') : ()),
);
