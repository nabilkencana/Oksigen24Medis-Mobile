#!/usr/bin/env python3
"""
Secret Scanner Wrapper for Shift-Left Security in CI/CD & Pre-commit Hooks.
Automates TruffleHog scanning and provides safe logging by masking raw secrets.
"""

import argparse
import json
import shutil
import subprocess
import sys
from typing import Dict, List, Any


class TruffleHogScanner:
    """Class wrapper untuk menjalankan dan mengelola pemindaian rahasia TruffleHog."""

    def __init__(self, target_dir: str = "."):
        self.target_dir = target_dir

    def check_binary_installation(self) -> str:
        binary_path = shutil.which("trufflehog")
        if not binary_path:
            raise FileNotFoundError(
                "Binary 'trufflehog' tidak ditemukan dalam sistem/PATH.\n"
                "Pastikan TruffleHog sudah terinstal (misal via Homebrew atau download binary resmi)."
            )
        return binary_path

    def execute_scan(self) -> List[Dict[str, Any]]:
        self.check_binary_installation()

        cmd = ["trufflehog", "filesystem", self.target_dir, "--json"]

        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            stdout, stderr = process.communicate()
            
            findings = []
            for line in stdout.splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    findings.append(data)
                except json.JSONDecodeError:
                    continue

            return findings

        except subprocess.SubprocessError as err:
            print(f"[ERROR] Gagal mengeksekusi TruffleHog: {err}", file=sys.stderr)
            sys.exit(2)

    def generate_safe_report(self, raw_findings: List[Dict[str, Any]]) -> int:
        leaks_detected = 0

        print("=" * 65)
        print("   [SHIFT-LEFT SECURITY] Pre-Commit / CI/CD Secret Scan Report   ")
        print("=" * 65)

        # ---------------------------------------------------------
        # KONFIGURASI FILTER KELAS PROFESIONAL
        # ---------------------------------------------------------
        # 1. Folder yang pasti berisi file pihak ketiga atau tidak relevan
        IGNORED_PATHS = ["node_modules", ".git", "vendor", "dist", "build", "Pods", "ios/Pods", ".dart_tool", ".idea", ".vscode", ".env"]
        
        # 2. Detektor yang sering memunculkan "noise" (Bukan API Key murni)
        # URI sering mendeteksi tautan web biasa seperti "https://schema.org"
        IGNORED_DETECTORS = ["URI", "Email"]
        # ---------------------------------------------------------

        for item in raw_findings:
            detector_name = item.get("DetectorName") or item.get("detectorName", "Unknown Detector")
            
            source_metadata = item.get("SourceMetadata", {})
            fs_metadata = source_metadata.get("Data", {}).get("Filesystem", {})
            
            file_path = fs_metadata.get("file") or item.get("file", "Unknown File")
            line_number = fs_metadata.get("line") or item.get("line", "Unknown Line")

            # ==========================================
            # FILTER 1: Lewati folder yang ada di daftar hitam (IGNORED_PATHS)
            # ==========================================
            if any(ignored_folder in file_path for ignored_folder in IGNORED_PATHS):
                continue
                
            # ==========================================
            # FILTER 2: Lewati jenis detektor yang berisi "noise" (URI biasa)
            # Dengan ini skrip akan fokus murni ke API Keys, Token, OAuth, dll.
            # ==========================================
            if detector_name in IGNORED_DETECTORS:
                continue

            leaks_detected += 1

            print(f"[!] DETEKSI API KEY/TOKEN BOCOR #{leaks_detected}")
            print(f"    - Jenis Kunci : {detector_name}")
            print(f"    - Nama File   : {file_path}")
            print(f"    - Baris Kode  : {line_number}")
            print(f"    - Nilai Rahasia: [DISAMARKAN / REDACTED UNTUK KEAMANAN LOG]")
            print("-" * 65)

        if leaks_detected > 0:
            print(f"\n[FAIL] Pemindaian Gagal: Ditemukan {leaks_detected} kredensial API yang bocor!")
            print("Tindakan Required: Hapus API Key dari kode dan gunakan Environment Variables (.env) / Secret Manager.")
            return 1
        else:
            print("\n[SUCCESS] Pemindaian Selesai: Tidak ditemukan API Key/Token yang bocor di kode Anda.")
            return 0


def main():
    parser = argparse.ArgumentParser(
        description="DevSecOps Automation: Safe TruffleHog Secret Scanner Wrapper"
    )
    parser.add_argument(
        "--path",
        default=".",
        help="Path direktori yang akan dipindai (default: direktori saat ini)"
    )
    args = parser.parse_args()

    scanner = TruffleHogScanner(target_dir=args.path)

    try:
        raw_findings = scanner.execute_scan()
        exit_code = scanner.generate_safe_report(raw_findings)
        sys.exit(exit_code)
    except FileNotFoundError as fnf_err:
        print(f"[ERROR SISTEM] {fnf_err}", file=sys.stderr)
        sys.exit(2)
    except Exception as err:
        print(f"[ERROR TIDAK TERDUGA] {err}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()