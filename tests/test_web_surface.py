from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class WebSurfaceTests(unittest.TestCase):
    def test_revenue_room_assets_are_present(self) -> None:
        for name in ("index.html", "styles.css", "app.js", "README.md"):
            self.assertTrue((ROOT / "web" / name).exists())

    def test_revenue_room_has_a_decision_story(self) -> None:
        html = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
        app = (ROOT / "web" / "app.js").read_text(encoding="utf-8")
        self.assertIn("Revenue room", html)
        self.assertIn("Do not automate the forecast yet", app)
        self.assertIn("Forecast lab", html)
        self.assertIn("Controls", html)
