# md2word_equations.py
import os
import sys
import shutil
import subprocess
import argparse
from pathlib import Path

def ensure_pandoc():
    """
    确保系统可用 pandoc。优先使用系统 pandoc；
    若不存在，尝试用 pypandoc 的下载器安装到用户目录。
    """
    try:
        if shutil.which("pandoc"):
            return True
        import pypandoc
        pypandoc.download_pandoc()
        return True
    except Exception as e:
        print(f"[warn] 无法自动安装 pandoc：{e}")
        return False

def md_to_word(md_path, output_path=None, use_cli_fallback=True):
    """
    将 Markdown(含 LaTeX 公式) 转为 Word(.docx)，保留 Word 可编辑公式(OMML)。
    """
    md_path = Path(md_path)
    if output_path is None:
        output_path = md_path.with_suffix(".docx")
    else:
        output_path = Path(output_path)

    print(f"Converting:\n  {md_path}\n→ {output_path}")

    has_pandoc = ensure_pandoc()

    md_str = str(md_path)
    out_str = str(output_path)

    extra_args = [
        "--from=markdown+tex_math_dollars+tex_math_single_backslash",
        "--to=docx",
        "--mathml",
        "--standalone"
    ]

    # 1) 优先 pypandoc（用 convert_text 避免 WindowsPath 坑）
    try:
        import pypandoc

        text = md_path.read_text(encoding="utf-8")
        pypandoc.convert_text(
            text,
            to="docx",
            format="markdown+tex_math_dollars+tex_math_single_backslash",
            outputfile=out_str,
            extra_args=["--mathml", "--standalone"],
        )
        print("Done (pypandoc).")
        return output_path

    except Exception as e:
        print(f"[warn] pypandoc 转换失败：{e}")

        # 2) 回退 pandoc CLI
        if use_cli_fallback and has_pandoc:
            try:
                # pandoc CLI 更规范的写法：-f/-t + 其余参数
                cmd = [
                    "pandoc",
                    md_str,
                    "-o", out_str,
                    "-f", "markdown+tex_math_dollars+tex_math_single_backslash",
                    "-t", "docx",
                    "--mathml",
                    "--standalone",
                ]
                subprocess.run(cmd, check=True)
                print("Done (pandoc CLI fallback).")
                return output_path
            except subprocess.CalledProcessError as e2:
                print(f"pandoc CLI 也失败：{e2}")
        else:
            print("未启用 CLI 回退或系统无 pandoc。")

    return None

def build_parser():
    p = argparse.ArgumentParser(
        prog="md2word.py",
        description="Convert Markdown (with LaTeX math) to Word .docx using pandoc/pypandoc."
    )

    # 互斥：要么用位置参数 input.md，要么用 --md_path
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("input_md", nargs="?", help="Input markdown file (positional).")
    g.add_argument("--md_path", "-i", help="Input markdown file (named).")

    p.add_argument("output_docx", nargs="?", help="Output docx (positional, optional).")
    p.add_argument("--output", "-o", default=None, help="Output docx (named).")

    p.add_argument(
        "--no_cli_fallback",
        action="store_true",
        help="Disable pandoc CLI fallback when pypandoc fails."
    )
    return p

if __name__ == "__main__":
    args = build_parser().parse_args()

    in_md = args.md_path or args.input_md

    # 输出：命名参数优先，其次位置参数，否则 None（自动同名）
    out_docx = args.output if args.output is not None else args.output_docx

    res = md_to_word(
        in_md,
        output_path=out_docx,
        use_cli_fallback=(not args.no_cli_fallback)
    )
    sys.exit(0 if res is not None else 2)