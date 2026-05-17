package ReadLine;
use strict;
use POSIX qw(:termios_h);
use Encode;
use Time::HiRes qw(usleep);



my $g_termios = POSIX::Termios->new();
my $g_lflag_org;
my $g_vmin_org;
my $g_vtime_org;

my $g_stdin = fileno( STDIN );
my $g_stty_setting="";
$| = 1;

our ($g_term_height, $g_term_width) = get_term_size();
my $g_uname = `uname`;
chomp( $g_uname );



#==================================================
# キーマップ（raw → logical key）
#
# 方針:
#   - ESC系（ターミナルエスケープ）
#   - Ctrl系（1byte制御文字）
#
# normalize_key() で使用する統一テーブル
#==================================================
my %g_keymap = (

	"\e" => 'ESC',

#--------------------------------------------------
# Cursor Keys
#--------------------------------------------------

    # normal
    "\e[A" => 'UP',
    "\e[B" => 'DOWN',
    "\e[C" => 'RIGHT',
    "\e[D" => 'LEFT',

    # application mode
    "\eOA" => 'UP',
    "\eOB" => 'DOWN',
    "\eOC" => 'RIGHT',
    "\eOD" => 'LEFT',

#--------------------------------------------------
# Shift + Arrow
#--------------------------------------------------

    "\e[1;2A" => 'SHIFT_UP',
    "\e[1;2B" => 'SHIFT_DOWN',
    "\e[1;2C" => 'SHIFT_RIGHT',
    "\e[1;2D" => 'SHIFT_LEFT',

#--------------------------------------------------
# Ctrl + Arrow
#--------------------------------------------------

    "\e[1;5A" => 'CTRL_UP',
    "\e[1;5B" => 'CTRL_DOWN',
    "\e[1;5C" => 'CTRL_RIGHT',
    "\e[1;5D" => 'CTRL_LEFT',

#--------------------------------------------------
# Function Keys (F1-F4)
#--------------------------------------------------

    # SS3
    "\eOP" => 'F1',
    "\eOQ" => 'F2',
    "\eOR" => 'F3',
    "\eOS" => 'F4',

    # CSI
    "\e[11~" => 'F1',
    "\e[12~" => 'F2',
    "\e[13~" => 'F3',
    "\e[14~" => 'F4',

#--------------------------------------------------
# Function Keys (F5-F12)
#--------------------------------------------------

    "\e[15~" => 'F5',
    "\e[17~" => 'F6',
    "\e[18~" => 'F7',
    "\e[19~" => 'F8',
    "\e[20~" => 'F9',
    "\e[21~" => 'F10',
    "\e[23~" => 'F11',
    "\e[24~" => 'F12',

#--------------------------------------------------
# Shift + Function Keys
#--------------------------------------------------

    "\e[1;2P" => 'SHIFT_F1',
    "\e[1;2Q" => 'SHIFT_F2',
    "\e[1;2R" => 'SHIFT_F3',
    "\e[1;2S" => 'SHIFT_F4',

    "\e[15;2~" => 'SHIFT_F5',
    "\e[17;2~" => 'SHIFT_F6',
    "\e[18;2~" => 'SHIFT_F7',
    "\e[19;2~" => 'SHIFT_F8',
    "\e[20;2~" => 'SHIFT_F9',
    "\e[21;2~" => 'SHIFT_F10',
    "\e[23;2~" => 'SHIFT_F11',
    "\e[24;2~" => 'SHIFT_F12',

#--------------------------------------------------
# Ctrl + Function Keys
#--------------------------------------------------

    "\e[1;5P" => 'CTRL_F1',
    "\e[1;5Q" => 'CTRL_F2',
    "\e[1;5R" => 'CTRL_F3',
    "\e[1;5S" => 'CTRL_F4',

    "\e[15;5~" => 'CTRL_F5',
    "\e[17;5~" => 'CTRL_F6',
    "\e[18;5~" => 'CTRL_F7',
    "\e[19;5~" => 'CTRL_F8',
    "\e[20;5~" => 'CTRL_F9',
    "\e[21;5~" => 'CTRL_F10',
    "\e[23;5~" => 'CTRL_F11',
    "\e[24;5~" => 'CTRL_F12',

#--------------------------------------------------
# Misc Keys
#--------------------------------------------------

    "\e[3~" => 'DELETE',
    "\e[2~" => 'INSERT',
    "\e[5~" => 'PAGE_UP',
    "\e[6~" => 'PAGE_DOWN',

    "\e[H" => 'HOME',
    "\e[F" => 'END',

#--------------------------------------------------
# Ctrl keys (1 byte control chars)
#--------------------------------------------------

    "\x01" => 'CTRL_A',
    "\x02" => 'CTRL_B',
    "\x03" => 'CTRL_C',
    "\x04" => 'CTRL_D',
    "\x05" => 'CTRL_E',
    "\x06" => 'CTRL_F',
    "\x07" => 'CTRL_G',
    "\x08" => 'BACKSPACE',
    "\x09" => 'TAB',
    "\x0a" => 'ENTER',
    "\x0d" => 'ENTER',
    "\x0e" => 'CTRL_N',
    "\x0f" => 'CTRL_O',
    "\x10" => 'CTRL_P',
    "\x11" => 'CTRL_Q',
    "\x12" => 'CTRL_R',
    "\x13" => 'CTRL_S',
    "\x14" => 'CTRL_T',
    "\x15" => 'CTRL_U',
    "\x16" => 'CTRL_V',
    "\x17" => 'CTRL_W',
    "\x18" => 'CTRL_X',
    "\x19" => 'CTRL_Y',
    "\x1a" => 'CTRL_Z',
);

my %g_prefix_map;

_build_prefix_map();



if ( $ARGV[0] >= 1 )
{
	tty_save();
	tty_set_raw();

	if ( $ARGV[0] == 1 ) {
		my $str = read_line("input=", "");
		printf( "\nstr=[%s]\n", $str );
	}
	elsif ( $ARGV[0] == 2 ) {
		while( 1 )
		{
			my $str = wait_key();
			printf( "str=[%s]\n", $str );

			if ( $str eq '^[' ) {
				last;
			}
		}
	}
	elsif ( $ARGV[0] == 3 ) {
		while( 1 )
		{
#			my $str = "\e";
			my $str = wait_key2();
#			printf "%v02X\n", $str;
			printf( "str=[%s]\n", normalize_key($str) );

			if ( $str eq 'z' ) {
				last;
			}
		}
	}

	tty_restore();
	exit(0);
}



sub stty_save
{
	$g_stty_setting=`stty -g`;
}

sub stty_unable
{
	`stty discard undef`;
	`stty eof undef`;
	`stty eol undef`;
	`stty eol2 undef`;
	`stty erase undef`;
	`stty intr undef`;
	`stty kill undef`;
	`stty lnext undef`;
	`stty quit undef`;
	`stty start undef`;
	`stty stop undef`;
	`stty susp undef`;
	`stty werase undef`;

	if ( $g_uname eq "Darwin" )
	{
		`stty dsusp undef`;
		`stty reprint undef`;
		`stty status undef`;
	}

	if ( $g_uname eq "Linux" )
	{
		`stty swtch undef`;
		`stty rprnt undef`;
	}

}

sub stty_load
{
	`stty $g_stty_setting`;
}

sub tty_save
{
	# tty設定を保存しておく
	# アプリ起動時1回だけ呼ぶ
	
	$g_termios->getattr($g_stdin);
	$g_lflag_org = $g_termios->getlflag();
	$g_vmin_org  = $g_termios->getcc(VMIN);
	$g_vtime_org = $g_termios->getcc(VTIME);
}

sub tty_set_raw
{
	# 一文字入力待ち状態にする 
	# アプリ初期化時呼ぶ 
	# 外部アプリ(vimとか)から復帰した時にも呼ぶ

	# raw 設定のlflag作成
	my $lflag_raw = $g_lflag_org;
	$lflag_raw &= ~ICANON;
	$lflag_raw &= ~ECHO;
	$lflag_raw &= ~ECHOK;

	# tty 設定
	$g_termios->setlflag( $lflag_raw );
	$g_termios->setcc( VMIN, 1 );
	$g_termios->setcc( VTIME, 0 );
	$g_termios->setattr( $g_stdin, TCSANOW );

}

sub tty_restore
{
	# ttyを起動時の状態に戻す 
	# アプリの終了時に呼ぶ

	$g_termios->setlflag( $g_lflag_org );
	$g_termios->setcc( VMIN, $g_vmin_org );
	$g_termios->setcc( VTIME, $g_vtime_org );
	$g_termios->setattr($g_stdin, TCSANOW);

#	print "\e[?25h";
}

sub wait_key
{
	my $ret;

#	if ( !$g_termios_init )
#	{
#		$g_termios->getattr( $g_stdin );

#		$g_lflag_org = $g_termios->getlflag();
#		$g_cc_VMIN   = $g_termios->getcc(VMIN);
#		$g_cc_VTIME  = $g_termios->getcc(VTIME);

#		my $lflag_wait = $g_lflag_org;
#		$lflag_wait &= ~ICANON;
#		$lflag_wait &= ~ECHO;
#		$lflag_wait &= ~ECHOK;

#		$g_termios->setlflag( $lflag_wait );
#		$g_termios->setcc( VMIN, 1 );
#		$g_termios->setcc( VTIME, 0 );
#		$g_termios->setattr( $g_stdin, TCSANOW );

#		$g_termios_init = 1;
#	}

	my $len = sysread( STDIN, my $input, 256 );
	my $c = substr( $input, 0, 1 );
	my $c_sz = unpack( 'C*', $c );
#    printf( "c=[%d] c_sz=[%s] len=[%d]\n", $c, $c_sz, $len );
	if ( $c_sz eq '27' ) {
#		usleep(20000); # 20ms wait

#		my $rest = '';
#		my $r = sysread(STDIN, $rest, 1 );
#		$ret = '^[' . $rest;

		my $seq = $input;

		if ( $len == 1 )
		{
			my $rin = '';
			vec( $rin, fileno(STDIN), 1 ) = 1;
			if ( select( $rin, undef, undef, 0.01 ) )
			{
				my $buf = '';
				sysread( STDIN, $buf, 10 );
				$seq .= $buf;
			}
		}

		$ret = '^[' . substr( $seq, 1, $len );
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
		$ret = "d$c_sz";
	}
	else {
		$ret = $input;
	}

#	$g_termios->setlflag($g_lflag_org);
#	$g_termios->setcc( VMIN, $g_cc_VMIN );
#	$g_termios->setcc( VTIME, $g_cc_VTIME );
#	$g_termios->setattr( $g_stdin, TCSANOW );
	return $ret;

}



#==================================================
# prefix map生成
#==================================================
sub _build_prefix_map {

    %g_prefix_map = ();

    for my $seq (keys %g_keymap) {

        #------------------------------------------
        # 自分自身は除外
        #------------------------------------------
        for my $i (1 .. length($seq) - 1) {

            my $prefix =
                substr($seq, 0, $i);

            $g_prefix_map{$prefix} = 1;
        }
    }
}

#==========================================================
# _has_os_input()
#
# stdin に入力があるか確認。
#
# timeout:
#   0     = non blocking
#   0.01  = 10ms wait
#==========================================================
sub _has_os_input {

    my ($timeout) = @_;

    my $rin = '';

    vec($rin, fileno(STDIN), 1) = 1;

    return select($rin, undef, undef, $timeout);
}

#==========================================================
# wait_key_raw()
#
# raw key sequence を返す。
#
# 戻り値例:
#
#   "a"
#   "\e[A"
#   "\x03"
#
# 特徴:
#
#   - sysread(1) ベース
#   - ESC時のみ追加読み込み
#   - 完全一致のみ採用
#   - 最大キー長で打ち切り
#==========================================================
sub wait_key_raw {

    my $seq = '';

    while( 1 ) {

        #------------------------------------------
        # 1byte読む
        #------------------------------------------
        my $ret =
            sysread(STDIN, my $ch, 1);

        #------------------------------------------
        # EOF / error
        #------------------------------------------
        if( !defined($ret) || $ret <= 0 ) {

            return undef;
        }

        $seq .= $ch;

        #------------------------------------------
        # 完全一致？
        #------------------------------------------
        my $is_complete =
            exists($g_keymap{$seq});

        #------------------------------------------
        # まだ続きの可能性？
        #------------------------------------------
        my $has_prefix =
            exists($g_prefix_map{$seq});

        #------------------------------------------
        # 完全一致
        # ＋
        # 続き無し
        #
        # → 即確定
        #------------------------------------------
        if( $is_complete && !$has_prefix ) {

            return $seq;
        }

        #------------------------------------------
        # 完全一致
        # ＋
        # 続きあり
        #
        # → 少し待つ
        #------------------------------------------
        if( $is_complete && $has_prefix ) {
        
        	# ESC単体かどうか確定するために入力がまだあるか待つ
			# 0.01 → 速いが危険
			# 0.03 → ギリ
			# 0.05 → 標準
			# 0.1 → 安定
            if( !_has_os_input(0.03) ) {

                return $seq;
            }

            next;
        }

        #------------------------------------------
        # 未完成sequence
        #
        # → 続き待ち
        #------------------------------------------
        if( $has_prefix ) {

            next;
        }

        #------------------------------------------
        # 通常1文字
        #------------------------------------------
        if( length($seq) == 1 ) {

            return $seq;
        }

        #------------------------------------------
        # 不明sequence
        #------------------------------------------
        return $seq;
    }
}

#==========================================================
# normalize_key()
#
# raw sequence -> normalized key
#
# 例:
#
#   "\e[A" -> "UP"
#   "\x01" -> "CTRL_A"
#==========================================================
sub normalize_key {

    my ($raw) = @_;

    if( !defined($raw) ) {

        return undef;
    }

    if( exists($g_keymap{$raw}) ) {

        return $g_keymap{$raw};
    }

    #----------------------------------------------
    # Ctrl+A ～ Ctrl+Z
    #----------------------------------------------
    my $ord = ord($raw);

    if( $ord >= 1 && $ord <= 26 ) {

        return 'CTRL+' .
            chr(ord('A') + $ord - 1);
    }

    return $raw;
}

#==========================================================
# has_input()
#
# queueに残入力があるか。
#==========================================================
sub has_input {

    return _has_os_input(0);
}

#==========================================================
# drain_input()
#
# stdin側に溜まっている入力を全取得。
#
# 非ブロッキング。
#
# 戻り値:
#   raw key sequence の配列
#==========================================================
sub drain_input {

    my @list;

    while( has_input() ) {

        my $raw = wait_key_raw();

        if( !defined($raw) ) {

            last;
        }

        push @list, normalize_key($raw);
    }

    return \@list;
}

#==========================================================
# キーマップ版 wait_key
# 特殊なキーは キーマップ の定義が返る。
# それ以外は入力された文字がそのまま返る
#==========================================================
sub wait_key2 {

    my $raw = wait_key_raw();

    if( !defined($raw) ) {

        return undef;
    }

    return normalize_key($raw);
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
