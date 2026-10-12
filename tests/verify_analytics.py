"""Exercise actual ClownSmash entrypoints in a disposable project/user-data namespace."""
import shutil
import subprocess
import uuid
from pathlib import Path

project = Path(__file__).resolve().parents[1]
fixture = (project / "builds/debug/verification/endless/analytics") / ("application_" + uuid.uuid4().hex[:8])
fixture.mkdir(parents=True)
for directory in ("scripts", "scenes", "data", "assets", "localization", "addons", "app", "tests"):
    shutil.copytree(project / directory, fixture / directory)
text = (project / "project.godot").read_text(encoding="utf-8")
text = text.replace('config/name="Цирковой переполох"', 'config/name="ClownAnalyticsFixture_' + uuid.uuid4().hex + '"')
# Do not reuse a custom user-data directory if the project adopts one later.
text = text.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + fixture.as_posix() + '/user"', 1)
(fixture / "project.godot").write_text(text, encoding="utf-8")
(fixture / "config").mkdir()
shutil.copyfile(project / "config/game_analytics.cfg", fixture / "config/game_analytics.cfg")
godot = r"C:\dev\Godot\Godot_console.exe"
for arguments in (["--editor", "--quit"], ["--script", "res://tests/analytics_integration_test.gd"]):
    log = fixture / ("import.log" if "--editor" in arguments else "application.log")
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run([godot, "--headless", "--path", str(fixture), *arguments], stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    output = log.read_text(encoding="utf-8", errors="replace")
    print(f"exit={result.returncode} log={log}")
    print("\n".join(output.splitlines()[-12:]))
    if result.returncode or "SCRIPT ERROR" in output or "Parse Error" in output:
        raise SystemExit(1)
# Same disposable copy exercises absent, invalid and throwing dynamic backend.
backend = fixture / "addons/game_analytics/game_analytics.gd"
original = backend.read_text(encoding="utf-8")
for variant, source in [("missing", None), ("invalid_backend", "extends Node\nfunc broken(:\n"), ("throwing_backend", 'extends Node\nfunc track(_event, _params = {}, _operation = ""):\n\tassert(false, "injected backend failure")\n')]:
    if source is None:
        backend.unlink()
    else:
        backend.write_text(source, encoding="utf-8")
    log = fixture / (variant + ".log")
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run([godot, "--headless", "--path", str(fixture), "--script", "res://tests/analytics_integration_test.gd"], stdout=stream, stderr=subprocess.STDOUT, timeout=40)
    output = log.read_text(encoding="utf-8", errors="replace")
    # Backend faults are injected here; gameplay assertions and exit remain authoritative.
    if result.returncode or "failed=0" not in output or "APPLICATION_FAIL_OPEN scenario=disabled PASS" not in output:
        print(output[-4000:])
        raise SystemExit(1)
    print(f"backend={variant} PASS log={log}")
backend.write_text(original, encoding="utf-8")
print(f"ANALYTICS_APPLICATION_VERIFY PASS fixture={fixture}")
