#!/usr/bin/env bash
# collect_folder_content_to_prompt — 把目录下所有文本文件转成带路径的 prompt 文本
#
# 用法:
#   ./collect_folder_content_to_prompt <路径...> [> 输出文件]
#
# 示例:
#   ./collect_folder_content_to_prompt lib > dump.txt
#   ./collect_folder_content_to_prompt lib/main.dart lib/page > dump.txt
#   ./collect_folder_content_to_prompt lib/page/navigation_bar.dart

set -euo pipefail

# ─────────────────────────────────────────────
emit() {
  local f="$1"
  printf '\n================================================================\n'
  printf '[file path]: %s\n' "$f"
  printf '[file content begin]\n'
  cat "$f"
  # 文件末尾无换行时补一个，避免结束标记贴在内容后
  [[ -n "$(tail -c 1 "$f" 2>/dev/null)" ]] && printf '\n'
  printf '[file content end]\n'
}


[[ $# -eq 0 ]] && { echo "用法: $0 <路径...>" >&2; exit 1; }

for arg in "$@"; do
  if [[ -d "$arg" ]]; then
    # 目录：递归展开，跳过二进制扩展名
    while IFS= read -r -d '' f; do
      emit "$f"
    done < <(find "$arg" -type f -print0 | sort -z)
  elif [[ -f "$arg" ]]; then
    emit "$arg"
  else
    echo "跳过（不存在）: $arg" >&2
  fi
done


# 注意：emit 定义在调用之后也能用，因为 while 循环在管道/进程替换里执行，
# 此时整个脚本已经解析完毕，函数已注册。用普通顺序更易读的话，把 emit
# 定义挪到脚本最上方即可。