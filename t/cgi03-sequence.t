#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

my $module     = 't/cgi03';
my $scriptname = 'chart';
my $testname   = 'sequence';
my $test_in  = "$module-$testname.in";
my $test_out = "$module-$testname.out";
my $psfile   = "$module-$testname.ps";

my @CGI = ( '.',
    "$ENV{HOME}/cgi",
    $ENV{CGI_DIR},
    $ENV{HOME},
    'srv/www/cgi-bin',
    'usr/local/httpd/cgi-bin',
);

my ($cgi, $script, $found);
foreach $cgi (@CGI) {
    $script = "$cgi/$scriptname.pl" if defined $cgi;
    $found = -e $script;
    last if $found;
}
unless ($found) {
    no warnings;
    diag "Unable to find $scriptname.pl in any of these directories: ". join(",", @CGI);
    diag "Set environment variable CGI_DIR or symlink '~/cgi' to the CGI scripts before running this test again.";
    exit;
}

plan tests => 4;
ok($found, 'cgi scripts found');

my $output   = `$script 'test_in=$test_in' 'test_out=$test_out'`;
ok( $output, 'Output captured' );
$output =~ s{^Content-Type: application/postscript\r\n\r\n}{};
open OUT, '>', $psfile or die "Unable to write to $psfile : $!";
print OUT $output;
close OUT;
ok( 1, "Saved as $psfile" );
ok(-s $psfile == 68825, 'file correct size');	# the chart looks different?
