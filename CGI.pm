package Finance::Shares::CGI;
our $VERSION = 0.11;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::MySQL 1.04;


our $query = 'where userid = ? and name = ?';
our @raw_data = (
    { name => 'Opening price', function => 'Opening price',   graph => 'prices' },
    { name => 'Highest price', function => 'Opening price',   graph => 'prices' },
    { name => 'Lowest price',  function => 'Lowest price',    graph => 'prices' },
    { name => 'Closing price', function => 'Closing price',   graph => 'prices' },
    { name => 'Volume',        function => 'Volume',          graph => 'volumes' },
);

sub new {
    my $class = shift;
    my $o = {
	## === edit these START ===
	dbuser	  => 'test',	# mysql user
	password  => 'test',	# mysql password
	database  => 'test',	# mysql database
	base_cgi  => 'http://hawk.home.net/cgi-bin/shares',	# URL for CGI scripts
	base_url  => 'http://hawk.home.net/shares',		# URL for website (index.html)
	base_dir  => '/srv/www/htdocs/shares',			# Directory holding index.html
	webmaster => 'webmaster@willmot.org.uk',
	## === edit these END ===
	
	bgcolor   => '#dde8ee',
	program	  => 'Finance::Shares',

	## user/session data
	db        => undef,	# Finance::Shares::MySQL for session
	user      => '',
	userid    => 0,
	ulevel    => 1,
	hlevel    => 1,
	cache	  => 'cache',
	frames	  => 0,
	css	  => 0,

	## drawing charts
	options   => {},	# all user options (for testing)
	multiple  => {},	# multi-choice user options
	signals   => {},	# option hashes for all signals
	pf        => undef,	# PostScript::File
	sql       => undef,     # Finance::Shares::MySQL for quotes
	fss       => {},        # Finance::Shares::Samples
	fsc       => {},        # Finance::Shares::Charts
	seq       => {},	# PostScript::Graph::Sequences
	allfns    => {},	# known functions keyed by line id
    };

    ## finish
    bless($o, $class);
    return $o;
}

sub login {
    my $o = shift;
    $o->{db} = new Finance::Shares::MySQL(
	user     => $o->{dbuser},
	password => $o->{password},
	database => $o->{database},
    ) unless defined $o->{db};
    croak 'No database connection' unless $o->{db};
    return $o->{db};
}

sub get_records {
    my $o = shift;
    my $user = param('u') || '';
    die "No user\n" unless $user;
    my $db = $o->login();
    my $h;
    
    foreach my $i (0 .. 1) {
	eval {
	    $h = $db->select_hash('Login::Users', 'where user = ?', $user);
	};
	if ($@) {
	    warn $@;
	}
	if ($h->{user}) {
	    last;
	} else {
	    $o->change_user( user => $user );
	}
    }
    die "Cannot record data for '$user'\n" unless $h->{user};
    
    $o->{user}   = $h->{user};
    $o->{userid} = $h->{userid};
    $o->{ulevel} = $h->{ulevel};
    $o->{hlevel} = $h->{hlevel};
    $o->{admin}  = $h->{admin};
    $o->{cache}  = $h->{cache};
    $o->{frames} = $h->{frames};
    $o->{css}    = $h->{css};

    foreach my $h (@raw_data) {
	$h->{shown} = 0;
	$h->{userid} = $o->{userid};
	$db->replace('Function::Options', %$h);
    }
    return $db;
}

sub change_user {
    my $o = shift;
    my %hash = (
	user   => $o->{user},
	userid => $o->{userid},
	ulevel => $o->{ulevel},
	hlevel => $o->{hlevel},
	admin  => $o->{admin},
	cache  => $o->{cache},
	frames => $o->{frames},
	css    => $o->{css},
	, @_);
    $o->{db}->replace('Login::Users', %hash );
}

sub print_header {
    my $o = shift;
    my ($title, $text, $script, $style) = @_;
    my @scripthash = ( -script => {-language => 'javascript', -code => $script} ) if $script;
    my $stylesheet = "$o->{base_url}/styles.css";
    my @stylehash = ( -style => ($style ? $style : {src => $stylesheet}) );

    my $program = '';
    if ($title) {
	print header ();
	$program = "<h2 align='center'>$o->{program}</h2>";
    } else {
	$title = "$o->{program}";
    }
    print start_html ( -title   => $title, 
		       -xbase   => "$o->{base_url}/",
		       -bgcolor => $o->{bgcolor}, -background => "!bgnd.jpg",
		       @stylehash, @scripthash );
    if (defined $text) {
	print start_table ({-width  => '500', -align => 'center',
			    -border => 0, -cellspacing => 20, -cellpadding => 8});
	
	my $headings;
	($headings = <<end_headings) =~ s/^\s+//gm;
	    <tr><td bgcolor='$o->{bgcolor}'>
		$program
		<h1 align='center'>$title</h1>
		$text
	    </td></tr>\n
end_headings
	print $headings;
    }
}

sub print_form_start {
    my ($o, $url, $code, $centered) = @_;
    $code = ''   unless defined $code;
    my $center = $centered ? " align='center'" : "";
    print "<tr><td bgcolor='$o->{bgcolor}'$center>\n";
    if (defined $url) {
	print start_form(-action => $url, -onsubmit => $code);
    } else {
	print start_form();
    }
}

sub print_form_end {
    my $o = shift;
    print end_form();
    print "</td></tr>\n";
}

sub print_footer {
    my $o = shift;
    my ($text) = @_;
    print "<tr><td bgcolor='$o->{bgcolor}'>$text</td></tr>\n" if defined $text;
    print "</table>\n";
    print end_html ();
}

sub show_error {
    my ($o, $error) = @_;
    $error = '' unless defined $error;
    my $html;
    ($html = <<end_html) =~ s/^\s+//gm;
    <p>There is a problem $error<br>You could try:</p>
    <ul>
    <li>Logging in again before trying the same thing.</li>
    <li>Choose alternative settings.</li>
    <li>Try <a href='$o->{base_cgi}/menu.pl?s=$o->{session};t=!cache;a=offline' target='menu'>Work offline</a> from the menu.</li>
    <li>Use the scripting interface; it is likely to be more reliable.</li>
    <li>Report the problem to <a href='mailto:$o->{webmaster}'>$o->{webmaster}</a>.</li>
    </ul>
end_html
    $o->print_header('Error', $html);
    $o->print_footer();
    exit;
}

sub show_params {
    my ($o, $table) = @_;
    $table = 1 unless defined $table;
    print "<tr><td bgcolor='$o->{bgcolor}'>\n" if $table;
    my @p = param();
    my @res;
    foreach my $p (@p) {
	if (defined param($p)) {
	    my @values = param($p);
	    push @res, "$p = '" . join(',', @values) . "'";
	} else {
	    push @res, "$p is undefined";
	}
    }
    print join('<br>', @res), '<br>';
    print "</td></tr>\n" if $table;
}

sub show_hash {
    my ($o, $hash, $sep) = @_;
    $sep = ', ' unless defined $sep;
    my @res;
    while( my($k, $v) = each( %$hash )) {
	push @res, defined($v) ? "$k='$v'" : "$k undefined";
    }
    return join($sep, @res);
}

sub show_records {
    my ($o, $table) = @_;
    $table = 1 unless defined $table;
    print "<tr><td bgcolor='$o->{bgcolor}'>\n" if $table == 1;
    my @res;
    while( my($k, $v) = each( %$o )) {
	push @res, defined($v) ? "obj:$k='$v'" : "$k undefined";
    }
    print join('<br>', @res), '<br>';
    warn join(', ', @res) if @res and $table == 2;
    print "</td></tr>\n" if $table == 1;
}

1;

