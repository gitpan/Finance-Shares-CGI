#!/usr/bin/perl
our $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Digest::MD5 qw(md5_hex);
use Finance::Shares::CGI 0.03;

my $w = new Finance::Shares::CGI;
my $db = $w->login();
$w->get_records( param('s') );
my $passwd1 = param('password1') || '';
my $passwd2 = param('password2') || '';
my $hint    = param('hint')      || '';
my $choice  = param('choice')    || '';
my $admin   = param('admin')	 || 1;
warn "admin = $admin";

my (@password, @hint);
if ($choice eq '') {
    show_form();
} elsif ($choice eq 'Submit') {
    push @password, q(<b>You mistyped something - the passwords are not the same.</b>) unless $passwd1 eq $passwd2;
    push @password, q(<b>This password is too short.</b>) unless length($passwd1) > 5;
    push @password, q(<b>This password is too long.</b>) if length($passwd1) > 20;
    push @password, q(<b>There should be no spaces.</b>) if $passwd1 =~ /\s/;
    push @password, q(<b>Please include at least one number.</b>) unless $passwd1 =~ /[0-9]/;
    push @password, q(<b>Please include some lower case letters.</b>) unless $passwd1 =~ /[a-z]/;
    push @password, q(<b>Please include some capital (upper case) letters.</b>) unless $passwd1 =~ /[A-Z]/;
    push @hint, q(<b>You haven't given a password hint.</b>) if ($hint =~ /^\s*$/);
    if (@password or @hint) {
	show_form();
    } else {
	$w->change_user( hint => $hint, pwd => md5_hex($passwd1), userlevel => $admin );
	warn $w->show_hash($w);
	warn $w->show_hash($w->{urec});
	$db->delete('Login::Sessions', 'session = ?', $w->{session});
	show_ok();
    }
}

sub show_form {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
	<p>Thank you for completing the registration process.  The final piece of information we need from you is
	a password.</p>
end_heading

    $w->print_header('Registration', $heading);
    $w->print_form_start();
    print "<table align='center' cellpadding='8'>\n";
    my $password1  = password_field(-name => 'password1', -maxlength => '20');
    my $password2  = password_field(-name => 'password2', -maxlength => '20');
    my $hint_input = textfield(-name => 'hint', -maxlength => '32');

    my $html;
    ($html = <<end_html) =~ s/^\s+//gm;
	<tr>
	    <td colspan='2'>
		<p>Please enter your chosen password twice to ensure it was typed correctly.</p>
		<p>A good password should be more than 6 characters made up of numbers, lower and upper case letters.
		It is best if it is memorable to you but unguessable by anyone else.</p>
		<p>For example, say you have an early memory of an elephant walking in the street outside a zoo you
		once visited.  That might become <b>taEw9tStr8</b>.  Quite unguessable to anyone who doesn't remember
		'<b>t</b>here's <b>a</b>n <b>E</b>lephant <b>w</b>alking in(<b>9</b>) <b>t</b>he
		<b>Str</b>eet(<b>8</b>)'.</p>
	    </td>
	</tr>
end_html
    print $html;
     
    if (@password) {
	print "<tr><td colspan='2'>\n";
	foreach my $msg (@password) {
	    print qq(<p style='color: #ee2200'>$msg</p>);
	}
	print "</td></tr>\n";
    }
    
    ($html = <<end_html) =~ s/^\s+//gm;
	<tr>
	    <td align='right'>
		Password
	    </td>
	    <td align='left'>
		$password1<br>
		$password2
	    </td>
	</tr>
	<tr><td colspan='2'>
	    <p>Please enter a phrase which will remind you of the password you have chosen.</p>
	</td></tr>
end_html
    print $html;

    if (@hint) {
	print "<tr><td colspan='2'>\n";
	foreach my $msg (@hint) {
	    print qq(<p style='color: #ee2200'>$msg</p>);
	}
	print "</td></tr>\n";
    }
    
    ($html = <<end_html) =~ s/^\s+//gm;
	<tr>
	    <td align='right'>
		Password hint
	    </td>
	    <td align='left'>
		$hint_input
	    </td>
	</tr>
	<tr>
	    <td>
	    </td>
	    <td align='left'>
		<input type='submit' name='choice' value='Submit'/>
	    </td>
	</tr>
    </table>
    <input type='hidden' name='s' value='$w->{session}'>
    <input type='hidden' name='admin' value='$admin'>
end_html
    print $html;

    $w->print_form_end();
    $w->print_footer();
}

sub show_ok {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p>Thank you.  Your details have been stored so you should be able to <a href='$w->{base_cgi}/login.pl'>log in</a>
    now.</p>    
end_heading

    $w->print_header('Registration', $heading);
    $w->print_footer();
}

