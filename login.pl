#!/usr/bin/perl
# $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Digest::MD5 qw(md5_hex);
use Finance::Shares::CGI 0.03;

my $login    = param('login')    || '';
my $password = param('password') || '';
my $choice   = param('choice')   || '';

my $w = new Finance::Shares::CGI;
$w->width();
if (defined url_param('frames')) {
    $w->{frames} = url_param('frames') || 0;
    $w->{css}    = url_param('css')    || 0;
    $w->{layers} = url_param('layers') || 0;
    $w->{dhtml}  = url_param('dhtml')  || 0;
    $w->{width}  = url_param('width')  || $w->{width};
} else {
    $w->{width}  = param('width')  || 499;
    $w->{frames} = param('frames') || 0;
    $w->{css}    = param('css')    || 0;
    $w->{layers} = param('layers') || 0;
    $w->{dhtml}  = param('dhtml')  || $w->{width};
}

my $line;
if ($choice eq 'Submit') {
    my $db = $w->login();
    my $urec = $db->select_hash('Login::Users', 'where login = ?', $login );
    my $encoded = md5_hex($password);
    if (($urec->{login} eq $login) 
	    and ($login ne '')
	    and	($urec->{pwd} eq $encoded)
	    and ($urec->{pwd} ne '')) {
	my $timestamp = $db->sql_eval('now()');
	my $digest = md5_hex($login . $timestamp);
	$db->replace( 'Login::Sessions', 
	    session => $digest,
	    userid  => $urec->{userid},
	    bwidth  => $w->{width},
	    frames  => $w->{frames},
	    css     => $w->{css},
	    layers  => $w->{layers},
	    dhtml   => $w->{dhtml} );
	print redirect ("$w->{base_cgi}/options.pl?s=$digest");
    } else {
	($line = <<end_heading) =~ s/^\s+//gm;
	<p class='centered'><b>Your login or password are incorrect.  Please try again</b></p>
end_heading
	show_form($line);
    }
} else {
    show_form();
}

sub show_form {
    my $errors = shift;
    
    my $url = url();
    my $script;
    ($script = <<end_script) =~ s/^\s+//gm;
    function set_vars() {
	var bwidth = 0;
	var frames = 0;
	var css = 0;
	var layers = 0;
	var dhtml = 0;
	
	if (screen.width) bwidth = 0.9 * screen.width;
	if (window.innerWidth) bwidth = 0.95 * window.innerWidth;

	if (document.getElementById) {
	    frames = 1; css = 1; dhtml = 1;
	} else if (document.all) {
	    frames = 1; css = 1;
	} else {
	    browserVersion = parseInt(navigator.appVersion);
	    if ((navigator.appName.indexOf('Netscape') != -1) && (browserVersion == 4)) {
		frames = 1; css=1; layers = 1;
	    } else {
		frames = 1;
	    }
	}
	if (layers) {
	    var search = window.location.search;
	    if (!search) {
		window.location = window.location.href + '?frames=' + frames + ';css=' + css +
			';layers=' + layers + ';dhtml=' + dhtml + ';width=' + bwidth;
	    }
	} else {
	    document.forms[0].width.value=bwidth;
	    document.forms[0].frames.value=frames;
	    document.forms[0].css.value=css;
	    document.forms[0].layers.value=layers;
	    document.forms[0].dhtml.value=dhtml;
	}
    }
end_script

    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p class='centered'>If you haven't been here before, 
    please <a href='$w->{base_cgi}/register.pl'>register here</a>.</p>
    <p class='centered'>Forgotten your password?  
    Let us <a href='$w->{base_cgi}/email.pl'>email</a> it to you.</p>
end_heading

    my $login_input = textfield(-name => 'login', -maxlength => '20');
    my $password_input = password_field(-name => 'password', -maxlength => '20');
    
    my $form;
    ($form = <<end_form) =~ s/^\s+//gm;
    <table align='center'>
	<tr>
	    <td align='right'>
		<p>Login name</p>
	    </td>
	    <td align='left'>
		$login_input
	    </td>
	</tr>
	<tr>
	    <td align='right'>
		<p>Password</p>
	    </td>
	    <td align='left'>
		$password_input
	    </td>
	</tr>
	<tr>
	    <td align='right'>
	    </td>
	    <td align='left'>
		<input type='submit' name='choice' value='Submit'/>
	    </td>
	</tr>
    </table>
    <input type='hidden' name='width' value='$w->{width}'>
    <input type='hidden' name='frames' value='$w->{frames}'>
    <input type='hidden' name='css' value='$w->{css}'>
    <input type='hidden' name='layers' value='$w->{layers}'>
    <input type='hidden' name='dhtml' value='$w->{dhtml}'>
end_form
    
    $w->print_header( 'Login', $heading, $script );
    #$w->show_params();
    $w->print_form_start();
    print "$errors\n" if $errors;
    print "$form\n";
    $w->print_form_end();
    print "<script language='javascript'>set_vars()</script>\n";
    $w->print_footer();
}

