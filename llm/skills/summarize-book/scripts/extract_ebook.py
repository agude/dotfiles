# /// script
# requires-python = ">=3.11"
# dependencies = ["beautifulsoup4>=4.12", "markdownify>=0.14"]
# ///
"""Extract an ebook (EPUB/AZW3/MOBI) into per-chapter markdown files."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree

from bs4 import BeautifulSoup, ProcessingInstruction
from markdownify import markdownify


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", type=Path, help="Path to EPUB, AZW3, or MOBI file")
    p.add_argument(
        "-d",
        "--output-dir",
        type=Path,
        required=True,
        help="Directory to write chapter files into",
    )
    p.add_argument(
        "--porcelain",
        action="store_true",
        help="Machine-readable output (full paths, no decoration)",
    )
    return p.parse_args()


def convert_to_epub(src: Path, tmp_dir: Path) -> Path:
    """Convert AZW3/MOBI to EPUB via ebook-convert."""
    if not shutil.which("ebook-convert"):
        print(
            "error: ebook-convert not found. Install calibre: apt install calibre",
            file=sys.stderr,
        )
        sys.exit(1)
    dest = tmp_dir / (src.stem + ".epub")
    subprocess.run(
        ["ebook-convert", str(src), str(dest)],
        check=True,
        capture_output=True,
        text=True,
    )
    return dest


def read_spine_order(zf: zipfile.ZipFile) -> tuple[str | None, str | None, list[str]]:
    """Parse the OPF to get title, author, and spine-ordered content paths."""
    # Find the OPF file from META-INF/container.xml
    container = ElementTree.fromstring(zf.read("META-INF/container.xml"))
    ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
    rootfile = container.find(".//c:rootfile", ns)
    if rootfile is None:
        print("error: no rootfile in container.xml", file=sys.stderr)
        sys.exit(1)
    opf_path = rootfile.get("full-path", "")
    opf_dir = str(Path(opf_path).parent)
    if opf_dir == ".":
        opf_dir = ""

    opf = ElementTree.fromstring(zf.read(opf_path))

    # Default namespace varies; detect it
    opf_ns = re.match(r"\{(.+?)\}", opf.tag)
    ns_map: dict[str, str] = {}
    if opf_ns:
        ns_map["opf"] = opf_ns.group(1)

    dc_ns = "http://purl.org/dc/elements/1.1/"
    ns_map["dc"] = dc_ns

    title_el = opf.find(".//dc:title", ns_map)
    title = title_el.text if title_el is not None and title_el.text else None

    creator_el = opf.find(".//dc:creator", ns_map)
    author = creator_el.text if creator_el is not None and creator_el.text else None

    # Build id -> href map from manifest
    manifest: dict[str, str] = {}
    for item in opf.iter():
        if item.tag.endswith("}item") or item.tag == "item":
            item_id = item.get("id", "")
            href = item.get("href", "")
            media = item.get("media-type", "")
            if "html" in media or "xml" in media:
                full = f"{opf_dir}/{href}" if opf_dir else href
                manifest[item_id] = full

    # Read spine order
    spine_paths: list[str] = []
    for itemref in opf.iter():
        if itemref.tag.endswith("}itemref") or itemref.tag == "itemref":
            idref = itemref.get("idref", "")
            if idref in manifest:
                spine_paths.append(manifest[idref])

    return title, author, spine_paths


def read_ncx_labels(zf: zipfile.ZipFile) -> dict[str, str]:
    """Try to read chapter labels from toc.ncx, keyed by content src."""
    labels: dict[str, str] = {}
    for name in zf.namelist():
        if name.endswith(".ncx"):
            try:
                ncx = ElementTree.fromstring(zf.read(name))
                ncx_dir = str(Path(name).parent)
                if ncx_dir == ".":
                    ncx_dir = ""
                for nav in ncx.iter():
                    if nav.tag.endswith("}navPoint") or nav.tag == "navPoint":
                        text_el = None
                        src = None
                        for child in nav:
                            tag = child.tag.split("}")[-1] if "}" in child.tag else child.tag
                            if tag == "navLabel":
                                for t in child:
                                    if t.tag.split("}")[-1] == "text" and t.text:
                                        text_el = t.text.strip()
                            elif tag == "content":
                                raw_src = child.get("src", "")
                                src = raw_src.split("#")[0]
                                if ncx_dir:
                                    src = f"{ncx_dir}/{src}"
                        if text_el and src:
                            labels[src] = text_el
            except Exception:
                pass
            break
    return labels


def extract_chapter_title(soup: BeautifulSoup) -> str | None:
    """Try to extract a chapter title from the first heading."""
    for tag_name in ("h1", "h2", "h3", "h4"):
        heading = soup.find(tag_name)
        if heading and heading.get_text(strip=True):
            return heading.get_text(strip=True)

    # Some EPUBs use styled <p> or <div> with class names hinting at headings
    for tag in soup.find_all(["p", "div"], limit=10):
        cls = " ".join(tag.get("class", []))
        if re.search(r"(chapter|heading|title|^h\d)", cls, re.IGNORECASE):
            text = tag.get_text(strip=True)
            if text and len(text) < 200:
                return text

    return None


def html_to_markdown(html: str) -> str:
    """Convert HTML to clean markdown."""
    soup = BeautifulSoup(html, "html.parser")

    # Remove elements that aren't book content
    for tag in soup.find_all(["script", "style", "nav", "title"]):
        tag.decompose()

    # html.parser turns <?xml ...?> into ProcessingInstruction nodes
    for pi in soup.find_all(string=lambda s: isinstance(s, ProcessingInstruction)):
        pi.extract()

    md = markdownify(str(soup), heading_style="ATX", strip=["img", "a"])

    # Strip any remaining XML/DOCTYPE declarations
    md = re.sub(r"<\?xml[^?]*\?>\s*", "", md)
    md = re.sub(r"<!DOCTYPE[^>]*>\s*", "", md)
    md = re.sub(r"^xml\s+version=.*?\?\s*$", "", md, flags=re.MULTILINE)

    # Clean up excessive whitespace
    md = re.sub(r"\n{3,}", "\n\n", md)
    return md.strip()


def is_content_chapter(md: str) -> bool:
    """Filter out non-content spine items (TOC, copyright, cover, etc.)."""
    text = md.lower()
    word_count = len(text.split())

    # Very short documents are usually front/back matter
    if word_count < 80:
        return False

    # Check for TOC-like content (many links, little prose)
    lines = text.splitlines()
    if lines:
        non_empty = [l for l in lines if l.strip()]
        if non_empty:
            # If most lines are very short (like a TOC), skip
            avg_len = sum(len(l) for l in non_empty) / len(non_empty)
            if avg_len < 30 and word_count < 300:
                return False

    return True


def slugify(text: str) -> str:
    """Convert text to a filename-safe slug."""
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-")[:60]


def main() -> None:
    args = parse_args()
    src = args.input.resolve()

    if not src.exists():
        print(f"error: file not found: {src}", file=sys.stderr)
        sys.exit(1)

    suffix = src.suffix.lower()
    tmp_dir = None
    epub_path = src

    try:
        if suffix in (".azw3", ".mobi"):
            tmp_dir = Path(tempfile.mkdtemp(prefix="ebook-"))
            if not args.porcelain:
                print(f"Converting {src.name} to EPUB...")
            epub_path = convert_to_epub(src, tmp_dir)
        elif suffix != ".epub":
            print(
                f"error: unsupported format '{suffix}'. Use .epub, .azw3, or .mobi",
                file=sys.stderr,
            )
            sys.exit(1)

        with zipfile.ZipFile(epub_path) as zf:
            title, author, spine_paths = read_spine_order(zf)
            ncx_labels = read_ncx_labels(zf)

            chapters: list[dict[str, str]] = []
            for spine_item in spine_paths:
                try:
                    raw_html = zf.read(spine_item).decode("utf-8", errors="replace")
                except KeyError:
                    continue

                md = html_to_markdown(raw_html)
                if not is_content_chapter(md):
                    continue

                soup = BeautifulSoup(raw_html, "html.parser")
                ch_title = extract_chapter_title(soup)
                if not ch_title:
                    ch_title = ncx_labels.get(spine_item)
                chapters.append({"title": ch_title, "content": md})

        # Write output
        args.output_dir.mkdir(parents=True, exist_ok=True)

        chapter_names: list[str] = []
        for i, ch in enumerate(chapters, 1):
            if ch["title"]:
                slug = slugify(ch["title"])
                filename = f"{i:02d}-{slug}.md"
            else:
                filename = f"{i:02d}-chapter.md"

            out_path = args.output_dir / filename
            out_path.write_text(ch["content"], encoding="utf-8")
            chapter_names.append(filename)

            if args.porcelain:
                print(str(out_path))
            else:
                label = ch["title"] or f"Chapter {i}"
                words = len(ch["content"].split())
                print(f"  {filename} ({label}, {words:,} words)")

        # Write metadata
        metadata = {
            "title": title,
            "author": author,
            "source": src.name,
            "chapters": [
                {
                    "number": i + 1,
                    "file": name,
                    "title": chapters[i]["title"],
                }
                for i, name in enumerate(chapter_names)
            ],
        }
        meta_path = args.output_dir / "metadata.json"
        meta_path.write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        if not args.porcelain:
            print(
                f"\nExtracted {len(chapters)} chapters from "
                f"'{title or src.name}'"
                + (f" by {author}" if author else "")
            )
            print(f"Metadata: {meta_path}")

    finally:
        if tmp_dir and tmp_dir.exists():
            shutil.rmtree(tmp_dir)


if __name__ == "__main__":
    main()
