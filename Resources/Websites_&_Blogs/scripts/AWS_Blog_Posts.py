#!/usr/bin/env python3
"""
Scrape all AWS Database Blog posts for the Amazon Aurora category and save to CSV.

Output: aws_aurora_blog_posts.csv
"""

import requests, time, csv, re
from bs4 import BeautifulSoup
from urllib.parse import urljoin

AURORA_URL = "https://aws.amazon.com/blogs/database/category/database/amazon-aurora/"
OUT_CSV = "aws_aurora_blog_posts.csv"
HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; aurora-blog-scraper/1.0)"}

def get_soup(url):
    r = requests.get(url, headers=HEADERS, timeout=30)
    r.raise_for_status()
    return BeautifulSoup(r.text, "html.parser")

def iter_index_pages(start_url):
    """Yield BeautifulSoup objects for index pages by following 'Older posts'."""
    url = start_url
    seen = set()
    while url and url not in seen:
        seen.add(url)
        soup = get_soup(url)
        yield url, soup
        # Find “Older posts” link; AWS Blog uses that label on category pages
        older = soup.find("a", string=lambda s: s and "Older posts" in s)
        url = urljoin(url, older["href"]) if older and older.get("href") else None
        time.sleep(0.4)  # be polite

def extract_post_links(index_soup, base_url):
    """Extract post hrefs from the index page."""
    # Typical structure: <h2 class="blog-post-title"><a href="...">Title</a></h2>
    for a in index_soup.select("h2 a[href]"):
        href = urljoin(base_url, a["href"])
        if "/blogs/database/" in href:
            yield href

def parse_date_from_byline(soup):
    """
    Try to get a human-readable date from the byline (e.g., 'on 22 AUG 2025 in ...'),
    then fall back to <time> or meta tags if present.
    """
    # 1) Byline pattern
    byline = soup.find(string=lambda s: s and " on " in s and " in " in s)
    if byline:
        # e.g., "... on 22 AUG 2025 in Amazon Aurora"
        m = re.search(r"\bon\s+(.+?)\s+in\b", str(byline))
        if m:
            return m.group(1).strip()

    # 2) <time> tag
    t = soup.find("time")
    if t and t.get_text(strip=True):
        return t.get_text(strip=True)

    # 3) meta property="article:published_time" or name="date"
    meta = soup.find("meta", attrs={"property": "article:published_time"}) or \
           soup.find("meta", attrs={"name": "date"}) or \
           soup.find("meta", attrs={"name": "pubdate"})
    if meta and meta.get("content"):
        return meta["content"].strip()

    return None

def get_post_meta(post_url):
    soup = get_soup(post_url)

    # Title: prefer <h1>, fall back to og:title
    title_tag = soup.find("h1")
    title = title_tag.get_text(strip=True) if title_tag else None
    if not title:
        og = soup.find("meta", attrs={"property": "og:title"})
        if og and og.get("content"):
            title = og["content"].strip()
    if not title:
        title = post_url  # final fallback

    pub_date = parse_date_from_byline(soup)
    return {"url": post_url, "title": title, "date": pub_date or ""}

def crawl_aurora(start_url=AURORA_URL, out_csv=OUT_CSV):
    seen_posts = set()
    rows = []

    for base_url, idx_soup in iter_index_pages(start_url):
        for href in extract_post_links(idx_soup, base_url):
            if href in seen_posts:
                continue
            seen_posts.add(href)
            rows.append(get_post_meta(href))
            time.sleep(0.3)

    # de-dup (by URL) and stable sort by (date text, title)
    dedup = {(r["url"]): r for r in rows}
    rows = list(dedup.values())
    rows.sort(key=lambda r: (r.get("date") or "", r["title"]))

    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["date", "title", "url"])
        w.writeheader()
        w.writerows(rows)

    print(f"Wrote {len(rows)} Aurora posts to {out_csv}")

if __name__ == "__main__":
    crawl_aurora()
