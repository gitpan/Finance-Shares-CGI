#!/usr/bin/perl
our $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI 0.03;

my $html;
my $w = new Finance::Shares::CGI;
$w->get_records( param('s') );
my $content = param('content') || 'interface';
my $table   = param('t') || 'Model';
my $args    = param('a')  || '';

$content = 'list', $table = '' if $w->{userlevel} == 4;
my $main = "$w->{base_cgi}/$content.pl?s=$w->{session};t=$table;a=$args";

if ($w->{frames}) {
    my ($col1, $col2);
    if ($w->{userlevel} == 1) {
	($col1, $col2) = ('17%', '83%');
    } elsif ($w->{dhtml}) {
	($col1, $col2) = ('17%', '83%');
    } else {
	($col1, $col2) = ('17%', '83%');
    }
    print header ();
    ($html = <<END_HTML) =~ s/^\s+//gm;
	<html><head>
	    <title>$w->{program}</title>
	    <base href='$w->{base_url}/'>
	</head>
	<frameset name='main' cols="$col1,$col2">
	    <frame name='menu' src='$w->{base_cgi}/menu.pl?s=$w->{session}'>
	    <frame name='content' src='$main'>
	</frameset>
	<noframes>
	    <body>
		<p>So, your browser can't handle frames.</p>
		<p>I hope that the site is still navigable without it.
		Please <a href='mailto:webmaster\@willmot.org.uk'>email me</a> if you come
		across something that doesn't work.</p>
		<p>If this page does not automatically redirect you,
		click <a href='$w->{base_cgi}/menu.pl?s=$w->{session}'>here</a> for the main menu.</p>
	    </body>
	</noframes>
	</html>
END_HTML
    print $html;
} else {
    print redirect "$w->{base_cgi}/menu.pl?s=$w->{session}";
}
