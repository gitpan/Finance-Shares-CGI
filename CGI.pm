package Finance::Shares::CGI;
our $VERSION = 0.03;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::MySQL 1.03;

our $query = 'where userid = ? and name = ?';
our @raw_data = (
    { name => 'Opening price', function => 'open_x',   graph => 'prices' },
    { name => 'Highest price', function => 'high_x',   graph => 'prices' },
    { name => 'Lowest price',  function => 'low_x',    graph => 'prices' },
    { name => 'Closing price', function => 'close_x',  graph => 'prices' },
    { name => 'Volume',        function => 'volume_y', graph => 'volumes' },
);

sub new {
    my $class = shift;
    my $o = {
	## === edit these START ===
	user	  => 'test',	# mysql user
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
	session	  => '',
	srec	  => {},
	urec	  => {},
	cache	  => 'online',
	width	  => 0,
	frames	  => 0,
	css	  => 0,
	layers	  => 0,
	dhtml	  => 0,		# not used at present
	ok        => 0,		# expirable sessions i.e. database has been created

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

sub width {
    my $o = shift;
    if ((not $o->{width}) or $o->{width} > 500) {
	$o->{width} = 500;
    } else {
	$o->{width} = '95%';
    }
}

sub params {
    my $o = shift;
    $o->{width}  = param('width')  || 0;
    $o->{frames} = param('frames') || 0;
    $o->{css}    = param('css')    || 0;
    $o->{layers} = param('layers') || 0;
    $o->{dhtml}  = param('dhtml')  || 0;
    $o->width();
}

sub settings {
    my $o = shift;
    # these may be read directly
    $o->{session}   = $o->{srec}{session};
    $o->{cache}     = $o->{srec}{cache};
    $o->{width}     = $o->{srec}{bwidth};
    $o->{frames}    = $o->{srec}{frames};
    $o->{css}       = $o->{srec}{css};
    $o->{layers}    = $o->{srec}{layers};
    $o->{dhtml}     = $o->{srec}{dhtml};
    $o->{userlevel} = $o->{urec}{userlevel};
    $o->{helplevel} = $o->{urec}{helplevel};
    $o->{userid}    = $o->{urec}{userid};
    $o->width();
}

sub login {
    my $o = shift;
    $o->{db} = new Finance::Shares::MySQL(
	user     => $o->{user},
	password => $o->{password},
	database => $o->{database},
    ) unless defined $o->{db};
    croak 'No database connection' unless $o->{db};
    $o->{ok} = $o->expire_sessions();
    return $o->{db};
}

sub get_records {
    my ($o, $init) = @_;
    my $db = $o->login();
    return $db if $init and param($init);
    $o->{session} = param('s');
    if ($o->{session}) {
	eval {
	    $o->{srec} = $db->select_hash('Login::Sessions', 'where session = ?', $o->{session});
	    $o->{urec} = $db->select_hash('Login::Users', 'where userid = ?', $o->{srec}{userid});
	    $o->settings();
	};
	if ($o->{ok} and $@) {
	    my $html;
	    ($html = <<end_html) =~ s/^\s+//gm;
	    <p>Your user data is incorrect or missing, probably due to a software problem.</p>
	    <p>Try to <a href='$o->{base_cgi}/register.pl'>re-register using a different login.</a> again.
	    If that fails, please report the problem to $o->{webmaster}</p>    
end_html
	    $o->print_header('Data Error', $html);
	    $o->print_footer();
	    croak $@;
	}
    }
    if ($o->{ok}) {
	if ($o->{session}) {
	    $o->ensure_raw_data($o->{srec}{userid});
	} else {
	    my $html;
	    ($html = <<end_html) =~ s/^\s+//gm;
	    <p>Your session has expired or has been lost.  Please <a href='$o->{base_cgi}/login.pl'
	    target='_top'>log in</a> again.  If that fails, please report the problem to <a
	    href='mailto:$o->{webmaster}'>$o->{webmaster}</a>.</p>    
end_html
	    $o->print_header('No Session', $html);
	    $o->print_footer();
	    warn "No session id";
	    exit;
	}
    }
	    
    return $db;
}

sub change_user {
    my $o = shift;
    my %hash = (%{$o->{urec}}, @_);
    $o->{db}->replace('Login::Users', %hash );
}

sub change_session {
    my $o = shift;
    my %hash = (%{$o->{srec}}, @_);
    $o->{db}->replace('Login::Sessions', %hash );
}

sub expire_sessions {
    my $o = shift;
    my ($d, $m, $y) = (localtime)[3 .. 5];
    my $todaystr = sprintf('%04d-%02d-%02d', $y+1900, $m+1, $d);
    my $db = $o->{db};
    my $root = $db->root();
    my $expired = 0;
    eval {
	my $table = $db->table('Login::Sessions');
	$expired = $db->sql_select(qq(sqlname from $root where username = ' expired'));
    };
    return 0 if ($@);
    if(!$expired) {
	$db->sql_replace($root, username => ' expired', sqlname => $todaystr);
    } elsif ($expired lt $todaystr) {
	my $table = $db->table('Login::Sessions');
	my @res = $db->sql_select(qq(session from $table where ts < date_sub(now(), interval '18:00' hour_minute) ));
	my @values = map { $_ = $_->[0] } @res;
	eval {
	    my $sth = $db->{dbh}->prepare(qq(delete from $table where session = ?));
	    my $n = 0;
	    if ($sth) {
		foreach my $s (@values) {
		    $n += $sth->execute($s);
		}
		#warn "$n sessions expired";
	    }
	    $db->sql_replace($root, username => ' expired', sqlname => $todaystr);
	};
	warn $@ if ($@);
    }
    return 1;
}

sub print_header {
    my $o = shift;
    my ($title, $text, $script, $style) = @_;
    my @scripthash = ( -script => {-language => 'javascript', -code => $script} ) if $script;
    my $stylesheet = $o->{dhtml} ? "$o->{base_url}/dhtml.css" : "$o->{base_url}/css.css";
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
	print start_table ({-width  => $o->{width}, -align => 'center',
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
    while( my($k, $v) = each( %{$o->{urec}} )) {
	push @res, defined($v) ? "usr:$k='$v'" : "$k undefined";
    }
    while( my($k, $v) = each( %{$o->{srec}} )) {
	push @res, defined($v) ? "ssn:$k='$v'" : "$k undefined";
    }
    print join('<br>', @res), '<br>';
    warn join(', ', @res) if @res and $table == 2;
    print "</td></tr>\n" if $table == 1;
}

sub ensure_raw_data {
    my ($o, $userid) = @_;
    my $db = $o->{db};

    foreach my $h (@raw_data) {
	$h->{shown} = 0;
	$h->{userid} = $userid;
	$db->replace('Function::Options', %$h);
    }
}

1;


