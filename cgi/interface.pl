#!/usr/bin/perl
# interface.pl version 0.06;
use strict;
use warnings;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params);
$CGI::Pretty::INDENT = '    ';
use PostScript::File        1.00;
use Finance::Shares::Sample 0.12;
use Finance::Shares::CGI    0.11;

### Parameters
# Single letter parameters are meta-data, passed as hidden fields
# other parameters correspond to the layout fields for $table
my $user      = param('u') || '';	# identifies user and browser settings
my $table     = param('t') || '';	# identifier for option, layout and help tables
my $args      = param('a') || '';	# optional arguments fine-tuning table presentation
my $choice    = param('c') || '';	# user button
my $menu      = param('m');		# set if table should be changed
my @history   = param('h');		# ( table,args,name, table,args,name, ... )
my @multi_sels= param('x');		# list of multiple-selection scrolling_rows on this page
my $name      = param('name') || '';	# current choice of key field
#warn "interface.pl table=$table name=$name args=$args choice=$choice\n";

my $db;
my $w = new Finance::Shares::CGI;
if (param 'u') {
    $db = $w->get_records();
} else {
    $w->show_error('No user parameter');
    exit;
}

### Globals
my ($options_name, $layout_name, $help_name);
my ($options_table, $layout_table, $help_table);
my (@fields, $describe, @keys, $data);
my $submit_btns;	# 1 if submit buttons have been added to page
init_globals();

### Menu jump
if ($menu) {
    do_submit();
    my $field = $db->select_one($layout_name, 'field', "where heading = ?", $menu);
    my $menu_name = $db->select_one($options_name, $field, "where userid = ? and name = ?", $w->{userid}, $name);
    unshift @history, $table, $args, $name if ($table and $name);
    $layout_name = "${table}::Layout";
    $options_name = "${table}::Options";
    
    ($field, $table, $args) = map { @$_ } $db->select($layout_name, 'field, entry_table, entry_args',
							    'where heading = ?', $menu);
    
    foreach my $param (param()) {
	Delete($param) if ($param !~ /^m_/);
    }
    param('c', $choice = '');
    param('t', $table);
    param('a', $args);
    param('name', $name = $menu_name);
    init_globals();
}

### Choices
if ($choice eq '') {
    # first call or 'return' pressed
} elsif ($choice eq 'Add') {
    $name = trim(param('m_entry'));
    if ($name) {
	foreach my $key (keys %$data) { delete $data->{$key}; }
	$data->{name} = $name;
	$data->{userid} = $w->{userid};
	$db->sql_replace($options_table, %$data);
	update();
    }
} elsif ($choice eq 'Rename') {
    my $old = param('name');
    my $new = trim(param('m_entry'));
    if($old and $new) {
	$db->delete($options_name, 'name = ?', $old);
	$data->{name} = $new;
	$db->sql_replace($options_table, %$data);
	param('name', $name = $new);
	update();
    }
} elsif ($choice eq 'Copy') {
    my $old = param('name');
    my $new = trim(param('m_entry'));
    if($old and $new) {
	$data->{name} = $new;
	$db->sql_replace($options_table, %$data);
	param('name', $name = $new);
	update();
    }
} elsif ($choice eq 'Remove') {
    my $id = trim(param('m_entry')) || param('name');
    if ($id) {
	$db->delete($options_name, 'name = ?', $id);
	update();
	param('name', $name = '');
    }
} elsif ($choice eq 'Choose') {
    $name = param('name');
    go_back() if raw_data();
} elsif ($choice eq 'Submit') {
    do_submit();
    go_back();
} elsif ($choice eq 'Cancel') {
    go_back();
} elsif ($choice eq 'Choose function') {
    do_submit();
} elsif ($choice eq 'Draw chart') {
    do_submit();
    print redirect( "$w->{base_cgi}/chart.pl?u=$w->{user};name=$name" );
    exit;
} elsif ($choice eq 'Run') {
    do_submit();
    print redirect( "$w->{base_cgi}/run.pl?u=$w->{user};name=$name" );
    exit;
}

### Show page
$submit_btns = 0;
@multi_sels = ();
my $l = $db->select_hash($layout_name, 'where field = ?', 'name');
my $heading = $l->{heading};

$w->print_header($heading);
print start_form();
#$w->show_params();

my ($col1, $col2, $col3) = qw(15% 25% 55%);
print start_table ({-width => '95%', -align => 'center'});

### Initial selection
my $prompt  = td({-width => $col1}, h1({-class => 'prompt'}, $heading) );
my $maxlen  = $describe->{name}{type};
$maxlen =~ s/\w+\((\d+)\)/$1/;
my $width   = $db->select_one($layout_name, 'width', 'where field = ?', 'name');
my $edit    = td ({-width => $col2}, textfield(-name => 'm_entry', -size => $width, -maxlength => $maxlen,
		    -override => 1) );
my $fmenu   = (!$w->{frames}) ? qq( <a href='$w->{base_cgi}/menu.pl?u=$w->{user}'>Back to menu</a>) : '';
my $add     = td ({-width => $col3},
		    submit(-name => 'c', -value => 'Add'),
		    submit(-name => 'c', -value => 'Remove'),   
		    submit(-name => 'c', -value => 'Rename'),
		    submit(-name => 'c', -value => 'Copy'),
		    );
print Tr ({-valign => 'middle'}, $prompt, $edit, $add);

@keys = ('') unless @keys;
my $list    = td({-width => $col2}, @keys ? scrolling_list(-name => 'name', -values => \@keys,
		    -defaults => $name, -size => 9, -override => 1) : '');
my $rhs     = td({-width => $col3, -bgcolor => $w->{bgcolor}}, help_text('name') || p(''),);
print Tr ({-valign => 'top'}, td({-width => $col1}, ''), $list, $rhs );
my $btns    = td(	submit(-name => 'c', -value => 'Choose'),
		    submit(-name => 'c', -value => 'Cancel'),
		    $fmenu );
print Tr ({-valign => 'top'}, td(''), td(''), $btns );

### Settings
my $raw_data = raw_data();
if ($name and not $raw_data) {
    print Tr( td({-colspan=>'3'}, hr()) );
    print Tr( td({-colspan=>'3'}, br(), h1(qq(Settings for '$name'))), td('')); 
    print Tr( td({-colspan=>'3'}, hr()) );
    #print Tr( td({-colspan=>'3'}, $w->show_hash($data) ) );
    
    ## Function
    if ($table eq 'Function') {
	$l = $db->select_hash($layout_name, 'where field = ?', 'function');
	my ($values, $labels) = eval_choices($l->{entry_table}, $l->{entry_field}, $l->{entry_extras},
		    "where type != 'x' and type != 'y'");
	my $help = help_text('function');
	print scrolling_row($l->{heading}, 'function', 0, 0, 8, 0, $help, $values, $labels, $data->{function});
	print Tr ({-valign => 'top'}, td(''), td(''), td(submit(-name => 'c', -value => 'Choose function')));
	shift @fields;
	$args = $db->select_one('Funcs::Options', 'type', 'where name = ?', $data->{function}) if $data->{function};
	print Tr( td({-colspan=>'3'}, hr()) ) if ($args and not $raw_data);
    }

    ## Show fields
    if (($table ne 'Function') or ($args and not $raw_data)) {
	foreach my $field (@fields) {
	    next if $field eq 'name';
	    $l = $db->select_hash($layout_name, 'where field = ?', $field);
	    if ($l->{levels} =~ /$w->{ulevel}/) {
		#print Tr( td({-colspan=>'3'}, qq(table='$table', field='$field', cond='$l->{conditions}', args='$args') ) );
		if ((not $l->{conditions}) or ($l->{conditions} =~ /$args/)) {
		    my $help = help_text($field);
		    my $max;
		    ## Section heading
		    if ($l->{validation} eq 'section') {
			print section_row($l->{heading}, $help);
		    ## Submit buttons
		    } elsif ($l->{validation} eq 'submit') {
			print submit_row($l->{entry_table}, $help);
		    ## Show data
		    } else {
			$max = $describe->{$field}{type};
			$max =~ s/\w+\((\d+)\)/$1/;
			my $chosen = $data->{$field};
			## Lookup table
			if (defined($l->{entry_table})) {
			    my ($query, @values);
			    if ($l->{entry_table} eq 'Funcs') {
				$query = '';
			    } elsif (($table eq 'Draw' or $table eq 'Model') and $field eq 'functions') {
				$query = "where userid = ? and not isnull(line_name)";
				@values = ( $w->{userid} );
			    } elsif ($field eq 'line_name') {
				$query = "where userid = ? and name != '$name'";
				@values = ( $w->{userid} );
			    }
			    my ($values, $labels) = eval_choices($l->{entry_table}, $l->{entry_field}, 
				$l->{entry_extras}, $query, @values);
			    ## Multiple selection
			    if ($l->{validation} eq 'multiple') {
				print scrolling_row($l->{heading}, $field, 0, 0, 5, 1, $help, $values, $labels,
				    $name, ($labels ? undef : $l->{entry_field}) );
			    ## Radio selection
			    } elsif ($l->{validation} eq 'radio') {
				print radio_row($l->{heading}, $field, 0, 0, $help, $values, $labels, $chosen, 
					$labels ? undef : $l->{entry_field});
			    ## Single selection
			    } else {
				print menu_row($l->{heading}, $field, 0, 0, $help, $values, $labels, $chosen,
				    $labels ? undef : $l->{entry_field});
			    }
			    print Tr( td({-colspan=>'3'}, hr()) );
			## Checkbox
			} elsif ($l->{validation} eq 'checkbox') {
			    print checkbox_row($l->{heading}, $field, $help, $chosen, $l->{entry_field}); 
			## Text entry
			} else {
			    print entry_row($l->{heading}, $field, $l->{width}, $max, $help, $chosen);
			    print Tr ( td({-colspan=>'3'}, hr()) );
			}
		    }
		}
	    }
	}
	print submit_row();
    }
}

## Finish
print end_table;
Delete('h');
print hidden('t', $table);
print hidden('a', $args);
print hidden('h', @history);
print hidden('x', @multi_sels);
print hidden('u', $w->{user});
print end_form;
print end_html;

sub trim {
    my $str = shift;
    $str =~ s/^\s*//;
    $str =~ s/\s*$//;
    return $str;
}

sub scrolling_row {
    my ($prompt, $field, $width, $max, $height, $multiple, $help, $values, $labels, $chosen, $entry_table) = @_;
    my $defaults;
    if ($multiple) {
	my @defaults = map { $_ = $_->[0] } 
	    $db->select("${table}::$field", 'value', 'where userid = ? and name = ?', $w->{userid}, $chosen);
	$defaults = [ @defaults ];
	push @multi_sels, $field;
    } else {
	$defaults = $chosen;
    }
    my $tp;
    if ($entry_table) {
	$tp = td( submit(-name => 'm', -value => $prompt) );
    } else {
	$tp = td( p({-class => 'prompt'}, $prompt) );
    }
    my $tf = td('');
    my @labels = (-labels => $labels) if $labels;
    $tf = td( scrolling_list(-name => $field, -values => $values, @labels, -defaults => $defaults, -size => $height, 
		-multiple => $multiple, -override => 1) ) if @$values;
    my $th = length($help) > 7 ? td({-bgcolor => $w->{bgcolor}}, $help) : td('');
    if ($width) {
	my $af = td( textfield(-name => $field, -size => $width, -maxlength => $max, -override => 1) );
	my $ab = td( submit(-name => 'choice', -value => 'Add'), 
		     submit(-name => 'choice', -value => 'Remove') );   
	return Tr({-valign => 'top'}, $tp, $tf, $th) . Tr({valign => 'middle'}, td(''), $af, $ab);
    } else {
	return Tr({-valign => 'top'}, $tp, $tf, $th );
    }
}

sub radio_row {
    my ($prompt, $field, $width, $max, $help, $values, $labels, $default, $entry_table) = @_;
    my $tp;
    if ($entry_table) {
	$tp = td( submit(-name => 'm', -value => $prompt) );
    } else {
	$tp = td( p({-class => 'prompt'}, $prompt) );
    }
    my $tf = td('');
    my @labels = (-labels => $labels) if $labels;
    $tf = td( radio_group(-name => $field, -values => $values, @labels, -default => $default,
		-linebreak => 'true', -override => 1) ) 
	if defined $values and @$values;
    my $th = length($help) > 7 ? td({-bgcolor => $w->{bgcolor}}, $help) : td('');
    if ($width) {
	my $af = td( textfield(-name => $field, -size => $width, -maxlength => $max, -override => 1) );
	my $ab = td( submit(-name => 'choice', -value => 'Add'), 
		     submit(-name => 'choice', -value => 'Remove') );   
	return Tr({-valign => 'top'}, $tp, $tf, $th) . Tr({valign => 'middle'}, td(''), $af, $ab);
    } else {
	return Tr({-valign => 'top'}, $tp, $tf, $th );
    }
}

sub checkbox_row {
    my ($prompt, $field, $help, $value, $label) = @_;
    warn "checkbox $prompt";
    my $tp = td( p({-class => 'prompt'}, $prompt) );
    my $tf = td( checkbox(-name => $field, -value=> 1, -checked => $value, -label => $label, -override => 1) );
    my $th = length($help) > 7 ? td({-bgcolor => $w->{bgcolor}}, $help) : td('');
    return Tr({-valign => 'top'}, $tp, $tf, $th );
}

sub menu_row {
    my ($prompt, $field, $width, $max, $help, $values, $labels, $default, $entry_table) = @_;
    my $tp;
    if ($entry_table) {
	$tp = td( submit(-name => 'm', -value => $prompt) );
    } else {
	$tp = td( p({-class => 'prompt'}, $prompt) );
    }
    my $tf = td('');
    my @labels = (-labels => $labels) if $labels;
    $tf = td( popup_menu(-name => $field, -values => $values, @labels, -default => $default, -override => 1) ) 
	if defined $values and @$values;
    my $th = length($help) > 7 ? td({-bgcolor => $w->{bgcolor}}, $help) : td('');
    if ($width) {
	my $af = td( textfield(-name => $field, -size => $width, -maxlength => $max, -override => 1) );
	my $ab = td( submit(-name => 'choice', -value => 'Add'), 
		     submit(-name => 'choice', -value => 'Remove') );   
	return Tr({-valign => 'top'}, $tp, $tf, $th) . Tr({valign => 'middle'}, td(''), $af, $ab);
    } else {
	return Tr({-valign => 'top'}, $tp, $tf, $th );
    }
}

sub entry_row {
    my ($prompt, $field, $width, $max, $help, $value) = @_;
    my $tp = td( p({-class => 'prompt'}, $prompt) );
    my $tf = td( textfield(-name => $field, -value=> $value, -size => $width, -maxlength => $max, -override => 1) );
    my $th = length($help) > 7 ? td({-bgcolor => $w->{bgcolor}}, $help) : td('');
    return Tr({-valign => 'top'}, $tp, $tf, $th );
}

sub section_row {
    my ($prompt, $help) = @_;
    my $text = Tr ( td({-colspan=>'2'}, br(), h2(qq($prompt))), td('')); 
    $text .= Tr ( td({-colspan=>'3'}, hr()) );
    return $text;
}

sub submit_row {
    my ($buttons, $help) = @_;
    return '' if $submit_btns;
    $submit_btns = 1;

    $buttons = '["Submit", "Cancel"]' unless $buttons;
    my $ar = eval($buttons);
    $buttons = '';
    foreach my $text (@$ar) {
	$buttons .= submit(-name => 'c', -value => $text);
    }
    ($help = <<end_help) =~ s/^\s+//gm if ($w->{hlevel} == 1) and (not $help);
	<p>Press <span class='btn'>&nbsp;Submit&nbsp;</span> to store your choices,
	or <span class='btn'>&nbsp;Cancel&nbsp;</span> to return without changing anything.</p>
end_help
    my $row = '';
    $row  = Tr ( td(''), td(''), td({-bgcolor => $w->{bgcolor}}, $help) );
    $row .= Tr ( td(''), td(''), td( $buttons ) );
    return $row;
}

sub eval_choices {
    my ($table_name, $field, $extras, $where, @args) = @_;
    return undef unless $table_name;
    
    my $values = eval $table_name;
    undef $@;
    my $labels;
    if (ref($values) eq 'ARRAY') {
	my $l = eval($field) if $field;
	undef $@;
	$labels = $l if (ref($l) eq 'HASH');
    } else {
	return undef unless $table_name;
	my $table = "${table_name}::Options";
	return undef unless $table;

	my @rows = map { $_ = $_->[0] } $db->select($table, $field, $where, @args);
	$values = [ @rows ];
    }
    
    my @x;
    if ($extras) {
	foreach my $extra (split(/[, ]+/, $extras)) {
	    if (defined $extra) {
		push @x, " <$extra> ";
	    }
	}
    }
    unshift @$values, @x; 
    
    #warn "$table_name, '$values', '$labels'";
    return ($values, $labels);
}

sub update {
    @keys = map { $_ = $_->[0] } $db->sql_select("name from $options_table where userid = ?", $w->{userid});
    $data = $db->select_hash($options_name, 'where name = ? and userid = ?', $name ? $name : $keys[0], $w->{userid});
}

sub help_text {
    my $field = shift;
    my ($help1, $help2, $help3) = $db->select_one($help_name, 'help1, help2, help3', 'where field = ?', $field);
    $help1 = '' unless defined $help1;
    if ($w->{hlevel} == 1) {
	return $help1;
    } elsif ($w->{hlevel} == 2) {
	if ($help2) {
	    return $help2;
	} else {
	    return $help1;
	}
    } elsif ($w->{hlevel} == 3) {
	if ($help3) {
	    return $help3;
	} elsif ($help2) {
	    return $help2;
	} else {
	    return $help1;
	}
    }
}

sub init_globals {
    $table  = 'Model' unless defined $table;
    $choice = ''      unless defined $choice;
    $name   = ''      unless defined $name;
    $args   = ''      unless defined $args;
    $options_name  = "${table}::Options";
    $layout_name   = "${table}::Layout";
    $help_name     = "${table}::Help";
    $options_table = $db->table($options_name);
    $layout_table  = $db->table($layout_name);
    $help_table    = $db->table($help_name);
    @fields        = map { $_ = $_->[0] } $db->sql_select("field from $layout_table where posn > 0");
    $describe      = $db->sql_describe($options_table);
    update();
}

sub do_submit {
    my $new_data = 0;
    foreach my $field (@multi_sels) {
	eval {
	    $db->delete("${table}::$field", 'userid = ? and name = ?', $w->{userid}, $name);
	};
	if ($@) {
	    die "$@\n" unless $@ =~ /table is missing/;
	}
    }
    foreach my $param (param()) {
	if (length($param) > 2) {
	    my @value = param($param);
	    # cannot just look at number of values as multi_sels can return 1 value
	    my $found = -1;
	    if (@multi_sels) {
		$found = 0;
		foreach my $field (@multi_sels) {
		    $found = 1, last if ($field eq $param);
		}
	    }
	    if ($found > 0) {
		my %hash = ( userid => $w->{userid}, name => $name );
		for( my $i=0; $i < @value; $i++ ) {
		    $hash{value} = ($value[$i] eq '') ? undef : $value[$i];
		    $db->replace("${table}::$param", %hash);
		}
		undef $data->{$param};
	    } elsif ($found < 0) {
		my $val = $value[0];
		$val =~ s/^\s<.*>\s$//;	    # don't store 'extras'
		$val =~ s/^\s+//;	    # strip outside spaces
		$val =~ s/\s+$//;
		$data->{$param} = $val;
		$new_data = 1;
	    }
	    Delete($param);
	}
    }
    if (raw_data()) {
	my $type = $db->select_one('Funcs::Options', 'type', 'where name = ?', $data->{function});
	if ($type eq 'x') {
	    $data->{graph} = 'prices';
	} elsif ($type eq 'y') {
	    $data->{graph} = 'volumes';
	}
    }
    $data->{userid} = $w->{userid};
    $db->replace("${table}::Options", %$data ) if $new_data;
}

sub go_back {
    ($table, $args, $name, @history) = @history if @history;
    init_globals();
    param('t', $table);
    param('a', $args);
    param('name', $name);
}

sub raw_data {
    return 0 unless $table eq 'Function';
    return 0 unless $data->{function};
    my $type = $db->select_one('Funcs::Options', 'type', 'where name = ?', $data->{function});
    return $type =~ /[xy]/;
}

