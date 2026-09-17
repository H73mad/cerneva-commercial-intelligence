"""Build Cerneva's source-controlled Tableau workbook and TWBX package.

The workbook uses a live packaged CSV connection so that recruiters can open
it without database credentials. XML is generated deterministically to keep
the Tableau artefact reviewable in Git.
"""

from __future__ import annotations

import csv
import shutil
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "data" / "processed" / "cerneva_deal_detail.csv"
TWB_FILE = ROOT / "tableau" / "Cerneva.twb"
TWBX_FILE = ROOT / "tableau" / "Cerneva.twbx"

DATASOURCE = "federated.cerneva"
CONNECTION = "textscan.cerneva"

FIELDS = {
    "opportunity_id": ("string", "dimension", "nominal"),
    "deal_stage": ("string", "dimension", "nominal"),
    "engage_date": ("date", "dimension", "ordinal"),
    "close_date": ("date", "dimension", "ordinal"),
    "close_month": ("string", "dimension", "ordinal"),
    "sales_agent": ("string", "dimension", "nominal"),
    "manager": ("string", "dimension", "nominal"),
    "regional_office": ("string", "dimension", "nominal"),
    "product": ("string", "dimension", "nominal"),
    "series": ("string", "dimension", "nominal"),
    "sales_price": ("real", "measure", "quantitative"),
    "account": ("string", "dimension", "nominal"),
    "sector": ("string", "dimension", "nominal"),
    "office_location": ("string", "dimension", "nominal"),
    "account_revenue_m": ("real", "measure", "quantitative"),
    "employees": ("integer", "measure", "quantitative"),
    "is_closed": ("boolean", "dimension", "nominal"),
    "is_won": ("integer", "measure", "quantitative"),
    "close_value": ("real", "measure", "quantitative"),
    "sales_cycle_days": ("integer", "measure", "quantitative"),
    "discount_pct": ("real", "measure", "quantitative"),
    "account_known": ("integer", "measure", "quantitative"),
    "account_enriched": ("integer", "measure", "quantitative"),
}

CALCULATIONS = {
    "Calculation_Won_Revenue": (
        "Won Revenue",
        "real",
        'IF [deal_stage] = "Won" THEN [close_value] END',
    ),
    "Calculation_Closed_Deal": (
        "Closed Deal",
        "integer",
        'IF [deal_stage] = "Won" OR [deal_stage] = "Lost" THEN 1 ELSE 0 END',
    ),
    "Calculation_Win_Rate": (
        "Win Rate",
        "real",
        "SUM([is_won]) / SUM([Calculation_Closed_Deal])",
    ),
    "Calculation_Open_Value": (
        "Open List Value",
        "real",
        'IF [deal_stage] = "Prospecting" OR [deal_stage] = "Engaging" THEN [sales_price] END',
    ),
}


def validate_data() -> int:
    if not DATA_FILE.exists():
        raise FileNotFoundError(
            f"Missing {DATA_FILE}. Run Rscript R/run_pipeline.R first."
        )
    with DATA_FILE.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = set(FIELDS) - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Processed data is missing fields: {sorted(missing)}")
        rows = sum(1 for _ in reader)
    if rows != 8_800:
        raise ValueError(f"Expected 8,800 opportunities, found {rows:,}")
    return rows


def add_column(parent: ET.Element, name: str, spec: tuple[str, str, str]) -> None:
    datatype, role, field_type = spec
    ET.SubElement(
        parent,
        "column",
        {
            "caption": name.replace("_", " ").title(),
            "datatype": datatype,
            "name": f"[{name}]",
            "role": role,
            "type": field_type,
        },
    )


def build_datasource(parent: ET.Element) -> None:
    datasource = ET.SubElement(
        parent,
        "datasource",
        {
            "caption": "Cerneva Deal Detail",
            "inline": "true",
            "name": DATASOURCE,
            "version": "18.1",
        },
    )
    connection = ET.SubElement(datasource, "connection", {"class": "federated"})
    named_connections = ET.SubElement(connection, "named-connections")
    named = ET.SubElement(
        named_connections,
        "named-connection",
        {"caption": "cerneva_deal_detail", "name": CONNECTION},
    )
    ET.SubElement(
        named,
        "connection",
        {
            "class": "textscan",
            "directory": "Data",
            "filename": "cerneva_deal_detail.csv",
            "password": "",
            "server": "",
        },
    )
    relation = ET.SubElement(
        connection,
        "relation",
        {
            "connection": CONNECTION,
            "name": "cerneva_deal_detail.csv",
            "table": "[cerneva_deal_detail.csv]",
            "type": "table",
        },
    )
    columns = ET.SubElement(relation, "columns", {"gridOrigin": "A1", "header": "yes"})
    for name, (datatype, _, _) in FIELDS.items():
        ET.SubElement(columns, "column", {"datatype": datatype, "name": name, "ordinal": str(len(columns))})

    metadata = ET.SubElement(connection, "metadata-records")
    for name, (datatype, _, _) in FIELDS.items():
        record = ET.SubElement(metadata, "metadata-record", {"class": "column"})
        ET.SubElement(record, "remote-name").text = name
        ET.SubElement(record, "remote-type").text = "130" if datatype == "string" else "5"
        ET.SubElement(record, "local-name").text = f"[{name}]"
        ET.SubElement(record, "parent-name").text = "[cerneva_deal_detail.csv]"
        ET.SubElement(record, "remote-alias").text = name
        ET.SubElement(record, "ordinal").text = str(len(metadata) - 1)
        ET.SubElement(record, "local-type").text = datatype
        ET.SubElement(record, "aggregation").text = "Sum" if datatype in {"real", "integer"} else "Count"
        ET.SubElement(record, "contains-null").text = "true"

    for name, spec in FIELDS.items():
        add_column(datasource, name, spec)

    for field, (caption, datatype, formula) in CALCULATIONS.items():
        column = ET.SubElement(
            datasource,
            "column",
            {
                "caption": caption,
                "datatype": datatype,
                "name": f"[{field}]",
                "role": "measure",
                "type": "quantitative",
            },
        )
        ET.SubElement(column, "calculation", {"class": "tableau", "formula": formula})

    layout = ET.SubElement(datasource, "layout", {"dim-ordering": "alphabetic", "measure-ordering": "alphabetic"})
    ET.SubElement(layout, "semantic-values")


def source_field(name: str, aggregation: str = "none", qualifier: str = "nk") -> str:
    return f"[{DATASOURCE}].[{aggregation}:{name}:{qualifier}]"


def add_dependencies(view: ET.Element, field_names: list[str]) -> None:
    dependencies = ET.SubElement(view, "datasource-dependencies", {"datasource": DATASOURCE})
    for name in field_names:
        if name in FIELDS:
            add_column(dependencies, name, FIELDS[name])
        else:
            caption, datatype, formula = CALCULATIONS[name]
            column = ET.SubElement(
                dependencies,
                "column",
                {
                    "caption": caption,
                    "datatype": datatype,
                    "name": f"[{name}]",
                    "role": "measure",
                    "type": "quantitative",
                },
            )
            ET.SubElement(column, "calculation", {"class": "tableau", "formula": formula})


def add_worksheet(
    parent: ET.Element,
    name: str,
    fields: list[str],
    rows: str = "",
    cols: str = "",
    mark: str = "Automatic",
    encoding: tuple[str, str] | None = None,
    color: str = "#5B1738",
) -> None:
    worksheet = ET.SubElement(parent, "worksheet", {"name": name})
    table = ET.SubElement(worksheet, "table")
    view = ET.SubElement(table, "view")
    datasources = ET.SubElement(view, "datasources")
    ET.SubElement(datasources, "datasource", {"caption": "Cerneva Deal Detail", "name": DATASOURCE})
    add_dependencies(view, fields)
    ET.SubElement(view, "aggregation", {"value": "true"})

    style = ET.SubElement(table, "style")
    ET.SubElement(style, "style-rule", {"element": "worksheet"})
    pane = ET.SubElement(ET.SubElement(table, "panes"), "pane", {"selection-relaxation-option": "selection-relaxation-allow"})
    pane_view = ET.SubElement(pane, "view")
    ET.SubElement(pane_view, "breakdown", {"value": "auto"})
    ET.SubElement(pane, "mark", {"class": mark})
    if encoding:
        encodings = ET.SubElement(pane, "encodings")
        ET.SubElement(encodings, encoding[0], {"column": encoding[1]})
    encodings = pane.find("encodings")
    if encodings is None:
        encodings = ET.SubElement(pane, "encodings")
    ET.SubElement(encodings, "color", {"column": source_field("deal_stage")})
    ET.SubElement(pane, "style")
    ET.SubElement(table, "rows").text = rows
    ET.SubElement(table, "cols").text = cols

    # Workbook-level brand colour preference retained as a semantic encoding.
    ET.SubElement(view, "customized-tooltip").text = f"Cerneva · {name} · {color}"


def build_workbook() -> ET.ElementTree:
    workbook = ET.Element(
        "workbook",
        {
            "original-version": "18.1",
            "source-build": "2024.1.0",
            "source-platform": "win",
            "version": "18.1",
        },
    )
    manifest = ET.SubElement(workbook, "document-format-change-manifest")
    ET.SubElement(manifest, "AccessibleZoneTabOrder")
    ET.SubElement(manifest, "AutoCreateAndUpdateDSDPhoneLayouts")
    ET.SubElement(manifest, "MarkAnimation")
    ET.SubElement(manifest, "ObjectModelExtractV2")
    preferences = ET.SubElement(workbook, "preferences")
    ET.SubElement(preferences, "preference", {"name": "ui.encoding.shelf.height", "value": "24"})

    datasources = ET.SubElement(workbook, "datasources")
    build_datasource(datasources)

    worksheets = ET.SubElement(workbook, "worksheets")
    add_worksheet(
        worksheets,
        "KPI — Won Revenue",
        ["deal_stage", "close_value", "Calculation_Won_Revenue"],
        mark="Text",
        encoding=("text", source_field("Calculation_Won_Revenue", "sum", "qk")),
    )
    add_worksheet(
        worksheets,
        "KPI — Win Rate",
        ["deal_stage", "is_won", "Calculation_Closed_Deal", "Calculation_Win_Rate"],
        mark="Text",
        encoding=("text", source_field("Calculation_Win_Rate", "ag", "qk")),
    )
    add_worksheet(
        worksheets,
        "Won Revenue by Product",
        ["deal_stage", "product", "close_value", "Calculation_Won_Revenue"],
        rows=source_field("product"),
        cols=source_field("Calculation_Won_Revenue", "sum", "qk"),
        mark="Bar",
        encoding=("label", source_field("Calculation_Won_Revenue", "sum", "qk")),
    )
    add_worksheet(
        worksheets,
        "Win Rate by Region",
        ["deal_stage", "regional_office", "is_won", "Calculation_Closed_Deal", "Calculation_Win_Rate"],
        rows=source_field("regional_office"),
        cols=source_field("Calculation_Win_Rate", "ag", "qk"),
        mark="Bar",
        encoding=("label", source_field("Calculation_Win_Rate", "ag", "qk")),
    )
    add_worksheet(
        worksheets,
        "Monthly Won Revenue",
        ["deal_stage", "close_month", "close_value", "Calculation_Won_Revenue"],
        rows=source_field("Calculation_Won_Revenue", "sum", "qk"),
        cols=source_field("close_month"),
        mark="Line",
        encoding=("label", source_field("Calculation_Won_Revenue", "sum", "qk")),
    )
    add_worksheet(
        worksheets,
        "Open Value by Stage",
        ["deal_stage", "sales_price", "Calculation_Open_Value"],
        rows=source_field("deal_stage"),
        cols=source_field("Calculation_Open_Value", "sum", "qk"),
        mark="Bar",
        encoding=("label", source_field("Calculation_Open_Value", "sum", "qk")),
    )

    dashboards = ET.SubElement(workbook, "dashboards")
    dashboard = ET.SubElement(
        dashboards,
        "dashboard",
        {"enable-sort-zone-taborder": "true", "name": "Commercial Command"},
    )
    ET.SubElement(dashboard, "layout-options")
    zones = ET.SubElement(dashboard, "zones")
    zone_specs = [
        ("KPI — Won Revenue", 0, 8000, 50000, 18000),
        ("KPI — Win Rate", 50000, 8000, 50000, 18000),
        ("Won Revenue by Product", 0, 26000, 60000, 41000),
        ("Win Rate by Region", 60000, 26000, 40000, 41000),
        ("Monthly Won Revenue", 0, 67000, 60000, 33000),
        ("Open Value by Stage", 60000, 67000, 40000, 33000),
    ]
    ET.SubElement(
        zones,
        "zone",
        {"h": "8000", "id": "1", "type-v2": "title", "w": "100000", "x": "0", "y": "0"},
    )
    for index, (sheet, x, y, width, height) in enumerate(zone_specs, start=2):
        zone = ET.SubElement(
            zones,
            "zone",
            {
                "h": str(height),
                "id": str(index),
                "name": sheet,
                "type-v2": "worksheet",
                "w": str(width),
                "x": str(x),
                "y": str(y),
            },
        )
        zone_style = ET.SubElement(zone, "zone-style")
        ET.SubElement(zone_style, "format", {"attr": "border-color", "value": "#DED5D9"})
        ET.SubElement(zone_style, "format", {"attr": "background-color", "value": "#F5F0E7"})
        ET.SubElement(zone_style, "format", {"attr": "padding", "value": "8"})
    ET.SubElement(dashboard, "devicelayouts")

    windows = ET.SubElement(workbook, "windows", {"saved-dpi-scale-factor": "1"})
    window = ET.SubElement(windows, "window", {"class": "dashboard", "name": "Commercial Command"})
    ET.SubElement(window, "cards")
    ET.SubElement(window, "simple-id", {"uuid": "{CA71E7A0-2026-4C0B-9A6A-000000000001}"})
    ET.SubElement(workbook, "thumbnails")
    return ET.ElementTree(workbook)


def package(tree: ET.ElementTree) -> None:
    ET.indent(tree, space="  ")
    tree.write(TWB_FILE, encoding="utf-8", xml_declaration=True)
    # Parse the written output as an explicit structural guard.
    ET.parse(TWB_FILE)

    with tempfile.TemporaryDirectory(prefix="cerneva-tableau-") as temp_dir:
        temp = Path(temp_dir)
        data_dir = temp / "Data"
        data_dir.mkdir()
        shutil.copy2(TWB_FILE, temp / TWB_FILE.name)
        shutil.copy2(DATA_FILE, data_dir / DATA_FILE.name)
        with zipfile.ZipFile(TWBX_FILE, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(temp / TWB_FILE.name, TWB_FILE.name)
            archive.write(data_dir / DATA_FILE.name, f"Data/{DATA_FILE.name}")

    with zipfile.ZipFile(TWBX_FILE) as archive:
        expected = {TWB_FILE.name, f"Data/{DATA_FILE.name}"}
        if set(archive.namelist()) != expected:
            raise ValueError("TWBX package did not contain the expected workbook and data")


if __name__ == "__main__":
    row_count = validate_data()
    workbook_tree = build_workbook()
    package(workbook_tree)
    print(f"Built {TWBX_FILE.name} with {row_count:,} opportunity rows.")
