#!/usr/bin/perl
# shares.pl version 0.03;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI 0.11;

my $w = new Finance::Shares::CGI;
if (param 'u') {
    $w->get_records();
} else {
    $w->show_error('No user parameter');
    exit;
}

# record settings from index.html
if (defined param('frames')) {
    $w->{frames} = param('frames') || 0;
    $w->{css}    = param('css')    || 0;
    $w->{layers} = param('layers') || 0;
    $w->{dhtml}  = param('dhtml')  || 0;
}
$w->change_user();

my $html;
my $content = param('content') || 'interface';
my $table   = param('t') || 'Model';
my $args    = param('a')  || '';

$content = 'list', $table = '' if $w->{ulevel} == 4;
my $main = "$w->{base_cgi}/$content.pl?u=$w->{user};t=$table;a=$args";

if ($w->{frames}) {
    my ($col1, $col2);
    if ($w->{ulevel} == 1) {
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
	    <frame name='menu' src='$w->{base_cgi}/menu.pl?u=$w->{user}'>
	    <frame name='content' src='$main'>
	</frameset>
	<noframes>
	    <body>
		<p>So, your browser can't handle frames.</p>
		<p>I hope that the site is still navigable without it.
		Please <a href='mailto:webmaster\@willmot.org.uk'>email me</a> if you come
		across something that doesn't work.</p>
		<p>If this page does not automatically redirect you,
		click <a href='$w->{base_cgi}/menu.pl?u=$w->{user}'>here</a> for the main menu.</p>
	    </body>
	</noframes>
	</html>
END_HTML
    print $html;
} else {
    print redirect "$w->{base_cgi}/menu.pl?u=$w->{user}";
}
