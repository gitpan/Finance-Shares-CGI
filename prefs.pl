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
$w->get_records( param('s') );  # $urec and $srec 

my $choice = param('choice') || '';
my $userlevel = $w->{userlevel};
my $helplevel = $w->{helplevel};

if ($choice eq 'Save') {
    $userlevel = param('userlevel');
    $helplevel = param('helplevel');
    $w->change_user( userlevel => $userlevel, helplevel => $helplevel );
    show_ok();
} elsif ($choice eq 'Cancel') {
    show_cancel();
} else {
    show_form();
}

sub show_form {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
	<p>Not everyone is the same, and we all need a little more help with unfamiliar things.</p>
	<p>Here you may change the amount of information the site gives you when constructing your model.</p>
end_heading

    $w->print_header('User & help levels', $heading);
    $w->print_form_start();

    my $user_input;
    if ($w->{userlevel} < 4) {
	$user_input = radio_group(-name => 'userlevel', -default => $userlevel, -linebreak => 'true',
	    -values => [1,2,3], -labels => { 1 => 'Beginner', 2 => 'Intermediate', 3 => 'Specialist' });
    } else {
	$user_input = radio_group(-name => 'userlevel', -default => $userlevel, -linebreak => 'true',
	    -values => [1,2,3,4], -labels => { 1 => 'Beginner', 2 => 'Intermediate', 3 => 'Specialist', 4 => 'Admin' });
    }
    my $help_input = radio_group(-name => 'helplevel', -default => $helplevel, -linebreak => 'true',
	-values => [1,2,3], -labels => { 1 => 'Simple', 2 => 'Brief', 3 => 'Detailed' });
    
    my ($col1, $col2) = ('25%', '75%');
    my $html;
    ($html = <<end_html) =~ s/^\s+//gm;
    <table align='center' cellpadding='8'>
	<tr><td colspan='2'><hr></td></tr>
	<tr>
	    <td width='$col1'>
		$user_input
	    </td>
	    <td width='$col2'>
		<p>There are a lot of settings, so it is probably best to start with <b>Beginner</b> which only
		offers you the main options.</p>
		<p>Once you have understood the way things work, <b>Intermediate</b> is probably the best choice.
		All the useful options are here.</p>
		<p>The <b>Specialist</b> setting offers you all the possible options, whether you need them or are
		just curious.</p>
	    </td>
	</tr>
	<tr><td colspan='2'><hr></td></tr>
	<tr>
	    <td width='$col1'>
		$help_input
	    </td>
	    <td width='$col2'>
		<p>This second group controls the help text next to each option.  If you haven't used this model
		before, <b>Simple</b> would be best.</p>
		<p>Alternative help texts are provided where it is useful.  If you are already familiar with the
		model, <b>Brief</b> help may be all you need.  The <b>Detailed</b> setting provides more technical
		information, often referring to the underlying software.</p>
	    </td>
	</tr>
	<tr><td colspan='2'><hr></td></tr>
	<tr>
	    <td width='$col1'>
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
end_heading
#    <script language='javascript'>
#	top.location='$w->{base_cgi}/options.pl?s=$w->{session}';
#    </script>
    $w->print_header('Preferences', $heading);
    $w->print_footer();
}

sub show_cancel {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p>If there is no menu visible, click <a href='$w->{base_cgi}/menu.pl?s=$w->{session}' target='top'>here</a></p>
end_heading
    $w->print_header('Preferences', $heading);
    $w->print_footer();
}


