package Config;

use strict;
use warnings;

#--------------------------------------------------
# 有効セクション定義（クラス共通）
#
# 説明:
#   許可するセクションを固定定義することで、
#   不正な設定の混入を防ぐ。
#   load()時のフォーマットチェックにも使用。
#--------------------------------------------------
our %g_valid_section = map { $_ => 1 } qw(
    Cursor Favorite DiffTarget SaveDir History
);

#--------------------------------------------------
# new
# 引数: ($file_path)
#   $file_path : 設定ファイルパス
#
# 戻り値:
#   Configオブジェクト
#
# 説明:
#   設定ファイル単位でインスタンスを生成する。
#   config / state を別ファイルにしたい場合も
#   同一クラスで扱えるようにするための設計。
#
# メンバ:
#   file   : 対象ファイルパス
#   config : 実際の設定データ（ハッシュ）
#   max    : セクションごとの最大件数制限
#--------------------------------------------------
sub new {
    my ($class, $file) = @_;

    my $self = {
        file   => $file,
        config => {},

        # セクションごとの最大件数（主にHistory用）
        max => {
            History => 20,   # デフォルト値
        },
    };

    return bless $self, $class;
}

#--------------------------------------------------
# set_max
# 引数: ($section, $max)
#   $section : セクション名
#   $max     : 最大件数
#
# 説明:
#   push_value()で使用する最大件数を設定する。
#   セクションごとに個別に設定可能。
#--------------------------------------------------
sub set_max {
    my ($self, $section, $max) = @_;

    if (!exists $g_valid_section{$section}) {
        return;
    }

    if (!defined $max || $max <= 0) {
        return;
    }

    $self->{max}{$section} = $max;
}

#--------------------------------------------------
# load
# 引数: なし（内部file使用）
#
# 戻り値:
#   0  : 正常
#  -1  : フォーマットエラー
#  -2  : ファイルopen失敗
#
# 説明:
#   INI形式のファイルを読み込み、内部ハッシュへ格納する。
#
# フォーマット制約:
#   - セクションは必須
#   - key=value形式のみ許可
#   - 不正行があれば即エラー終了
#
# 注意:
#   - 不正なセクションは即エラー
#   - 途中エラー時はcloseして戻る
#--------------------------------------------------
sub load {
    my ($self) = @_;

    $self->{config} = {};

    my $file = $self->{file};

    if (!-f $file) {
        return 0;  # 初回起動想定
    }

    open(my $fh, '<', $file) or return -2;

    my $section = '';

    while (my $line = <$fh>) {
        chomp $line;

        # 前後空白除去
        $line =~ s/^\s+|\s+$//g;

        # 空行・コメントはスキップ
        if ($line eq '' || $line =~ /^#/) {
            next;
        }

        #------------------------------
        # セクション解析
        #------------------------------
        if ($line =~ /^\[(.+?)\]$/) {
            my $sec = $1;

            # 許可されていないセクションはエラー
            if (!exists $g_valid_section{$sec}) {
                close($fh);
                return -1;
            }

            $section = $sec;
            next;
        }

        #------------------------------
        # key=value解析
        #------------------------------
        if ($line =~ /^([^=\s]+)\s*=(.*)$/) {

            # セクション未定義状態はエラー
            if ($section eq '') {
                close($fh);
                return -1;
            }

            my ($key, $val) = ($1, $2);

            # key,vel はスペースを取り除く
            $key =~ s/^\s+|\s+$//g;
            $val =~ s/^\s+|\s+$//g;

            # 内部へ格納
            $self->set($section, $key, $val);
        }
        else {
            # 不正フォーマット
            close($fh);
            return -1;
        }
    }

    close($fh);
    return 0;
}

#--------------------------------------------------
# save
# 引数: なし（内部file使用）
#
# 戻り値:
#   1 : 成功
#   0 : 失敗
#
# 説明:
#   内部データをINI形式でファイルに保存する。
#
# 特徴:
#   - 一旦 tmp ファイルへ書き出し
#   - rename で置き換え（安全性確保）
#
# 注意:
#   - セクションは固定順で出力
#   - 存在しないセクションも空で出力
#--------------------------------------------------
sub save {
    my ($self) = @_;

    my $file = $self->{file};

    if (!$file) {
        return 0;
    }

    my $tmp = "$file.tmp";

    open(my $fh, '>', $tmp) or return 0;

    for my $section (qw(Cursor Favorite DiffTarget SaveDir History)) {

        print $fh "[$section]\n";

        if ($self->exists_section($section)) {
            for my $key (sort keys %{ $self->{config}{$section} }) {
                print $fh "$key=$self->{config}{$section}{$key}\n";
            }
        }

        print $fh "\n";
    }

    close($fh);

    # 安全な置き換え
    if (!rename($tmp, $file)) {
        unlink($tmp);
        return 0;
    }

    return 1;
}

#--------------------------------------------------
# get
# 引数: ($section, $key, $default)
#
# 戻り値:
#   値 or デフォルト値
#
# 説明:
#   指定キーの値を取得する。
#   存在しない場合は default を返す。
#--------------------------------------------------
sub get {
    my ($self, $section, $key, $default) = @_;

    if ($self->exists_key($section, $key)) {
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
#   無効なセクションは無視する。
#--------------------------------------------------
sub set {
    my ($self, $section, $key, $value) = @_;

    if (!exists $g_valid_section{$section}) {
        return;
    }

    $self->{config}{$section}{$key} = $value;
}

#--------------------------------------------------
# exists_key
# 引数: ($section, $key)
#
# 戻り値:
#   1 : 存在
#   0 : 非存在
#
# 説明:
#   指定キーの存在チェックを行う。
#--------------------------------------------------
sub exists_key {
    my ($self, $section, $key) = @_;

    if (!$self->exists_section($section)) {
        return 0;
    }

    if (exists $self->{config}{$section}{$key}) {
        return 1;
    }

    return 0;
}

#--------------------------------------------------
# exists_section
# 引数: ($section)
#
# 戻り値:
#   1 : 存在
#   0 : 非存在
#
# 説明:
#   セクションの存在チェック
#--------------------------------------------------
sub exists_section {
    my ($self, $section) = @_;

    if (exists $self->{config}{$section}) {
        return 1;
    }

    return 0;
}

#--------------------------------------------------
# clear_section
# 引数: ($section)
#
# 説明:
#   セクションを丸ごと削除する
#--------------------------------------------------
sub clear_section {
    my ($self, $section) = @_;

    delete $self->{config}{$section};
}

#--------------------------------------------------
# push_value（汎用版）
#
# 引数:
#   $section : セクション名
#   $value   : 登録する値
#   $key     : 重複判定用キー（省略可）
#
# 動作:
#   - keyベースで重複除去
#   - 先頭に追加（最新優先）
#   - max件数でトリム
#
# 注意:
#   - フォーマット解析は一切行わない
#   - keyの意味は呼び出し側責任
#--------------------------------------------------
sub push_value {
    my ($self, $section, $value, $key) = @_;

    if (!exists $g_valid_section{$section}) {
        return;
    }

    if (!defined $value || $value eq '') {
        return;
    }

    # key省略時はvalueをキー扱い
    if (!defined $key) {
        $key = $value;
    }

    my @list;

    # 既存データ取得
    if ($self->exists_section($section)) {

        @list = sort {
            if ($a =~ /^(\d+)$/ && $b =~ /^(\d+)$/) {
                $a <=> $b;
            } else {
                $a cmp $b;
            }
        } keys %{ $self->{config}{$section} };

        @list = map { $self->{config}{$section}{$_} } @list;
    }

    #------------------------------
    # 重複除去（keyベース）
    #------------------------------
    @list = grep {
        my $old_value = $_;
        my $old_key   = $old_value;

        $old_key ne $key;
    } @list;

    # 先頭に追加
    unshift @list, $value;

    # max制限
    my $max = $self->{max}{$section};

    if (defined $max && $max > 0 && @list > $max) {
        @list = @list[0 .. $max - 1];
    }

    # 再構築
    $self->clear_section($section);

    my $i = 0;
    for my $v (@list) {
        $self->set($section, $i++, $v);
    }
}

#--------------------------------------------------
# push_history_value（History専用）
#
# 引数:
#   $dir    : ディレクトリ（重複キー）
#   $loc    : カーソル位置
#   $offset : カーソルオフセット
#
# 動作:
#   - dir単位で重複排除
#   - "dir|loc|offset"として保存
#   - maxはHistory設定を使用
#
# 注意:
#   - History専用ロジック
#   - フォーマットはここでのみ管理
#--------------------------------------------------
sub push_history_value {
    my ($self, $dir, $loc, $offset) = @_;

    if (!defined $dir || $dir eq '') {
        return;
    }

    my $value = join('|', $dir, $loc, $offset);
    my $key   = $dir;

    $self->push_value('History', $value, $key);
}

1;
