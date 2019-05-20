use strict;
#use warnings;
use FindBin;
use lib "$FindBin::Bin";
require "read_line.pm";
use File::Basename;



my %cmd = (
	'^[[A' => \&cmd_top,    # ↑
	'^[[B' => \&cmd_bottom, # ↓
	'^[[C' => \&cmd_right,  # →
	'^[[D' => \&cmd_left,   # ←

	'^[[5~' => \&cmd_large_top,    # pageup
	'^[[6~' => \&cmd_large_bottom, # pagedown

	' '  => \&mark, # space

	'^[[1;2A' => \&set_cursor_search_prev, # Shift+Up
	'^[[1;2B' => \&set_cursor_search_next, # Shift+Down
	'^[[1;2C' => \&cmd_empty,              # Shift+Right
	'^[[1;2D' => \&cmd_empty,              # Shift+Left

	'^[OP'     => \&cmd_empty,          # F1
	'^[OQ'     => \&cmd_empty,          # F2
	'^[OR'     => \&cmd_empty,          # F3
	'^[OS'     => \&cmd_empty,          # F4
	'^[[15~'   => \&cmd_update_display, # F5
	'^[[17~'   => \&cmd_empty,          # F6
	'^[[18~'   => \&cmd_empty,          # F7
	'^[[19~'   => \&cmd_empty,          # F8
	'^[[20~'   => \&cmd_grep,           # F9
	'^[[20;2~' => \&cmd_grep_recursive, # Shift+F9
	'^[[21~'   => \&find_file,          # F10
	'^[[23~'   => \&cmd_empty,          # F11
	'^[[24~'   => \&cmd_empty,          # F12
	

	'3'  => \&copy_file,       # Ctrl+c
	'24' => \&move_file,       # Ctrl+x
	'1'  => \&add_copy,        # Ctrl+a
	'22' => \&paste_file,      # Ctrl+v
	'18' => \&rename_file,     # Ctrl+r
	'23' => \&duplicate_file,  # Ctrl+w
	'4'  => \&delete_file,     # Ctrl+d
	'11' => \&create_dir,      # Ctrl+k
	'9'  => \&calc_total_size, # Ctrl+i
	'2'  => \&open_binary,     # Ctrl+b

);

my $g_menu_start_row = 5;

my %di = ();
my %mi = (
	'cur_loc' => 0,
	'cur_loc_offset' => 0,
	'cur_loc_prev' => 0,
	'cur_height_max' => $ReadLine::g_term_height - $g_menu_start_row,
	'term_height_max' => $ReadLine::g_term_height,
	'term_width_max' => $ReadLine::g_term_width,
	'update' => 1,

	'virtual' => 0,
	'virtual_return' => "/Users/user",
);
my %mi_bk = ();

my $g_pwd = "";
my $g_search = "";
my $g_footer_buf = "";
my %g_marked = ();
my $g_script_dir = dirname($0);
my $g_user = "";
my $g_uid = 0;
my @g_gid = ();

#-------------------------------------------------------------------------------
# {{{ main
#-------------------------------------------------------------------------------
ReadLine::stty_save();
ReadLine::stty_unable();

$g_pwd = `pwd`; chomp( $g_pwd );
$g_user = `whoami`; chomp( $g_user );
$g_uid = `id -u $g_user`; chomp( $g_uid );
load_di();
init_file_action();
init_my_group();
update_dir( $g_pwd );
printf("\e[?25l");
cls();

while( 1 )
{
	draw();

	my $key = ReadLine::wait_key();
	if ( $key eq '^[' ) { last; }
	elsif( defined($cmd{$key}) )
	{
		$cmd{$key}->();
	}
	elsif( $key =~ /[a-zA-Z-_\.\?\*]+/o )
	{
		if ( $key eq '^[DEL' ) {
			$g_search = substr( $g_search, 0, length($g_search)-1 );
		}
		elsif ( $key !~ /[\^\[]+/o ) {
			$g_search = $g_search . $key;
		}

		$mi{update} = 1;
		set_cursor_search();
	}
}

save_di();
ReadLine::stty_load();
printf("\e[?25h");
exit(0);
# }}}






#-------------------------------------------------------------------------------
# {{{ cmd
#-------------------------------------------------------------------------------
sub cmd_empty
{
}

sub cmd_left
{
	if ( $mi{virtual} == 1 )
	{
		move_dir( $mi{virtual_return} );
		$mi{virtual} = 0;
	}
	else
	{
		move_upper();
	}
}

sub cmd_right
{
	if ( $mi{virtual} == 1 )
	{
		my $item = get_selected_item();
		if ( defined($item->{jump}) )
		{
			my $path = $item->{jump};
			my $dir = dirname( $path );
			my $base = basename( $path );
			if ( -d $dir ) {
				move_dir( $dir );
				set_cursor_any( $base );
				$mi{virtual} = 0;
			}
		}
		elsif ( defined($item->{exec}) )
		{
			my $cmd = $item->{exec};
			system( $cmd );
		}
	}
	else
	{
		if ( get_di_count() == 0 ) {
			return;
		}

		my $path = get_selected_path();
		if ( -d $path ) {
			move_dir( $path );
		}
		else {
			ReadLine::stty_load();
			system( "/usr/bin/vim $path" );
			ReadLine::stty_unable();
		}
	}
	
}

sub cmd_top
{
	set_cursor( $mi{cur_loc} -1 );
}

sub cmd_bottom
{
	set_cursor( $mi{cur_loc} +1 );
}

sub cmd_large_top
{
	set_cursor( $mi{cur_loc} -10 );
}

sub cmd_large_bottom
{
	set_cursor( $mi{cur_loc} +10 );
}

sub cmd_grep
{
	grep_file(0);
}

sub cmd_grep_recursive
{
	grep_file(1);
}

sub cmd_update_display
{
	if ( !$mi{virtual} ) {
		update_dir( $g_pwd );
	}

	ReadLine::update_term_size();
	$mi{cur_height_max} = $ReadLine::g_term_height - $g_menu_start_row,
	$mi{term_height_max} = $ReadLine::g_term_height,
	$mi{term_width_max} = $ReadLine::g_term_width,
	$mi{update} = 1;
}

# }}}



#-------------------------------------------------------------------------------
# {{{ dir
#-------------------------------------------------------------------------------
sub update_dir
{
	my $dir_name = shift;

	my @di_array = ();

	my $ret = opendir( my $dh, $dir_name );
	if ( !$ret ) {
		$di{$dir_name} = \@di_array;
		print( "$!\n" );
		return;
	}
	while( my $item = readdir($dh) )
	{
		if ( $item eq '.' || $item eq '..' ) {
			next;
		}

		my %dir_info = ();
		my $full_path = $dir_name eq '/' ? "/$item" : "$dir_name/$item";
		my @fstat = stat( $full_path );

		$dir_info{name} = $item;

		$dir_info{perm} = is_permission($full_path, $fstat[2], $fstat[4], $fstat[5]);

		if ( -l $full_path ) {
			$dir_info{type} = 'l';
		}
		elsif ( -d $full_path ) {
			$dir_info{type} = 'd';
		}
		elsif ( -x $full_path ) {
			$dir_info{type} = 'x';
		}
		else {
			$dir_info{type} = 'f';
		}

		$dir_info{size} = $fstat[7];
		1 while $dir_info{size} =~ s/(.*\d)(\d\d\d)/$1,$2/;

		$dir_info{atime} = unixtime2str( $fstat[8] );
		$dir_info{mtime} = unixtime2str( $fstat[9] );

		$dir_info{mark} = 0;

		push( @di_array, \%dir_info );
	}

	closedir( $dh );

	my @di_sorted = sort( compare_di @di_array );
	$di{$dir_name} = \@di_sorted;
}

sub compare_di
{
	if ( $a->{type} eq 'd' && $b->{type} eq 'd' ) {
		return $a->{name} cmp $b->{name}
	}
	elsif ( $a->{type} eq 'd' ) {
		return -1;
	}
	elsif ( $b->{type} eq 'd' ) {
		return 1
	}

	return $a->{name} cmp $b->{name};
}

sub unixtime2str
{
	my $unixtime = shift;
	my ($sec, $min, $hour, $day, $mon, $year) = localtime($unixtime);
	$mon ++;
	$year += 1900;
	return sprintf( "%d/%02d/%02d %02d:%02d:%02d", $year, $mon, $day, $hour, $min, $sec );
}

sub is_permission
{
	my $f_path = shift;
	my $f_mode = shift;
	my $f_uid = shift;
	my $f_gid = shift;

	if ( $g_uid == $f_uid ) {
		return 1;
	}

	foreach my $gid ( @g_gid )
	{
		if ( $gid == $f_gid ) {
			return 1;
		}
	}

	if ( $f_mode & 0x04 ) {
		return 1;
	}

	

	return 0;
}

sub init_my_group
{
	my $groups = `id -G $g_user`; chomp( $groups );
	@g_gid = split( /[ ]/, $groups );
}

sub move_dir
{
	my $new_dir = shift;

	if ( !-d $new_dir ) {
		return 0;
	}

	if ( defined($di{$new_dir}) )
	{
		$mi_bk{$g_pwd}->{cur_loc}       = $mi{cur_loc};
		$mi_bk{$g_pwd}->{cur_loc_offset} = $mi{cur_loc_offset};

		$g_pwd = $new_dir;
		$mi{cur_loc}        = $mi_bk{$g_pwd}->{cur_loc};
		$mi{cur_loc_offset} = $mi_bk{$g_pwd}->{cur_loc_offset};
		$mi{update} = 1;
		mark_delete();
		return 1;
	}
	else
	{
		my %menu_info;
		$menu_info{cur_loc}        = $mi{cur_loc};
		$menu_info{cur_loc_offset} = $mi{cur_loc_offset};
		$mi_bk{$g_pwd} = \%menu_info;

		$mi{cur_loc} = 0;
		$mi{cur_loc_offset} = 0;
		$mi{cur_loc_prev} = 0;
		$mi{update} = 1;
		mark_delete();

		$g_pwd = $new_dir;
		update_dir( $g_pwd );
		return 1;
	}

	return 0;
}

sub move_upper
{
	if ( $g_pwd eq '/' ) {
		return;
	}

	my $upper_dir = dirname( $g_pwd );
	my $upper_name = basename( $g_pwd );
	move_dir( $upper_dir );
	set_cursor_any( $upper_name );

}

sub move_virtual
{
	my $new_dir = shift;

	$mi{virtual} = 1;
	$mi{virtual_return} = $g_pwd;
	$g_pwd = $new_dir;

	$mi{cur_loc} = 0;
	$mi{cur_loc_offset} = 0;
	$mi{cur_loc_prev} = 0;
	$mi{update} = 1;

}

sub mk_abs_path
{
	my $rel_path = shift;
	if ( $g_pwd eq '/' ) {
		return "/$rel_path";
	}
	else {
		return "$g_pwd/$rel_path";
	}
}

# }}}



#-------------------------------------------------------------------------------
# {{{ cursor
#-------------------------------------------------------------------------------
sub set_cursor
{
	my $loc = shift;

	if ( get_di_count() == 0 ) {
		$mi{cur_loc} = 0;
		$mi{cur_loc_prev} = 0;
		return;
	}

	$mi{cur_loc_prev} = $mi{cur_loc};
	$mi{cur_loc} = $loc;

	if ( $mi{cur_loc} < 0 ) {
		$mi{cur_loc} = 0;
	}
	elsif ( $mi{cur_loc} >= get_di_count() ) {
		$mi{cur_loc} = get_di_count() -1;
	}

	my $elem_count = get_di_count();
	if ( $elem_count >= $mi{'cur_height_max'} )
	{
		if ( $mi{cur_loc} < $mi{cur_loc_offset} )
		{
			$mi{cur_loc_offset} = $mi{cur_loc};
			$mi{update} = 1;
		}
		elsif( $mi{cur_loc} > ($mi{cur_loc_offset}+$mi{'cur_height_max'}-1) )
		{
			$mi{cur_loc_offset} = $mi{cur_loc} - $mi{'cur_height_max'} + 1;
			$mi{update} = 1;
		}
	}
}

sub set_cursor_search
{
	if ( $g_search eq "" ) {
		return;
	}

	my $di_arr = $di{$g_pwd};
	for( my $i=0; $i<get_di_count(); $i++ )
	{
		my $item = $di_arr->[$i];
		my $search = get_search_string();
		if ( $item->{name} =~ /$search/ ) {
			set_cursor( $i );
			last;
		}
	}
}

sub set_cursor_search_next
{
	if ( $g_search eq "" ) {
		return;
	}

	my $di_arr = $di{$g_pwd};
	my $search = get_search_string();
	for( my $i=$mi{cur_loc}+1; $i<get_di_count(); $i++ )
	{
		my $item = $di_arr->[$i];
		if ( $item->{name} =~ /$search/ ) {
			set_cursor( $i );
			return;
		}
	}

	for( my $i=0; $i<$mi{cur_loc}; $i++ )
	{
		my $item = $di_arr->[$i];
		if ( $item->{name} =~ /$search/ ) {
			set_cursor( $i );
			return;
		}
	}
}

sub set_cursor_search_prev
{
	if ( $g_search eq "" ) {
		return;
	}

	my $di_arr = $di{$g_pwd};
	my $search = get_search_string();
	for( my $i=$mi{cur_loc}-1; $i>=0; $i-- )
	{
		my $item = $di_arr->[$i];
		if ( $item->{name} =~ /$search/ ) {
			set_cursor( $i );
			return;
		}
	}

	for( my $i=get_di_count()-1; $i>=$mi{cur_loc}; $i-- )
	{
		my $item = $di_arr->[$i];
		if ( $item->{name} =~ /$search/ ) {
			set_cursor( $i );
			return;
		}
	}
}

sub set_cursor_any
{
	my $key = shift;

	my $di_arr = $di{$g_pwd};
	for( my $i=0; $i<get_di_count(); $i++ )
	{
		my $item = $di_arr->[$i];
		if ( $item->{name} eq $key ) {
			set_cursor( $i );
			last;
		}
	}

}

sub get_di_count
{
	return scalar( @{ $di{$g_pwd} } );
}

sub get_cursor_max
{
	my $elem_count = get_di_count();
	return $elem_count <= $mi{'cur_height_max'} ? $elem_count : $mi{'cur_height_max'};
}

sub get_selected_item
{
	my $di_arr = $di{$g_pwd};
	return $di_arr->[$mi{cur_loc}];
}

sub get_selected_path
{
	my $item = get_selected_item();
	if ( $g_pwd eq '/' ) {
		return "/$item->{name}"
	}
	else {
		return "$g_pwd/$item->{name}";
	}
}

sub get_search_string
{
	my $search = $g_search;
	$search =~ s/[.]/\\./g;
	$search =~ s/[?]/./g;
	$search =~ s/[*]/.*/g;
	return $search;
}

sub mark
{
	my $item = get_selected_item();
	my $name = $item->{name};

	if ( defined($g_marked{$name}) )
	{
		$g_marked{$name} ^= 1;
	}
	else
	{
		$g_marked{$name} = 1;
	}

	set_cursor( $mi{cur_loc} + 1 );
	if ( $mi{cur_loc} == get_di_count()-1 ) {
		$mi{update} = 1;
	}
}

sub mark_delete
{
	%g_marked = ();
	$mi{update} = 1;
}

sub get_marked
{
	my @list;

	foreach my $key ( keys(%g_marked) )
	{
		push( @list, $key );
	}

	return @list;
}

sub get_marked_count
{
	my $count = 0;
	foreach my $key ( keys(%g_marked) )
	{
		if ( $g_marked{$key} ) {
			$count ++;
		}
	}

	return $count;
}

# }}}



#-------------------------------------------------------------------------------
# {{{ draw
#-------------------------------------------------------------------------------
sub cls
{
	printf( "\e[2J\e[1;1H" );
}

sub clm
{

	printf( "\e[s" );

	for( my $i=$g_menu_start_row; $i<$mi{term_height_max}; $i++ )
	{
		printf( "\e[%d;1H\e[K", $i )
	}

	printf( "\e[u" );
}

sub draw
{
	draw_header();
	if ( $mi{update} ) {
		clm();
		draw_di_all();
		$mi{update} = 0;
	}
	else {
		draw_di_diff();
		#draw_di_all();
	}
	draw_footer();
}

sub draw_header
{
	printf( "\e[1;1H\e[K" );
	printf( "\e[2;1H\e[K" );
	printf( "\e[3;1H\e[K" );
	printf( "\e[4;1H\e[K" );
	printf( "\e[1;1H" );

	my $item = get_selected_item();
	if ( $g_pwd eq '/' ) {
		printf( "/$item->{name}\n" );
	}
	else {
		printf( "$g_pwd/$item->{name}\n" );
	}


	printf( "\e[3;1H" );
	if ( $mi{virtual} == 0 )
	{
		my $df = `df -h '$g_pwd' | tail -n1 2>/dev/null`;
		if ( $df ne "" )
		{
			my @df_size = split( /[ ]+/, $df );
			printf( "\e[Kused: %s/%s ", $df_size[2], $df_size[1] );
		}
	}

	printf( "cursor=[%d/%d]\n", get_di_count() ? $mi{cur_loc}+1 : 0, get_di_count() );

	printf( "search=[%s]\e[K\n", $g_search );
}

sub draw_footer
{
	printf( "\e[%d;%dH", $mi{term_height_max}, 1 );
	printf( "\e[K$g_footer_buf" );
	$g_footer_buf = "";
}

sub draw_footer_area
{
	my $msg = sprintf( shift, @_ );
	$g_footer_buf .= $msg;
}

sub draw_di_all
{
	my $di_arr = $di{$g_pwd};
	my $elem_max = $mi{cur_loc_offset}+get_cursor_max();

	for( my $i=$mi{cur_loc_offset}; $i<$elem_max; $i++ )
	{
		my $item = $di_arr->[$i];
		if ( $mi{cur_loc} == $i ) {
			draw_di( $item, 1 );
		}
		else {
			draw_di( $item, 0 );
		}
	}
}

sub draw_di_diff
{
	if ( $mi{cur_loc} == $mi{cur_loc_prev} ) {
		return;
	}

	my $di_arr = $di{$g_pwd};
	my $elem_max = $mi{cur_loc_offset}+get_cursor_max();
	my $count = 0;

	for( my $i=$mi{cur_loc_offset}; $i<$elem_max; $i++ )
	{
		my $item = $di_arr->[$i];
		if ( $mi{cur_loc} == $i ) {
			printf( "\e[%d;1H", $count+$g_menu_start_row );
			draw_di( $item, 1 );
		}
		elsif ( $mi{cur_loc_prev} == $i ) {
			printf( "\e[%d;1H", $count+$g_menu_start_row );
			draw_di( $item, 0 );
		}
		$count ++;
	}
}

sub draw_di
{
	my $item = shift;
	my $is_cursor = shift;
	my $draw_buf = "";
	my $name = "";
	my $name_color = "";


	$draw_buf .= "\e[K";

	if ( $is_cursor )
	{
		$draw_buf .= " -> ";
		$draw_buf .= "\e[4m";
		$name_color .= "\e[4m";
	}
	else
	{
		$draw_buf .= "    ";
	}

	if ( $item->{perm} == 0 )
	{
		$name_color = "\e[38;5;240m";
		$name = $item->{name};
	}
	elsif ( $item->{type} eq 'd' )
	{
		$name_color = "\e[36m";
		$name = $item->{name};
	}
	elsif( $item->{type} eq 'x' )
	{
		$name_color = "\e[32m";
		$name = $item->{name};
	}
	elsif( $item->{type} eq 'l' )
	{
		$name_color = "\e[35m";
		my $target = readlink( "$g_pwd/$item->{name}" );
		$name = "$item->{name} -> $target";
	}
	else
	{
		$name = $item->{name};
	}
	$draw_buf .= $name_color;


	if ( length($name) > ($mi{term_width_max}-4) )
	{
		$name = substr( $name, 0, $mi{term_width_max}-4 );
	}


	my $bg_color = "";
	if ( defined($g_marked{$item->{name}}) )
	{
		if ( $g_marked{$item->{name}} ) {
			$bg_color = "\e[48;5;17m";
			$draw_buf .= $bg_color;
		}
	}


	if ( $g_search ne "" )
	{
		my $search = get_search_string();
		if ( $name =~ /$search/ ) {
			$draw_buf .= $`;
			$draw_buf .= "\e[48;5;52m$&\e[m$name_color$bg_color";
			$draw_buf .= $';
		}
		else {
			$draw_buf .= $name;
		}
	}
	else
	{
		$draw_buf .= $name;;
	}


	if ( $mi{virtual} == 0 )
	{
		if ( $item->{type} eq 'd' )
		{
			$draw_buf .= "\e[10000D\e[40C ┃";
			$draw_buf .= sprintf( "%17s", "<DIR>" );
		}
		else
		{
			$draw_buf .= "\e[10000D\e[40C ┃";
			$draw_buf .= sprintf( "%17s", $item->{size} );
		}

		$draw_buf .= " ┃ $item->{atime} ┃ $item->{mtime}";
	}


	$draw_buf .= "\e[m\n";
	print( $draw_buf );
}

# }}}



#-------------------------------------------------------------------------------
# {{{ save & load
#-------------------------------------------------------------------------------
sub save_di
{
	if ( $mi{virtual} == 1 ) {
		return;
	}

	my $fname = "$g_script_dir/.filerlastdir";
	my $ret = open( my $fh, '>', $fname );
	if ( !$ret ) {
		return;
	}

	print( $fh "$g_pwd\n" );
	print( $fh "$mi{cur_loc}\n" );
	print( $fh "$mi{cur_loc_offset}\n" );

	close( $fh );

}

sub load_di
{
	my $fname = "$g_script_dir/.filerlastdir";
	my $ret = open( my $fh, '<', $fname );
	if ( !$ret ) {
		return;
	}

	my $path;
	my $cur_loc;
	my $cur_loc_offset;
	$path = <$fh>;           chomp($path);
	$cur_loc = <$fh>;        chomp($cur_loc);
	$cur_loc_offset = <$fh>; chomp($cur_loc_offset);
	close( $fh );

	if ( $path eq $g_pwd ) {
		$mi{cur_loc} = int($cur_loc);
		$mi{cur_loc_offset} = int($cur_loc_offset);
	}

}

sub init_file_action
{
	my $fname = "$g_script_dir/.fileraction";
	unlink( $fname );
}

sub save_file_action
{
	my $action = shift;
	my @path_list = get_marked();

	my $fname = "$g_script_dir/.fileraction";
	my $ret = open( my $fh, '>', $fname );
	if ( !$ret ) {
		return;
	}

	print( $fh "$action\n" );
	foreach my $path ( @path_list )
	{
		if ( $g_pwd eq '/' ) {
			print( $fh "/$path\n" );
		}
		else {
			print( $fh "$g_pwd/$path\n" );
		}
	}

	close( $fh );
}

sub add_file_action
{
	my @path_list = get_marked();

	my $fname = "$g_script_dir/.fileraction";

	if ( !-f $fname ) {
		return -1;
	}

	my $ret = open( my $fh, '>>', $fname );
	if ( !$ret ) {
		return -1;
	}


	foreach my $path ( @path_list )
	{
		if ( $g_pwd eq '/' ) {
			print( $fh "/$path\n" );
		}
		else {
			print( $fh "$g_pwd/$path\n" );
		}
	}

	close( $fh );

	my $total_action_num = `wc -l $fname`;
	return $total_action_num - 1;
}

sub load_file_action
{
	my $fname = "$g_script_dir/.fileraction";
	my $ret = open( my $fh, '<', $fname );
	if ( !$ret ) {
		return "";
	}

	my $action = <$fh>;
	chomp( $action );
	my @path = ();
	while( my $line = <$fh> )
	{
		chomp($line);
		push( @path, $line );
	}

	close( $fh );

	return ($action, @path);
}

sub delete_file_action
{
	unlink( "$g_script_dir/.fileraction" );
}

# }}}



#-------------------------------------------------------------------------------
# {{{ exec
#-------------------------------------------------------------------------------
sub copy_file
{
	my $marked_count = get_marked_count();
	if ( $marked_count == 0 ) {
		return;
	}

	save_file_action( 'cp' );

	my $msg = sprintf( "Copy file(%d items)", $marked_count );
	draw_footer_area( $msg );
	mark_delete();

}

sub move_file
{
	my $marked_count = get_marked_count();
	if ( $marked_count == 0 ) {
		return;
	}

	save_file_action( 'mv' );

	my $msg = sprintf( "Cut file(%d items)", $marked_count );
	draw_footer_area( $msg );
	mark_delete();


}

sub add_copy
{
	my $marked_count = get_marked_count();
	if ( $marked_count == 0 ) {
		return;
	}

	my $total = add_file_action();

	my $msg = sprintf( "Add file(%d items, total %d items)", $marked_count, $total );
	draw_footer_area( $msg );
	mark_delete();

}

sub paste_file
{
	my ($action, @path) = load_file_action();
	if ( $action eq "" ) {
		return;
	}

	printf( "\n" );
	foreach my $p ( @path )
	{
		printf( "$p\n" );
	}

	$mi{update} = 1;
	my $ans = ReadLine::read_line( "$action these above files? (Enter:OK, Escape:Cancel)" );
	if ( !defined($ans) ) {
		return;
	}

	foreach my $src ( @path )
	{
		my $cmd = sprintf( "$action '$src' '%s'", mk_abs_path('') );
		system( $cmd );
	}

	delete_file_action();
	cmd_update_display();
}

sub rename_file
{
	my $item = get_selected_item();

	$mi{update} = 1;
	my $ans = ReadLine::read_line( "new name=", $item->{name} );
	if ( !defined($ans) ) {
		return;
	}
	if ( $ans eq $item->{name} ) {
		return;
	}
	if ( -e mk_abs_path($ans) ) {
		return;
	}

	my $cmd = sprintf( "mv '%s' '%s'", mk_abs_path($item->{name}), mk_abs_path($ans) );
	system( $cmd );

	cmd_update_display();
}

sub duplicate_file
{
	my $item = get_selected_item();

	$mi{update} = 1;
	my $ans = ReadLine::read_line( "dup name=", $item->{name} );
	if ( !defined($ans) ) {
		return;
	}
	if ( $ans eq $item->{name} ) {
		return;
	}

	my $cmd = sprintf( "cp '%s' '%s'", mk_abs_path($item->{name}), mk_abs_path($ans) );
	system( $cmd );

	cmd_update_display();
}

sub mk_delete_unique_name
{
	my $unixtime = time();
	my ($sec, $min, $hour, $day, $mon, $year) = localtime($unixtime);
	$mon ++;
	$year += 1900;
	return sprintf( "filer_deleted_%d%02d%02d%02d%02d%02d", $year, $mon, $day, $hour, $min, $sec );
}

sub delete_file
{
	my $marked_count = get_marked_count();
	if ( $marked_count == 0 )
	{
		my $item = get_selected_item();
		$mi{update} = 1;
		my $ans = ReadLine::read_line( "Delete the file/directory on cursor? (Enter:OK, Escape:Cancel)" );
		if ( !defined($ans) ) {
			return;
		}

		my $del_name = sprintf( "%s.%s", mk_delete_unique_name(), $item->{name} );
		my $cmd = sprintf( "mv '%s' '/var/tmp/%s'", mk_abs_path($item->{name}), $del_name );
		system( $cmd );

		cmd_update_display();
	}
	else
	{
		my @list = get_marked();

		printf( "\n" );
		foreach my $file ( @list )
		{
			printf( "$file\n" );
		}

		$mi{update} = 1;
		my $ans = ReadLine::read_line( "Delete these above files? (Enter:OK, Escape:Cancel)" );
		if ( !defined($ans) ) {
			return;
		}

		foreach my $targ ( @list )
		{
			my $del_name = sprintf( "%s.%s", mk_delete_unique_name(), $targ );
			my $cmd = sprintf( "mv '%s' '/var/tmp/%s'", mk_abs_path($targ), $del_name );
			system( $cmd );
		}

		my $msg = sprintf( "Delete files(%d items)", $marked_count );
		draw_footer_area( $msg );
		cmd_update_display();
		mark_delete();
	}

}

sub create_dir
{
	$mi{update} = 1;
	my $ans = ReadLine::read_line( "new dir name=" );
	if ( !defined($ans) ) {
		return;
	}
	if ( -e mk_abs_path($ans) ) {
		return;
	}

	my $cmd = sprintf( "mkdir '%s'", mk_abs_path($ans) );
	system( $cmd );

	cmd_update_display();
}

sub calc_total_size
{

}

sub open_binary
{
	my $path = get_selected_path();
	system( "vim -b '$path'" );
}

sub find_file
{
	my $key_str = ReadLine::read_line("find file str=");
	if ( $key_str eq "" ) {
		return;
	}
	print( "\n" );


	my $vdir = "<find_list>";
	my @di_arr = ();
	my $cmd = "find $g_pwd -name '*$key_str*' 2>/dev/null";

	
	ReadLine::stty_load();
	open( my $fh, "$cmd |" ) or die("$!");
	while( my $line = <$fh> )
	{
		chomp( $line );
		my $b = basename($line);
		my $d = dirname($line);

		my $item_name = "";
		if ( $b =~ /$key_str/ ) {
			if    ( -l $line ) { $item_name .= "l "; }
			elsif ( -d $line ) { $item_name .= "d "; }
			else               { $item_name .= "f "; }
			$item_name .= $d;
			$item_name .= "/$`\e[1;35m$&\e[m$'";
		}

		my %di_info = ();
		$di_info{name} = $item_name;
		$di_info{type} = 'f';
		$di_info{jump} = $line;
		$di_info{real_path} = $line;
		push( @di_arr, \%di_info );
	}
	ReadLine::stty_unable();


	$di{$vdir} = \@di_arr;
	move_virtual( $vdir );
}

sub grep_file
{
	my $is_recursive = shift;
	my $key_str = "";

	if ( $is_recursive ) {
		$key_str = ReadLine::read_line("grep str(recursive)=");
	}
	else {
		$key_str = ReadLine::read_line("grep str(only current)=");
	}
	if ( $key_str eq "" ) {
		return;
	}
	print( "\n" );


	my $vdir = "<grep_list>";
	my @di_arr = ();
	my $cmd = "";
	if ( $is_recursive ) {
		$cmd = "grep --color=never -rnI '$key_str' $g_pwd";
	}
	else {
		$cmd = "grep --color=never -nI '$key_str' $g_pwd/*";
	}

	ReadLine::stty_load();
	open( my $fh, "$cmd |" ) or die("$!");
	while( my $line = <$fh> )
	{
		chomp( $line );
		my $path = "";
		my $lnumber = 0;
		my $hit = "";
		if ( $line =~ /^(.*):(\d+):(.*)/o )
		{
			$path = $1;
			$lnumber = $2;
			$hit = $3;
		}
		if ( $hit =~ /$key_str/ )
		{
			$hit = "[$`\e[1;35m$&\e[m$']";
		}
		my $fname = basename($path) . ':' . $lnumber;
		

		my %di_info = ();
		$di_info{name} = sprintf( "%-20s %s", $fname, $hit );
		$di_info{type} = 'f';
		$di_info{exec} = "vim -c $lnumber '$path'";
		$di_info{real_path} = $path;
		push( @di_arr, \%di_info );
	}
	ReadLine::stty_unable();


	$di{$vdir} = \@di_arr;
	move_virtual( $vdir );
}



# }}}

