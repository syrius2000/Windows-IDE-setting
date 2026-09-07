import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_utf8(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_openspec_version_is_pinned_and_project_scoped():
    config = json.loads(read_utf8("config/ai-framework-versions.json"))
    assert config["openspec"]["package"] == "@fission-ai/openspec"
    assert config["openspec"]["version"]
    assert config["openspec"]["version"] != "latest"

    setup_script = read_utf8("scripts/project/setup-openspec.ps1")
    assert "npx --yes" in setup_script
    assert "@latest" not in setup_script
    assert "AI_FRAMEWORK_STATUS.yml" in setup_script


def test_windows_reporting_stack_verifies_npm_and_npx():
    install_script = read_utf8("scripts/windows/03-install-reporting.ps1")
    verify_script = read_utf8("scripts/windows/05-verify.ps1")
    assert 'foreach ($commandName in @("npm", "npx"))' in install_script
    assert 'Assert-Tool "npm" "npm" "npm" "--version"' in verify_script
    assert 'Assert-Tool "npx" "npx" "npx" "--version"' in verify_script


def test_project_factory_has_destination_and_openspec_flow():
    factory = read_utf8("scripts/project/New-AnalysisProject.ps1")
    assert "[string]$DestinationPath" in factory
    assert "-NonInteractive requires -DestinationPath" in factory
    assert "-DestinationPath と -DestinationRoot/-Name" in factory
    assert "setup-openspec.ps1" in factory
    assert "AI_FRAMEWORK_STATUS.yml" in factory
    assert "OpenSpecを初期化しますか？" in factory
    assert 'if (Test-Path "openspec")' in factory


def test_generated_project_readme_has_beginner_openspec_recovery_path():
    readme = read_utf8("templates/analysis-project/template/README.md.jinja")
    assert "OpenSpecで解析テーマを始める" in readme
    assert "proposal" in readme and "specs" in readme and "design" in readme and "tasks" in readme
    assert ".\\scripts\\setup-openspec.ps1" in readme
    assert "AI_FRAMEWORK_STATUS.yml" in readme
    assert "outputs/private/" in readme
