package ReadLine;
use strict;
use POSIX qw(:termios_h);
use Encode;


my $g_termios = POSIX::Termios->new();
my $g_stdin = fileno( STDIN );
my $g_stty_setting="";
$| = 1;

our ($g_term_height, $g_term_width) = get_term_size();
my $g_uname = `uname`;
chomp( $g_uname );

#----- sample
#stty_save();
#stty_unable();

#my $str = read_line("input=","あaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaw");
#printf( "str=[%s]\n", $str );

#stty_load();

#exit(0);




sub stty_save
{
	$g_stty_setting=`stty -g`;
}

sub stty_unable
{
	`stty discard undef`;
	`stty dsusp undef`;
	`stty eof undef`;
	`stty eol undef`;
	`stty eol2 undef`;
	`stty erase undef`;
	`stty intr undef`;
	`stty kill undef`;
	`stty lnext undef`;
	`stty quit undef`;
	`stty reprint undef`;
	`stty start undef`;
	`stty status undef`;
	`stty stop undef`;
	`stty susp undef`;
	`stty werase undef`;
}

sub stty_load
{
	`stty $g_stty_setting`;
}

sub wait_key
{
	my $ret;

	$g_termios->getattr( $g_stdin );

	my $lflag_org = $g_termios->getlflag();
	my $cc_VMIN   = $g_termios->getcc(VMIN);
	my $cc_VTIME  = $g_termios->getcc(VTIME);

	my $lflag_wait = $lflag_org;
	$lflag_wait &= ~ICANON;
	$lflag_wait &= ~ECHO;
	$lflag_wait &= ~ECHOK;

	$g_termios->setlflag( $lflag_wait );
	$g_termios->setcc( VMIN, 1 );
	$g_termios->setcc( VTIME, 0 );
	$g_termios->setattr( $g_stdin, TCSANOW );

	my $len = sysread( STDIN, my $input, 256 );
	my $c = substr( $input, 0, 1 );
	my $c_sz = unpack( 'C*', $c );
#    printf( "c=[%d] c_sz=[%s] len=[%d]\n", $c, $c_sz, $len );
	if ( $c_sz eq '27' ) {
		$ret = '^[' . substr( $input, 1, $len );
	}
	elsif ( $c_sz eq '8' ) {
		$ret = '^H';
	}
	elsif ( $c_sz eq '127' ) {
		$ret = '^[DEL';
	}
	elsif ( int($c_sz) == 10 ) {
		$ret = "\n";
	}
	elsif ( int($c_sz) == 9 ) {
		$ret = "\t";
	}
	elsif ( int($c_sz) < 27 ) {
		$ret = $c_sz;
	}
	else {
		$ret = $input;
	}

	$g_termios->setlflag($lflag_org);
	$g_termios->setcc( VMIN, $cc_VMIN );
	$g_termios->setcc( VTIME, $cc_VTIME );
	$g_termios->setattr( $g_stdin, TCSANOW );
	return $ret;

}

my $TIOCGWINSZ = 1074295912;

sub get_term_size
{
#	ioctl( STDOUT, $TIOCGWINSZ, my $winsize );
#	my ($row, $col, $xpixel, $ypixel) = unpack ("S4", $winsize);
#	return ( $row, $col);

	my $row = `tput lines`;
	my $col = `tput cols`;
	chomp( $row );
	chomp( $col );
	return (int($row), int($col));
}

sub update_term_size
{
	($g_term_height, $g_term_width) = get_term_size();
}

my $g_total_LF_prev = 0;
sub read_line
{
	my $title = shift;
	my $initial_text = shift;

	my @tistr = split( //, decode('UTF-8', $title) );
	my $title_scr_len = 0;
	foreach my $c (@tistr) {
		$title_scr_len += scrlen($c);
	}

	my @instr = split( //, decode('UTF-8', $initial_text) );
	my $abs_len = scalar( @instr );
	my $abs_loc = $abs_len;

	printf( "%s\e[K", $title );
	draw_scr( \@instr, 0, $abs_loc, $title_scr_len );

	while( 1 )
	{
		my $key = wait_key();

		if ( $key eq "\n" ) { last; }
		elsif( $key eq '^[' ) {
			$g_total_LF_prev = 0;
			return undef;
		}
		# Left
		elsif ( $key eq '^[[D' )
		{
			$abs_loc --;
			if ( $abs_loc < 0 ) {
				$abs_loc = 0;
			}
			else {
				my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev) = calc_scr( \@instr, $abs_loc+1, $title_scr_len );
				if ( $is_LF ) {
					move_cursor( -1, -10000 );
				}
				else {
					move_cursor( 0, -10000 );
				}
				move_cursor( 0, $scr_loc_prev );
			}
		}
		# Shift+Left
		elsif ( $key eq '^[[1;2D' )
		{
			my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev) = calc_scr( \@instr, $abs_loc, $title_scr_len );
			$abs_loc = 0;
			move_cursor( - $total_LF, -10000 );
			move_cursor( 0, $title_scr_len );
		}
		# Right
		elsif ( $key eq '^[[C' )
		{
			$abs_loc ++;
			if ( $abs_loc > $abs_len ) {
				$abs_loc = $abs_len;
			}
			else {
				my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev) = calc_scr( \@instr, $abs_loc, $title_scr_len );
				if ( $is_LF ) {
					move_cursor( 1, -10000 );
				}
				else {
					move_cursor( 0, -10000 );
				}
				move_cursor( 0, $scr_loc );
			}
		}
		# Shift+Right
		elsif( $key eq '^[[1;2C' )
		{
			my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev) = calc_scr( \@instr, $abs_loc, $title_scr_len );
			$abs_loc = $abs_len;
			my ($is_LF2, $total_LF2, $scr_loc2, $scr_loc_prev2) = calc_scr( \@instr, $abs_loc, $title_scr_len );
			move_cursor( ($total_LF2 - $total_LF), -10000 );
			move_cursor( 0, $scr_loc2 );
		}
		# BackSpace
		elsif( $key eq '^[DEL' )
		{
			$abs_loc --;
			if ( $abs_loc < 0 ) {
				$abs_loc = 0;
			}
			else {
				my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev, $is_remainder, $is_remainder_prev) = calc_scr( \@instr, $abs_loc+1, $title_scr_len );
				if ( $is_LF ) {
					move_cursor( -1, -10000 );
				}
				else {
					move_cursor( 0, -10000 );
				}
				move_cursor( 0, $scr_loc_prev );
				splice( @instr, $abs_loc, 1 );
				$abs_len --;
				if ( $is_remainder_prev ) {
					move_cursor( -1, -10000 );
					move_cursor( 0, $g_term_width );
				}
				draw_scr( \@instr, $abs_loc, $abs_loc, $title_scr_len );
			}
		}
		# Delete
		elsif ( $key eq '^[[3~' )
		{
			my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev, $is_remainder, $is_remainder_prev) = calc_scr( \@instr, $abs_loc, $title_scr_len );
			splice( @instr, $abs_loc, 1 );
			$abs_len --;
			if ( $is_remainder ) {
				move_cursor( -1, -10000 );
				move_cursor( 0, $g_term_width );
			}
			draw_scr( \@instr, $abs_loc, $abs_loc, $title_scr_len );
		}
		# Other
		elsif ( $key !~ /\^\[/o )
		{
			if ( scrlen($instr[$abs_loc]) > 1 )
			{
				my ($is_LF, $total_LF, $scr_loc, $scr_loc_prev, $is_remainder) = calc_scr( \@instr, $abs_loc, $title_scr_len );
				if ( $is_remainder ) {
					move_cursor( -1, -10000 );
					move_cursor( 0, $g_term_width );
				}
			}

			my @add_str = split( //, decode('UTF-8', $key) );
			my $add_len = scalar( @add_str );
			splice( @instr, $abs_loc, 0, @add_str );
			$abs_loc += $add_len;
			$abs_len += $add_len;
			draw_scr( \@instr, $abs_loc - $add_len, $abs_loc, $title_scr_len );
		}
	}

	$g_total_LF_prev = 0;
	return encode('UTF-8', join("",@instr));
}

sub move_cursor
{
	my $row = shift;
	my $col = shift;
	my $move_str = "";

	if ( $row > 0 ) {
		$move_str .= "\e[${row}B";
	}
	elsif ( $row < 0 ) {
		$move_str .= sprintf( "\e[%dA", abs($row) );
	}

	if ( $col > 0 ) {
		$move_str .= "\e[${col}C";
	}
	elsif ( $col < 0 ) {
		$move_str .= sprintf( "\e[%dD", abs($col) );
	}

	print( $move_str );
}

sub scrlen
{
	my $array_char = shift;
	if ( length(encode('UTF-8', $array_char)) <= 1 ) {
		return 1;
	}
	else {
		return 2;
	}
}

sub calc_scr
{
	my $array_str = shift;
	my $len = shift;
	my $title_len = shift;

	my $is_LF = 0;
	my $total_LF = 0;
	my $total_scr_width = $title_len;
	my $total_scr_width_prev = 0;
	my $char_len;
	my $char_len_next;
	my $is_remainder = 0;
	my $is_remainder_prev = 0;

	for ( my $i=0; $i<$len; $i++ )
	{
		if ( !defined($array_str->[$i]) ) { last; }
		$char_len = scrlen( $array_str->[$i] );
		$char_len_next = scrlen( $array_str->[$i+1] );
		
		$total_scr_width_prev = $total_scr_width;
		$total_scr_width += $char_len;

		if ( $is_LF == 0 && ($total_scr_width+$char_len_next) > $g_term_width )
		{
			$is_remainder_prev = $is_remainder;
			if ( $total_scr_width == ($g_term_width-1) ) {
				$is_remainder = 1;
			}

			$is_LF = 1;
			$total_scr_width = 0;
			$total_LF ++;
		}
		else
		{
			$is_LF = 0;
			$is_remainder_prev = $is_remainder;
			$is_remainder = 0;
		}
	}

	return ($is_LF, $total_LF, $total_scr_width, $total_scr_width_prev, $is_remainder, $is_remainder_prev);
}

sub draw_scr
{
	my $array_str = shift;
	my $loc = shift;
	my $loc_add = shift;
	my $title_len = shift;

	my $len = scalar( @{$array_str} );

	my $is_LF = 0;
	my $total_LF = 0;
	my $total_scr_width = $title_len;
	my $total_scr_width_prev = 0;
	my $char_len;
	my $char_len_next;
	my $total_LF_back = 0;
	my $total_scr_width_back = 0;
	my $draw_buf = "";

	# 1
	for( my $i=0; $i<$loc; $i++ )
	{
		if ( !defined($array_str->[$i]) ) { last; }
		
		$char_len = scrlen( $array_str->[$i] );
		$char_len_next = scrlen( $array_str->[$i+1] );
		$total_scr_width_prev = $total_scr_width;
		$total_scr_width += $char_len;
		if ( $is_LF == 0 && ($total_scr_width+$char_len_next) > $g_term_width )
		{
			# for mac -----
			if ( $g_uname eq 'Darwin' )
			{
				if ( $i==$loc-1 &&
					 $char_len_next == 2 &&
					 ($total_scr_width+$char_len_next) == ($g_term_width+1) ) {
					$draw_buf .= "\n";
				}
			}
			#-------

			$is_LF = 1;
			$total_scr_width = 0;
			$total_LF ++;
		}
		else
		{
			$is_LF = 0;
		}
	}

	$draw_buf .= "\e[K";

	# 2
	for( my $i=$loc; $i<$loc_add; $i++ )
	{
		if ( !defined($array_str->[$i]) ) { last; }

		$char_len = scrlen( $array_str->[$i] );
		$char_len_next = scrlen( $array_str->[$i+1] );

		$total_scr_width_prev = $total_scr_width;
		$total_scr_width += $char_len;

		if ( $is_LF == 0 && ($total_scr_width + $char_len_next > $g_term_width) )
		{
			$is_LF = 1;
			$total_scr_width = 0;
			$total_LF ++;
			$draw_buf .= encode('UTF-8', $array_str->[$i]) . "\n\e[K";
		}
		else
		{
			$is_LF = 0;
			$draw_buf .= encode('UTF-8', $array_str->[$i]);
		}
	}

	# 3
	$total_scr_width_back = $total_scr_width;

	# 4
	for( my $i = $loc_add; $i<$len; $i++ )
	{
		if ( !defined($array_str->[$i]) ) { last; }

		$char_len = scrlen( $array_str->[$i] );
		$char_len_next = scrlen( $array_str->[$i+1] );

		$total_scr_width_prev = $total_scr_width;
		$total_scr_width += $char_len;

		if ( $is_LF == 0 && ($total_scr_width + $char_len_next) > $g_term_width )
		{
			$is_LF = 1;
			$total_scr_width = 0;
			$total_LF ++;
			$total_LF_back ++;
			$draw_buf .= encode('UTF-8',$array_str->[$i]) . "\n\e[K"
		}
		else
		{
			$is_LF = 0;
			$draw_buf .= encode('UTF-8', $array_str->[$i]);
		}
	}

	# 5
	if ( $is_LF == 0 && ($total_scr_width+1) > $g_term_width )
	{
		$is_LF = 1;
		$total_scr_width = 0;
		$total_LF ++;
		$total_LF_back ++;
		$total_scr_width_back = 1;
		$draw_buf .= "\n\e[K";
	}
	else
	{
		$is_LF = 0;
	}

	# 6
	if ( $total_LF < $g_total_LF_prev )
	{
		my $del_line = $g_total_LF_prev - $total_LF;

		for( my $i=0; $i<$del_line; $i++ ) {
			$draw_buf .= "\n\e[2K";
			$total_LF_back ++;
		}
	}
	$g_total_LF_prev = $total_LF;

	print( $draw_buf );

	# 7
	if ( $is_LF == 0 && $total_LF_back > 0 )
	{
		if ( $total_scr_width_back >= 1 ) {
			move_cursor( - $total_LF_back, -10000 );
			move_cursor( 0, $total_scr_width_back );
		}
		else {
			move_cursor( - $total_LF_back, -10000 );
		}
	}
	else
	{
		if ( $total_scr_width_back >= 1 ) {
			move_cursor( 0, -10000 );
			move_cursor( 0, $total_scr_width_back );
		}
		else {
			move_cursor( 0, -10000 );
		}
	}
}


1;
