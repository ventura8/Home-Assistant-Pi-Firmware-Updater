import sys
import os
import xml.etree.ElementTree as ET

def generate_badge(line_rate, output_path="badge.svg"):
    try:
        coverage = float(line_rate) * 100
    except ValueError:
        coverage = 0.0

    color = "#e05d44" # red
    if coverage >= 95:
        color = "#4c1" # brightgreen
    elif coverage >= 90:
         color = "#97ca00" # green
    elif coverage >= 75:
        color = "#dfb317" # yellow
    elif coverage >= 50:
        color = "#fe7d37" # orange

    coverage_str = f"{int(coverage)}%"

    # Calculate widths based on text length
    # Heuristic: ~7.5px per character for Verdana 11px
    # "Coverage": ~59-61px

    label_text = "Coverage"
    value_text = coverage_str

    # Estimate widths
    # 6px approx per char + padding
    label_width = 61 
    value_width = int(len(value_text) * 8.5) + 10 # 4 chars (100%) -> 34+10=44px. 3 chars -> 25+10=35px

    total_width = label_width + value_width

    # Center positions
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
    <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
        <text aria-hidden="true" x="{int(label_x)}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="{label_width*10 - 100}">{label_text}</text>
        <text x="{int(label_x)}" y="140" transform="scale(.1)" fill="#fff" textLength="{label_width*10 - 100}">{label_text}</text>
        <text aria-hidden="true" x="{int(value_x)}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="{value_width*10 - 100}">{value_text}</text>
        <text x="{int(value_x)}" y="140" transform="scale(.1)" fill="#fff" textLength="{value_width*10 - 100}">{value_text}</text>
    </g>
</svg>"""

    with open(output_path, "w") as f:
        f.write(svg)
    print(f"Generated badge: {output_path} ({coverage_str})")

def check_attributes(element):
    """Ensure essential attributes expected by CodeCoverageSummary exist."""
    required_attrs = ['branches-covered', 'branches-valid', 'line-rate', 'branch-rate', 'complexity']
    for attr in required_attrs:
        if attr not in element.attrib:
             # Default to 0 or 0.0 if missing, strictly for passing the parser
             if 'rate' in attr:
                 element.set(attr, "0.0")
             else:
                 element.set(attr, "0")

def transform_coverage(input_file, badge_output="badge.svg"):
    print(f"Transforming coverage report: {input_file}")
    
    try:
        tree = ET.parse(input_file)
        root = tree.getroot()

        # Generate Badge from root line-rate
        root_line_rate = root.get("line-rate", "0")
        generate_badge(root_line_rate, output_path=badge_output)

        # Ensure root has required attributes
        check_attributes(root)
        if 'branches-valid' not in root.attrib:
             root.set('branches-valid', root.get('branches-covered', '0'))

        sources = root.find('sources')
        if sources is None:
            sources = ET.SubElement(root, 'sources')
            source = ET.SubElement(sources, 'source')
            source.text = '.'
        else:
            for source in sources.findall('source'):
                source.text = '.'

        packages_el = root.find('packages')
        if packages_el is None:
             packages_el = ET.SubElement(root, 'packages')

        original_packages = list(packages_el.findall('package'))
        
        # Clear existing packages to rebuild them
        for pkg in original_packages:
            packages_el.remove(pkg)

        for pkg in original_packages:
            classes = pkg.find('classes')
            if classes is None:
                continue

            for cls in classes.findall('class'):
                filename = cls.get('filename')
                # Fix filename path if it's relative or coming from docker
                if not filename.startswith('custom_components/'):
                    basename = os.path.basename(filename)
                    filename = f"custom_components/pi_firmware_updater/{basename}"
                    cls.set('filename', filename)

                # Create a new package for this file
                pkg_name = os.path.basename(filename)
                
                new_pkg = ET.SubElement(packages_el, 'package')
                new_pkg.set('name', pkg_name)
                
                new_pkg.set('line-rate', cls.get('line-rate', '0.0'))
                new_pkg.set('branch-rate', cls.get('branch-rate', '0.0'))
                new_pkg.set('complexity', cls.get('complexity', '0'))
                
                # Try to get covered lines from children
                lines = cls.find('lines')
                lines_valid = 0
                lines_covered = 0
                if lines is not None:
                    all_lines = lines.findall('line')
                    lines_valid = len(all_lines)
                    lines_covered = sum(1 for l in all_lines if int(l.get('hits', 0)) > 0)
                
                new_pkg.set('lines-covered', str(lines_covered))
                new_pkg.set('lines-valid', str(lines_valid))
                
                new_pkg.set('branches-covered', '0')
                new_pkg.set('branches-valid', '0')
                
                # Reconstruct classes element
                new_classes = ET.SubElement(new_pkg, 'classes')
                new_classes.append(cls)
                
                check_attributes(new_pkg)

        tree.write(input_file)
        print(f"Successfully transformed {input_file}")

    except Exception as e:
        print(f"Error transforming XML: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 transform_coverage.py <path_to_cobertura_xml> [badge_output_path]")
        sys.exit(1)

    xml_p = sys.argv[1]
    badge_p = sys.argv[2] if len(sys.argv) > 2 else "badge.svg"
    transform_coverage(xml_p, badge_p)
