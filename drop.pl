#!/usr/bin/perl
# $VERSION = 0.02;
use strict;
use warnings;
use Pod::Usage;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params escapeHTML);
$CGI::Pretty::INDENT = '    ';
use DBIx::Namespace	 0.03;
use Finance::Shares::CGI 0.03;

my $w = new Finance::Shares::CGI;
my $db = $w->get_records();
my $table = param('t');
my $choice = param('choice');
my $title = 'Drop table';
unless ($choice) {
    $w->print_header($title,'');
    $w->print_form_start();
    print p('Which table do you want to remove?');
    print textfield(-name => 't');
    print submit(-name => 'choice', -value => 'Ok');
    print hidden(-name => 's', -value => $w->{session});
    $w->print_form_end();
    $w->print_footer();
    exit;
}

print header();
print start_html(-title => $title);

my $r1;
eval {
    $r1 = $db->delete($table);
};
if ($@) {
    print "Deleting '$table' failed : $@\n";
} else {
    print "Deleting '$table' ", $r1 ? "succeeded\n" : "failed\n";
}

print end_html();

