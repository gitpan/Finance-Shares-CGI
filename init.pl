#!/usr/bin/perl
our $VERSION = 0.07;
use strict;
use warnings;
use Pod::Usage;
use CGI::Carp('fatalsToBrowser');
use CGI::Pretty qw(:standard *table -no_undef_params escapeHTML);
$CGI::Pretty::INDENT = '    ';
use DBIx::Namespace      0.03;
use Finance::Shares::CGI 0.03;

### CGI interface
my $w = new Finance::Shares::CGI;
my $db = $w->get_records('initialize');
my $choice = param('choice');
my $title = 'Reset Tables';
unless ($choice) {
    $w->print_header($title,'');
    $w->print_form_start();
    print p(q(<b>WARNING</b> Choosing 'sessions', 'users' or 'tables' will destroy user's data.));
    print checkbox(-name => 'list');
    print checkbox(-name => 'sessions');
    print checkbox(-name => 'users');
    print checkbox(-name => 'tables');
    print checkbox(-name => 'layouts');
    print checkbox(-name => 'prompts');
    print checkbox(-name => 'all');
    print textfield(-name => 'names', -size => 50);
    print submit(-name => 'choice', -value => 'Ok');
    print hidden(-name => 's', -value => $w->{session});
    $w->print_form_end();
    $w->print_footer();
    exit;
}

print header();
print start_html(-title => $title);
print "<pre>";

### Globals
my ($name, $mysql, $layout, $mapping, $help);
my $aux_mysql = [
['name'          ,1,'VARCHAR', 20],
['value'         ,1,'VARCHAR', 20],
['userid'        ,1,'INT'    , 10],
];

my $layout_fields = [qw(field posn width levels conditions heading validation 
			entry_field entry_table entry_extras entry_args)];

=head1 NAME

sql_init - setup mysql tables for Finance::Shares web interface

=head1 SYNOPSIS

Arguments

    users=;
    sessions=;
    all=;
    layouts=;
    prompts=;
    tables=;
    q=&lt;table_name&gt;;...

Or

    help=;
    list=;

This CGI interface requires a number of arguments, given to the url in the usual way.  For example

    http://willmot.org.uk/cgi-bin/init.pl?list=

=head1 DESCRIPTION

The command line options are:

=over 10

=item B<database>

The mysql database to update.  (Default: 'willmot_org_uk')

=item B<user>

The mysql user to log in as.  (Default: 'willmot')

=item B<password>

The password given when logging on to mysql.  (Default: 'typg2KC')

=item B<newusers>

Create a new table holding users details.  B<Caution>: all existing users' details will be lost!  As the sessions
table depends on this, it is also (re)created.

=item B<sessions>

Create a new table holding login session details.  The user information is not touched, but all currently open
sessions will be closed.

=item B<list>

Print a list of all the known table names.

=item B<all>

A shorter way of typing all the table names.

=item B<layouts>

(Re)create the layout data for the named tables.

=item B<prompts>

(Re)create the help data for the named tables.

=item B<tables>

(Re)create the user data for the named tables.  B<Caution>: Using this command deletes all user settings for the
named tables.

=item B<mappings>

(Re)create the mapping of user choices as collected to option hashes for the relevant object constructors.

=item B<help>

Print a brief summary of the command line options.

=item B<man>

Print this file.

=back

B<help>, B<man> or B<list> are safe in that no tables can be changed when these options are given.

For any changes to the main tables to occur, either B<all> or a list of named tables must be given along with
one or more of B<mysql>, B<prompt> or B<layout>.  The command to create all tables from scratch is therefore:

    shares_init --newusers --all --table --prompt --layout

Or after a minor change in the help text associated with the Models and Test tables, the following command could
be given, without harming any user data:

    shares_init --prompt Model Test
    
=cut

### Notes
# The following are expected by 'interface.pl':
# All tables must have the same field names which should be unique within the table.
# All field names must be 3 or more characters.
# All table names are singular.
# 
# In mysql:
# The key field name must be called 'name'.
# All 'k' fields with the same number are parts of the same key (index).
# The 'aux' field should hold the table name, if given.  The main table entry is ignored.
# Be careful giving a value for 'default'.  It is better to set a default in the module code and leave this
# blank.
# 
# In layout:
# layout key must be called 'field'
# 'posn' must always be 0 for 'name'.
# If 'table' can be eval'ed to produce an arrayref, it holds values to be returned.  In that case 'entry' should
# be a string holding a hashref with keys and values.  The keys are the returned items and the hash values are
# their displayable labels. i.e. eval'ing the string yields a value for CGI::popup_menu(-labels => ...).
# The first entry in the 'table' list is always the default, again as CGI::popup_menu(-values => ...).
# table extras: 'default' means store undef.
# validation: 'radio' =use radio button group, 'multiple' =use scrolling menu.
# table args: 'p'=price, 'v'=volume, 'a'=analysis, 'z'=all graphs; 'q'=price, 'w'=volume, 'b'=analysis lines; 
#
# Helper functions ending ...formatN() include a trailing '</p>' although they assume the paragraph has already
# started.

### Command line arguments
my $hlp      = defined(param('help'))     || 0;
my $man      = defined(param('man'))      || 0;
my $all      = defined(param('all'))      || 0;
my $list     = defined(param('list'))     || 0;
my $newusers = defined(param('users'))    || 0;
my $sessions = defined(param('sessions')) || 0;
my $layouts  = defined(param('layouts'))  || 0;
my $prompts  = defined(param('prompts'))  || 0;
my $tables   = defined(param('tables'))   || 0;
@ARGV = split(/[ ,]+/, param('names'));
pod2usage(-verbose => 2) if ($man);
pod2usage(-verbose => 1) if ($hlp);
pod2usage(-verbose => 1) unless ($list or $all or @ARGV or $newusers or $sessions);
$all = 1 if $list;

my %ch;
foreach my $table (@ARGV) { $ch{$table}++; }

### Log onto mysql
#my $db = new DBIx::Namespace(
#    user     => $user,
#    password => $password,
#    database => $database,
#) unless $list;

warn "sessions = $sessions";
if (($sessions or $newusers) and $db) {
    eval {
	users_create() and print "user table re-created\n" if $newusers;
	sessions_create() and print "session table re-created\n";
    exit unless ($list or $all or @ARGV);
    };
    if ($@) {
	print "\n$@\n";
	$db->disconnect();
	exit;
    }
}

### Axis
if ($all or $ch{Axis}) {
$name = 'Axis';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['title'         ,0,'VARCHAR', 20],
['show_day'      ,0,'TINYINT',  1],
['show_weekday'  ,0,'TINYINT',  1],
['show_month'    ,0,'TINYINT',  1],
['show_year'     ,0,'TINYINT',  1],
['changes_only'  ,0,'TINYINT',  1],
['show_lines'    ,0,'TINYINT',  1],
['background'    ,0,'VARCHAR', 18],
['heavy_color'   ,0,'VARCHAR', 18],
['heavy_width'   ,0,'VARCHAR',  4],
['mid_color'     ,0,'VARCHAR', 18],
['mid_width'     ,0,'VARCHAR',  4],
['light_color'   ,0,'VARCHAR', 18],
['light_width'   ,0,'VARCHAR',  4],
['mark_max'      ,0,'VARCHAR',  4],
['mark_min'      ,0,'VARCHAR',  4],
['smallest'      ,0,'VARCHAR',  4],
['si_shift'      ,0,'VARCHAR',  4],
['label_gap'     ,0,'VARCHAR',  4],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Axis'          ,'.*'           ],
['title'         , 2,16,'123','y'  ,'Axis title'    ,'.*'           ],
['dates'         , 3, 0,' 23','x'  ,'Date Labels'   ,'section'      ],
['show_day'      , 4, 1,' 23','x'  ,'Show day'      ,'radio'        ,'[1,0]', '{1 => "Show", 0 => "Hide"}' ],
['show_weekday'  , 5, 1,' 23','x'  ,'Show weekday'  ,'radio'        ,'[1,0]', '{1 => "Show", 0 => "Hide"}' ],
['show_month'    , 6, 1,' 23','x'  ,'Show month'    ,'radio'        ,'[1,0]', '{1 => "Show", 0 => "Hide"}' ],
['show_year'     , 7, 1,' 23','x'  ,'Show year'     ,'radio'        ,'[1,0]', '{1 => "Show", 0 => "Hide"}' ],
['changes_only'  , 8, 1,'  3','x'  ,'Changes only'  ,'radio'        ,'[1,0]', '{1 => "Changes", 0 => "All labels"}' ],
['grid_lines'    ,11, 0,'123',''   ,'Grid Lines'    ,'section'      ],
['smallest'      ,12, 6,'123','y'  ,'Granularity'   ,'^[0-9.]*$'    ],
['show_lines'    ,13, 1,' 23','x'  ,'Vertical lines','radio'        ,'[1,0]', '{1 => "Show", 0 => "Hide"}' ],
['heavy_color'   ,15,18,' 23',''   ,'Heavy color'   ,'^[][0-9., ]*$'],
['heavy_width'   ,16, 6,'123',''   ,'Heavy width'   ,'^[0-9.]*$'    ],
['mid_color'     ,17,18,' 23',''   ,'Mid color'     ,'^[][0-9., ]*$'],
['mid_width'     ,18, 6,'123',''   ,'Mid width'     ,'^[0-9.]*$'    ],
['light_color'   ,19,18,' 23',''   ,'Light color'   ,'^[][0-9., ]*$'],
['light_width'   ,20, 6,'123',''   ,'Light width'   ,'^[0-9.]*$'    ],
['marks'         ,21, 0,'  3',''   ,'Axis marks'    ,'section'      ],
['mark_max'      ,22, 6,'  3',''   ,'Mark max'      ,'^[0-9.]*$'    ],
['mark_min'      ,23, 6,'  3',''   ,'Mark min'      ,'^[0-9.]*$'    ],
['si_shift'      ,24, 6,'  3','y'  ,'Power of 10'   ,'^[0-9.]*$'    ],
['label_gap'     ,25, 6,'  3',''   ,'Label gap'     ,'^[0-9.]*$'    ],
];
## help
$help = [
['name',
q(<p>These settings are concerned with how each graph axis is marked.  Most of the features are
interchangeable, and a settings group designed for one axis may be used on another.</p>) . intro('axis') . q(</p>)], 
['title',
q(<p>Do you want this axis to be labelled as anything special?</p>),
q(<p>Label this axis only</p>)],
['show_day',
q(<p>Do you want the day of the month (e.g. 21st) to appear on the Date labels?</p>),
q(<p>Date on chart date labels.</p>),
q(<p>Day of the month, e.g. 21st.</p>)],
['show_weekday',
q(<p>Do you want the day of the week (e.g. Tuesday) to appear on the Date labels?</p>),
q(<p>Weekdays on chart date labels.</p>),
q(<p>Day of the week, e.g. Tuesday.</p>)],
['show_month',
q(<p>Do you want the month name to appear on the Date labels?</p>),
q(<p>Months on chart date labels.</p>),
q(<p></p>)],
['show_year',
q(<p>Do you want the year to appear on the Date labels?</p>),
q(<p>Years on chart date labels.</p>),
q(<p></p>)],
['changes_only',
q(<p>Answer ) . code('Changes') . q( if you are happy to have the labels as short as possible, or ) . code('All labels') . q(
if you want all labels to be shown in full.</p>),
q(<p>) . code('Yes') . q( for shortened labels.</p>),
q(<p>If ) . code('Yes') . q(, details are omitted if they are the same as the previous label.  There can
be problems if such a large number of dates are requested that some of the labels need to be missed out.</p>)],
['show_lines',
q(<p>Vertical grid lines are provided to make it easier to line up points on the various graphs.  However, if they
are in the way, choose ) . code('Hide') . q( here.</p>), 
q()],
['smallest',
q(<p>How close can grid lines be before they are too close?  Enter a small number like ) . code(4) . q( or
) . code(10) . q( to indicate the size of the smallest gap allowed between the lines. A larger value
reduces the number of lines drawn and therefore might speed up chart generation.),
q(<p>Gap size between minor grid lines.</p>),
q(<p>Gap size between minor grid lines in PostScript units of 1/72 inch.</p>)],
['background',
q(<p>Do you want a colored background to this graph? ) . color1() . q(</p>),
q(<p>Color of graph paper. ) . color2() . q(</p>),
q(<p>Color of graph paper. ) . color2() . q(</p>)],
['heavy_color',
q(<p>What color should the major, labelled, grid lines be? ) . color1() . q(</p>),
q(<p>Labelled major grid lines. ) . color2() . q(</p>),
q(<p>Labelled major grid lines. ) . color3() . q(</p>)],
['heavy_width',
q(<p>How wide should the major, labelled grid lines be? ) . width1() . q(</p>),
q(<p>Labelled major grid lines. ) . width2() . q(</p>),
q(<p>Labelled major grid lines. ) . width3() . q(</p>)],
['mid_color',
q(<p>When there is no room for all the labels, some of the main lines have their labels omitted and their lines
are typically lighter.  What color should these lines be? ) . color1() . q(</p>),
q(<p>Unlabelled major grid lines. ) . color2() . q(</p>),
q(<p>Unlabelled major grid lines. ) . color3() . q(</p>)],
['mid_width',
q(<p>How wide should the major, unlabelled grid lines be? ) . width1() . q(</p>),
q(<p>Unlabelled major grid lines. ) . width2() . q(</p>),
q(<p>Unlabelled major grid lines. ) . width3() . q(</p>)],
['light_color',
q(<p>What color should the lightest, minor, lines be? ) . color1() . q(</p>),
q(<p>Minor lines. ) . color2() . q(</p>),
q(<p>Minor lines. ) . color3() . q(</p>)],
['light_width',
q(<p>How wide do you want the lightest, minor lines? ) . width1() . q(</p>),
q(<p>Minor lines. ) . width2() . q(</p>),
q(<p>Minor lines. ) . width3() . q(</p>)],
['mark_max',
q(<p>Do you wish to change the size of the axis marks?  This is the size of the marks against the major grid
lines.  Values of ) . code(0) . q( to ) . code(10) .q( should be reasonable.</p>),
q(<p>Major grid line, in points.</p>),
q(<p>The size of the largest axis marks, in PostScript units of 1/72".)],
['mark_min',
q(<p>If you have changed ) . button('Mark max') . q(, this should be set to the size of the marks agains the minor
grid lines.  Values of ) . code(0) . q( to ) . code(5) .q( should be reasonable.</p>),
q(<p>Minor grid line, in points.</p>),
q(<p>The size of the smallest axis marks, in PostScript units of 1/72".)],
['si_shift',
q(<p>This allows a number of zeroes to be removed from the axis numbers.  For example, ) . code(2) . q( would show
the numbers as hundreds, ) . code(3) . q( as thousands, and ) . code(0) . q( for the numbers to be displayed
naturally.</p>), 
q(<p>) . code(2) . q( for 100's, ) . code(3) . q( for 1000's etc.</p>),
q(<p>Multiply the axis reading by this power of 10 to get the true value.)],
['label_gap',
q(<p>If the labels are too close together, try some different values here.  The default is ) . code(14) . q(.</p>),
q(<p>Space allowed for each label.</p>),
q(<p>Space allowed for each label, in PostScript units of 1/72 inch.</p>)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Chart
if ($all or $ch{Chart}) {
$name = 'Chart';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['heading'       ,0,'VARCHAR', 20],
['background'    ,0,'VARCHAR', 18],
['bgnd_outline'  ,0,'TINYINT',  1],
['dots_per_inch' ,0,'FLOAT'  ,  5],
['prices_pc'     ,0,'FLOAT'  ,  5],
['prices'        ,0,'VARCHAR', 20],
['volumes_pc'    ,0,'FLOAT'  ,  5],
['volumes'       ,0,'VARCHAR', 20],
['cycles_pc'     ,0,'FLOAT'  ,  5],
['cycles'        ,0,'VARCHAR', 20],
['signals_pc'    ,0,'FLOAT'  ,  5],
['signals'       ,0,'VARCHAR', 20],
['x_axis'        ,0,'VARCHAR', 20],
['key_panel'     ,0,'VARCHAR', 20],
['heading_font'  ,0,'VARCHAR', 20],
['normal_font'   ,0,'VARCHAR', 20],
['file'          ,0,'VARCHAR', 20],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Charts'        ,'.*'           ],
['heading'       , 1,16,'123',''   ,'Heading'       ,'.*'           ],
['background'    , 2,18,'123',''   ,'Background'    ,'^[][0-9., ]*$'],
['bgnd_outline'  , 3, 1,' 23',''   ,'Outline'       ,'radio'        ,'[1,0]', 
    '{0 => "Contrasting", 1 => "As background"}'],
['dots_per_inch' , 4, 6,'123',''   ,'Dots per inch' ,'^[0-9.]*$'    ],
['prices_pc'     , 5, 6,'1  ',''   ,'Prices %'      ,'^[0-9.]*$'    ],
['prices'        , 6,16,' 23',''   ,'Prices'        ,''             ,'Graph','name','default','p'],
['volumes_pc'    , 7, 6,'1  ',''   ,'Volumes %'     ,'^[0-9.]*$'    ],
['volumes'       , 8,16,' 23',''   ,'Volumes'       ,''             ,'Graph','name','default','v'],
['cycles_pc'     , 9, 6,'1  ',''   ,'Cycles %'      ,'^[0-9.]*$'    ],
['cycles'        ,10,16,' 23',''   ,'Cycles'        ,''             ,'Graph','name','default','c'],
['signals_pc'    ,11, 6,'1  ',''   ,'Signals %'     ,'^[0-9.]*$'    ],
['signals'       ,12,16,' 23',''   ,'Signals'       ,''             ,'Graph','name','default','s'],
['x_axis'        ,13,16,' 23',''   ,'Dates axis'    ,''             ,'Axis','name','default','x'],
['key_panel'     ,14,16,' 23',''   ,'Key panels'    ,''             ,'Key_Panel','name','default'],
['heading_font'  ,15,16,' 23',''   ,'Heading font'  ,''             ,'Font','name','default'],
['normal_font'   ,16,16,' 23',''   ,'Normal font'   ,''             ,'Font','name','default'],
['file'          ,17,16,'123',''   ,'Results File'  ,''             ,'File','name','default'],
];
## help
$help = [
['name',
"<p>A <b>Chart</b> is a page with up to 4 graphs showing prices, volumes and the results of <b>Tests</b>
    and <b>Functions</b>.</p>" . intro('chart') . ""],
['heading',
"<p>Do you want the chart to have any special title?  A suitable one will be produced if this is left blank.</p>"],
['background',
"<p>What colour do you want for the graph background? ". color1() ."</p>"],
['bgnd_outline',
q(<p>The lines and points have an outline.  Do you want this to be the same color as the backgound or coloured to
stand out?</p>)],
['dots_per_inch',
"<p>What resolution does the output need to be?  Setting this to 72 produces output suitable for most computer
monitors.  Use a higher figure for hard copy, depending on you printer's capabilities.</p>"],
['prices_pc',
"<p>The proportion of chart space to be allocated to the prices graph.  These are not strict percentages in that
they don't <i>have</i> to add up to 100.  Enter ". code(0) ." to prevent the graph from appearing.  Leave this
blank to allow the graphs to appear as they are needed.</p>",],
['prices',
"<p>Have you any preferences for how the prices graph looks? ". menu('Prices') ."</p>"],
['volumes_pc',
"<p>The proportion of chart space to be allocated to the volumes graph.</p>",],
['volumes',
"<p>Have you any preferences for how the volumes graph looks? ". menu('Volumes') ."</p>"],
['cycles_pc',
"<p>The proportion of chart space to be allocated to the cycles graph.</p>",],
['cycles',
"<p>Have you any preferences for how the cycles graph looks? ". menu('Cycles') ."</p>"],
['signals_pc',
"<p>The proportion of chart space to be allocated to the signals graph.</p>",],
['signals',
"<p>Have you any preferences for how the signals graph looks? ". menu('Signals') ."</p>"],
['x_axis',
"<p>The same X axis is used for all graphs.  How should it be set up? ". menu('Dates') ."</p>"],
['key_panel',
"<p>Each graph that has lines on it acquires a Key where the lines can be identified.  Are there any special
settings you want for this? ". menu('Key panels') ."</p>"],
['heading_font',
"<p>How do you want the heading to look? ". menu('Heading font'). "</p>"],
['normal_font',
"<p>How do you want the axis text to look? ". menu('Normal font'). "</p>"],
['file',
"<p>If you have any special requirements for printing the chart, this is where you change them.
" .menu('Results file'). "</p>"],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Draw
if ($all or $ch{Draw}) {
$name = 'Draw';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['sample'        ,0,'VARCHAR', 20],
['functions'     ,0,'CHAR'   ,  1, undef, 'Draw'],
['chart'         ,0,'VARCHAR', 20],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Function charts','.*'            ],
['sample'        , 5,16,'123',''   ,'Sample'        ,''             ,'Sample','name'],
['functions'     , 4,16,'123',''   ,'Functions'     ,'multiple'     ,'Function','name'],
['chart'         , 5,16,'123',''   ,'Chart'         ,''             ,'Chart','name','default'],
['buttons'       , 6, 0,'123',''   ,''              ,'submit'       ,'["Draw chart", "Submit", "Cancel"]'],
];
## help
$help = [
['name',
"<p>A <b>Function chart</b> shows the prices and volumes of a <b>Sample</b> together with any functions acting on
them.</p>". intro('function chart'),],
['sample',
"<p>What quotes do you want to graph? ". menu('Sample') ."</p>",],
['functions',
"<p>Would you like to draw add any functions to the chart? ". menu('Functions') ." ". &multiple ."</p>",],
['chart',
"<p>Do you want the results to be shown in any particular way? " .menu('Chart'). " </p>"],
['buttons',
q(<p>Press <span class='btn'>&nbsp;Draw chart&nbsp;</span> to chart this sample, <span class='btn'>&nbsp;Submit&nbsp;</span>
to store your choices or <span class='btn'>&nbsp;Cancel&nbsp;</span> to return without changing anything.</p>),
q()],
];
create($name, $mysql, $layout, $mapping, $help);
}

### File
if ($all or $ch{File}) {
$name = 'File';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['landscape'     ,0,'VARCHAR',  1],
['paper'         ,0,'VARCHAR', 12],
['width'         ,0,'INT'    ,  4],
['height'        ,0,'INT'    ,  4],
['mleft'         ,0,'INT'    ,  4],
['mright'        ,0,'INT'    ,  4],
['mtop'          ,0,'INT'    ,  4],
['mbottom'       ,0,'INT'    ,  4],
['eps'           ,0,'VARCHAR',  1],
['page'          ,0,'VARCHAR', 12],
['page_order'    ,0,'VARCHAR', 12],
['clipping'      ,0,'VARCHAR',  1],
['headings'      ,0,'VARCHAR',  1],
['title'         ,0,'VARCHAR', 20],
['version'       ,0,'VARCHAR', 12],
['strip'         ,0,'VARCHAR', 12],
['reencode'      ,0,'VARCHAR', 20],
['errors'        ,0,'VARCHAR',  1],
['debug'         ,0,'VARCHAR',  1],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Results File'  ,'.*'            ],
['landscape'     , 1, 1,'123',''   ,'Landscape'     ,'radio'        ,'[1,0]', 
    '{1 => "Landscape", 0 => "Portrait"}','default'],
['paper'         , 2,12,'123',''   ,'Paper'         ,''             ,
    '[qw(Letter US-Letter Half-Letter Folio Executive Legal US-Legal Tabloid SuperB Ledger
	 A0 A1 A2 A3 A4 A5 A6 A7 A8 A9 B0 B1 B2 B3 B4 B5 B6 B7 B8 B9 B10)]','','default'],
['width'         , 3, 6,'  3',''   ,'Paper width'   ,'^[0-9.]*$'    ],
['height'        , 4, 6,'  3',''   ,'Paper height'  ,'^[0-9.]*$'    ],
['mleft'         , 5, 6,'  3',''   ,'Left margin'   ,'^[0-9.]*$'    ],
['mright'        , 6, 6,'  3',''   ,'Right margin'  ,'^[0-9.]*$'    ],
['mtop'          , 7, 6,'  3',''   ,'Top margin'    ,'^[0-9.]*$'    ],
['mbottom'       , 8, 6,'  3',''   ,'Bottom margin' ,'^[0-9.]*$'    ],
['presentation'  , 9, 0,' 23',''   ,'Presentation'  ,'section' ],
['eps'           ,10, 1,' 23',''   ,'EPS'           ,'radio'        ,'[1,0]', '{1 => "Yes", 0 => "No"}','default' ],
['clipping'      ,11, 1,' 23',''   ,'Clipping'      ,'radio'        ,'[1,2,0]', 
	'{1 => "Yes", 0 => "No", 2 => "Border"}','default' ],
['reencode'      ,12,12,'  3',''   ,'Encoding'      ,'radio'        ,'[qw(ISOLatin1Encoding)]','','default'],
['postscript'    ,13, 0,'  3',''   ,'PostScript'    ,'section' ],
['headings'      ,14, 1,'  3',''   ,'Headings'      ,'radio'        ,'[1,0]', '{1 => "Yes", 0 => "No"}','default' ],
['title'         ,15,16,'  3',''   ,'Title'         ,'.*'           ],
['version'       ,16,12,'  3',''   ,'Version'       ,'.*'           ],
['page'          ,17,12,' 23',''   ,'Page'          ,'.*'           ],
['page_order'    ,18,12,' 23',''   ,'Order'         ,'radio'        ,'[qw(ascend descend special)]',
	'{ascend => "Ascending", descend => "Descending", special => "Special"}','default'],
['strip'         ,19, 1,'  3',''   ,'Strip'         ,'radio'        ,'[qw(none space comments)]',
	'{none => "Nothing", space => "Spaces", comments => "Comments"}','default'],
['errors'        ,20, 1,'  3',''   ,'Errors'        ,'radio'        ,'[1,0]', '{1 => "Yes", 0 => "No"}','default' ],
['debug'         ,21, 1,'  3',''   ,'Debug'         ,'radio'        ,'[0,1,2]',
	'{1 => "Supported", 0 => "No", 2 => "Yes"}','default' ],
];
## help
$help = [
['name',
"<p>The <b>Results File</b> holds the <b>Charts</b> produced by a <b>Model</b>.  The graphs on it can be printed
out or viewed on a computer screen.
</p>" . intro('result file') . ""],
['landscape',
q(<p>Do you want the chart to have most space across the page?</p>),
q()],
['paper',
q(<p>Pick the size of paper to be used.</p>),
q()],
['width',
q(<p>Entering a number here to specify an alternative paper width.  The number should be a point size e.g.
8 inches would be ) . code(576) . q(.</p>),
q(<p>Width of paper.</p>),
q(<p>Width of paper in PostScript units of 1/72".</p>)],
['height',
q(<p>Entering a number here to specify an alternative paper height.  The number should be a point size e.g.
11 inches would be ) . code(792) . q(.</p>),
q(<p>Height of paper.</p>),
q(<p>Height of paper in PostScript units of 1/72".</p>)],
['mleft',
q(<p>Is the printout too close to the left margin?  A value of ) . code(30) . q( or more might help.</p>),
q(<p>Offset of left edge in points, roughly.</p>),
q(<p>Offset of left edge in PostScript units of 1/72".</p>),],
['mright',
q(<p>Is the printout too close to the right margin?  A value of ) . code(30) . q( or more might help.</p>),
q(<p>Offset of right edge in points, roughly.</p>),
q(<p>Offset of right edge in PostScript units of 1/72".</p>),],
['mtop',
q(<p>Is the printout too close to the top margin?  A value of ) . code(30) . q( or more might help.</p>),
q(<p>Offset of top edge in points, roughly.</p>),
q(<p>Offset of top edge in PostScript units of 1/72".</p>),],
['mbottom',
q(<p>Is the printout too close to the bottom margin?  A value of ) . code(30) . q( or more might help.</p>),
q(<p>Offset of bottom edge in points, roughly.</p>),
q(<p>Offset of bottom edge in PostScript units of 1/72".</p>),],
['left',
q(<p>Is the printout too close to the left margin?  A value of ) . code(30) . q( or more might help.</p>),
q(<p>Offset of left edge in points, roughly.</p>),
q(<p>Offset of left edge in PostScript units of 1/72".</p>),],
['eps',
q(<p>If you don't know what EPS is, you don't want it.</p>),
q(<p>Encapsulated PostScript format.</p>),
q(<p>Encapsulated PostScript format.  This will not work properly unless only one Date type (e.g. days or
weeks) has been used.</p>)],
['clipping',
q(<p>Choose ) . code('No') . q( here if some of the Y axis text is missing, or ) . code('Border') . q( to draw
a border around the page.</p>),
q(<p>) . code('Border') . q( draws page frame.</p>)],
['page',
q(<p>The first page number.  This can be a simple number, roman numeral or some combination like '1a'.  These are
for PostScript handling software and don't appear on the printout.</p>)],
['page_order',
q(<p>How subsequent page numbers are generated.</p>)],
['headings',
q(<p>Choosing ) . code('No') . q( makes the PostScript file slightly smaller, but won't work with most PostScript
handling software.</p>)],
['title',
q(<p>The PostScript file title.  This appears in a GhostScript window title bar, for instance.</p>)],
['version',
q(<p>A place to record a version number for the tests, perhaps.</p>)],
['strip',
q(<p>Determines the readability of the PostScript file.</p>)],
['reencode',
q(<p>If you have entered any headings or date abbreviations which require a Latin1 font, you must set this.</p>)],
['errors',
q(<p>PostScript isn't good at reporting errors.  With this set to ) . code('Yes') . q( any errors in the
PostScript code will be reported on the printout.</p>)],
['debug',
q(<p>Probably not very useful unless you are playing with the PostScript code.</p>)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Font
if ($all or $ch{Font}) {
$name = 'Font';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['font'          ,0,'VARCHAR', 18],
['size'          ,0,'VARCHAR',  4],
['color'         ,0,'VARCHAR', 18],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Fonts'         ,'.*'           ],
['font'          , 1,12,'123',''   ,'Face'          ,''             ,
    '[qw(Times-Roman Times-Italic Times-Bold Times-BoldItalic Helvetica Helvetica-Oblique Helvetica-Bold
	 Helvetica-BoldOblique Courier Courier-Oblique Courier-Bold Courier-BoldOblique Symbol)]' ],
['size'          , 2, 6,'123',''   ,'Size'          ,'^[0-9.]*$'    ],
['color'         , 3,18,'123',''   ,'Color'         ,'^[][0-9., ]*$'],
];
## help
$help = [
['name',
q(<p>Text appears in several places on the charts, and each can be set to a particular style.  It is probably
  a good idea to define settings for normal text and a seperate set for headings.</p>
  <p>Which font settings do you wish to see or change?</p>
  <p>To <b>start a new group</b>, type a name and press ) . button('Add') . q(.<br>To <b>view or change</b>
  the settings, click on the name and press ) . button('Choose') . q(.<br>To <b>delete</b> unwanted
  settings, click on the name and press ) . button('Remove') . q(.</p>),
],
['font',
q(<p>Choose the style of font.</p>),
q(<p>Font style.</p>),
q(<p>Only PostScript level 1 fonts are available.</p>)],
['size',
q(<p>How big should the font be?  Enter a number in normal 'point' size. ) . code('12') . q( is good for normal
text.</p>)],
['color',
q(<p>) . color1() . q(</p>),
q(<p>) . color2() . q(</p>),
q(<p>) . color3() . q(</p>)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Function
if ($all or $ch{Function}) {
$name = 'Function';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['function'      ,0,'VARCHAR', 20],
['graph'         ,0,'VARCHAR', 20],
['line_name'     ,0,'VARCHAR', 20],
['price'         ,0,'FLOAT'  , 10],
['volume'        ,0,'FLOAT'  , 10],
['period'        ,0,'FLOAT'  , 10],
['percent'       ,0,'FLOAT'  , 10],
['edge'          ,0,'TINYINT',  1],
['strict'        ,0,'TINYINT',  1, 0],
['shown'         ,0,'TINYINT',  1, 1],
['style'         ,0,'VARCHAR', 20],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Functions'     ,'.*'            ],
['function'      , 1,16,'123',''   ,'Function'      ,''             ,
'[qw(value_p value_v simple_a weighted_a expo_a env_e boll_b chan_c)]',
'{value_p => "Price level", value_v => "Volume level",
  simple_a => "Simple average", weighted_a => "Weighted average", expo_a => "Exponential average",
  env_e => "Envelope", boll_b => "Bollinger band", chan_c => "Highest/lowest",}'],
['graph'         , 2, 0,'   ','lta','Graph'         ,'radio'        ,'[qw(prices volumes cycles signals)]',
			'{prices => "Prices", volumes => "Volumes", cycles => "Cycles", signals => "Signals"}'],
['line_name'     , 3,16,'123','aebc','Source line'   ,''             ,'Function','name'],
['edge'          , 4,16,'123','ebc','Edge'          ,'radio'        ,'[1,0]',
			'{1 => "Upper bound", 0 => "Lower bound"}'], 
['price'         , 5, 6,'123','p'  ,'Price'         ,'^[0-9.]*$'    ],
['volume'        , 6,12,'123','v'  ,'Volume'        ,'^[0-9.]*$'    ],
['period'        , 7, 6,'123','ac' ,'Period'        ,'^[0-9.]*$'    ],
['percent'       , 8, 6,'123','e'  ,'Percent'       ,'^[0-9.]*$'    ],
['strict'        ,10,16,' 23','aebc','Strict'       ,'radio'        ,'[1,0]','{1 => "Yes", 0 => "No"}'], 
['shown'         ,11,16,'  3','avpebc','Visible'    ,'radio'        ,'[1,0]','{1 => "Yes", 0 => "No"}'], 
['style'         ,12,16,'123','avpebc','Style'      ,''             ,'Style','name','default'],
];
## help
$help = [
['name',
"<p>A <b>Function</b> analyses some data such as prices, and produces another line which may be graphed.  They are
usually used by <b>Tests</b>.
</p>" . intro('function') . ""],
['function',
q(<p>These are all the functions that can be used in tests.  Most of them need additional values.</p>
  <p>If you have changed the Line type, <b>don't forget to press</b> ) . button('Choose function') . q( so that you
  can select any additional parameters.</p>)],
['graph',
q(<p>What graph should it appear on?</p>),
q()],
['line_name',
q(<p>The line type you have chosen needs another line to work on. ) . menu('Central line') . q(</p>)],
['edge',
q(<p>This function produces a band around the central line.  Which line do you want to use?</p>)],
['price',
q(<p>Please enter the price you want to use as a comparison.</p>)],
['volume',
q(<p>Please enter the volume you want to use as a comparison.</p>)],
['period',
q(<p>This will normally be a number of days.</p>)],
['percent',
q(<p>How wide a band do you want above or below the inner line? ) . code('3') . q( percent is a good
starting value.</p>)],
['strict',
q(<p>Do you want the line to be drawn strictly by the book? Answering ) . code('No') . q( will sometimes produce
a better looking graph.</p>),
q(<p>By the book?</p>),
q(<p>) . code('Yes') . q( if values are only to be calculated if the required conditions are present.  ) . 
  code('No') . q( if approximations and estimates are acceptable.</p>)],
['shown',
q(<p>Do you want this line drawn on the graph?</p>)],
['style',
q(<p>Do you want the function line to be drawn in any particular way? ) . menu('Style') . q(</p>)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Graph
if ($all or $ch{Graph}) {
$name = 'Graph';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['percent'       ,0,'FLOAT'  ,  5],
['sequence'      ,0,'VARCHAR', 20],
['show_dates'    ,0,'TINYINT',  1],
['spacing'       ,0,'FLOAT'  ,  5],
['top_margin'    ,0,'FLOAT'  ,  5],
['right_margin'  ,0,'FLOAT'  ,  5],
['y_axis'        ,0,'VARCHAR', 20],
['pshape'        ,0,'VARCHAR', 12],
['pi_color'      ,0,'VARCHAR', 18],
['po_color'      ,0,'VARCHAR', 18],
['po_width'      ,0,'FLOAT'  ,  5],
['bi_color'      ,0,'VARCHAR', 18],
['bo_color'      ,0,'VARCHAR', 18],
['bo_width'      ,0,'FLOAT'  ,  5],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Graphs'        ,'.*'          ],
['percent'       , 1, 6,'123',''   ,'Percent space' ,'^[0-9.]*$'   ],
['sequence'      , 2,16,'123',''   ,'Sequence'      ,''             ,'Sequence','name','default'],
['show_dates'    , 3, 1,'123',''   ,'Show dates'    ,'radio'        ,'[1,0]', '{1 => "Show", 0 => "Hide"}', 'default' ],
['layout'        , 4, 0,'  3',''   ,'Layout'        ,'section'     ],
['spacing'       , 5, 6,'  3',''   ,'Spacing'       ,'^[0-9.]*$'   ],
['top_margin'    , 6, 6,'  3',''   ,'Top margin'    ,'^[0-9.]*$'   ],
['right_margin'  , 7, 6,'   ',''   ,'Right margin'  ,'^[0-9.]*$'   ],
['y_axis'        , 8,16,' 23',''   ,'Y axis'        ,''             ,'Axis','name','default','y'],
['points'        , 9, 0,' 23','p'  ,'Price points'  ,'section'     ],
['pshape'        ,10,18,'123','p'  ,'Shape'         ,''             ,'[qw(stock2 stock close2 close)]',
    q({stock => "Day's spread (simple)", stock2 => "Day's spread (outlined)",
    close => "Closing price (simple)", close2 => "Closing price (outlined)"}), 'default'], 
['pi_color'      ,12,18,' 23','p'  ,'Color'         ,'^[][0-9., ]*$'],
['po_color'      ,13,18,'  3','p'  ,'Outline color' ,'^[][0-9., ]*$'],
['po_width'      ,14, 6,'  3','p'  ,'Outline width' ,'^[0-9.]*$'    ],
['bars'          ,15, 0,' 23','v'  ,'Volume bars'   ,'section'     ],
['bi_color'      ,16,18,'123','v'  ,'Bar color'     ,'^[][0-9., ]*$'],
['bo_color'      ,17,18,'  3','v'  ,'Outline color' ,'^[][0-9., ]*$'],
['bo_width'      ,18, 6,'  3','v'  ,'Outline width' ,'^[0-9.]*$'    ],
];
## help
$help = [
['name',
"<p>A <b>Graph</b> is one of four grids that can appear on a <b>Chart</b>.</p>". intro('graph'),],
['percent',
q(<p>How much space do you want this graph to take up?  The value given here is compared with this value for the
other graphs.  They are not true percentages - they don't have to add up to 100.</p>),
q(<p>Proportion of chart space for this graph.</p>),
qq(<p>Proportion of chart space for this graph.  Defaults are <b>Price</b> \() .code(75) .qq(\), <b>Volume</b> \()
. code(25) . qq(\) and <b>Analysis</b> \() . code(0) . qq(\).</p>)],
['sequence',
q(<p>When more than one test or function line is to be shown, the software can ensure each line has a different appearance
(color, dashes etc.). These lines should all normally belong to the same <b>Sequence</b>. ) . menu('Sequence') . q(</p>)],
['show_dates',
q(<p>Do you want dates to appear along the X axis of this graph?</p>)],
['spacing',
q(<p>Do you want more space between the chart elements?  The number is a point size, so ) . code(0) . q( to
) . code(20) . q( would be suitable.</p>),
q(<p>Space between chart elements.</p>),
q(<p>Space between chart elements, in PostScript units of 1/72".</p>)],
['top_margin',
q(<p>If set, this controls how much space there is between the top of the Y axis and the top of the graph.  The
default is ) . code(5) . q(</p>)],
['right_margin',
q(<p>If set, this controls how much space there is between the right edge of the graph and the Key panel.  The
default is ) . code(15) . q(</p>)],
['y_axis',
q(<p>Do you want any special settings for the Y axis or horizontal grid lines? ) . menu('Y axis') . q(</p>)],
['pshape',
q(<p>What shape do you want the price mark to be?  The ) . code('Day\'s spread') . q( shows the market's opening
and closing prices marked on a line between lowest and highest prices for the day.</p> <p>Normally, all
marks on the graph have an outline, but the ) . code('(simple)') . q( marks are only drawn once.  They don't look
as good but for a lot of prices they will be displayed faster and make a smaller file.</p>)],
['pi_color',
q(<p>What colour would you like the price marks? ) . color1() . q(</p>)],
['pi_width',
q(<p>How wide should the price lines be? ) . width1() . q(</p>),
q(<p>Price line width. ) . width2() . q(</p>),
q(<p>Price line width. ) . width3() . q(</p>)],
['po_color',
q(<p>The outer color can be set here, overriding the ) . button('Outline') . q( Chart setting. ) . color3()
. q(</p>)],
['po_width',
q(<p>This is the width of the outer edge.  Note that only half the width is visible as it is obscured by the mark. ) . width2() . q(</p>)],
['bi_color',
q(<p>What colour would you like the bars to be? ) . color1() . q(</p>)],
['bo_color',
q(<p>Bars have an outer edge as well as the inner color.  The outer color can be set here. ) . color2() . q(</p>)],
['bo_width',
q(<p>This controls the width of the outer edges, but half of this value is hidden by the bar itself. ) . width1()
. q(</p>),
q(<p>This controls the width of the outer edges.  Only half is visible.</p>),
q(<p>This controls the width of the outer edges.  Only half is visible, so to get a 1pt border, enter
) . code('2') . q(. ) . width3() . q(</p>)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Key_Panel
if ($all or $ch{Key_Panel}) {
$name = 'Key_Panel';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['background'    ,0,'VARCHAR', 18],
['outline_color' ,0,'VARCHAR', 18],
['outline_width' ,0,'VARCHAR',  4],
['spacing'       ,0,'VARCHAR',  4],
['vert_spacing'  ,0,'VARCHAR',  4],
['horz_spacing'  ,0,'VARCHAR',  4],
['icon_height'   ,0,'VARCHAR',  4],
['icon_width'    ,0,'VARCHAR',  4],
['text_font'     ,0,'VARCHAR', 20],
['text_width'    ,0,'VARCHAR',  4],
['title'         ,0,'VARCHAR', 20],
['title_font'    ,0,'VARCHAR', 20],
['glyph_ratio'   ,0,'VARCHAR',  4],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Key Panel'     ,'.*'           ],
['color_sect'    , 2, 0,'  3',''   ,'Colors'        ,'section'      ],
['background'    , 3,18,' 23',''   ,'Background'    ,'^[][0-9., ]*$'],
['outline_color' , 4,18,' 23',''   ,'Outline color' ,'^[][0-9., ]*$'],
['outline_width' , 5, 6,' 23',''   ,'Outline width' ,'^[0-9.]*$'    ],
['text_sect'     , 6, 0,'  3',''   ,'Text'          ,'section'      ],
['title'         , 7,16,' 23',''   ,'Key title'     ,'.*'           ],
['title_font'    , 8,16,' 23',''   ,'Title font'    ,''             ,'Font','name','default'],
['text_font'     , 9,16,' 23',''   ,'Normal font'   ,''             ,'Font','name','default'],
['glyph_ratio'   ,10, 6,'  3',''   ,,'Glyph ratio'   ,'^[0-9.]*$'   ],
['spacing_sect'  ,11, 0,'  3',''   ,'Spacing'       ,'section'      ],
['spacing'       ,12, 6,' 2 ',''   ,'Spacing'       ,'^[0-9.]*$'    ],
['vert_spacing'  ,13, 6,'  3',''   ,'Vertical spacing','^[0-9.]*$'    ],
['horz_spacing'  ,14, 6,'  3',''   ,'Horizontal spacing','^[0-9.]*$'    ],
['icon_width'    ,15, 6,'  3',''   ,'Icon width'    ,'^[0-9.]*$'    ],
['icon_height'   ,16, 6,'  3',''   ,'Icon height'   ,'^[0-9.]*$'    ],
['text_width'    ,17, 6,'  3',''   ,'Text width'    ,'^[0-9.]*$'    ],
];
## help
$help = [
['name',
q(<p>Each graph on the chart may have a <b>Key panel</b> identifying any Test lines.</p>) . intro('key panel')],
['background',
q(<p>If you are not happy with the Key panel's default background color, set it here.) . color1() . q(</p>),
q(<p>Background color of the Key panel.</p>),
q(<p>Background color of the Key panel.) . color3() . q(</p>)],
['outline_color',
q(<p>What color do you want the box around the Key? ) . color1() . q(</p>)],
['outline_width',
q(<p>How thick should the Key box outline be? ) . width1() . q(</p>)],
['title',
q(<p>Do you want to call the Key panel anything special?  Leave blank and the software will choose something
suitable.</p>)],
['text_font',
q(<p>Which settings do you want for the normal Key text?</p>)],
['title_font',
q(<p>Which settings should be applied to the title?</p>)],
['spacing',
q(<p>Are the items on the Key squashed together?  Entering a number from ) . code(4) . q( to ) . code(10) . 
q(, say, might help.</p>),
q(<p>Between elements in Key panel.</p>),
q(<p>Default spacing between elements in Key panel.  A number in PostScript default units (1/72").</p>)],
['vert_spacing',
q(<p>Are the items on top of each other?  Entering a number from ) . code(4) . q( to ) . code(10) . 
q(, say, will spread them vertically.</p>),
q(<p>Between elements in Key panel.</p>),
q(<p>Vertical spacing between elements in Key panel.  A number in PostScript default units (1/72").</p>)],
['horz_spacing',
q(<p>Are the icons and text too cramped together?  Entering a number from ) . code(4) . q( to ) . code(10) . 
q(, say, should spread them out, although less space will be left for the graph.</p>),
q(<p>Between elements in Key panel.</p>),
q(<p>Horizontal spacing between elements in Key panel.  A number in PostScript default units (1/72").</p>)],
['icon_width',
q(<p>Space allocated for graphic.</p>),
q(<p>Space allocated for graphic.  A number in PostScript default units (1/72").</p>)],
['icon_height',
q(<p>Space allocated for graphic.</p>),
q(<p>Space allocated for graphic.  A number in PostScript default units (1/72").</p>)],
['text_width',
q(<p>Space allocated for label.</p>),
q(<p>Space allocated for label.  A number in PostScript default units (1/72").</p>)],
['glyph_ratio',
q(<p>Are the text labels not fitting well inside the Key panel?  It is not possible to get the actual
width of proportional font strings from PostScript, so this gives the opportunity to guess an 'average width' for
particular fonts.  The default is ) .code(0.5). q(</p>),],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Model
if ($all or $ch{Model}) {
$name = 'Model';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['samples'       ,0,'CHAR'   ,  1, undef, 'Model'],
['functions'     ,0,'CHAR'   ,  1, undef, 'Model'],
['tests'         ,0,'CHAR'   ,  1, undef, 'Model'],
['chart'         ,0,'VARCHAR', 20],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Models'       ,'.*'            ],
['samples'       , 1,16,'123',''   ,'Samples'       ,'multiple'     ,'Sample','name',''],
['tests'         , 2,16,'123',''   ,'Tests'         ,'multiple'     ,'Test','name',''],
['functions'     , 4,16,' 23',''   ,'Functions'     ,'multiple'     ,'Function','name',''],
['chart'         , 5,16,'123',''   ,'Chart'         ,''             ,'Chart','name','default'],
['buttons'       , 6, 0,'123',''   ,''              ,'submit'       ,'["Run", "Submit", "Cancel"]'],
];
## help
$help = [
['name',
"<p>A <b>Model</b> is a group of tests applied to share prices to determine whether the stock should be
  bought or sold.</p>" . intro('model') . "",],
['samples',
"<p>What quotes do you want the model to work on? " .menu('Samples'). " " .&multiple. "</p>"],
['functions',
"<p>All functions used in " .button('Tests'). " are covered there.  But do you want any additional functions to be
calculated? " .menu('Functions'). " " .&multiple. "</p>"],
['tests',
"<p>What conditions do you want to look out for? " .menu('Tests'). " " .&multiple. "</p>"],
['chart',
"<p>Do you want the results to be shown in any particular way? " .menu('Chart'). " </p>"],
['buttons',
q(<p>Press <span class='btn'>&nbsp;Run&nbsp;</span> to run this model, <span class='btn'>&nbsp;Submit&nbsp;</span>
to store your choices or <span class='btn'>&nbsp;Cancel&nbsp;</span> to return without changing anything.</p>),
q()],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Sample
if ($all or $ch{Sample}) {
$name = 'Sample';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['symbol'        ,0,'VARCHAR', 10],
['start_date'    ,0,'VARCHAR', 10],
['end_date'      ,0,'VARCHAR', 10],
['dates_by'      ,0,'VARCHAR', 10],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Samples'        ,'.*'            ],
['symbol'        , 1,12,'123',''   ,'Stock symbol'  ,'.*'           ],
['start_date'    , 7,12,'123',''   ,'Start date'    ,'^\d\d\d\d.\d\d.\d\d$'],
['end_date'      , 8,12,'123',''   ,'End date'      ,'^\d\d\d\d.\d\d.\d\d$'],
['dates_by'      , 6, 0,' 23',''   ,'Compare over'  ,''             ,'[qw(days weeks months)]',
			'{days => "Trading days", weeks => "Weeks", months => "Months"}' ],
];
## help
$help = [
['name',
"<p>A <b>Sample</b> is a series of quotes for a share over a period of time.</p>". intro('sample'),],
['symbol',
q(<p>Which stock are you investigating?  You should use the same code that ) . yahoo() . q( uses, eg ) . 
  code('MSFT') . q( or ) . code('BSY.L') . q(.</p>),
q(<p>The EPIC or stock abbreviation used by ) . yahoo() . q(.</p>),
q(<p>This must be recognized by ) . yahoo() . q(, usually in the format ) .
    code("<STOCK-CODE>.<EXCHANGE-CODE>") . q(.</p>)],
['start_date',
"<p>What is the first date you want to test? ". dates() ."</p>",],
['end_date',
q(<p>What is the last date you want to test?</p>)],
['dates_by',
q(<p>What timescale do you want? If the test is to be done over a lengthy period, it would be better to set this
to ) . code('Weeks') . q( or even ) .  code('Months') . q(.  Otherwise ) . code('Trading days') . q( should be
fine.</p>),
q(<p>The timescale.</p>),
q(<p>This determines the number and frequency of values tested.  The default ) . code('Trading days') . q(is just
  the data as returned from <a href='http://finance.yahoo.com'>!Yahoo</a> when the range of dates is requested.</p>
  <p>The various 'day' options will produce slightly differing results in moving averages, for example.  They are
  provided because some stocks are sold in many markets, invalidating some assumptions behind the 'Trading day'
  choice.)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Sequence
if ($all or $ch{Sequence}) {
$name = 'Sequence';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['red'           ,0,'VARCHAR', 255, q(0.5, 1, 0)],
['green'         ,0,'VARCHAR', 255, q(0, 0.5, 0.25, 0.75, 1)],
['blue'          ,0,'VARCHAR', 255, q(0, 1, 0.5)],
['color'         ,0,'VARCHAR', 255, q([0.8,0.8,0], [0,0.5,0.5], [0.3,0,0.3], [0.9,0.3,0])],
['width'         ,0,'VARCHAR', 255, q(0.5, 1, 3, 2)],
['dashes'        ,0,'VARCHAR', 255, q([], [9, 9], [3, 3], [9, 3], [3, 9], [9, 3, 3, 3])],
['shape'         ,0,'VARCHAR', 255, q(dot, cross, square, plus, diamond)],
['size'          ,0,'VARCHAR', 255, q(2, 4, 6)],
['gray'          ,0,'VARCHAR', 255, q(0.6, 0, 0.45, 0.15, 0.75, 0.3, 0.9)],
['sequence'      ,0,'VARCHAR', 255, q(dashes, shape, width, size)],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Sequences'     ,'.*'           ],
['sequence'      , 1,20,' 23',''   ,'Sequence'      ,'^[a-z, ]$'    ],
['dashes'        , 6,20,' 23',''   ,'Dashes'        ,'^[][0-9, ]$'  ],
['shape'         , 7,20,' 23',''   ,'Shape'         ,'^[a-z, ]$'    ],
['size'          , 8,20,' 23',''   ,'Size'          ,'^[0-9., ]$'   ],
['width'         , 5,20,' 23',''   ,'Width'         ,'^[0-9., ]$'   ],
['red'           , 2,20,' 23',''   ,'Red'           ,'^[0-9., ]$'   ],
['green'         , 3,20,' 23',''   ,'Green'         ,'^[0-9., ]$'   ],
['blue'          , 4,20,' 23',''   ,'Blue'          ,'^[0-9., ]$'   ],
['color'         , 6,20,' 23',''   ,'Colours'       ,'^[][0-9, ]$'  ],
['gray'          ,12,20,'  3',''   ,'Gray'          ,'^[0-9., ]$'   ],
];
## help
$help = [
['name',
"<p>The software can give a different appearance to each chart line.  To do this, it must be told whether to
change the color or width next, and what to change it to.  A <b>Sequence</b> is what controls this behaviour.</p>
" .intro('sequence'). "",],
['sequence',
q(<p>This list controls the order in which the attributes listed below change.  The first attribute cycles through
fastest, with the last changing slowest.  Select from these ,seperated by commas, all in lower case:</p>) .
"<p>" . code('color') . ", " . code('red') . ", " . code('green') . ", " . code('blue') . ", " . code('gray') . ",
" . code('width') . ", " . code('dashes') . ", " . code('shape') . ", " . code('size') . "</p>",],
['red',
q(<p>These are the color intensities chosen in order when <b>red</b> is the changing attribute in
) . button('Sequence') . q(. All color values should be decimals between ) . code('0.0') . q( and ) . code('1.0') . q(,
seperated by commas ",".</p>)],
['green',
q(<p>When <b>green</b> is the changing attribute in ) . button('Sequence') . q(, these color intensities are
cycled through.  The eye is more sensitive to green, so narrower differences and more values can be usefully
used.</p>)],
['blue',
q(<p>Each color in ) . button('Sequence') . q( is cycled through independently.  The eye is not very sensitive to
blue so there should be few, widely spaced values here.</p>)],
['width',
q(<p>The line width is measured in point sizes (more or less), so values between ) . code(0.25) . q( and ) . code(5) . q( might be best.</p>)],
['dashes',
"<p>Dash patterns are number lists inside square brackets. These patterns are themselves seperated by commas such
as ". code('[3,3], [2,8]') .". ". dashes() ."</p>",],
['shape',
q(<p>The only values allowed here are ) . code('dot') . q(, ). code('cross') . q(, ). code('square') . q(, ).
code('plus') . q(, ). code('diamond') . q( and ) . code('circle') . q(.  These should be seperated by commas.</p>)],
['size',
q(<p>This is the width across the point shapes.  Try values between ) . code(2) . q( and ) . code(10) . q(.</p>)],
['gray',
q(<p>If you have a black and white printer, it may be useful to have full control over the gray scale.</p>)],
['color',
"<p>Here you can specify a sequence of individual colours.
Each colour need three decimals for <b>red</b>, <b>green</b> and <b>blue</b> seperated by commas.  For example,
a red-orange would be ". code('[1.0, 0.25, 0]') .".</p>
<p><b>IMPORTANT:</b> each red, green, blue group must be placed inside square brackets.</p>",],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Signal
if ($all or $ch{Signal}) {
$name = 'Signal';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['signal'        ,0,'VARCHAR', 20],
['graph'         ,0,'VARCHAR', 20],
['style'         ,0,'VARCHAR', 20],
['line_name'     ,0,'VARCHAR', 20],
['value'         ,0,'FLOAT'  ,  5],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Signals'        ,'.*'            ],
['signal'        , 1,16,'123',''   ,'Signal'         ,'radio'        ,'[qw(mark_buy mark_sell)]',
	'{mark_buy => "Buy point", mark_sell => "Sell point"}'],
['graph'         , 2, 0,'  3',''   ,'Graph'          ,'radio'        ,'[qw(prices volumes cycles signals)]',
			'{prices => "Prices", volumes => "Volumes", cycles => "Cycles", signals => "Signals"}'],
['value'         , 3, 6,'  3',''   ,'Value'          ,'^[0-9.]*$'    ],
['line_name'     , 4,16,'123',''   ,'Position line'  ,''             ,'Function','name'],
['style'         , 5,16,'  3',''   ,'Style'          ,''             ,'Style','name','default'],
];
## help
$help = [
['name',
"<p>A <b>Signal</b> is something that happens when a test passes.</p>". intro('sample'),],
['signal',
"<p>These are the only two signals that will show on a chart.  See the Finance::Shares::Model module for other
signals available.</p>"],
['graph',
"<p>If a ". menu('Value') ." is provided, this should indicate what type of value it is.</p>"],
['value',
"<p>Entering a number here will override any " .menu('Position line'). ", forcing all signal marks to this level
on the ". menu('Graph') ." indicated.</p>"],
['line_name',
"<p>The test determines whether a signal is shown for each date, but not what it marks.  Choosing a line here has
the effect of marking that value.</p>"],
['style',
"<p>Do you wish to specify the mark's appearance?  The default setting shows arrows.</p>"],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Style
if ($all or $ch{Style}) {
$name = 'Style';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['display'       ,0,'TINYINT',  1, 3],
['color'         ,0,'VARCHAR', 18],
['width'         ,0,'FLOAT'  ,  5],
['sequence'      ,0,'VARCHAR', 20],
['same'          ,0,'TINYINT',  1, 1],
['li_color'      ,0,'VARCHAR', 18],
['li_width'      ,0,'FLOAT'  ,  5],
['li_dashes'     ,0,'VARCHAR', 30],
['lo_color'      ,0,'VARCHAR', 18],
['lo_width'      ,0,'FLOAT'  ,  5],
['lo_dashes'     ,0,'VARCHAR', 30],
['pshape'        ,0,'VARCHAR', 12],
['psize'         ,0,'FLOAT'  ,  5],
['pi_color'      ,0,'VARCHAR', 18],
['po_color'      ,0,'VARCHAR', 18],
['po_width'      ,0,'FLOAT'  ,  5],
['bi_color'      ,0,'VARCHAR', 18],
['bo_color'      ,0,'VARCHAR', 18],
['bo_width'      ,0,'FLOAT'  ,  5],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Styles'        ,'.*'            ],
['display'       , 4, 1,'123',''   ,'Display'       ,'radio'        ,'[1,2,3]', 
    '{1 => "Lines only", 2 => "Points only", 3 => "Lines with points"}'],
['color'         , 1,18,'1  ',''   ,'Color'         ,'^[][0-9., ]*$'],
['width'         , 2, 6,'1  ',''   ,'Width'         ,'^[0-9.]*$'    ],
['sequence'      , 3,16,' 23',''   ,'Sequence'      ,''             ,'Sequence','name','default'],
['same'          , 4, 1,' 23',''   ,'Outline'       ,'radio'        ,'[1,0]', 
    '{0 => "Contrasting", 1 => "As background"}'],
['line_settings' , 5, 0,' 23',''   ,'Line settings' ,'section' ],
['li_color'      , 7,18,' 23',''   ,'Line color'    ,'^[][0-9., ]*$'],
['li_width'      , 8, 6,' 23',''   ,'Line width'    ,'^[0-9.]*$'    ],
['li_dashes'     , 9,18,' 23',''   ,'Line dashes'   ,'^[][0-9., ]*$'],
['lo_color'      ,10,18,'  3',''   ,'Outline color' ,'^[][0-9., ]*$'],
['lo_width'      ,11, 6,'  3',''   ,'Outline width' ,'^[0-9.]*$'    ],
['lo_dashes'     ,12,18,'  3',''   ,'Outline dashes','^[][0-9., ]*$'],
['point_settings',13, 0,' 23',''   ,'Point settings','section' ],
['pshape'        ,16,12,'123',''    ,'Shape'         ,''             ,
    '[qw(circle cross diamond dot plus square north south east west)]',
'{circle=>"Circle",cross=>"Cross",diamond=>"Diamond",dot=>"Dot",plus=>"Plus",square=>"Square",
north=>"Up arrow",south=>"Down arrow",east=>"Left arrow",west=>"Right arrow"}',
'default'],
['psize'         ,17, 6,'123',''   ,'Size'          ,'^[0-9.]*$'    ],
['pi_color'      ,18,18,' 23',''   ,'Color'         ,'^[][0-9., ]*$'],
['po_color'      ,19,18,'  3',''   ,'Outline color' ,'^[][0-9., ]*$'],
['po_width'      ,20, 6,'  3',''   ,'Outline width' ,'^[0-9.]*$'    ],
['bi_color'      ,22,18,' 23',''   ,'Bar color'     ,'^[][0-9., ]*$'],
['bo_color'      ,23,18,'  3',''   ,'Outline color' ,'^[][0-9., ]*$'],
['bo_width'      ,24, 6,'  3',''   ,'Outline width' ,'^[0-9.]*$'    ],
];
## help
$help = [
['name',
"<p>A <b>Style</b> determines how things look on the <b>Chart</b>.  In particular they control the lines, points
    and bars on each graph.</p>". intro('style'),],
['color',
"<p>What colour do you want? ". color1() ."</p>"],
['width',
"<p>How wide do you want the lines? ". width1() ."</p>"],
['sequence',
q(<p>When more than one line is to be shown, the software can ensure each line has a different appearance
(color, dashes etc.). Lines on the same graph should normally belong to the same <b>Sequence</b>. ) . menu('Sequence') . q(</p>)],
['same',
q(<p>The lines and points have an outline.  Do you want this to be the same color as the backgound or coloured to
stand out?</p>)],
['display',
"<p>How do you want the lines to be drawn?</p>"],
['li_color',
"<p>What colour do you want the lines to be? ". color1() ."</p>"],
['li_width',
"<p>How wide do you want the lines? ". width1() ."</p>"],
['li_dashes',
"<p>Do you want a dash pattern? ". dashes() ."</p>"],
['lo_color',
"<p>Lines have an outer edge as well as the inner color.  Do you want to specify a colour for the outer edge? ". color1() ."</p>"],
['lo_width',
"<p>How wide should the outer line be? ". width1() ."</p>"],
['lo_dashes',
q(<p>If left blank, the line background is continuous.  However, you might wish to set this to the same as
) . button('Line dashes') . q( </p>)],
['price_shape',
q(<p>What shape do you want the price mark to be?  The ) . code('Day\'s spread') . q( shows market's opening and
) . code('Closing prices') . q( marked on a line between lowest and highest prices for the day.</p>
<p>Normally, all marks on the graph have an outline, but the ) . code('(simple)') . q( marks are only drawn once.
They don't look as good but for a lot of prices they will be displayed faster and make a smaller file.</p>)],
['pshape',
q(<p>What shape would you like the mark to be? ) . code('Plus') . q( and ) . code('Cross') . q( are lines, while
) . code('Dot') . q(, ) . code('Square') . q( and ) . code('Diamond') . q( are filled.  ) . code('Circle') . q( is
unusual in that the center is hollow, allowing the point being marked to be visible.</p>),
q(<p>What shape would you like the mark to be?),
q(<p>What shape would you like the mark to be? ) . code('Plus') . q( and ) . code('Cross') . q( are lines, while
) . code('Dot') . q(, ) . code('Square') . q( and ) . code('Diamond') . q( are filled.  ) . code('Circle') . q( is
has a hollow center and works better with a larger ) . button('Size') . q(.</p>),
],
['psize',
q(<p>This is the width across the whole mark.  Values between ) . code('2.5') . q( and ) . code('10') . q( might
be suitable.</p>)],
['pi_color',
"<p>What colour do you want the points to be? ". color1() ."</p>"],
['po_color',
"<p>Points have an outer edge as well as the inner color.  Do you want to specify a colour for the outer edge? ". color1() ."</p>"],
['po_width',
"<p>How wide do you want the outer edge? ". width1() ." Note that half of this edge line is covered by the inner
colour.</p>"],
['bi_color',
"<p>What colour do you want the bars to be? ". color1() ."</p>"],
['bo_color',
"<p>Bars have an outer edge as well as the inner color.  Do you want to specify a colour for the outer edge? ". color1() ."</p>"],
['bo_width',
"<p>How wide do you want the outer edge? ". width1() ." Note that half of this edge line is covered by the inner
colour.</p>"],
];
create($name, $mysql, $layout, $mapping, $help);
}

### Test
if ($all or $ch{Test}) {
$name = 'Test';
## mysql
$mysql = [
#'field----------,k,'type'---,max,default,aux
['name'          ,1,'VARCHAR', 20],
['graph1'        ,0,'VARCHAR', 20],
['line1_name'    ,0,'VARCHAR', 20],
['test'          ,0,'VARCHAR', 20],
['graph2'        ,0,'VARCHAR', 20],
['line2_name'    ,0,'VARCHAR', 20],
['shown'         ,0,'TINYINT',  1],
['style'         ,0,'VARCHAR', 20],
['graph'         ,0,'VARCHAR', 20, 'signals'],
['weight'        ,0,'FLOAT'  , 10],
['decay'         ,0,'FLOAT'  , 10],
['ramp'          ,0,'FLOAT'  , 10],
['signals'       ,0,'VARCHAR', 20, undef, 'Test'],
['userid'        ,1,'INT'    , 10],
];
## layout
$layout = [
#'field'---------,sq,wi,'lvl','cnd','heading'-------,'validation'---,'table','entry','extras','args'
['name'          , 0,16,'123',''   ,'Tests'         ,'.*'            ],
['graph1'        , 1, 0,'   ',''   ,'First line graph','radio'        ,'[qw(prices volumes cycles signals)]',
			'{prices => "Prices", volumes => "Volumes", cycles => "Cycles", signals => "Signals"}'],
['line1_name'    , 2,16,'123',''   ,'First line'    ,''             ,'Function','name',''],
['test'          , 3, 0,'123',''   ,'Comparison'    ,''             ,'[qw(gt lt ge le eq ne)]',
    '{gt => "moves above", lt => "moves below", ge => "moves above or touches",
    le => "moves below or touches", eq => "touches", ne => "doesn\'t touch"}'],
['graph2'        , 4, 0,'   ',''   ,'Second line graph','radio'     ,'[qw(prices volumes cycles signals)]',
			'{prices => "Prices", volumes => "Volumes", cycles => "Cycles", signals => "Signals"}'],
['line2_name'    , 5,16,'123',''   ,'Second line'   ,''             ,'Function','name','default'],
['shown'         , 6,16,'  3',''   ,'Visible'       ,'radio'        ,'[1,0]','{1 => "Yes", 0 => "No"}'], 
['style'         , 7,16,'123',''   ,'Style'         ,''             ,'Style','name','default','l'],
['graph'         , 8, 0,'   ',''   ,'Graph'         ,'radio'        ,'[qw(prices volumes cycles signals)]',
			'{prices => "Prices", volumes => "Volumes", cycles => "Cycles", signals => "Signals"}'],
['weight'        , 9, 6,' 23',''   ,'Percent'       ,'^[0-9.]*$'    ],
['decay'         ,10, 6,' 23',''   ,'Decay factor'  ,'^[0-9.]*$'    ],
['ramp'          ,11, 6,' 23',''   ,'Ramp constant' ,'^[0-9.]*$'    ],
['signals'       ,12, 0,' 23',''   ,'Signals'       ,'multiple'     ,'Signal','name'],
];
## help
$help = [
['name',
"<p>A <b>Test</b> usually compares two readings on a graph and produces a recommendation line depending on the
result.  The resulting line is not always shown but often is used to generate buy or sell signals.
</p>" . intro('test') . ""],
['graph1',
"<p></p>",],
['line1_name',
q(<p>This is the '1st' line referred to by the ) . button('Comparison') . q( choices.  If only one value is needed
for the test, this is it. ) . menu('First line') . q(</p>)],
['test',
"<p>How do you want the ". menu('First line') ." compared with the ". menu('Second line') ."?</p>"],
['graph2',
"<p></p>",],
['line2_name',
q(<p>This is the '2nd' line referred to by the ) . button('Comparison') . q( choices.  If only one value is needed
for the test, this one is ignored. ) . menu('Second line') . q(</p>)],
['shown',
q(<p>Do you want this line drawn on the chart?</p>)],
['style',
q(<p>Do you want the test line to be drawn in any particular way? ) . menu('Style') . q(</p>)],
['graph',
"<p>If it is " .button('Visible'). " which graph should the test line appear on?</p>",
q()],
['weight',
q(<p>How significant is this test?  Enter ) . code('100') . q( for 'must be obeyed', down to ) . code('0.0') . q(
if it should be ignored.</p>)],
['decay',
q(<p>Typically a decimal between 0 and 1. ). code('0.95') .q( will make the test result decay gradually.  With each period, the test
result is multiplied by this value, if one is given.</p>),],
['ramp',
q(<p>Typically a number in the same range as the Y axis, this amount is taken from the test value each period.
Where ). button('Decay') .q( produces a curve, ). button('Ramp') .q( gives a straight line.</p>),],
['signals',
q(<p>Do you want success marked in any particular way?  If the comparison is 'true' for a particular date, any
signals selected here are invoked. ) . &multiple . q(</p>)],
];
create($name, $mysql, $layout, $mapping, $help);
}

### End main program
print "</pre>";
print end_html();

sub sessions_create {
    my $uname = 'Login::Sessions';
    
    my $fields = '';
    $fields .= "session char(32) not null, ";
    $fields .= "userid int(4) not null, ";
    $fields .= "ts timestamp default null, ";
    $fields .= "cache enum ('online', 'cache', 'offline' ) default 'online', ";
    $fields .= "bwidth int(4) default 0, ";
    $fields .= "frames tinyint(1) default 0, ";
    $fields .= "css tinyint(1) default 0, ";
    $fields .= "layers tinyint(1) default 0, ";
    $fields .= "dhtml tinyint(1) default 0, ";
    $fields .= "primary key(session)";
    return $db->create($uname, $fields);
}

sub users_create {
    my $uname = 'Login::Users';
    
    my $fields = '';
    $fields .= "login char(20) not null unique, ";
    $fields .= "userid int(4) not null auto_increment, ";
    $fields .= "pwd char(32) not null, ";
    $fields .= "hint char(32) default '', ",
    $fields .= "email char(40) not null, ";
    $fields .= "ts timestamp default null, ";
    $fields .= "userlevel tinyint(1) default 1, ";
    $fields .= "helplevel tinyint(1) default 1, ";
    $fields .= "primary key(userid)";
    return $db->create($uname, $fields);
}

sub mysql_create {
    my ($tname, $data) = @_;
    
    my (@fields,  @idx);
    foreach my $field (@$data) {
	my ($name, $key, $type, $size, $default, $aux);
	my $extras = '';
	($name, $key, $type, $size, $default, $aux) = @$field;
	if ($aux) {
	    my $auxname = "${aux}::$name";
	    mysql_create($auxname, $aux_mysql);
	    print "($auxname) ";
	}
	if (defined $default) {
	    no warnings;
	    $default = qq('$default') if ($type =~ /CHAR/i);
	    $extras .= qq(DEFAULT $default );
	}
	if ($key) {
	    $extras .= 'NOT NULL ';
	    $idx[$key] = [] unless defined $idx[$key];
	    push @{$idx[$key]}, $name;
	}
	if ($size) {
	    push @fields, "$name $type($size) $extras";
	} else {
	    push @fields, "$name $type $extras";
	}
    }
    my $desc = join(', ', @fields);
    # @idx is indexed by 'index number' with 1 being the first index (0=no index, unused)
    for (my $i = 1; $i <= $#idx; $i++) {
	my $keyname = ($i == 1) ? 'PRIMARY KEY' : 'INDEX';
	$desc   .= ", $keyname (" . join(',',@{$idx[$i]}) . ')';
    }
    return $db->create($tname, $desc);
}

sub layout_create {
    my ($name, $data) = @_;
    
    my $fields = '';
    $fields .= "field varchar(20) not null, ";
    $fields .= "posn integer(3), ";
    $fields .= "width integer(3), ";
    $fields .= "levels char(3), ";
    $fields .= "conditions char(6), ";
    $fields .= "heading varchar(20), ";
    $fields .= "validation varchar(20), ";
    $fields .= "entry_table varchar(255), ";
    $fields .= "entry_field text, ";
    $fields .= "entry_extras varchar(80), ";
    $fields .= "entry_args varchar(20), ";
    $fields .= "primary key(field)";
    my $table = $db->create($name, $fields);
    
    my $default_posn = 0;
    foreach my $d (@$data) {
	my ($field, $posn, $width, $levels, $conditions, $heading, $validation,
	    $entry_table, $entry_field, $entry_extras, $entry_args) = @$d;
	croak 'No field name' unless $field;
	$levels = '' unless defined $levels;
	$conditions = '' unless defined $conditions;
	$posn = $default_posn unless defined $posn;
	$heading = '' unless defined $heading;
	$width = length($heading) unless defined $width;
	my $job = "replace into $table (". join(',', @$layout_fields) . ") values (";
	$job   .= $db->quote($field) .     ',';
	$job   .= $db->quote($posn) .      ',';
	$job   .= $db->quote($width) .     ',';
	$job   .= $db->quote($levels) .    ',';
	$job   .= $db->quote($conditions) .',';
	$job   .= $db->quote($heading) .   ',';
	$job   .= defined($validation)   ? $db->quote($validation)   .',' : q(NULL,);
	$job   .= defined($entry_field)  ? $db->quote($entry_field)  .',' : q(NULL,);
	$job   .= defined($entry_table)  ? $db->quote($entry_table)  .',' : q(NULL,);
	$job   .= defined($entry_extras) ? $db->quote($entry_extras) .',' : q(NULL,);
	$job   .= defined($entry_args)   ? $db->quote($entry_args)         : q(NULL);
	$job   .= ')';
	$db->dbh()->do($job);
	$default_posn++;
    }

    return $table;
}

sub help_create {
    my ($name, $data) = @_;
    
    my $fields = '';
    $fields .= "field varchar(20) not null, ";
    $fields .= "help1 text, ";
    $fields .= "help2 text, ";
    $fields .= "help3 text, ";
    $fields .= "primary key(field)";
    my $table = $db->create($name, $fields);

    foreach my $d (@$data) {
	my ($field, $help1, $help2, $help3) = @$d;
	croak 'No field name' unless $field;
	$help1 = '' unless defined $help1;
	$help2 = '' unless defined $help2;
	$help3 = '' unless defined $help3;
	my $job = "replace into $table (field, help1, help2, help3) values (";
	$job   .= $db->quote($field) .',';
	$job   .= $db->quote($help1) .',';
	$job   .= $db->quote($help2) .',';
	$job   .= $db->quote($help3);
	$job   .= ')';
	$db->dbh()->do($job);
    }

    return $table;
}

sub create {
    my ($name, $m, $l, $r, $h) = @_;
    croak "No 'name' given" unless $name;
    croak "No mysql data given"  unless $m and ref $m eq 'ARRAY';
    croak "No layout data given" unless $l and ref $l eq 'ARRAY';
    croak "No help data given"   unless $h and ref $h eq 'ARRAY';
    if ($list) {
	print "'$name'\n";
	return;
    }
    eval {
	print "'$name' : ";
	mysql_create("${name}::Options", $m) and print 'table ' if $tables;
	layout_create("${name}::Layout", $l) and print 'layout ' if $layouts;
	help_create("${name}::Help", $h) and print 'prompt ' if $prompts;
	print "\n";
    };
    if ($@) {
	print "\n$@\n";
	exit;
    }
}

### Helper functions

sub intro {
    my $type = shift;
    return "<p>Which ${type}'s details do you wish to see or change?".
    "<br>To <b>view or change</b> the settings, click on the name and press " .button('Choose'). " below.</p>".
    "<p>To <b>start a new group</b> or <b>delete</b> unwanted settings, type in the name and press "
    .button('Add'). " or " .button('Remove'). " above.".
    "<br>To <b>rename</b> or <b>copy</b> a group, click on the old name, type in the new name, and press "
    .button('Rename'). " or " .button('Copy'). " above.</p>";
}

sub button {
    my $label = shift;
    my $html = escapeHTML($label);
    $html =~ s/\s/&nbsp;/g;
    return "<span class='btn'>&nbsp;$html&nbsp;</span>";
}

sub menu {
    my $label = shift;
    my $res = 'Click on ' . button($label) . ' to create or change suitable options.';
    return $res;
}

sub multiple {
    return 'You may choose more than one by holding down CTRL when clicking on a line.';
}

sub code {
    my $text = shift;
    my $html = escapeHTML($text);
    $html =~ s/\s/&nbsp;/g;
    return "<span class='code'>$html</span>";
}

sub dashes {
    return "The numbers are represent the dots on then off (then on then off, ...).  For example," .code('5,2').
    " would produce a line made up of " .code(' -----  ----- ----- '). "  or " .code('5,2,1,2'). " would make
    " .code(' -----  -  -----  -  ----- '). ". The special pattern " .code('[]'). " indicates a continuous line."
}

sub dates {
    return '&nbsp;Enter as ' .code('YYYY-MM-DD'). ' e.g. ' .code('2003-12-31'). ' for 31st December 2003.';
}

sub color1 {
    return "&nbsp;Entering a decimal will specify a gray from " . code('0.0') . " (black) to " . code('1.0')
    . " (white).  Colors need three decimals for <b>red</b>, <b>green</b> and <b>blue</b> seperated by commas.
    For example, a red-orange would be " . code('1.0, 0.25, 0');
}

sub color2 {
    return "Example: " .code('0.75, 1, 0'). ".";
}

sub color3 {
    return code('<red>,<green>,<blue>'). " or " .code('<gray>'). " All decimals " .code('0.0'). " to " .code('1.0');
}

sub width1 {
    return "&nbsp;The number is about the same as point sizes used for fonts, so suitable values might be from"
    .code(0.5). " to " .code(4);
}

sub width2 {
    return "&nbsp;Widths are roughly point sizes." 
}

sub width3 {
    return "&nbsp;In PostScript default units of 1/72\", so suitable values might be from " .code(0.5). " to
    " .code(4);
}

sub upgrade {
    return q(<p>Having moved beyond simple help, you should probably also select ) . code('Intermediate') .
    q( or ) . code('Specialist') . q( on the <b>Level of help</b> page.</p>);
}

sub perl_module {
    my $module = shift;
    return q(&nbsp;Perl module ) . code(escapeHTML($module)) . q( See the man page on <a href='http://search.cpan.org'
    target='other'>CPAN</a> for details.);
}

sub yahoo {
    return q(<a href='http://finance.yahoo.com'>!Yahoo</a>);
}

sub email {
    my $name = shift;
    return qq(<a href='mailto:webmaster\@willmot.org.uk'>$name</a>);
}

=head1 BUGS

Please report those you find to the author.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

=head1 SEE ALSO

See also L<DBIx::Namespace>

=cut

1;
