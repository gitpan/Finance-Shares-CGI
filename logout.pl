#!/usr/bin/perl
our $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI 0.03;

my $w = new Finance::Shares::CGI;
my $db = $w->login();
$w->get_records( param('s') );

$db->delete('Login::Sessions', 'session = ?', $w->{session});

my $heading;
($heading = <<end_heading) =~ s/^\s+//gm;
    <p align='center'>Thank you for your visit.  You are now logged out</p>
    <p align='center'>If you wish to continue, you will have to <a href='$w->{base_cgi}/login.pl'>log in</a> again.</p>    
end_heading

$w->print_header('Logout', $heading);
$w->print_footer();


