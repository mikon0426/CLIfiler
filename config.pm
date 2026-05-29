package Config;

use strict;
use warnings;



#===========================================================
# new()
#
# constructor
#
# usage:
#
#   my $cfg = Config->new(
#       'user.conf',
#       'History',
#       'Cursor',
#       'Bookmark',
#   );
#
# note:
#   ・第1引数:
#       config file path
#
#   ・第2引数以降:
#       valid section list
#
#   ・valid sectionはインスタンス毎に保持する
#
#   ・section定義をglobal固定化しないことで、
#       user.conf / action.conf 等へ柔軟対応する
#===========================================================
sub new {

    my ($class, $path, @sections) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if( !defined($path) || $path eq '' ) {

        die "Config::new(): invalid path\n";
    }

    my $self = {

        #---------------------------------------------------
        # config file path
        #---------------------------------------------------
        path => $path,

        #---------------------------------------------------
        # config data
        #---------------------------------------------------
        config => {},

        #---------------------------------------------------
        # max count per section
        #---------------------------------------------------
        max => {},

        #---------------------------------------------------
        # valid section table
        #---------------------------------------------------
        valid_section => {},

    };
    
    $self->{max}{History}  = 100;
    $self->{max}{Favorite} = 300;

    bless $self, $class;

    #-------------------------------------------------------
    # build valid section table
    #-------------------------------------------------------
    for my $section (@sections) {

        next if(
            !defined($section)
            ||
            $section eq ''
        );

        $self->{valid_section}{$section} = 1;
    }

    return $self;
}


#===========================================================
# set_array_max()
#
# 配列型セクションの最大保持数を設定する
#
# usage:
#
#   $cfg->set_array_max('History', 100);
#
# note:
#   ・配列型セクション専用
#
#   ・push_value(), push_history_value() 等で
#       max数を超えた場合、
#       古い要素を自動削除する
#
#   ・0以下を指定した場合は
#       無制限扱い
#
#===========================================================
sub set_array_max {

    my ($self, $section, $max) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($section)
        ||
        $section eq ''
    ) {

        return;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # undefined -> unlimited
    #-------------------------------------------------------
    if( !defined($max) ) {

        $max = 0;
    }

    #-------------------------------------------------------
    # negative value -> unlimited
    #-------------------------------------------------------
    if( $max < 0 ) {

        $max = 0;
    }

    #-------------------------------------------------------
    # set max
    #-------------------------------------------------------
    $self->{max}{$section} = int($max);
}


#===========================================================
# load()
#
# config file を読み込む
#
# return:
#   1 : success
#   0 : open error / invalid path
#
# note:
#   ・constructorで指定された section のみ読み込む
#
#   ・未知の section は無視する
#
#   ・config file が存在しない場合は
#       空configとして成功扱い
#
#   ・load後、配列型sectionは
#       normalize_array_section() を実行する
#
#===========================================================
sub load {

    my ($self) = @_;

    my $path = $self->{path};

    if(
        !defined($path)
        ||
        $path eq ''
    ) {

        return 0;
    }

    if( !-f $path ) {

        return 1;
    }

    my $fh;
    if( !open($fh, '<:utf8', $path) ) {

       return 0;
    }

    my $section = undef;

    while( my $line = <$fh> ) {

        chomp($line);

        $line =~ s/\r$//;

        #---------------------------------------------------
        # skip empty line
        #---------------------------------------------------
        if( $line =~ /^\s*$/ ) {

            next;
        }

        #---------------------------------------------------
        # comment
        #---------------------------------------------------
        if( $line =~ /^\s*[#;]/ ) {

            next;
        }

        #---------------------------------------------------
        # section
        #---------------------------------------------------
        if( $line =~ /^\[(.+?)\]$/ ) {

            my $name = $1;

            if(
                exists($self->{valid_section}{$name})
            ) {

                $section = $name;
            }
            else {

                $section = undef;
            }

            next;
        }

        #---------------------------------------------------
        # key=value
        #---------------------------------------------------
        if(
            defined($section)
            &&
            $line =~ /^(.*?)=(.*)$/
        ) {

            my $key   = $1;
            my $value = $2;

            $key =~ s/^\s+//;
            $key =~ s/\s+$//;

            $self->{config}{$section}{$key} = $value;
        }
    }

    close($fh);

    #-------------------------------------------------------
    # normalize array sections
    #-------------------------------------------------------
    for my $section (keys %{ $self->{max} }) {

        next if(
            !defined($self->{max}{$section})
            ||
            $self->{max}{$section} <= 0
        );

        $self->normalize_array_section($section);
    }

    return 1;
}


#===========================================================
# save()
#
# config file を保存する
#
# return:
#   1 : success
#   0 : open error / write error / invalid path
#
# note:
#   ・現在の内部状態から
#       config file を完全再生成する
#
#   ・constructorで指定された
#       valid section のみ保存する
#
#   ・存在しない section は保存しない
#
#   ・配列型sectionは
#       key を数値sortして保存する
#
#===========================================================
sub save {

    my ($self) = @_;

    my $path = $self->{path};

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($path)
        ||
        $path eq ''
    ) {

        return 0;
    }

    #-------------------------------------------------------
    # open
    #-------------------------------------------------------
    my $fh;
    if(
        !open(
            $fh,
            '>:encoding(UTF-8)',
            $path
        )
    ) {

        return 0;
    }

    #-------------------------------------------------------
    # save section
    #-------------------------------------------------------
    for my $section (sort keys %{ $self->{valid_section} }) {

        #---------------------------------------------------
        # skip empty section
        #---------------------------------------------------
        if(
            !exists($self->{config}{$section})
            ||
            ref($self->{config}{$section}) ne 'HASH'
            ||
            !keys %{ $self->{config}{$section} }
        ) {

            next;
        }

        print $fh "[$section]\n";

        #---------------------------------------------------
        # sort keys
        #---------------------------------------------------
        my @keys = sort {

            if(
                $a =~ /^(\d+)$/
                &&
                $b =~ /^(\d+)$/
            ) {

                $a <=> $b;
            }
            else {

                $a cmp $b;
            }

        } keys %{ $self->{config}{$section} };

        #---------------------------------------------------
        # save key=value
        #---------------------------------------------------
        for my $key (@keys) {

            my $value =
                $self->{config}{$section}{$key};

            next if( !defined($value) );

            print $fh "$key=$value\n";
        }

        print $fh "\n";
    }

    close($fh);

    return 1;
}


#===========================================================
# get()
#
# 引数:
#   ($section, $key, $default)
#
# 戻り値:
#   ・存在する場合: 値
#   ・存在しない場合: $default
#   ・section無効 / key無し: $default
#
# 説明:
#   指定section/keyの値を取得する。
#   default指定方式（undefではなく呼び出し側指定値を返す）
#
# note:
#   ・valid_section に登録されたsectionのみ対象
#   ・未登録sectionは無視してdefault返却
#===========================================================
sub get {

    my ($self, $section, $key, $default) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($section)
        || $section eq ''
        || !defined($key)
        || $key eq ''
    ) {
        return $default;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {
        return $default;
    }

    #-------------------------------------------------------
    # section exists check
    #-------------------------------------------------------
    if(
        !exists($self->{config}{$section})
    ) {
        return $default;
    }

    #-------------------------------------------------------
    # key exists check
    #-------------------------------------------------------
    if(
        exists($self->{config}{$section}{$key})
    ) {
        return $self->{config}{$section}{$key};
    }

    return $default;
}


#--------------------------------------------------
# set
# 引数: ($section, $key, $value)
#
# 説明:
#   指定キーに値を設定する。
#
#   constructor で登録された
#   valid section のみ設定可能。
#
#   無効な section は無視する。
#--------------------------------------------------
sub set {

    my ($self, $section, $key, $value) = @_;

    #----------------------------------------------
    # validation
    #----------------------------------------------
    if(
        !defined($section)
        ||
        $section eq ''
    ) {

        return;
    }

    if( !defined($key) ) {

        return;
    }

    #----------------------------------------------
    # valid section check
    #----------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return;
    }

    #----------------------------------------------
    # set value
    #----------------------------------------------
    $self->{config}{$section}{$key} = $value;
}


#===========================================================
# dump()
#
# 引数:
#   ($section, $key)
#
# 説明:
#   config内容を標準出力へdumpする。
#
# usage:
#
#   dump()
#       全section / 全key表示
#
#   dump($section)
#       指定sectionの全key表示
#
#   dump($section, $key)
#       指定section + 指定keyのみ表示
#
# note:
#   ・存在しない section / key は無視する
#
#   ・配列型sectionは key を数値sortして表示する
#
#===========================================================
sub dump {

    my ($self, $target_section, $target_key) = @_;

    #-------------------------------------------------------
    # section list
    #-------------------------------------------------------
    my @sections;

    if( defined($target_section) ) {

        if(
            !exists(
                $self->{config}{$target_section}
            )
        ) {

            return;
        }

        @sections = ($target_section);
    }
    else {

        @sections = sort keys %{ $self->{config} };
    }

    #-------------------------------------------------------
    # dump section
    #-------------------------------------------------------
    for my $section (@sections) {

        print "[$section]\n";

        #---------------------------------------------------
        # sort keys
        #---------------------------------------------------
        my @keys = sort {

            if(
                $a =~ /^(\d+)$/
                &&
                $b =~ /^(\d+)$/
            ) {

                $a <=> $b;
            }
            else {

                $a cmp $b;
            }

        } keys %{ $self->{config}{$section} };

        #---------------------------------------------------
        # key filter
        #---------------------------------------------------
        if( defined($target_key) ) {

            @keys = grep {
                $_ eq $target_key
            } @keys;
        }

        #---------------------------------------------------
        # dump key=value
        #---------------------------------------------------
        for my $key (@keys) {

            my $value =
                $self->{config}{$section}{$key};

            $value = ''
                if( !defined($value) );

            print "$key=$value\n";
        }

        print "\n";
    }
}


#===========================================================
# clear_section_keys()
#
# 引数:
#   ($section)
#
# 説明:
#   指定sectionに所属する
#   全key/valueを削除する。
#
# note:
#   ・section自体は削除しない
#
#   ・存在しない section は無視する
#
#   ・invalid section は無視する
#
# usage:
#
#   clear_section_keys(
#       'FileAction'
#   );
#
#===========================================================
sub clear_section_keys {

    my ($self, $section) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($section)
        ||
        $section eq ''
    ) {

        return;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # section not exists
    #-------------------------------------------------------
    if(
        !exists($self->{config}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # clear keys
    #-------------------------------------------------------
    $self->{config}{$section} = {};
}


#===========================================================
# normalize_array_section()
#
# 引数:
#   ($section)
#
# 説明:
#   配列型sectionのkeyを
#   0,1,2,3... へ正規化する。
#
#   user編集などにより、
#
#       0
#       1
#       3
#       7
#
#   のように壊れたindexを
#   自動補正する。
#
# note:
#   ・値の並び順は維持する
#
#   ・数値keyは数値sortされる
#
#   ・section自体は削除しない
#
#   ・存在しない section は無視する
#
# usage:
#
#   normalize_array_section(
#       'History'
#   );
#
#===========================================================
sub normalize_array_section {

    my ($self, $section) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($section)
        ||
        $section eq ''
    ) {

        return;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # section not exists
    #-------------------------------------------------------
    if(
        !exists($self->{config}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # sort keys
    #-------------------------------------------------------
    my @keys = sort {

        if(
            $a =~ /^(\d+)$/
            &&
            $b =~ /^(\d+)$/
        ) {

            $a <=> $b;
        }
        else {

            $a cmp $b;
        }

    } keys %{ $self->{config}{$section} };

    #-------------------------------------------------------
    # extract values
    #-------------------------------------------------------
    my @values = map {
        $self->{config}{$section}{$_}
    } @keys;

    #-------------------------------------------------------
    # rebuild section
    #-------------------------------------------------------
    $self->{config}{$section} = {};

    my $i = 0;

    for my $value (@values) {

        $self->{config}{$section}{$i++}
            = $value;
    }
}


#===========================================================
# get_size()
#
# 引数:
#   ($section)
#
# 戻り値:
#   要素数
#
# 説明:
#   配列型sectionの要素数を取得する。
#
# note:
#   ・存在しない section は 0 を返す
#
#   ・empty section は 0 を返す
#
#   ・normalize済みであることを前提とする
#
# usage:
#
#   my $size =
#       $cfg->get_size('History');
#
#===========================================================
sub get_size {

    my ($self, $section) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($section)
        ||
        $section eq ''
    ) {

        return 0;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return 0;
    }

    #-------------------------------------------------------
    # section not exists
    #-------------------------------------------------------
    if(
        !exists($self->{config}{$section})
    ) {

        return 0;
    }

    return scalar(
        keys %{ $self->{config}{$section} }
    );
}


#===========================================================
# push_value()
#
# 引数:
#   ($section, $value, $key)
#
# 説明:
#   配列型sectionへ値を先頭追加する。
#
#   既存データに同一keyが存在する場合は
#   古い要素を削除してから先頭追加する。
#
# usage:
#
#   push_value(
#       'Favorite',
#       '/tmp/a.txt'
#   );
#
#   push_value(
#       'Favorite',
#       '/tmp/a.txt',
#       '/tmp/a.txt'
#   );
#
# note:
#   ・$key省略時は
#       $value を key として使用する
#
#   ・重複判定は key ベース
#
#   ・max設定されている場合、
#       超過分は末尾から削除する
#
#   ・History専用ロジックは含まない
#
#===========================================================
sub push_value {

    my ($self, $section, $value, $key) = @_;

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($section)
        ||
        $section eq ''
    ) {

        return;
    }

    if(
        !defined($value)
        ||
        $value eq ''
    ) {

        return;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # key省略時は value を使用
    #-------------------------------------------------------
    if( !defined($key) ) {

        $key = $value;
    }

    my @list;

    #-------------------------------------------------------
    # existing values
    #-------------------------------------------------------
    if(
        exists($self->{config}{$section})
    ) {

        my @keys = sort {

            if(
                $a =~ /^(\d+)$/
                &&
                $b =~ /^(\d+)$/
            ) {

                $a <=> $b;
            }
            else {

                $a cmp $b;
            }

        } keys %{ $self->{config}{$section} };

        @list = map {
            $self->{config}{$section}{$_}
        } @keys;
    }

    #-------------------------------------------------------
    # remove duplicated key
    #-------------------------------------------------------
    @list = grep {

        my $old_value = $_;
        my $old_key   = $old_value;

        $old_key ne $key;

    } @list;

    #-------------------------------------------------------
    # push front
    #-------------------------------------------------------
    unshift @list, $value;

    #-------------------------------------------------------
    # max limit
    #-------------------------------------------------------
    my $max = $self->{max}{$section};

    if(
        defined($max)
        &&
        $max > 0
        &&
        @list > $max
    ) {

        @list = @list[0 .. $max - 1];
    }

    #-------------------------------------------------------
    # rebuild section
    #-------------------------------------------------------
    $self->{config}{$section} = {};

    my $i = 0;

    for my $v (@list) {

        $self->{config}{$section}{$i++} = $v;
    }
}


#===========================================================
# push_history_value()
#
# 引数:
#   ($dir, $loc, $offset)
#
# 説明:
#   History section 専用push処理。
#
#   dir|loc|offset 形式の履歴データを
#   History section の先頭へ追加する。
#
#   同一dirが既に存在する場合は、
#   古い要素を削除してから先頭追加する。
#
# usage:
#
#   push_history_value(
#       '/tmp',
#       100,
#       20
#   );
#
# note:
#   ・History section 専用
#
#   ・重複判定は dir のみ
#
#   ・loc / offset は
#       重複判定対象にしない
#
#   ・同一dirが存在した場合、
#       loc / offset は新値で上書きされる
#
#   ・内部保存形式:
#
#       dir|loc|offset
#
#===========================================================
sub push_history_value {

    my ($self, $dir, $loc, $offset) = @_;

    my $section = 'History';

    #-------------------------------------------------------
    # validation
    #-------------------------------------------------------
    if(
        !defined($dir)
        ||
        $dir eq ''
    ) {

        return;
    }

    #-------------------------------------------------------
    # valid section check
    #-------------------------------------------------------
    if(
        !exists($self->{valid_section}{$section})
    ) {

        return;
    }

    #-------------------------------------------------------
    # build value
    #-------------------------------------------------------
    my $value = join(
        '|',
        $dir,
        $loc,
        $offset
    );

    my @list;

    #-------------------------------------------------------
    # existing values
    #-------------------------------------------------------
    if(
        exists($self->{config}{$section})
    ) {

        my @keys = sort {

            if(
                $a =~ /^(\d+)$/
                &&
                $b =~ /^(\d+)$/
            ) {

                $a <=> $b;
            }
            else {

                $a cmp $b;
            }

        } keys %{ $self->{config}{$section} };

        @list = map {
            $self->{config}{$section}{$_}
        } @keys;
    }

    #-------------------------------------------------------
    # remove duplicated dir
    #-------------------------------------------------------
    @list = grep {

        my $old_value = $_;

        my (
            $old_dir,
            $old_loc,
            $old_offset
        ) = split(
            /\|/,
            $old_value,
            3
        );

        $old_dir ne $dir;

    } @list;

    #-------------------------------------------------------
    # push front
    #-------------------------------------------------------
    unshift @list, $value;

    #-------------------------------------------------------
    # max limit
    #-------------------------------------------------------
    my $max = $self->{max}{$section};

    if(
        defined($max)
        &&
        $max > 0
        &&
        @list > $max
    ) {

        @list = @list[0 .. $max - 1];
    }

    #-------------------------------------------------------
    # rebuild section
    #-------------------------------------------------------
    $self->{config}{$section} = {};

    my $i = 0;

    for my $v (@list) {

        $self->{config}{$section}{$i++} = $v;
    }
}


1;
