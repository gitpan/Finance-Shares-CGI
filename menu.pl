#!/usr/bin/perl
# $VERSION = 0.04;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI 0.03;

my $w = new Finance::Shares::CGI;
$w->get_records( param('s') );
#$w->{frames} = 1;
#$w->{css} = 1;
$w->{dhtml} = 0;

my $table = param('t') || '';
my $args  = param('a')  || '';
my $var;
($var) = ($table =~ /^!(\w+)$/);
if (defined($var) and ($var eq 'cache')) {
    $w->{cache} = $w->{srec}{cache} = $args;
    $w->change_session();
}

my $image_num = 0;
my $interface = "$w->{base_cgi}/interface.pl?s=$w->{session}";  
my $prefs     = "$w->{base_cgi}/prefs.pl?s=$w->{session}";  
my $this_menu = "$w->{base_cgi}/menu.pl?s=$w->{session}";  
my $browser   = "$w->{base_cgi}/browser.pl?s=$w->{session}";  
my $logout    = "$w->{base_cgi}/logout.pl?s=$w->{session}";  
my $login     = "$w->{base_cgi}/login.pl?";  
my $chart     = "$w->{base_cgi}/chart.pl?s=$w->{session}";  
my $run       = "$w->{base_cgi}/run.pl?s=$w->{session}";  
my $list      = "$w->{base_cgi}/list.pl?s=$w->{session}";  
my $drop      = "$w->{base_cgi}/drop.pl?s=$w->{session}";  
my $init      = "$w->{base_cgi}/init.pl?s=$w->{session}";  
my $fetch     = "$w->{base_cgi}/fetch.pl?s=$w->{session}";  

my $menu_full = "!menuNU.gif";
my $menu_out  = "!menuNS.gif";
my $menu_over = "!menuMS.gif";
my $item_out  = "!itemNU.gif";
my $item_over = "!itemMU.gif";
my $isel_out  = "!itemNS.gif";
my $isel_over = "!itemMS.gif";

### Admin Menu
# each entry has url, id, prompt, table, arg, heading, submenu
my $admin = [
    $browser, 'browser', 'Preferences', '', '', 'Preferences', [
	$prefs, undef, 'User & help levels','', '', undef, undef,
	$this_menu, undef, 'Online', '!cache', 'online', undef, undef,
	$this_menu, undef, 'Online (caching)', '!cache', 'cache', undef, undef,
	$this_menu, undef, 'Offline (cache)', '!cache', 'offline', undef, undef,
    ],
    $logout, undef, 'Log out','', '', undef, undef,
    '', '', '', '', '', undef, undef,
    $list, 'admin', 'Tables', '', '', 'Administration', [
    $init, undef, 'Initialize tables', '', '', undef, undef,
    $drop, undef, 'Drop a table', '', '', undef, undef,
    $fetch, undef, 'Fetch quotes', '', '', undef, undef,
    ],
];

### Normal Menu
my $normal = [
    $browser, 'browser', 'Browser settings', '', '', 'Preferences', [
	$prefs, undef, 'User & help levels','', '', undef, undef,
	$this_menu, undef, 'Online', '!cache', 'online', undef, undef,
	$this_menu, undef, 'Online (caching)', '!cache', 'cache', undef, undef,
	$this_menu, undef, 'Offline (cache)', '!cache', 'offline', undef, undef,
    ],
    $logout, undef, 'Log out','', '', undef, undef,
    '', '', '', '', '', undef, undef,
    $interface, 'models', 'Model', 'Model', 'Settings', undef, [
	$interface, undef, 'Samples', 'Sample', '', undef, undef,
	$interface, 'tests', 'Tests', 'Test', 'Tests', undef, [
	    $interface, undef, 'Functions', 'Function', '', undef, undef,
	    $interface, undef, 'Signals', 'Signal', '', undef, undef,
	],
	$interface, 'chart', 'Chart', 'Chart', 'Chart', undef, [
	    $interface, 'prices', 'Prices graph', 'Graph', 'p', undef, undef,
	    $interface, 'volumes', 'Volumes graph', 'Graph', 'v', undef, undef,
	    $interface, undef, 'Cycles graph', 'Graph', 'c', undef, undef,
	    $interface, undef, 'Signals graph', 'Graph', 's', undef, undef,
	    $interface, undef, 'Dates axis', 'Axis', 'x', undef, undef,
	    $interface, undef, 'Key panels', 'Key_Panel', '', undef, undef,
	    $interface, undef, 'Styles', 'Style', 'l', undef, undef,
	    $interface, undef, 'Sequences', 'Sequence', '', undef, undef,
	    $interface, undef, 'Fonts', 'Font', '', undef, undef,
	],
	$interface, undef, 'Results file', 'File', '', undef, undef,
    ],
    '', '', '', '', '', undef, undef,
    $interface, undef, 'Draw chart','Draw', '', undef, undef,
    $interface, 'models', 'Run model', 'Model', '', undef, undef,
];

### Javascript
my $dhtml_script;
($dhtml_script = <<end_script) =~ s/^\s+//gm;
    function obj(objId) {
	if (document.getElementById) {
	    return document.getElementById(objId);
	} else if (document.all) {
	    return document.all[objId];
	}
    }
     function objStyle(objId) {
	if (document.getElementById) {
	    return document.getElementById(objId).style;
	} else if (document.all) {
	    return document.all[objId].style;
	}
    }
    
    function clk(objId, imageNum) {
	domObj = obj(objId);
	name = domObj.id + 'Menu';
	if (show[name]) {
	    show[name] = 0;
	    objStyle(name).display = 'none';
	} else {
	    show[name] = 2;
	    objStyle(name).display = 'block';
	}
	document.images[imageNum].src=gif[ show[name]+1 ];
    }

    function over(objId, imageNum) {
	domObj = obj(objId);
	name = domObj.id + 'Menu';
	document.images[imageNum].src=gif[ show[name]+1 ];
    }

    function out(objId, imageNum) {
	domObj = obj(objId);
	name = domObj.id + 'Menu';
	document.images[imageNum].src=gif[ show[name] ];
    }

    gif = new Array(4);
    gif[0] = "!menuNU.gif";
    gif[1] = "!menuMU.gif";
    gif[2] = "!menuNS.gif";
    gif[3] = "!menuMS.gif";

    show = new Object;
    addr = new Object;
end_script

#top.frames[1].location = url + ';t=' + table + ';a=' + arg;
	    
### Main program
my $menu = ($w->{userlevel} == 4) ? $admin : $normal;
$w->print_header('Menu', undef, ($w->{dhtml} ? $dhtml_script : undef) );
if ($w->{dhtml}) {
    print qq(<script language='javascript'>\n);
    js_menu('top', $menu);
    print qq(</script>\n);
}
menu('top', $menu);
print qq(</body></html>\n);

sub menu {
    my ($id, $menu, $level) = @_;
    $level = 0 unless defined $level;
    print qq(<ul>\n) unless $w->{frames}; 
    
    while (@$menu) {
	my $url     = shift @$menu;
	my $id      = shift @$menu;
	my $prompt  = shift @$menu;
	my $table   = shift @$menu;
	my $arg     = shift @$menu;
	my $heading = shift @$menu;
	my $submenu = shift @$menu;
	my $more    = @$menu;
	if ($submenu) {
	    submenu($url, $id, $prompt, $table, $arg, $heading, $level);
	    my $class = $level ? 'menu' : 'top';
	    if ($w->{dhtml}) {
		print qq(<div id=${id}Menu class='menu' style='margin-left:16px'>);
		item($url, $prompt, $table, $arg, $level);
	    } elsif ($w->{css}) {
		print qq(<div id=${id}Menu class='menu'>);
	    }
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
    if ($w->{dhtml}) {
	# Uses active DOM
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a class='$class' href ='$url;t=$table;a=$arg' target='$target'
	onmouseover='document.images[$image_num].src="$over"' onmouseout='document.images[$image_num].src="$out"'>
	<img src='$out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$prompt</a><br>
end_text
	$image_num++;
    } elsif ($w->{css}) {
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
    if ($w->{dhtml}) {
	# Uses active DOM
	$heading = uc($heading);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<div><a class='head' href ='javascript:void 0' target='content'
	onclick='clk("$id",$image_num)' onmouseover='over("$id",$image_num)' onmouseout='out("$id",$image_num)'>
	<img id='$id' src='$menu_full' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$heading</a></div>
end_text
	$image_num++;
    } elsif ($w->{css}) {
	# Uses CSS and Javascript
	print spacers($level);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a class='head' href ='$url;t=$table;a=$arg' target='content'
	onmouseover='document.images[$image_num].src="$menu_over"' onmouseout='document.images[$image_num].src="$menu_out"'>
	<img id='$id' src='$menu_out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
	$prompt</a><br>
end_text
	$image_num++;
    } elsif ($w->{frames}) {
	# HTML only
	print spacers($level);
	($text .= <<"end_text") =~ s/^\s+//gm;
	<a href ='$url;t=$table;a=$arg' target='content'>
	<img src='$menu_out' width='16' height='12' border='0' hspace='0' vspace='0' valign='middle'/>
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

sub js_menu {
    my ($id, $m) = @_;
    my @menu = @$m;
    while (@menu) {
	my $url     = shift @menu;
	my $id      = shift @menu;
	my $prompt  = shift @menu;
	my $table   = shift @menu;
	my $arg     = shift @menu;
	my $heading = shift @menu;
	my $submenu = shift @menu;
	if ($submenu) {
	    print qq(show.${id}Menu=0; addr.$id='$url;t=$table;a=$arg';\n);
	    js_menu($id, $submenu);
	}
    }
}

