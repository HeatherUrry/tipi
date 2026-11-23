# TIPI personality profile

A web page where students complete the Ten-Item Personality Inventory (TIPI) and
see their Big Five percentiles compared with published norms, as a spider chart,
percentile strips, and a table, with a "Print or save my results (PDF)" button.

**Live:** https://heatherurry.io/tipi/

R does all the computing ahead of time: `build.R` uses the scoring code and norms
to precompute every possible result (each comparison group × trait × possible
score) and writes them into the page. In the browser, a small script adds up each
student's answers, looks up their results, and draws the charts. The page is
about 130 KB, loads in about a second, and is plain static files, so any number
of students can use it at once and nothing comes back to you.

## Folder contents

| Path | What it is |
|---|---|
| `R/tipi_scoring.R` | Scoring key, norm lookup, percentiles, bands, labels |
| `R/tables.R` | Builds the lookup tables the page uses from `tipi_scoring.R` |
| `R/tipi_text.R` | Most wording and page sections (privacy notice, instructions, notes, references, disclaimer, footer); headings, buttons, and the page title are in `build.R`, and on-page messages and table headers in `web/app.js` |
| `data/norms.csv` | Norms typed in from `../TIPInormsFEMALE.pdf` and `../TIPInormsMALE.pdf` |
| `web/app.js` | The page's browser code: scoring, lookups, SVG charts, validation, printing |
| `web/base.css`, `web/styles.css`, `web/print.css` | Base styles, the page's look, and the print/PDF layout |
| `build.R` | Runs the tests, builds the tables and page, checks them, then updates `docs/` |
| `tests/test_scoring.R` | Checks the scoring and percentile code, including every norm value against the PDFs and the Excel scorer's key and bands |
| `tests/test_tables.R` | Checks every cell of the built `docs/data.js` against an independent calculation from the PDF norms |
| `tests/golden_norms.csv` | Norm values extracted from the two PDFs, used by both tests |
| `tests/browser-check.html` | Runs the page's own scoring/lookup code on every answer pair for every trait in every comparison group |
| `docs/` | The finished website (what GitHub Pages serves) |

## How scoring works

- **Scoring key** (from `../tipi.pdf`): each trait is the mean of two items;
  reversed items are scored as 8 − response. Extraversion 1, 6R · Agreeableness 2R, 7 ·
  Conscientiousness 3, 8R · Emotional Stability 4R, 9 · Openness to Experiences 5, 10R.
  The tests confirm this matches `../excelscoreTIPI.xls` on 20,000 random response sets.
- **Display**: traits are shown in OCEAN order with the TIPI's labels, Emotional
  Stability in Neuroticism's place (with a note that it's N reversed). The norm
  tables call the last trait "Openness"; `NORM_COLUMN` in `R/tipi_scoring.R` maps it.
- **Percentiles** = `pnorm(score, mean, sd)` for the student's norm group (by sex and
  age group), i.e., assuming a normal distribution within each group. Because TIPI
  scores come in half-point steps, this works out to "% scoring below you, with
  ties counted as half", which is how the page words it. The normal assumption is
  least accurate near the ends of the 1–7 scale (e.g., a score of 7 can show as
  only about the 88th–90th percentile).
- **Gender other than female/male, or not given**: the average of the student's
  percentile against the female norms and against the male norms (same age group).
  This differs from averaging the norms' means and SDs by at most 0.72 percentile points.
- **Age not given**: the 15–20 and 21–30 groups combined, weighted by sample size.
  That is, the percentile is the sample-size-weighted average of the student's
  percentiles in those two groups, not a percentile from a pooled mean and SD.
- **Bands** (same as the Excel scorer): mean ± 1 SD, i.e., cutoffs at the 15.87th,
  50th, and 84.13th percentiles. The displayed whole-number percentile is rounded
  toward its band when it sits right at a cutoff (e.g., 15.7 shows as 15th, Low),
  so the number and band never disagree: Low ≤ 15th, Medium low 16th–49th,
  Medium high 50th–83rd, High ≥ 84th.

## How it's checked

Each trait depends only on its own two items, so every possible answer set
(7¹⁰ = 282,475,249) for every comparison group (28) is covered by checking all 49
answer pairs per trait plus all 1,820 group × trait × score cells:

- `build.R` refuses to publish unless `tests/test_scoring.R` passes and every cell of
  the newly built `data.js` matches the independent calculation in `tests/test_tables.R`.
- After building, open `tests/browser-check.html` (it needs a local server, e.g.,
  `Rscript -e "httpuv::runStaticServer('.', port = 7452)"` from this folder, then
  http://localhost:7452/tests/browser-check.html). It should say "All checks passed."
- An independent audit (November 2026) reproduced every cell, every answer pair, and
  the chart positions at 11 screen widths from the PDFs with its own code: 0 mismatches.

## Privacy

The page doesn't save, send, or upload anything; set cookies; use local or session
storage; or use analytics; and it loads nothing from any other server (`build.R`
refuses to publish if it would). Answers are cleared whenever the page loads, so they
disappear when it's closed or reloaded, in every browser.

GitHub Pages logs the IP address of every visitor for security purposes (GitHub's
documentation, "About GitHub Pages" → "Data collection"). The privacy notice says so
and states that using the page means consenting to that. Because the first request is
logged before any page can show a notice, also include the notice wherever you post
the link. If you host elsewhere, change `HOST_NAME` in `R/tipi_text.R` and rebuild.

- Share the full **https://** link (the QR code uses it). The site has no HSTS header,
  so a typed `http://` address makes one unencrypted request before redirecting.
- The page shares the `heatherurry.io` origin with the personal website. Don't add
  analytics, embeds, or a site-wide service worker to that site.

## Rebuild and preview

From this folder in PowerShell (stop any local preview server first; it keeps files open):

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" build.R
```

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" -e "httpuv::runStaticServer('docs', port = 7451)"
```

Then open http://localhost:7451.

## Where it's published

This folder is its own git repository, `HeatherUrry/tipi`. GitHub Pages serves the
`docs/` folder of the `main` branch; because the account's user site has the custom
domain `heatherurry.io`, it appears at **https://heatherurry.io/tipi/**. To update,
in Git Bash (in Windows PowerShell 5.1, use `;` instead of `&&`):

```bash
git status            # check that only expected files changed
git add -A && git commit -m "Update page" && git push
```

The repo is public, so check `git status` first; `.gitignore` blocks PDFs,
spreadsheets, and Word files as a safeguard. Browsers may show the old version for
up to 10 minutes after a push (check in a private window).

**History:** the page began as a Shiny app running R in the browser through
Shinylive (about 32 MB per first visit). It was retired in November 2026 in favor of
this precomputed version; it's in the git history if ever needed. `docs/lite/`
forwards the page's former address, and `docs/shinylive-sw.js` removes the old
version's service worker from browsers that visited it.

## License

- **Code written for this page** (`R/`, `web/`, `tests/`, `build.R`): MIT License; see
  [LICENSE](LICENSE). Forks and pull requests are welcome.
- **TIPI items and scoring key**: Gosling, S. D., Rentfrow, P. J., & Swann, W. B., Jr.
  (2003). A very brief measure of the Big-Five personality domains. *Journal of
  Research in Personality, 37*(6), 504–528. https://doi.org/10.1016/S0092-6566(03)00046-1.
  [Sam Gosling's TIPI page](https://gosling.psy.utexas.edu/scales-weve-developed/ten-item-personality-measure-tipi/)
  says anyone can use the TIPI for any purpose; please cite the article.
- **Norms** (`data/norms.csv`, `tests/golden_norms.csv`): Gosling, S. D., Rentfrow,
  P. J., & Potter, J. (2014). *Norms for the Ten Item Personality Inventory*
  [Unpublished data], from the same page. They aren't covered by the MIT License;
  cite them as above.

## Changing things

- Wording, instructions, privacy notice: `R/tipi_text.R` (headings and buttons:
  `build.R`; messages: `web/app.js`). The comparison-group sentence comes from
  `group_description()` in `R/tipi_scoring.R`, and both test files check it word for
  word, so change them together.
- Colors and layout: `web/styles.css` (phone rules at 560 px and 400 px); chart colors
  near the top of `web/app.js` (charts switch to narrow layouts below 432 px and 480 px)
- Print/PDF layout: `web/print.css`, plus `beforePrint()` in `web/app.js`, which redraws
  the charts at print size
- Norms: `data/norms.csv` (keep the same columns), then rebuild. The tests check it
  against the PDF values in `tests/golden_norms.csv`, so new norms also need new
  values there, in the numbers hard-coded in `tests/test_scoring.R` (sample sizes,
  worked example), and in "about 278,000" and the citation in `R/tipi_text.R`.
