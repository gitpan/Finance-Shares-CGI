#!/usr/bin/perl
# chart.pl version 0.06;
use strict;
use warnings;
use Carp;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use Finance::Shares::CGI      0.11;
use Data::Dumper;
use PostScript::Graph::Style  1.00;
use Finance::Shares::Sample   0.12 qw(&call_function %function %functype);
use Finance::Shares::Averages 0.12;
use Finance::Shares::Bands    0.13;
use Finance::Shares::Momentum 0.04;
use Finance::Shares::Chart    0.14;
use Finance::Shares::Model    0.12;

### Globals
our ($db, $name);
our $query = 'where userid = ? and name = ?';
our $testfile = param('test_in');
our %data_graph = (
    'x' => 'prices',
    'y' => 'volumes',
);


### Main program
our $w = new Finance::Shares::CGI;
if ($testfile) {
    # The $Testing file should define:
    #   $name, $w->{ulevel}	# from 'vars' with "source => <csv_file>," added to sample(s)
    #   $w->{options}		#
    #   1;			# 'do' must return true
    do $testfile or die "Unable to read $testfile";
} else {
    if (param 'u') {
	$db = $w->get_records();
    } else {
	$w->show_error('No user parameter');
	exit;
    }
    $name = param('name');

    $w->{sql} = new Finance::Shares::MySQL {
	database => $w->{database},
	user     => $w->{dbuser},
	password => $w->{password},
    };
}
croak 'No name' unless $name;
my $h = fetch_hash('Draw', 'draws', $name);
show_error("No Draw data found for $name.") unless $h;

my $sh = process_sample($h, 'sample');
show_error("No Sample data found for $h->{sample}.") unless $sh;
my $sample = new Finance::Shares::Sample( $sh );

$w->{functions} = fetch_multiple('Draw', 'functions', 'Function', 'chosen_fns', $name);
foreach my $h (values %{$w->{functions}}) {
    process_function( $sample, $h->{name} );
}

my $ch = process_chart($h, 'chart');
dump_vars($w, 'vars', [$name, $w->{ulevel}, $w->{options}],
    ['$name', '$w->{ulevel}', '$w->{options}']) unless $testfile;

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
    <li>Choose alternative <a href='$w->{base_cgi}/chart.pl?u=$w->{user};name=$name'>Function chart</a>
    settings.</li>
    <li>Try <a href='$w->{base_cgi}/menu.pl?u=$w->{user};t=!cache;a=offline' target='menu'>Work offline</a> from the menu.</li>
    <li>Report the problem to <a href='mailto:$w->{webmaster}'>$w->{webmaster}</a>.</li>
    </ul>
end_html
    $w->print_header('No graph', $html);
    $w->print_footer();
    warn "No graph settings for '$name'";
    exit;
}

sub dump_vars {
    my ($w, $filename, $cbjects, $names) = @_;

    $Data::Dumper::Indent = 1;
    open FILE, '>', $filename or die "Unable to write to $filename : $!";
    print FILE Data::Dumper->Dump($cbjects, $names);
    close FILE;
    warn "$filename saved";
}
# call as 
# $w->dump_vars('temp', [$arg1, $arg2], [qw(arg1 arg2)] );

sub get_color {
    my $str = shift;
    return (defined($str) and $str =~ /,/) ? eval "[$str]" : $str;
}

sub fetch_hash {
    my ($table, $data, $name) = @_;
    my $h;
    
    if (defined $name) {
	my $d = $w->{options};
	if ($testfile) {
	    $h = $d->{$data}{$name};
	} else {
	    $h = $w->{db}->select_hash("${table}::Options", $query, $w->{userid}, $name);
	    $d->{$data}{$name} = { %$h };
	}
    }

    return $h;
}

sub fetch_multiple {
    my ($table1, $field, $table2, $data, $name) = @_;
    my $res = {};
    my $d = $w->{options};
    if ($testfile) {
	$res = $d->{$data}{$name};
    } else {
	my @choices = map { $_ = $_->[0] } $w->{db}->select("${table1}::${field}", 'value', $query, $w->{userid}, $name);
	if (@choices) {
	    foreach my $ch (@choices) {
		$res->{$ch} = $w->{db}->select_hash("${table2}::Options", $query, $w->{userid}, $ch);
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
    
    $h->{source} = $w->{sql} unless defined $h->{source};
    $h->{mode}   = $w->{cache};
    delete $h->{name}; # 'name' means stock name to Sample
    delete $h->{userid};
    
    return $h;
}

sub process_function {
    my ($sample, $name) = @_;
    my $h = fetch_hash('Function', 'functions', $name);
    $h->{line} = undef;
    $h->{key} = $name;
    my $line = $db->select_one('Funcs::Options', 'function', 'where name = ?', $h->{function});
    my $type = $db->select_one('Funcs::Options', 'type', 'where name = ?', $h->{function});
    my $graph = $data_graph{$type};
    #warn "process_fn: name=", $name || '',' fn=', $h->{function} || '',' graph=', $graph || '',' line=', $line || '',' type=', $type || '', "\n";
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
    my $func = $db->select_one('Funcs::Options', 'function', 'where name = ?', $h->{function});
    my ($line1, $line2) = call_function(\%function, $func, $sample, %$h);
    if (defined $line2) {
	$h->{line} = $h->{edge} ? $line1 : $line2;
    } else {
	$h->{line} = $line1;
    }
    #warn "pfn create: name=", $name || '',' fn=', $h->{function} || '',' graph=', $h->{graph} || '',' line=', $h->{line} || '', "\n";
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
	$w->{seq}{$name} = new PostScript::Graph::Sequence unless $w->{seq}{$name};
	$seq = $w->{seq}{$name};
	
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
    if ($w->{ulevel} == 1) {
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
	$ph->{shape} = $h->{pshape} if defined $h->{pshape};
	$ph->{width} = $h->{pwidth} if defined $h->{pwidth};
	$ph->{inner_color} = get_color($h->{pi_color}) if defined $h->{pi_color};
	$ph->{outer_color} = get_color($h->{po_color}) if defined $h->{po_color};
	$ph->{outer_width} = $h->{po_width} if defined $h->{po_width};
    } elsif ($key eq 'volumes') {
	my $vh = $h->{bars} = {};
	$vh->{inner_color} = get_color($h->{bi_color}) if defined $h->{bi_color};
	$vh->{outer_color} = get_color($h->{bo_color}) if defined $h->{bo_color};
	$vh->{outer_width} = $h->{bo_width} if defined $h->{bo_width};
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

