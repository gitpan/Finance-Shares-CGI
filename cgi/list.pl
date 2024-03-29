#!/usr/bin/perl
# list.pl version 0.03;
use strict;
use warnings;
use Pod::Usage;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params escapeHTML);
$CGI::Pretty::INDENT = '    ';
use DBIx::Namespace      0.03;
use Finance::Shares::CGI 0.11;

my $db;
my $w = new Finance::Shares::CGI;
if (param 'u') {
    $db = $w->get_records();
} else {
    $w->show_error('No user parameter');
    exit;
}

my $table = param('t');
my $choice = param('choice');
unless ($choice) {
    $w->print_header('Mysql Tables','');
    $w->print_form_start();
    print p('Which table prefix?  (Leave blank for all tables)');
    print textfield(-name => 't');
    print submit(-name => 'choice', -value => 'Ok');
    print hidden(-name => 'u', -value => $w->{user});
    $w->print_form_end();
    $w->print_footer();
    exit;
}

print header();
print start_html(-title => 'Mysql Tables');
print "<pre>";

my @rows = $db->sql_names($db->table($table));
foreach my $r (@rows) {
    my ($name, $table, $level) = @$r;
    my $count = '';
    if ($table =~ /^t\d+$/) {
	eval {
	    my $n = $db->sql_eval("count(*) from $table");
	    $count = "($n)"; 
	};
    }
    printf '%5s %6s %s%s%s', $table, $count, '  ' x $level, $name, "\n";
}

print "</pre>";
print end_html();

