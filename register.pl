#!/usr/bin/perl
our $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table);
$CGI::Pretty::INDENT = '    ';
use Digest::MD5 qw(md5_hex);
use Mail::Sendmail;
use Finance::Shares::CGI 0.03;
    
my $w = new Finance::Shares::CGI;
my $db = $w->login();
$w->params();
my $login  = param('login')  || '';
my $email1 = param('email1') || '';
my $choice = param('choice') || '';

### Choices
my (@login, @email);
if ($choice eq '') {
    show_form();
} elsif ($choice eq 'Submit') {
    push @login, q(<b>Please fill in this field with a single name identifying yourself.</b>) unless $login;
    push @login, q(<b>No spaces here, please.</b>) if $login =~ /\s+/;
    push @login, q(<b>There must no more than 20 characters.</b>) if length($login) > 20;
    push @email, q(<b>Please enter a valid email address.</b>) unless $email1;
    push @email, q(<b>There should be no spaces in your email address.</b>) if $email1 =~ /\s+/;
    push @email, q(<b>Your email address should look like 'myname@somewhere.com'.</b>) unless $email1 =~ /[^\s]+@[^\s.]+[^\s]+/;
    push @email, q(<b>There must be no more than 40 characters.</b>) if length($email1) > 40;
    if (@login or @email) {
	show_form();
    } else {
	my ($email, $pwd);
	(($email, $pwd)) = $db->select('Login::Users', 'pwd, email', 'where login = ?', $login);
	if ($email) {
	    if ($email eq $email1) {
		if ($pwd) {
		    show_member();
		} else {
		    new_member($email1);
		}
	    } else {
		push @login, q(<b>Sorry, that login is already taken.</b>);
		show_form();
	    }
	} else {
	    new_member($email1);
	}
    }
}

### Finish
$db->disconnect();

sub show_form {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p class='centered'>You will need to specify some settings of your own.  By registering, we will be able to store them for you.</p>
    <p class='centered'>Your email address is only used for identification and will not passed to anyone else.</p>    
end_heading

    $w->print_header('Registration', $heading);
    $w->print_form_start();
    print "<table align='center' cellpadding='8'>\n";
    #$w->show_params();

    my $login_input =  textfield(-name => 'login', -maxlength => '20');
    my $email1_input = textfield(-name => 'email1', -maxlength => '40');
    
    my $html;
    ($html = <<end_html) =~ s/^\s+//gm;
	<tr>
	    <td colspan='2'>
		<p>Please enter the name you wish to be known by.</p>
	    </td>
	</tr>
end_html
    print $html;
    
    if (@login) {
	print "<tr><td colspan='2'>\n";
	foreach my $msg (@login) {
	    print qq(<p style='color: #ee2200'>$msg</p>\n);
	}
	print "</td></tr>\n";
    }
    
    ($html = <<end_html) =~ s/^\s+//gm;
	<tr>
	    <td align='right'>
		Login name
	    </td>
	    <td align='left'>
		$login_input
	    </td>
	</tr>
end_html
    print $html;
    
    if (@email) {
	print "<tr><td colspan='2'>\n";
	foreach my $msg (@email) {
	    print qq(<p style='color: #ee2200'>$msg</p>);
	}
	print "</td></tr>\n";
    }
	
    ($html = <<end_html) =~ s/^\s+//gm;
	<tr>
	    <td align='right'>
		Email
	    </td>
	    <td align='left'>
		$email1_input<br>
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
end_html
    print $html;

    $w->print_form_end();
    $w->print_footer();
}

sub show_member {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p>It seems that you are already a member.</p>
    <p>Please <a href='$w->{base_cgi}/login.pl'>log in</a> as normal.</p>    
end_heading

    $w->print_header('Registration', $heading);
    $w->print_footer();
}
sub show_register {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p>Thank you for registering with this site.  You should shortly receive an email from us.  When it arrives,
    follow the link provided to complete the registration process.</p>
end_heading

    $w->print_header('Registration', $heading);
    $w->print_footer();
}

sub new_member {
    my $email = shift;
    my $digest = md5_hex($login . $email . localtime);
    my $r = $db->replace( 'Login::Users', login => $login, pwd => '', email => $email );
    my $userid = $db->sql_eval('last_insert_id()');
    $db->replace( 'Login::Sessions', userid => $userid, session => $digest );

    my %mail = (
	From => 'auto-mailer@willmot.org.uk',
	To => $email1,
	Subject => 'Share Modelling Registration',
    );
    ($mail{Body} = <<end_message) =~ s/^\s+//gm;
	Thank you for registering with $w->{program}.
	Your login name will be '$login'.
	Please go to $w->{base_cgi}/password.pl?s=$digest to choose a password.
end_message
    sendmail(%mail);

    show_register();
}

