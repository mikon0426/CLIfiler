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

# bracketed paste
my $BRACKETED_PASTE_ON  = "\e[?2004h";
my $BRACKETED_PASTE_OFF = "\e[?2004l";
my $PASTE_BEGIN = "\e[200~";
my $PASTE_END   = "\e[201~";

my $g_paste_buffer   = '';



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
    "\x7F"  => 'DELETE',
    "\e[2~" => 'INSERT',
    "\e[5~" => 'PAGE_UP',
    "\e[6~" => 'PAGE_DOWN',

    "\e[H" => 'HOME',
    "\e[F" => 'END',
    "\e[1~" => 'HOME',
    "\e[4~" => 'END',

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
			printf( "str=[%s %x]\n", normalize_key($str), unpack('C*', $str) );

			if ( $str eq 'PASTE' ) {
				my $pdata = drain_paste();
				printf("pdata=[%s]\n", $pdata)
			}
			if ( $str eq 'z' ) {
				last;
			}
		}
	}

	tty_restore();
	exit(0);
}



#sub stty_save
#{
#	$g_stty_setting=`stty -g`;
#}

#sub stty_unable
#{
#	`stty discard undef`;
#	`stty eof undef`;
#	`stty eol undef`;
#	`stty eol2 undef`;
#	`stty erase undef`;
#	`stty intr undef`;
#	`stty kill undef`;
#	`stty lnext undef`;
#	`stty quit undef`;
#	`stty start undef`;
#	`stty stop undef`;
#	`stty susp undef`;
#	`stty werase undef`;
#
#	if ( $g_uname eq "Darwin" )
#	{
#		`stty dsusp undef`;
#		`stty reprint undef`;
#		`stty status undef`;
#	}
#
#	if ( $g_uname eq "Linux" )
#	{
#		`stty swtch undef`;
#		`stty rprnt undef`;
#	}
#
#}

#sub stty_load
#{
#	`stty $g_stty_setting`;
#}

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
	
	# enable bracketed paste mode
	print STDOUT $BRACKETED_PASTE_ON;
	STDOUT->flush();

}

sub tty_restore
{
	# ttyを起動時の状態に戻す 
	# アプリの終了時に呼ぶ

	$g_termios->setlflag( $g_lflag_org );
	$g_termios->setcc( VMIN, $g_vmin_org );
	$g_termios->setcc( VTIME, $g_vtime_org );
	$g_termios->setattr($g_stdin, TCSANOW);
	
	# disable bracketed paste mode
	print STDOUT $BRACKETED_PASTE_OFF;
	STDOUT->flush();

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

#===========================================================
# wait_key_raw()
#
# 説明:
#   STDINから1イベントを取得する最下位入力レイヤ。
#
#   ESC起点の入力については各プロトコル解析関数へ委譲し、
#   結果をそのままイベントとして返す。
#
#   本関数の責務は「分岐のみ」であり、
#   解析・解釈は行わない。
#
# 戻り値:
#   undef   : EOF / read error
#   'PASTE' : pasteイベント
#   other   : CSI / SS3 / UTF8 / ASCII / ESC単体
#
#===========================================================
sub wait_key_raw {

    while(1) {

        #---------------------------------------------------
        # 1byte取得
        #---------------------------------------------------
        my $buf = '';
        my $ret = sysread(STDIN, $buf, 1);

        if( !defined($ret) || $ret <= 0 ) {
            return undef;
        }

        my $c = $buf;
        my $o = ord($c);

        #===================================================
        # ASCII fast path
        #===================================================
        if( $o < 0x80 ) {

            #------------------------------------------------
            # ESCシーケンス処理
            #------------------------------------------------
            if( $c eq "\e" ) {

                #-------------------------------------------
                # 入力が来なければESC単体として確定
				# 後続入力待ち（timeout内に入力が来るかを確認する）
				# ESC単体かどうか確定するために入力がまだあるか待つ
				# 0.01 → 速いが危険
				# 0.03 → ギリ
				# 0.05 → 標準
				# 0.1 → 安定
                #-------------------------------------------
                if( !_has_os_input(0.03) ) {

                    # ESC単体確定
                    return "\e";
                }
                
                # まずESC後の最初の1byteだけ確認
                my $next = '';
                my $r = sysread(STDIN, $next, 1);

                if( !defined($r) || $r <= 0 ) {
                    return "\e";
                }

                my $seq = "\e" . $next;

                #================================================
                # CSI系（ESC [）
                #================================================
                if( $next eq "[" ) {

                    # CSI完全読み込み
                    my $csi = csi_read($seq, 0.5);

                    if( !defined($csi) ) {
                        return undef;
                    }

                    #--------------------------------------------
                    # PASTE BEGIN判定（csi_read結果ベース）
                    #--------------------------------------------
                    if( $csi eq 'PASTE_BEGIN' ) {

                        my $recv = paste_read(
                            1024*1024,   # max_byte
                            3,           # total_timeout
                            0.5          # io_timeout
                        );

                        if( !defined($recv) ) {
                            return undef;
                        }

                        return 'PASTE';
                    }

                    return $csi;
                }

                #================================================
                # SS3（ESC O）
                #================================================
                if( $next eq "O" ) {

                    my $ss3 = ss3_read($seq, 0.5);

                    if( !defined($ss3) ) {
                        return undef;
                    }

                    return $ss3;
                }

                #================================================
                # ESC単体 or 未知シーケンス
                #================================================
                return $seq;
            }

            #------------------------------------------------
            # ASCII通常文字
            #------------------------------------------------
            return $c;
        }

        #===================================================
        # UTF-8
        #===================================================
        my $utf8 = utf8_read($c, 0.5);

        if( !defined($utf8) ) {
            return undef;
        }

        return $utf8;
    }
}

#===========================================================
# csi_read()
#
# 説明:
#   CSI sequence を最後まで読み込む。
#
# 開始条件:
#   ESC [ を既に読み込み済みであること。
#
# 処理内容:
#   CSI終端文字が現れるまで1byteずつ追加取得する。
#
#   CSI終端文字:
#       0x40 (@)
#       ～
#       0x7e (~)
#
#   sequence完成後、
#   keymapに存在するか確認する。
#
#   未知CSI sequenceの場合は
#   warnを出してundefを返す。
#
# timeout:
#   各追加読み込み前に
#   _has_os_input() により監視する。
#
# 引数:
#   $seq
#       初期sequence。
#       通常は "\e["。
#
#   $timeout
#       追加入力待ちtimeout(sec)
#
# return:
#   undef         : timeout / read error / unknown sequence
#   'PASTE_BEGIN' : Paste開始用のタグだった
#   other         : 完成したCSI sequence
#   
#===========================================================
sub csi_read {

	my ($seq, $timeout) = @_;
	my $max_len = 100; # 最大CSI byte数(CSI終端文字が欠損していた場合の暴走防止対策)


    while(1) {

        #---------------------------------------------------
        # max length check
        #---------------------------------------------------
        if( length($seq) >= $max_len ) {

            warn sprintf(
                "csi_read(): sequence too long (%d byte)\n",
                $max_len
            );

            return undef;
        }

        #---------------------------------------------------
        # wait next input
        #---------------------------------------------------
        if( !_has_os_input($timeout) ) {

            warn "csi_read(): timeout\n";

            return undef;
        }

        my $buf = '';

        my $ret = sysread(STDIN, $buf, 1);

        #---------------------------------------------------
        # stdin closed / read error
        #---------------------------------------------------
        if( !defined($ret) || $ret <= 0 ) {

            warn "csi_read(): sysread failed\n";

            return undef;
        }

        $seq .= $buf;

        my $o = ord($buf);

        #===================================================
        # CSI final byte check
        #===================================================
        #
        # CSI終端文字:
        #   0x40 (@)
        #     ～
        #   0x7E (~)
        #
        #===================================================
        if( $o >= 0x40 && $o <= 0x7E ) {

            #-----------------------------------------------
            # Bracketed Paste Begin
            #-----------------------------------------------
            if( $seq eq $PASTE_BEGIN ) {

                return 'PASTE_BEGIN';
            }

            #-----------------------------------------------
            # known CSI sequence
            #-----------------------------------------------
            if( exists($g_keymap{$seq}) ) {

                return $seq;
            }

            #-----------------------------------------------
            # unknown CSI sequence
            #-----------------------------------------------
            warn sprintf(
                "csi_read(): unknown CSI sequence [%v02X]\n",
                $seq
            );

            return undef;
        }
    }
}

#===========================================================
# ss3_read()
#
# 説明:
#   SS3 sequence を最後まで読み込む。
#
# 開始条件:
#   ESC O を既に読み込み済みであること。
#
# 処理内容:
#   SS3 sequence の最後の1byteを取得し、
#   sequenceを完成させる。
#
#   sequence完成後、
#   keymapに存在するか確認する。
#
#   未知SS3 sequenceの場合は
#   warnを出してundefを返す。
#
# SS3仕様:
#   ESC O <final>
#
#   final は通常1byte固定。
#
# timeout:
#   追加読み込み前に
#   _has_os_input() により監視する。
#
# 引数:
#   $seq
#       初期sequence。
#       通常は "\eO"。
#
#   $timeout
#       追加入力待ちtimeout(sec)
#
# return:
#   undef : timeout / read error / unknown sequence
#   other : 完成したSS3 sequence
#===========================================================
sub ss3_read {

    my ($seq, $timeout) = @_;

    #---------------------------------------------------
    # 後続入力待ち
    #---------------------------------------------------
    if( !_has_os_input($timeout) ) {

        warn "ss3_read(): timeout\n";

        return undef;
    }

    my $buf = '';

    my $ret = sysread(STDIN, $buf, 1);

    #---------------------------------------------------
    # stdin切断またはread失敗
    #---------------------------------------------------
    if( !defined($ret) || $ret <= 0 ) {

        warn "ss3_read(): sysread failed\n";

        return undef;
    }

    $seq .= $buf;

    #===================================================
    # known SS3 sequence
    #===================================================
    if( exists($g_keymap{$seq}) ) {

        return $seq;
    }

    #===================================================
    # unknown SS3 sequence
    #===================================================
    warn sprintf(
        "ss3_read(): unknown SS3 sequence [%v02X]\n",
        $seq
    );

    return undef;
}

#===========================================================
# paste_read()
#
# Bracketed Pasteデータ読み込み
#
# 引数:
#   $total_timeout
#       全体タイムアウト(sec)
#
#   $io_timeout
#       _has_os_input() に渡す待ち時間(sec)
#       例: 0.01〜0.5
#
# return:
#   success : 今回取得したpaste byte数
#   failed  : undef
#
# note:
#   ・pasteデータは $g_paste_buffer に蓄積される
#   ・PASTE_END はbufferに含めない
#   ・異常時は paste_cancel() によりrollbackされる
#===========================================================
sub paste_read {

    my ($total_timeout, $io_timeout) = @_;

    my $start_time = time();

    my $old_len = length($g_paste_buffer);

    my $tail_buffer = '';

    my $recv_size = 0;

    while(1) {

        #---------------------------------------------------
        # total timeout check
        #---------------------------------------------------
        if( (time() - $start_time) >= $total_timeout ) {

            warn "paste_read(): total timeout\n";

            paste_cancel( $old_len, $tail_buffer, $io_timeout );

            return undef;
        }

        #---------------------------------------------------
        # wait input
        #---------------------------------------------------
        if( !_has_os_input($io_timeout) ) {

            next;
        }

        my $buf = '';

        my $ret = sysread(STDIN, $buf, 1);

        #---------------------------------------------------
        # read error
        #---------------------------------------------------
        if( !defined($ret) || $ret <= 0 ) {

            warn "paste_read(): sysread failed\n";

            paste_cancel( $old_len, $tail_buffer, $io_timeout );

            return undef;
        }

        #---------------------------------------------------
        # append paste buffer
        #---------------------------------------------------
        $g_paste_buffer .= $buf;

        $recv_size += length($buf);

        #---------------------------------------------------
        # update tail buffer
        #---------------------------------------------------
        $tail_buffer .= $buf;

        if(
            length($tail_buffer)
            > length($PASTE_END)
        ) {
            $tail_buffer = substr(
                $tail_buffer,
                -length($PASTE_END)
            );
        }

        #===================================================
        # PASTE_END check
        #===================================================
        if( $tail_buffer eq $PASTE_END ) {

            #-----------------------------------------------
            # remove PASTE_END
            #-----------------------------------------------
            substr(
                $g_paste_buffer,
                -length($PASTE_END)
            ) = '';

            $recv_size -= length($PASTE_END);

            return $recv_size;
        }
    }
}

#===========================================================
# paste_cancel()
#
# Bracketed Paste異常終了時の復旧処理
#
# 処理内容:
#   1. paste buffer rollback
#   2. PASTE_ENDまでstdinを読み捨て
#   3. 入力stream同期を回復
#
# args:
#   $old_len       : rollback位置
#   $tail_buffer   : PASTE_END途中一致状態
#   $total_timeout : 全体timeout(sec)
#
# return:
#   success : 1
#   failed  : undef
#
# note:
#   ・PASTE_END検出まで読み捨て継続
#   ・timeout時は同期回復失敗
#===========================================================

sub paste_cancel {

    my ($old_len, $tail_buffer, $total_timeout) = @_;

    my $start_time = time();

    #-------------------------------------------------------
    # rollback paste buffer
    #-------------------------------------------------------
    substr($g_paste_buffer, $old_len) = '';

    while(1) {

        #---------------------------------------------------
        # total timeout
        #---------------------------------------------------
        if( (time() - $start_time) >= $total_timeout ) {

            warn "paste_cancel(): total timeout\n";

            return undef;
        }

        my $buf = '';

        my $ret = sysread(STDIN, $buf, 1);

        #---------------------------------------------------
        # read error
        #---------------------------------------------------
        if( !defined($ret) || $ret <= 0 ) {

            warn "paste_cancel(): sysread failed\n";

            return undef;
        }

        #---------------------------------------------------
        # update tail buffer
        #---------------------------------------------------
        $tail_buffer .= $buf;

        # tail buffer size limit
        if(
            length($tail_buffer)
            > length($PASTE_END)
        ) {
            $tail_buffer = substr(
                $tail_buffer,
                -length($PASTE_END)
            );
        }

        #===================================================
        # PASTE_END check
        #===================================================
        if( $tail_buffer eq $PASTE_END ) {

            return 1;
        }
    }
}

#===========================================================
# utf8_read()
#
# 説明:
#   UTF-8マルチバイト文字を1文字単位で読み込む。
#
# 開始条件:
#   ・ASCII(0x00-0x7F)ではない1byteが来た場合
#   ・かつCSI / SS3 / PASTE等の制御系に該当しないこと
#
# 処理内容:
#   先頭byteからUTF-8の文字長を判定し、
#   必要な続きbyteを読み込んで1文字を完成させる。
#
#   途中でread失敗した場合は異常としてundefを返す。
#
# 注意:
#   ・本関数は「1文字単位で確定したUTF-8文字」を返す
#   ・バイナリ不正はそのまま返す場合あり
#
# 引数:
#   $first_byte
#       既に読み込んだUTF-8先頭byte
#
#   $io_timeout
#       追加byte読み込み時の待ち時間(_has_os_input用)
#
# return:
#   undef : read error / timeout
#   other : 完成したUTF-8文字
#===========================================================
sub utf8_read {

    my ($first_byte, $io_timeout) = @_;

    my $utf8 = $first_byte;

    my $o = ord($first_byte);

    my $need = 0;

    #---------------------------------------------------
    # invalid:
    # continuation byte
    # 0x80 - 0xBF
    #---------------------------------------------------
    if( $o >= 0x80 && $o <= 0xBF ) {

        warn "utf8_read(): invalid top byte\n";

        return undef;
    }

    #---------------------------------------------------
    # 2byte UTF-8
    # 0xC2 - 0xDF
    #
    # 0xC0 / 0xC1 are invalid
    #---------------------------------------------------
    elsif( $o >= 0xC2 && $o <= 0xDF ) {

        $need = 1;
    }

    #---------------------------------------------------
    # 3byte UTF-8
    # 0xE0 - 0xEF
    #---------------------------------------------------
    elsif( $o >= 0xE0 && $o <= 0xEF ) {

        $need = 2;
    }

    #---------------------------------------------------
    # 4byte UTF-8
    # 0xF0 - 0xF4
    #
    # 0xF5 - 0xFF are invalid
    #---------------------------------------------------
    elsif( $o >= 0xF0 && $o <= 0xF4 ) {

        $need = 3;
    }

    else {

        warn "utf8_read(): invalid utf8 first byte\n";

        return undef;
    }

    #---------------------------------------------------
    # continuation byte read
    #---------------------------------------------------
    for( 1 .. $need ) {

        if( !_has_os_input($io_timeout) ) {

            warn "utf8_read(): timeout\n";

            return undef;
        }

        my $buf = '';

        my $ret = sysread(STDIN, $buf, 1);

        if( !defined($ret) || $ret <= 0 ) {

            warn "utf8_read(): sysread failed\n";

            return undef;
        }

        my $co = ord($buf);

        #-------------------------------------------------
        # continuation byte check
        # 10xxxxxx
        #-------------------------------------------------
        if( ($co & 0xC0) != 0x80 ) {

            warn "utf8_read(): invalid continuation byte\n";

            return undef;
        }

        $utf8 .= $buf;
    }

    return $utf8;
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

#===========================================================
# has_paste()
# pasteにデータがあるか否か。
#===========================================================
sub has_paste {

    return length($g_paste_buffer) ? 1 : 0;
}

#===========================================================
# drain_paste()
# 蓄積していたpasteデータを取得し、バッファは空にする
#===========================================================
sub drain_paste {

    my $tmp = $g_paste_buffer;

    $g_paste_buffer = '';

    return $tmp;
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
