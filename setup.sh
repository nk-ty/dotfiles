#!/bin/bash

# --- 1. 初期設定とエラー処理 ---

# エラー発生時 (-e)、または未定義変数使用時 (-u) に即時終了
set -eu

# グローバル変数の設定
REPO_URL="https://github.com/nk-ty/dotfiles.git"
REPO_DIR=~/dotfiles
# バックアップディレクトリはリンク作成時に必要
BACKUP_DIR=~/dotfiles_backup_$(date +%Y%m%d%H%M%S)

echo "🚀 開発環境のセットアップを開始します..."
cd ~ || { echo "❌ ホームディレクトリへの移動に失敗しました。"; exit 1; }
echo "現在のディレクトリ: $(pwd)"

# --- 2. dotfilesリポジトリのクローン/更新 ---

if [ -d "$REPO_DIR" ]; then
    echo "⚠️ $REPO_DIR が既に存在します。プルして最新の状態にします。"
    cd "$REPO_DIR"
    git pull || { echo "❌ 既存のリポジトリのプルに失敗しました。"; exit 1; }
    cd ~
else
    echo "📥 $REPO_URL をクローン中..."
    git clone "$REPO_URL" || { echo "❌ dotfiles のクローンに失敗しました。"; exit 1; }
fi
echo "✅ dotfiles の準備が完了しました。"

# --- 3. vim-plugのインストール ---

PLUG_PATH=~/dotfiles/vim/autoload/plug.vim
PLUG_URL="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

echo "🔌 vim-plug をインストール中..."
mkdir -p "$(dirname "$PLUG_PATH")" || { echo "❌ vim-plug ディレクトリの作成に失敗しました。"; exit 1; }
curl -fLo "$PLUG_PATH" "$PLUG_URL" || { echo "❌ vim-plug のダウンロードに失敗しました。"; exit 1; }
echo "✅ vim-plug を $PLUG_PATH にインストールしました。"

# --- 4. Oh My Zsh の非対話的インストール (修正済み) ---

echo "💻 Oh My Zsh をインストール中 (非対話モード)..."
# CHSH=no: デフォルトシェル変更のパスワード入力を回避
# yes Y | ...: .zshrcの上書き確認に自動で 'Y' を応答
if yes Y | CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
    echo "✅ Oh My Zsh のインストールスクリプトを実行しました。"
else
    # 実際には yes Y のおかげで失敗する可能性は低いが、念のため
    echo "⚠️ Oh My Zsh のインストールは非ゼロステータスで終了しましたが、続行します。"
fi

# --- 5. Git グローバル設定 (エイリアスとカラー) ---

echo "⚙️ Git グローバル設定を適用中..."
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global color.ui true
echo "✅ Git エイリアスとカラー設定を適用しました。"

# --- 6. シンボリックリンク作成のための関数定義 ---

# リンクを作成するファイルのリスト
DOTFILES=(
    "vimrc:~/.vimrc"
    "tmux.conf:~/.tmux.conf"
    "zshrc:~/.zshrc"
    "inputrc:~/.inputrc"
    "vim:~/.vim"
    "jshintrc:~/.jshintrc"
)

create_symlink() {
    local SOURCE_FILE_BASE="$1"
    local TARGET_FILE="$2"
    local SOURCE_FILE="$REPO_DIR/$SOURCE_FILE_BASE"
    eval TARGET_FILE_EXPANDED="$TARGET_FILE" # ~ を展開

    if [ ! -e "$SOURCE_FILE" ]; then
        echo "   ⚠️ リンク元ファイル $SOURCE_FILE が存在しません。スキップします。"
        return 0
    fi

    if [ -e "$TARGET_FILE_EXPANDED" ] || [ -L "$TARGET_FILE_EXPANDED" ]; then
        if [ -L "$TARGET_FILE_EXPANDED" ]; then
            rm "$TARGET_FILE_EXPANDED"
            echo "   - 既存のシンボリックリンク $TARGET_FILE_EXPANDED を削除しました。"
        else
            echo "   - 既存のファイル/ディレクトリ $TARGET_FILE_EXPANDED を $BACKUP_DIR にバックアップします。"
            mkdir -p "$BACKUP_DIR"
            mv "$TARGET_FILE_EXPANDED" "$BACKUP_DIR/"
        fi
    fi

    if ln -s "$SOURCE_FILE" "$TARGET_FILE_EXPANDED"; then
        echo "   - $SOURCE_FILE_BASE -> $TARGET_FILE_EXPANDED のリンクを作成しました。"
    else
        echo "   ❌ シンボリックリンクの作成に失敗しました: $SOURCE_FILE_BASE -> $TARGET_FILE_EXPANDED"
        return 1
    fi
}

# --- 7. シンボリックリンクの実行 ---

echo "🔗 設定ファイルへのシンボリックリンクを作成中..."
for item in "${DOTFILES[@]}"; do
    SOURCE="${item%%:*}"
    TARGET="${item##*:}"
    create_symlink "$SOURCE" "$TARGET"
done
echo "✅ すべてのシンボリックリンクを作成しました。"

# --- 8. 最終確認 ---

echo "📂 ホームディレクトリの最新ファイル一覧 (設定ファイル):"
ls -ltd ~/.{vimrc,tmux.conf,zshrc,inputrc,vim,jshintrc} 2>/dev/null || echo "（一部または全てのファイルが見つかりません）"

echo "🎉 セットアップが完了しました！新しい設定を反映させるには、新しいシェルを起動してください。"
