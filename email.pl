#!/usr/bin/perl
our $VERSION = 0.02;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table);
$CGI::Pretty::INDENT = '    ';
use Mail::Sendmail;
use Finance::Shares::CGI 0.03;

my $email    = param('email')  || '';
my $choice   = param('choice') || '';
my $w = new Finance::Shares::CGI;
$w->params();

if ($choice eq '') {
    show_form();
} elsif ($choice eq 'Submit') {
    my $db = $w->login();
    my @res = $db->select('Login::Users', 'login, hint', 'where email = ?', $email);
    if (@res) {
	my %mail = (
	    From => 'auto-mailer@willmot.org.uk',
	    To => $email,
	    Subject => 'Share Modelling Registration Details',
	);
	($mail{Body} = <<end_message);
Someone, probably you, has requested your login details for our web site.

These are the details we have for this email address:

end_message
	foreach my $row (@res) {

	    $mail{Body} .= "\tFor login '$row->[0]', the password hint is '$row->[1]'.\n";
	}
	($mail{Body} .= <<end_message);

We hope that helps.

Regards,

The support team.
end_message
	sendmail(%mail);
	show_sent();
    } else {
	show_form("<p><b>Sorry, the email address '$email' is not recognized</b></p>");
    }
}
    
sub show_sent {
    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
    <p class='centered'>You should shortly receive an email from us containing your login name and password.</p>
    <p class='centered'>When it arrives, try <a href='$w->{base_cgi}/login.pl'>logging in</a> again. 
    If that fails, please report the problem to <a href='mailto:$w->{webmaster}'>$w->{webmaster}</a>.</p>
end_heading

    $w->print_header('Details sent', $heading);
    $w->print_footer();
}

sub show_form {
    my $errors = shift;

    my $heading;
    ($heading = <<end_heading) =~ s/^\s+//gm;
	<p class='centered'>Please enter the email address you gave us, and we will send you your login details.</p>
end_heading

    my $email_input = textfield(-name => 'email', -maxlength => '32');
    
    $w->print_header('Login Reminder', $heading);
    $w->print_form_start();
    
    print "$errors\n" if $errors;

    my $form;
    ($form = <<end_form) =~ s/^\s+//gm;
	<table align='center'>
	    <tr>
		<td align='right'>
		    Email address
		</td>
		<td align='left'>
		    $email_input
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
end_form
    print "$form\n";

    $w->print_form_end();
    $w->print_footer();
}

