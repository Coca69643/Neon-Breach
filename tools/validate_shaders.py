#!/usr/bin/env python3
"""Compile every GLSL ES shader embedded in the native C++ renderer."""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "app/src/main/cpp/game.cpp"
VALIDATOR = shutil.which("glslangValidator")

if VALIDATOR is None:
    raise SystemExit("glslangValidator is required; install the glslang-tools package")

cpp = SOURCE.read_text(encoding="utf-8")


def shader_source(function_name: str, label: str, symbol: str) -> str:
    start = cpp.find(f"GLuint {function_name}(){{")
    if start < 0:
        raise SystemExit(f"Shader factory not found: {function_name}")
    terminator = f'return linkProgram(vs,fs,"{label}");'
    end = cpp.find(terminator, start)
    if end < 0:
        raise SystemExit(f"Shader factory terminator not found: {label}")
    body = cpp[start:end]
    match = re.search(rf'const char\*{symbol}=R"\((.*?)\)";', body, re.DOTALL)
    if not match:
        raise SystemExit(f"Could not extract {symbol} from {function_name}")
    return match.group(1)


shader_sets = (
    ("make3DProgram", "3D scene", "vs", "vert", "scene.vert"),
    ("make3DProgram", "3D scene", "fs", "frag", "scene.frag"),
    ("makePostProgram", "stylized lens post-process", "vs", "vert", "post.vert"),
    ("makePostProgram", "stylized lens post-process", "fs", "frag", "post.frag"),
    ("makeProjectileProgram", "instanced projectiles", "vs", "vert", "projectiles.vert"),
    ("makeProjectileProgram", "instanced projectiles", "fs", "frag", "projectiles.frag"),
    ("makeFallbackProgram", "fallback", "vs", "vert", "fallback.vert"),
    ("makeFallbackProgram", "fallback", "fs", "frag", "fallback.frag"),
)

with tempfile.TemporaryDirectory(prefix="neon-breach-glsl-") as temp_dir:
    temp = Path(temp_dir)
    for factory, label, symbol, stage, filename in shader_sets:
        path = temp / filename
        path.write_text(shader_source(factory, label, symbol), encoding="utf-8")
        result = subprocess.run(
            [VALIDATOR, "-S", stage, str(path)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            sys.stderr.write(f"GLSL validation failed: {filename}\n")
            sys.stderr.write(result.stdout)
            sys.stderr.write(result.stderr)
            raise SystemExit(result.returncode)
        print(f"GLSL ES 3.00 OK: {filename}")

print(f"All {len(shader_sets)} embedded OpenGL ES shader stages compiled successfully.")
