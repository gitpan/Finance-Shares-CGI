#!/usr/bin/perl
# menu.pl version 0.05;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI 0.11;

my $db;
my $w = new Finance::Shares::CGI;
if (param 'u') {
    $db = $w->get_records();
} else {
    $w->show_error('No user parameter');
    exit;
}
#$w->{frames} = 1;
#$w->{css} = 1;

my $table = param('t') || '';
my $args  = param('a')  || '';
my $var;
($var) = ($table =~ /^!(\w+)$/);
if (defined($var) and ($var eq 'cache')) {
    $w->{cache} = $args;
    $w->change_user();
}

my $image_num = 0;
my $interface = "$w->{base_cgi}/interface.pl?u=$w->{user}";  
my $prefs     = "$w->{base_cgi}/prefs.pl?u=$w->{user}";  
my $this_menu = "$w->{base_cgi}/menu.pl?u=$w->{user}";  
my $browser   = "$w->{base_cgi}/browser.pl?u=$w->{user}";  
my $logout    = "$w->{base_cgi}/logout.pl?u=$w->{user}";  
my $chart     = "$w->{base_cgi}/chart.pl?u=$w->{user}";  
my $run       = "$w->{base_cgi}/run.pl?u=$w->{user}";  
my $list      = "$w->{base_cgi}/list.pl?u=$w->{user}";  
my $drop      = "$w->{base_cgi}/drop.pl?u=$w->{user}";  
my $init      = "$w->{base_cgi}/init.pl?u=$w->{user}";  
my $fetch     = "$w->{base_cgi}/fetch.pl?u=$w->{user}";  

my $menu_full = "!menuNU.gif";
my $menu_out  = "!menuNS.gif";
my $menu_over = "!menuMS.gif";
my $item_out  = "!itemNU.gif";
my $item_over = "!itemMU.gif";
my $isel_out  = "!itemNS.gif";
my $isel_over = "!itemMS.gif";

### Normal Menu
# each entry has url, id, prompt, table, arg, heading, submenu
my @normal = (
    '', 'prefs', 'Preferences', [
	$prefs     ,'User levels'       ,''         ,'',
	$this_menu ,'Online mode'       ,'!cache'   ,'online',
	$this_menu ,'Fetch mode'        ,'!cache'   ,'fetch',
	$this_menu ,'Cache mode'        ,'!cache'   ,'cache',
	$this_menu ,'Offline mode'      ,'!cache'   ,'offline',
    ],
    '', '', '', undef,
    '', 'models',  'Settings', [
	$interface ,'Model'             ,'Model'    ,'',
	$interface ,'Samples'           ,'Sample'   ,'',
	'', 'tests', 'Tests', [
	    $interface ,'Tests'         ,'Test'     ,'',
	    $interface ,'Functions'     ,'Function' ,'',
	    $interface ,'Signals'       ,'Signal'   ,'',
	],
	'', 'chart', 'Chart', [
	    $interface ,'Chart'         ,'Chart'    ,'',
	    $interface ,'Prices graph'  ,'Graph'    ,'p',
	    $interface ,'Volumes graph' ,'Graph'    ,'v',
	    $interface ,'Cycles graph'  ,'Graph'    ,'c',
	    $interface ,'Signals graph' ,'Graph'    ,'s',
	    $interface ,'Dates axis'    ,'Axis'     ,'x',
	    $interface ,'Key panels'    ,'Key_Panel','',
	    $interface ,'Styles'        ,'Style'    ,'l',
	    $interface ,'Sequences'     ,'Sequence' ,'',
	    $interface ,'Fonts'         ,'Font'     ,'',
	],
	$interface ,'Results file'      ,'File'     ,'',
    ],
    '', '', '', undef,
    $interface ,'Draw chart'            ,'Draw'     ,'',
    $interface ,'Run model'             ,'Model'    ,'',
);

### Admin Menu
my @admin = (
    '', '', '', undef,
    '', 'admin', 'Administration', [
    $list      ,'List tables'           ,''         ,'',
    $init      ,'Initialize tables'     ,''         ,'',
    $drop      ,'Drop a table'          ,''         ,'',
    $fetch     ,'Fetch quotes'          ,''         ,'',
    ],
);

### Main program
$w->print_header('Menu');
my $menu = $w->{admin} ? [ @normal, @admin ] : [ @normal ];
menu('top', $menu);
print qq(</body></html>\n);

sub menu {
    my ($id, $menu, $level) = @_;
    $level = 0 unless defined $level;
    print qq(<ul>\n) unless $w->{frames}; 
    
    while (@$menu) {
	my ($url, $id, $prompt, $table, $arg, $heading, $submenu);
	$url = shift @$menu;
	if ($url) {
	    ## item
	    $prompt  = shift @$menu;
	    $table   = shift @$menu;
	    $arg     = shift @$menu;
	} else {
	    ## submenu
	    $id      = shift @$menu;
	    $heading = shift @$menu;
	    $submenu = shift @$menu;
	}
	if ($submenu) {
	    submenu($url, $id, $prompt, $table, $arg, $heading, $level);
	    print qq(<div id=${id}Menu class='menu'>) if $w->{css};
	    menu($id, $submenu, $level+1);
	    print qq(</div>) if $w->{css};
	} elsif ($url) {
	    item($url, $prompt, $table, $arg, $level);
	} else {
	    print qq(<br>);
	}
    }
    
    print qq(</ul>\n) unless $w->{frames}; 
}

sub spacers {
    my ($level) = @_;
    my $text = '';
    for (my $i = 0; $i < $level-1; $i++) {
	($text .= <<"end_text") =~ s/^\s+//gm;
	<img src='!spacer.gif' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
end_text
	$image_num++;
    }
    if ($level) {
	($text .= <<"end_text") =~ s/^\s+//gm;
	<img src='!spacer.gif' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
end_text
	$image_num++;
    }
    return $text;
}

sub item {
    my ($url, $prompt, $table, $arg, $level) = @_;
    $table = '' unless defined $table;
    $arg = '' unless defined $arg;
    my $target = ($url eq $this_menu) ? 'menu' : 'content';
    my ($class, $out, $over, $var);
    $class = 'item';
    $out = $item_out;
    $over = $item_over;
    ($var) = ($table =~ /^!(\w+)$/);
    if ($var and $w->{$var} eq $arg) {
	$class = 'isel';
	$out = $isel_out;
	$over = $isel_over;
    }
    
    my $text = '';
    if ($w->{css}) {
	# Uses CSS and Javascript
	print spacers($level);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a class='$class' href ='$url;t=$table;a=$arg' target='$target'
	onmouseover='document.images[$image_num].src="$over"' onmouseout='document.images[$image_num].src="$out"'>
	<img src='$out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$prompt</a><br>
end_text
	$image_num++;
    } elsif ($w->{frames}) {
	# HTML only
	print spacers($level);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a href ='$url;t=$table;a=$arg' target='$target'>
	<img src='$out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$prompt</a><br>
end_text
	$image_num++;
    } else {
	# No frames
	($text = <<"end_text") =~ s/^\s+//gm;
	<li><a href ='$url;t=$table;a=$arg'>
	$prompt
	</a></li>
end_text
    }
    print $text;
}

sub submenu {
    my ($url, $id, $prompt, $table, $arg, $heading, $level) = @_;
    $table = '' unless defined $table;
    $arg = '' unless defined $arg;
    $heading = $prompt unless defined $heading;
    
    my $text = '';
    if ($w->{css}) {
	# Uses CSS and Javascript
	print spacers($level);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a class='head' href = $this_menu>
	<img id='$id' src='$menu_out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$heading</a><br>
end_text
	$image_num++;
    } elsif ($w->{frames}) {
	# HTML only
	print spacers($level);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a href = $this_menu>
	<img src='$menu_out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$heading</a><br>
end_text
	$image_num++;
    } else {
	# No frames
	($text = <<"end_text") =~ s/^\s+//gm;
	<li><a href = $this_menu>
	$heading
	</a></li>
end_text
    }
    
    print $text;
}

