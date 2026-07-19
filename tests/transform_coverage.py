import os
import sys
import xml.etree.ElementTree as ET

import lizard

COMPLEXITY_THRESHOLD = 10


def format_percentage(rate_value):
    return f"{float(rate_value) * 100:.2f}%"


def format_complexity(complexity_value):
    return f"{float(complexity_value):.2f}"


def analyze_complexity(file_path):
    analysis = lizard.analyze_file(file_path)
    function_complexities = [function.cyclomatic_complexity for function in analysis.function_list]
    if not function_complexities:
        return 0.0, 0.0, 0

    total_complexity = float(sum(function_complexities))
    max_complexity = float(max(function_complexities))
    return total_complexity, max_complexity, len(function_complexities)


def generate_summary(root, output_path):
    packages_el = root.find("packages")
    package_rows = []

    if packages_el is not None:
        for pkg in packages_el.findall("package"):
            package_rows.append(
                {
                    "name": pkg.get("name", "unknown"),
                    "line_rate": pkg.get("line-rate", "0"),
                    "complexity": pkg.get("complexity", "0"),
                    "max_complexity": pkg.get("max-function-complexity", "0"),
                    "function_count": pkg.get("function-count", "0"),
                    "lines_covered": pkg.get("lines-covered", "0"),
                    "lines_valid": pkg.get("lines-valid", "0"),
                }
            )

    package_rows.sort(key=lambda item: item["name"])

    summary_lines = [
        "# Coverage Summary",
        "",
        "## Overall",
        "",
        "| Metric | Value |",
        "| --- | --- |",
        f"| Coverage | {format_percentage(root.get('line-rate', '0'))} |",
        f"| Complexity | {format_complexity(root.get('complexity', '0'))} |",
        f"| Max Function Complexity | {format_complexity(root.get('max-function-complexity', '0'))} |",
        f"| Complexity Threshold | <= {COMPLEXITY_THRESHOLD:.2f} per function |",
        f"| Function Count | {root.get('function-count', '0')} |",
        f"| Lines Covered | {root.get('lines-covered', '0')} |",
        f"| Lines Valid | {root.get('lines-valid', '0')} |",
        "",
        "## Per File",
        "",
        '| File | Coverage | Complexity | Max Function Complexity | Threshold | Functions | Lines Covered | Lines Valid |',
        '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ]

    for row in package_rows:
        summary_lines.append(
            f"| {row['name']} | {format_percentage(row['line_rate'])} | "
            f"{format_complexity(row['complexity'])} | {format_complexity(row['max_complexity'])} | "
            f"<= {COMPLEXITY_THRESHOLD:.2f} | {row['function_count']} | {row['lines_covered']} | {row['lines_valid']} |"
        )

    summary_lines.append("")

    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(summary_lines))

    print(f"Generated summary: {output_path}")


def generate_badge(line_rate, output_path="badge.svg"):
    try:
        coverage = float(line_rate) * 100
    except ValueError:
        coverage = 0.0

    color = "#e05d44"
    if coverage >= 95:
        color = "#4c1"
    elif coverage >= 90:
        color = "#97ca00"
    elif coverage >= 75:
        color = "#dfb317"
    elif coverage >= 50:
        color = "#fe7d37"

    coverage_str = f"{int(coverage)}%"
    label_text = "Coverage"
    value_text = coverage_str
    label_width = 61
    value_width = int(len(value_text) * 8.5) + 10
    total_width = label_width + value_width
    label_x = label_width / 2.0 * 10
    value_x = (label_width + value_width / 2.0) * 10

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{total_width}" height="20" role="img" aria-label="{label_text}: {value_text}">
    <title>{label_text}: {value_text}</title>
    <linearGradient id="s" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <clipPath id="r">
        <rect width="{total_width}" height="20" rx="3" fill="#fff"/>
    </clipPath>
    <g clip-path="url(#r)">
        <rect width="{label_width}" height="20" fill="#555"/>
        <rect x="{label_width}" width="{value_width}" height="20" fill="{color}"/>
        <rect width="{total_width}" height="20" fill="url(#s)"/>
    </g>
        <g fill="#fff" text-anchor="middle"
         font-family="Verdana,Geneva,DejaVu Sans,sans-serif"
         text-rendering="geometricPrecision" font-size="110">
          <text aria-hidden="true" x="{int(label_x)}" y="150" fill="#010101"
              fill-opacity=".3" transform="scale(.1)"
              textLength="{label_width * 10 - 100}">{label_text}</text>
          <text x="{int(label_x)}" y="140" transform="scale(.1)" fill="#fff"
              textLength="{label_width * 10 - 100}">{label_text}</text>
          <text aria-hidden="true" x="{int(value_x)}" y="150" fill="#010101"
              fill-opacity=".3" transform="scale(.1)"
              textLength="{value_width * 10 - 100}">{value_text}</text>
          <text x="{int(value_x)}" y="140" transform="scale(.1)" fill="#fff"
              textLength="{value_width * 10 - 100}">{value_text}</text>
    </g>
</svg>"""

    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write(svg)
    print(f"Generated badge: {output_path} ({coverage_str})")


def check_attributes(element):
    required_attrs = ["branches-covered", "branches-valid", "line-rate", "branch-rate", "complexity"]
    for attr in required_attrs:
        if attr not in element.attrib:
            if "rate" in attr:
                element.set(attr, "0.0")
            else:
                element.set(attr, "0")


def transform_coverage(input_file, badge_output="badge.svg", summary_output=None):
    print(f"Transforming coverage report: {input_file}")

    try:
        tree = ET.parse(input_file)
        root = tree.getroot()

        root_line_rate = root.get("line-rate", "0")
        generate_badge(root_line_rate, output_path=badge_output)

        check_attributes(root)
        if "branches-valid" not in root.attrib:
            root.set("branches-valid", root.get("branches-covered", "0"))

        sources = root.find("sources")
        if sources is None:
            sources = ET.SubElement(root, "sources")
            source = ET.SubElement(sources, "source")
            source.text = "."
        else:
            for source in sources.findall("source"):
                source.text = "."

        packages_el = root.find("packages")
        if packages_el is None:
            packages_el = ET.SubElement(root, "packages")

        original_packages = list(packages_el.findall("package"))
        for pkg in original_packages:
            packages_el.remove(pkg)

        for pkg in original_packages:
            classes = pkg.find("classes")
            if classes is None:
                continue

            for cls in classes.findall("class"):
                filename = cls.get("filename")
                if not filename.startswith("custom_components/"):
                    basename = os.path.basename(filename)
                    filename = f"custom_components/pi_firmware_updater/{basename}"
                    cls.set("filename", filename)

                pkg_name = os.path.basename(filename)
                new_pkg = ET.SubElement(packages_el, "package")
                new_pkg.set("name", pkg_name)
                new_pkg.set("line-rate", cls.get("line-rate", "0.0"))
                new_pkg.set("branch-rate", cls.get("branch-rate", "0.0"))
                new_pkg.set("complexity", cls.get("complexity", "0"))

                lines = cls.find("lines")
                lines_valid = 0
                lines_covered = 0
                if lines is not None:
                    all_lines = lines.findall("line")
                    lines_valid = len(all_lines)
                    lines_covered = sum(1 for line in all_lines if int(line.get("hits", 0)) > 0)

                new_pkg.set("lines-covered", str(lines_covered))
                new_pkg.set("lines-valid", str(lines_valid))
                new_pkg.set("branches-covered", "0")
                new_pkg.set("branches-valid", "0")

                new_classes = ET.SubElement(new_pkg, "classes")
                new_classes.append(cls)

                check_attributes(new_pkg)

        total_complexity = 0.0
        max_function_complexity = 0.0
        function_count = 0

        for pkg in packages_el.findall("package"):
            classes = pkg.find("classes")
            if classes is None:
                continue

            cls = classes.find("class")
            if cls is None:
                continue

            filename = cls.get("filename")
            if not filename:
                continue

            file_total_complexity, file_max_complexity, file_function_count = analyze_complexity(filename)
            pkg.set("complexity", f"{file_total_complexity:.2f}")
            pkg.set("max-function-complexity", f"{file_max_complexity:.2f}")
            pkg.set("function-count", str(file_function_count))
            cls.set("complexity", f"{file_total_complexity:.2f}")
            total_complexity += file_total_complexity
            max_function_complexity = max(max_function_complexity, file_max_complexity)
            function_count += file_function_count

        root.set("complexity", f"{total_complexity:.2f}")
        root.set("max-function-complexity", f"{max_function_complexity:.2f}")
        root.set("function-count", str(function_count))

        tree.write(input_file)
        if summary_output:
            generate_summary(root, summary_output)
        print(f"Successfully transformed {input_file}")

    except Exception as exc:
        print(f"Error transforming XML: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 transform_coverage.py <path_to_cobertura_xml> [badge_output_path] [summary_output_path]")
        sys.exit(1)

    xml_p = sys.argv[1]
    badge_p = sys.argv[2] if len(sys.argv) > 2 else "badge.svg"
    summary_p = sys.argv[3] if len(sys.argv) > 3 else None
    transform_coverage(xml_p, badge_p, summary_p)
