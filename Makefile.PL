use ExtUtils::MakeMaker;
WriteMakefile(
    NAME	=> 'Finance::Shares::CGI',
    VERSION	=> '0.07',
    ABSTRACT_FROM => 'CGI.pod',
    AUTHOR      => 'Christopher Willmot <chris@willmot.org.uk>',
    PREREQ_PM	=> {
	'CGI::Carp' => 0,
	'CGI::Pretty' => 0,
	'DBIx::Namespace'           => 0.03,
	'PostScript::File'          => 1.00,
	'PostScript::Graph::Paper'  => 1.00,
	'PostScript::Graph::Style'  => 1.00,
	'PostScript::Graph::Key'    => 1.00,
	'Finance::Shares::MySQL'    => 1.04,
	'Finance::Shares::Model'    => 0.11,
	'Finance::Shares::Sample'   => 0.12,
	'Finance::Shares::Averages' => 0.12,
	'Finance::Shares::Bands'    => 0.13,
	'Finance::Shares::Momentum' => 0.01,
    },
    PM	=> {
	'CGI.pm' => '$(INST_LIBDIR)/CGI.pm',
    },
    MAN3PODS => {
	'CGI.pod' => '$(INST_MAN3DIR)/Finance::Shares::CGI.3pm',
    },
);
