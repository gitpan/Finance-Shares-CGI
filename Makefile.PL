use ExtUtils::MakeMaker;
WriteMakefile(
    NAME	=> 'Finance::Shares::CGI',
    VERSION	=> '0.03',
    ABSTRACT	=> 'CGI Interface for Finance::Shares',
    AUTHOR      => 'Christopher Willmot <chris@willmot.org.uk>',
    PREREQ_PM	=> {
	'CGI::Carp' => 0,
	'CGI::Pretty' => 0,
	'Finance::Shares::MySQL' => 1.03,
    },
    PM	=> {
	'CGI.pm' => '$(INST_LIBDIR)/CGI.pm',
    },
    MAN3PODS => {
	'CGI.pod' => '$(INST_LIBDIR)/CGI.pod',
    },
);
