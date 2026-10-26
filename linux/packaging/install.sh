#!/usr/bin/env bash
# Jotsy for Linux: install from the extracted release tarball, or uninstall.
#
#   ./install.sh               install (or update) for the current user
#   ./install.sh --uninstall   remove what install.sh put in place
#   PREFIX=/usr/local sudo -E ./install.sh   install for all users
#
# Files (PREFIX defaults to ~/.local):
#   $PREFIX/share/jotsy/                          the app (jotsy, lib/, data/)
#   $PREFIX/share/applications/com.jotsy.diary.desktop
#   $PREFIX/share/icons/hicolor/<size>/apps/com.jotsy.diary.png
#
# Your diaries live in the app's data directory (~/.local/share/com.jotsy.diary
# and friends), not here: updating or uninstalling never touches them.
#
# 用法：解压发布的 .tar.gz 后运行 ./install.sh 安装或更新（默认装到 ~/.local，
# 无需 root）；./install.sh --uninstall 卸载。日记数据不在安装目录里，更新与
# 卸载都不会删除。
set -euo pipefail

readonly APP_ID='com.jotsy.diary'
readonly BINARY='jotsy'

usage() {
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
}

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
prefix="${PREFIX:-$HOME/.local}"
prefix="${prefix%/}"
app_dir="$prefix/share/jotsy"
desktop_dir="$prefix/share/applications"
icons_dir="$prefix/share/icons/hicolor"
desktop_file="$desktop_dir/$APP_ID.desktop"

refresh_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "$desktop_dir" 2>/dev/null || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ -f "$icons_dir/index.theme" ]]; then
    gtk-update-icon-cache -q -t "$icons_dir" 2>/dev/null || true
  fi
}

# Only remove an app directory that holds a Jotsy bundle, so a mistyped PREFIX
# cannot wipe an unrelated folder.
remove_app_dir() {
  if [[ -d "$app_dir" ]]; then
    if [[ ! -f "$app_dir/$BINARY" || ! -d "$app_dir/data" ]]; then
      echo "Refusing to remove $app_dir: it does not look like a Jotsy install." >&2
      exit 1
    fi
    rm -rf -- "$app_dir"
  fi
}

uninstall() {
  remove_app_dir
  rm -f -- "$desktop_file"
  local icon
  for icon in "$icons_dir"/*/apps/"$APP_ID".png; do
    [[ -e "$icon" ]] && rm -f -- "$icon"
  done
  refresh_caches
  echo "Jotsy has been removed from $prefix. Your diaries were kept."
}

# Desktop Entry Exec values quote arguments with double quotes (for spaces) and
# write a literal % as %%. Escaping ", `, $ and \ inside the quotes stacks two
# escape layers that desktop environments disagree on, so such paths are refused.
desktop_exec_quote() {
  local value="$1"
  case "$value" in
    *[\"\`\$\\]*)
      echo "Cannot install to $value: the path contains \", \`, \$ or \\. Set PREFIX to another folder." >&2
      exit 1
      ;;
  esac
  printf '"%s"' "${value//%/%%}"
}

install_app() {
  local bundle_files=("$BINARY" lib data)
  local name
  for name in "${bundle_files[@]}" "$APP_ID.desktop" icons; do
    if [[ ! -e "$source_dir/$name" ]]; then
      echo "Missing $name next to install.sh; run it from the extracted release folder." >&2
      exit 1
    fi
  done
  if [[ "$source_dir" == "$app_dir" ]]; then
    echo "install.sh is already running from $app_dir; extract the release elsewhere first." >&2
    exit 1
  fi
  # Check the path before touching anything.
  local exec_path line
  exec_path="$(desktop_exec_quote "$app_dir/$BINARY")"

  # Replace the previous version as a whole, so files dropped from the new
  # bundle do not linger next to it.
  remove_app_dir
  mkdir -p -- "$app_dir"
  cp -R -- "${bundle_files[@]/#/$source_dir/}" "$app_dir/"
  chmod 755 -- "$app_dir/$BINARY"

  mkdir -p -- "$icons_dir"
  cp -R -- "$source_dir/icons/hicolor/." "$icons_dir/"

  # Point Exec (and TryExec) at the installed binary: ~/.local/share/jotsy is
  # not on PATH, so the plain "jotsy" in the shipped entry would not launch.
  mkdir -p -- "$desktop_dir"
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      Exec=*) printf 'Exec=%s %%U\n' "$exec_path" ;;
      TryExec=*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$source_dir/$APP_ID.desktop" >"$desktop_file.tmp"
  mv -f -- "$desktop_file.tmp" "$desktop_file"
  chmod 644 -- "$desktop_file"

  refresh_caches
  echo "Jotsy is installed in $app_dir."
  echo "Open it from your application menu, or run: $app_dir/$BINARY"
}

case "${1:-}" in
  '') install_app ;;
  --uninstall) uninstall ;;
  -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
