#!/usr/bin/perl
our $VERSION = 0.04;
use strict;
use warnings;
use Carp;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI      0.03;
use Data::Dumper;
use PostScript::Graph::Style  0.08;
use Finance::Shares::Sample   0.11 qw(&function %line);
use Finance::Shares::Averages 0.11;
use Finance::Shares::Bands    0.12;
use Finance::Shares::Chart    0.12;
use Finance::Shares::Model    0.10;

### Globals
our ($db, $name, $session);
our $query = 'where userid = ? and name = ?';
our $testfile = param('test_in');
our %data_graph = (
    'x' => 'prices',
    'y' => 'volumes',
);


### Main program
our $c = new Finance::Shares::CGI;
if ($testfile) {
    # The $Testing file should define:
    #   $name, $c->{userlevel}	# from 'vars' with "source => <csv_file>," added to sample(s)
    #   $c->{options}		#
    #   1;			# 'do' must return true
    do $testfile or die "Unable to read $testfile";
} else {
    $session = param('s') || '';		# identifies user and browser settings
    $db = $c->get_records($session);
    $name = param('name');

    $c->{sql} = new Finance::Shares::MySQL {
	database => $c->{database},
	user     => $c->{user},
	password => $c->{password},
    };
}
croak 'No name' unless $name;
my $h = fetch_hash('Draw', 'draws', $name);
show_error("No Draw data found for $name.") unless $h;

my $sh = process_sample($h, 'sample');
show_error("No Sample data found for $h->{sample}.") unless $sh;
my $sample = new Finance::Shares::Sample( $sh );

$c->{functions} = fetch_multiple('Draw', 'functions', 'Function', 'chosen_fns', $name);
foreach my $h (values %{$c->{functions}}) {
    process_function( $sample, $h->{name} );
}

my $ch = process_chart($h, 'chart');
dump_vars($c, 'vars', [$name, $c->{userlevel}, $c->{options}],
    ['$name', '$c->{userlevel}', '$c->{options}']) unless $testfile;

$ch->{sample} = $sample;
my $chart = new Finance::Shares::Chart( $ch );
print header ('application/postscript');
print $chart->output();


sub show_error {
    my $error = shift || '';
    my $html;
    ($html = <<end_html) =~ s/^\s+//gm;
    <p>There is a problem creating this graph. $error You could try:</p>
    <ul>
    <li>Choose alternative <a href='$c->{base_cgi}/chart.pl?s=$c->{session};name=$name'>Function chart</a>
    settings.</li>
    <li>Try <a href='$c->{base_cgi}/menu.pl?s=$c->{session};t=!cache;a=offline' target='menu'>Work offline</a> from the menu.</li>
    <li>Report the problem to <a href='mailto:$c->{webmaster}'>$c->{webmaster}</a>.</li>
    </ul>
end_html
    $c->print_header('No graph', $html);
    $c->print_footer();
    warn "No graph settings for '$name'";
    exit;
}

sub dump_vars {
    my ($c, $filename, $cbjects, $names) = @_;

    $Data::Dumper::Indent = 1;
    open FILE, '>', $filename or die "Unable to write to $filename : $!";
    print FILE Data::Dumper->Dump($cbjects, $names);
    close FILE;
    warn "$filename saved";
}
# call as 
# $cgi->dump_vars('temp', [$arg1, $arg2], [qw(arg1 arg2)] );

sub get_color {
    my $str = shift;
    return (defined($str) and $str =~ /,/) ? eval "[$str]" : $str;
}

sub fetch_hash {
    my ($table, $data, $name) = @_;
    my $h;
    
    if (defined $name) {
	my $d = $c->{options};
	if ($testfile) {
	    $h = $d->{$data}{$name};
	} else {
	    $h = $c->{db}->select_hash("${table}::Options", $query, $c->{userid}, $name);
	    $d->{$data}{$name} = { %$h };
	}
    }

    return $h;
}

sub fetch_multiple {
    my ($table1, $field, $table2, $data, $name) = @_;
    my $res = {};
    my $d = $c->{options};
    if ($testfile) {
	$res = $d->{$data}{$name};
    } else {
	my @choices = map { $_ = $_->[0] } $c->{db}->select("${table1}::${field}", 'value', $query, $c->{userid}, $name);
	if (@choices) {
	    foreach my $ch (@choices) {
		$res->{$ch} = $c->{db}->select_hash("${table2}::Options", $query, $c->{userid}, $ch);
	    }
	}
	$d->{$data}{$name} = $res;
    }
	
    return $res;
}

sub process_sample {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('Sample', 'samples', $name);
    
    $h->{source} = $c->{sql} unless defined $h->{source};
    $h->{mode}   = $c->{cache};
    delete $h->{name}; # 'name' means stock name to Sample
    delete $h->{userid};
    
    return $h;
}

sub process_function {
    my ($sample, $name) = @_;
    my $h = fetch_hash('Function', 'functions', $name);
    $h->{line} = undef;
    $h->{key} = $name;
    my ($line, $type);
    ($line, $type) = ($h->{function} =~ /^(\w+)_(\w)$/);
    my $graph = $data_graph{$type};
    if ($graph) {
	$h->{graph} = $graph;
	$h->{line}  = $line;
    }
    return ($h->{graph}, $h->{line}) if $h->{graph} and $h->{line} and $sample->choose_line($h->{graph}, $h->{line}, 1);
    # source line doesn't exist (yet)
    ($graph, $line) = process_function( $sample, $h->{line_name} );
    $h->{graph} = $graph unless defined $h->{graph};
    $h->{line}  = $line  unless defined $h->{line};
    $h->{style} = process_style($h, 'style') if $h->{style} and not ref($h->{style});
    $h->{line}  = function(\%line, $h->{function}, $sample, %$h);
    return ($h->{graph}, $h->{line});
}
# Note the first parameter is a Finance::Shares::Sample object, not a hash

sub process_style {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    my $h    = fetch_hash('Style', 'styles', $name);
    my $seq  = process_sequence($h, 'sequence');
    my ($line, $point, $bar);

    if ($h->{display} & 1) {
	my $width = $h->{width} ? $h->{width} : 1;
	my $iw = $h->{li_width} ? $h->{li_width} : $width;
	$line = {
	    color	 => get_color($h->{color}),
	    inner_color  => get_color($h->{li_color}),
	    outer_color  => get_color($h->{lo_color}),
	    inner_dashes => get_color($h->{li_dashes}),
	    outer_dashes => $h->{lo_dashes} ? get_color($h->{lo_dashes}) : '[]',
	    width	 => $width,
	    inner_width  => $iw,
	    outer_width  => $h->{lo_width} ? $h->{lo_width} : $iw,
	},
    }

    if ($h->{display} & 2) {
	$point = {
	    size         => $h->{psize},
	    shape        => $h->{pshape},
	    color	 => get_color($h->{color}),
	    inner_color  => get_color($h->{pi_color}),
	    outer_color  => get_color($h->{po_color}),
	    width	 => $h->{width},
	    #inner_width  => $h->{pi_width},
	    outer_width  => $h->{po_width},
	},
    }

    my $style = {
	sequence => $seq,
	same	 => $h->{same},
	label	 => $name,
	line	 => $line,
	point	 => $point,
	bar	 => $bar,
    };

    return $style;
}

sub process_sequence {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    my $seq;

    if (defined $name) {
	$c->{seq}{$name} = new PostScript::Graph::Sequence unless $c->{seq}{$name};
	$seq = $c->{seq}{$name};
	
	my $sh = fetch_hash('Sequence', 'sequences', $name);
	my ($k, $v);
	while( ($k, $v) = each %$sh ) {
	   next if $k eq 'name';
	   next if $k eq 'userid';
	   if ($k eq 'sequence') {
	       $v =~ s/,//g;
	       my @list = eval "qw($v)";
	       $seq->auto( @list ) if @list;
	       #warn "auto: ", join(',',@list);
	   } else {
	       my @list;
	       if ($k eq 'shape') {
		   $v =~ s/,//g;
		   $v = "qw($v)";
	       }
	       @list = eval $v;
	       $seq->setup( $k, \@list ) if @list;
	       #warn "setup: $k = $v [", join(',',@list) if $k eq 'shape';
	   }
	}
    }

    return $seq;
}
# Note this returns a PostScript::Graph::Sequence object, not a hash

sub process_chart {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('Chart', 'charts', $name);

    $h->{background}    = get_color($h->{background});

    $h->{prices}  = process_graph($h, 'prices');
    $h->{volumes} = process_graph($h, 'volumes');
    $h->{cycles}  = process_graph($h, 'cycles');
    $h->{signals} = process_graph($h, 'signals');
    if ($c->{userlevel} == 1) {
	$h->{prices}{percent}  = $h->{prices_pc}  if defined $h->{prices_pc};
	$h->{volumes}{percent} = $h->{volumes_pc} if defined $h->{volumes_pc};
	$h->{cycles}{percent}  = $h->{cycles_pc}  if defined $h->{cycles_pc};
	$h->{signals}{percent} = $h->{signals_pc} if defined $h->{signals_pc};
    }
    
    $h->{x_axis}       = process_axis($h, 'x_axis');
    $h->{key}          = process_key($h, 'key_panel');
    $h->{heading_font} = process_font($h, 'heading_font');
    $h->{normal_font}  = process_font($h, 'normal_font');
    $h->{file}         = process_file($h, 'file');

    return $h;
}

sub process_graph {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('Graph', 'graphs', $name);
    
    $h = {} unless defined $h;
    $h->{sequence} = process_sequence($h, 'sequence');
    $h->{y_axis}   = process_axis($h, 'y_axis');
    if ($key eq 'prices') {
	my $ph = $h->{points} = {};
	$ph->{pshape} = $h->{pshape};
	$ph->{pi_color} = get_color($h->{pi_color});
	$ph->{po_color} = get_color($h->{po_color});
	$ph->{po_width} = $h->{po_width};
    } elsif ($key eq 'volumes') {
	my $vh = $h->{bars} = {};
	$vh->{bi_color} = get_color($h->{bi_color});
	$vh->{bo_color} = get_color($h->{bo_color});
	$vh->{bo_width} = $h->{bo_width};
    }

    return $h;
}

sub process_axis {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('Axis', 'axes', $name);
    
    $h->{heavy_color} = get_color($h->{heavy_color});
    $h->{mid_color}   = get_color($h->{mid_color});
    $h->{light_color} = get_color($h->{light_color});

    return $h;
}

sub process_key {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('Key_Panel', 'kpanels', $name);
    
    $h->{background}    = get_color($h->{background});
    $h->{outline_color} = get_color($h->{outline_color});
    $h->{title_font}    = process_font($h, 'title_font');
    $h->{text_font}     = process_font($h, 'text_font');

    return $h;
}

sub process_font {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('Font', 'fonts', $name);
    
    $h->{color} = get_color($h->{color});
    
    return $h;
}

sub process_file {
    my ($parent, $key) = @_;
    my $name = $parent->{$key};
    return undef unless defined $name;
    my $h = fetch_hash('File', 'files', $name);
    
    return $h;
}

