#!/usr/bin/perl
our $VERSION = 0.02;
use strict;
use warnings;
use Pod::Usage;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params escapeHTML);
$CGI::Pretty::INDENT = '    ';
use DBIx::Namespace	   0.03;
use Finance::Shares::MySQL 1.03;
use Finance::Shares::CGI   0.03;

### CGI interface
my $w = new Finance::Shares::CGI;
my $db = $w->get_records();
$db->debug(4);
my $choice = param('choice');
my $title = 'Fetch Quotes';
my $text = q(<p>This page primes the database cache.  Quotes for the stock codes listed are fetched for the given
period.</p>);
unless ($choice) {
    $w->print_header($title,$text);
    $w->print_form_start();
    print "<table align='center' width='100%'>";
    print "<tr><td align='right'>Start date</td><td>";
    print textfield(-name => 'start_date');
    print "</td></tr>";
    print "<tr><td align='right'>End date</td><td>";
    print textfield(-name => 'end_date');
    print "</td></tr>";
    print "<tr><td align='right'>Enter !Yahoo stock codes, seperated by commas.</td><td>";
    print textarea(-name => 'codes', -rows => 10, -columns => 40);
    print "</td></tr><tr><td></td><td align = 'right'>";
    print submit(-name => 'choice', -value => 'Ok');
    print "</td></tr></table>";
    print hidden(-name => 's', -value => $w->{session});
    $w->print_form_end();
    $w->print_footer();
    exit;
}

print header();
print start_html(-title => $title);
print "<pre>";

no warnings;
open SAVEOUT, ">&STDOUT";
open SAVEERR, ">&STDERR";
open STDERR, ">&STDOUT" or warn "Can't dup stdout";
select STDOUT; $| = 1;
select STDERR; $| = 1;

my @codes      = split('[\s,]+', param('codes'));
my $start_date = param('start_date');
my $end_date   = param('end_date');

foreach my $stock_code (@codes) {
    eval {
	$db->fetch(
	    stock_code => $stock_code,
	    start_date => $start_date,
	    end_date   => $end_date,
	);
    };
    if ($@) {
	print $@;
    } else {
	print "$stock_code ok\n";
    }
}

close STDOUT;
close STDERR;
open STDOUT, ">&SAVEOUT";
open STDERR, ">&SAVEERR";
select STDERR; $| = 1;
select STDOUT; $| = 1;

print "</pre>";
print end_html();

