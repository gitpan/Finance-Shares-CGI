#!/usr/bin/perl
# $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI 0.03;

my $w = new Finance::Shares::CGI;
my $db = $w->login();
$w->get_records( param('s') );

my $choice = param('choice') || '';
my $frames = $w->{frames};
my $layers = $w->{layers};
my $css    = $w->{css};
my $dhtml  = $w->{dhtml};
my $width  = $w->{width}; 

if ($choice eq 'Save') {
    $frames = param('frames');
    $layers = param('layers');
    $css    = param('css');
    $dhtml  = param('dhtml');
    $width  = param('width');
    $w->change_session( frames => $frames, layers => $layers, css => $css, dhtml => $dhtml, bwidth => $width );
    show_ok();
} elsif ($choice eq 'Cancel') {
    show_cancel();
} else {
    show_form();
}

sub show_form {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
	<p>This page allows direct manual control of how this site delivers pages.  If say, the menu won't show,
	try clearing one of the check boxes and clicking <span class='btn'>&nbsp;Save&nbsp;</span>.</p>
	<p>With nothing checked, all pages should work on even the oldest, text only
	browsers.</p>
	<p>If you've noticed something you'd like to comment on, do please email
	<a href='mailto:$w->{webmaster}'>$w->{webmaster}</a>.</p>
end_heading

    $w->print_header('Browser settings', $heading);
    $w->print_form_start();

    my $frames_input = checkbox(-name => 'frames', -checked => $frames, -value => 1, -label => 'Frames');
    my $layers_input = checkbox(-name => 'layers', -checked => $layers, -value => 1, -label => 'Layers');
    my $css_input    = checkbox(-name => 'css',    -checked => $css,    -value => 1, -label => 'Style sheets');
    my $dhtml_input  = checkbox(-name => 'dhtml',  -checked => $dhtml,  -value => 1, -label => 'Dynamic effects');
    
    my ($col1, $col2) = ('30%', '70%');
    my $html;
    ($html = <<end_html) =~ s/^\s+//gm;
    <table align='center' cellpadding='8'>
	<tr>
	    <td width='$col1'>
		$dhtml_input
	    </td>
	    <td width='$col2'>
		<p>This enables the most sophisticated code which complies with the most recent standards.  If
		your having problems, this is the one to turn off first.</p>
	    </td>
	</tr>
	<tr>
	    <td width='$col1'>
		$css_input
	    </td>
	    <td width='$col2'>
		<p>Most browsers should be able to handle this.  Turn it off if your browser has disabled
		Cascading Style Sheets or you are using a stylesheet of your own.</p>
	    </td>
	</tr>
	<tr>
	    <td width='$col1'>
		$layers_input
	    </td>
	    <td width='$col2'>
		<p>Most browsers don't need this.  Turning this on might enhance pages shown on <b>Netscape 4</b>
		browsers, but note that the other choices you make may be altered.</p>
	    </td>
	</tr>
	<tr>
	    <td width='$col1'>
		$frames_input
	    </td>
	    <td width='$col2'>
		<p>Almost all browsers these days can handle frames.  But turning this off will give text-only
		pages suitable for accessibility enhancing browsers.  This is the only option which will have any
		effect if your browser has <b>JavaScript</b> disabled.</p>
	    </td>
	</tr>
	<tr>
	    <td width='$col1'>
		<p></p> 
	    </td>
	    <td width='$col2'>
		<input type='submit' name='choice' value='Save'/><input type='submit' name='choice' value='Cancel'/>
	    </td>
	</tr>
    </table>
    <script language='javascript'>
	var bwidth = 0;
	if (screen.width) bwidth = 0.9 * screen.width;
	if (window.innerWidth) bwidth = 0.95 * window.innerWidth;
	document.writeln("<input type='hidden' name='width' value=" + bwidth + ">");
    </script>
    <input type='hidden' name='s' value='$w->{session}'>
end_html
    print $html;

    $w->print_form_end();
    $w->print_footer();
}

sub show_ok {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p>Your settings have been saved and will take effect when the page is reloaded.  If this doesn't happen
    automatically, <a href='$w->{base_cgi}/options.pl?s=$w->{session}' target='_top'>click here</a> or press the <span class='btn'>&nbsp;Reload&nbsp;</span> button on
    your browser.</p>
    <script language='javascript'>
	top.location='$w->{base_cgi}/options.pl?s=$w->{session}';
    </script>
end_heading
    $w->print_header('Browser settings', $heading);
    $w->print_footer();
}

sub show_cancel {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p>If there is no menu visible, click <a href='$w->{base_cgi}/menu.pl?s=$w->{session}' target='top'>here</a></p>
end_heading
    $w->print_header('Browser settings', $heading);
    $w->print_footer();
}


