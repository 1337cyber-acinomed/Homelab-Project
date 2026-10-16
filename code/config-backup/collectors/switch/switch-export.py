#!/usr/bin/env python3
"""
Polaris Switch Collector - Playwright automation for the Netgear GS324TP's
config export via its web UI (no SSH/CLI/scriptable API available on this
switch - see Phase 3 runbook for why).

Logs into the switch, triggers a "Text Configuration" HTTP export, and saves
the resulting download to --output. Designed to be called by a thin bash
wrapper (switch.sh) matching the other collectors' interface - this script
only knows how to talk to the switch and produce a file; hashing, staging,
and lifecycle handling stay in bash where the rest of the framework expects.

Exit codes:
  0 = success, file saved to --output
  1 = collection failed - see stderr for detail
"""

import argparse
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

DEFAULT_TIMEOUT_MS = 30000


def read_password(credentials_path: Path) -> str:
    """
    Credentials file format: a single line containing the switch's admin
    password. (The switch's login page has a pre-filled default username;
    only a password field needs to be supplied here.)
    """
    if not credentials_path.exists():
        raise FileNotFoundError(f"Credentials file not found: {credentials_path}")
    password = credentials_path.read_text().strip()
    if not password:
        raise ValueError(f"Credentials file is empty: {credentials_path}")
    return password


DEBUG_DIR = Path("/tmp/polaris-switch-debug")


def _debug_screenshot(page, step_name: str) -> None:
    """Best-effort screenshot after a navigation step, for diagnosing flows
    that don't throw an error but also don't land where expected."""
    try:
        DEBUG_DIR.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(DEBUG_DIR / f"{step_name}.png"))
    except Exception as exc:  # noqa: BLE001
        print(f"DEBUG: Could not capture screenshot for step '{step_name}': {exc}", file=sys.stderr)


def export_switch_config(host: str, password: str, config_output_path: Path, tech_support_output_path: Path) -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1920, "height": 1080})
        page = context.new_page()
        page.set_default_timeout(DEFAULT_TIMEOUT_MS)

        try:
            page.goto(f"http://{host}/base/cheetah_login.html")
            page.get_by_role("textbox").click()
            page.get_by_role("textbox").fill(password)
            page.get_by_role("link", name="Login").click()
            page.wait_for_timeout(2000)
            _debug_screenshot(page, "01-after-login")

            page.get_by_role("link", name="Maintenance").click()
            page.wait_for_timeout(1500)
            _debug_screenshot(page, "02-after-maintenance-click")

            page.get_by_role("link", name="Export").click()
            page.wait_for_timeout(1500)
            _debug_screenshot(page, "03-after-export-click")

            page.get_by_role("link", name="HTTP File Export").click()
            page.wait_for_timeout(1500)
            _debug_screenshot(page, "04-after-http-file-export-click")

            main_frame = page.locator('iframe[name="maincontent"]').content_frame

            # Text Configuration export
            main_frame.get_by_role("combobox").select_option("Text Configuration")
            page.wait_for_timeout(500)
            _debug_screenshot(page, "05-after-select-text-configuration")

            with page.expect_download() as config_download_info:
                page.get_by_role("cell", name="Apply", exact=True).click()
            config_download = config_download_info.value
            config_output_path.parent.mkdir(parents=True, exist_ok=True)
            config_download.save_as(str(config_output_path))
            _debug_screenshot(page, "06-after-config-download")

            # Tech Support export - same session, avoids logging in twice
            main_frame.get_by_role("combobox").select_option("Tech Support")
            page.wait_for_timeout(500)
            _debug_screenshot(page, "07-after-select-tech-support")

            with page.expect_download() as tech_support_download_info:
                page.get_by_role("link", name="Apply").click()
            tech_support_download = tech_support_download_info.value
            tech_support_output_path.parent.mkdir(parents=True, exist_ok=True)
            tech_support_download.save_as(str(tech_support_output_path))

            # Log out cleanly rather than abandoning the session
            page.locator('iframe[name="logframe"]').content_frame.locator("a").click()

        except Exception:
            debug_path = Path("/tmp/polaris-switch-debug-failure.png")
            try:
                page.screenshot(path=str(debug_path))
                print(f"DEBUG: Failure screenshot saved to {debug_path}", file=sys.stderr)
                print(f"DEBUG: Per-step screenshots (if any succeeded) are in {DEBUG_DIR}", file=sys.stderr)
            except Exception as screenshot_exc:  # noqa: BLE001
                print(f"DEBUG: Could not capture failure screenshot: {screenshot_exc}", file=sys.stderr)
            raise

        finally:
            context.close()
            browser.close()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export Netgear GS324TP switch configuration and tech-support bundle via Playwright"
    )
    parser.add_argument("--host", required=True, help="Switch management IP/hostname")
    parser.add_argument(
        "--credentials", required=True, type=Path, help="Path to credentials file (0600 perms expected)"
    )
    parser.add_argument("--output-config", required=True, type=Path, help="Path to save the Text Configuration export")
    parser.add_argument("--output-tech-support", required=True, type=Path, help="Path to save the Tech Support export")
    args = parser.parse_args()

    try:
        password = read_password(args.credentials)
        export_switch_config(args.host, password, args.output_config, args.output_tech_support)
    except PlaywrightTimeoutError as exc:
        print(f"ERROR: Timed out waiting for a switch UI element: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001 - top-level boundary, must not crash uncaught
        print(f"ERROR: Switch export failed: {exc}", file=sys.stderr)
        return 1

    for label, path in (("configuration", args.output_config), ("tech-support", args.output_tech_support)):
        if not path.exists() or path.stat().st_size == 0:
            print(f"ERROR: Expected {label} output file missing or empty: {path}", file=sys.stderr)
            return 1

    print(f"SUCCESS: Switch configuration exported to {args.output_config}")
    print(f"SUCCESS: Switch tech-support bundle exported to {args.output_tech_support}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
