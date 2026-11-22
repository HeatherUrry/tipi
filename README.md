# TIPI personality profile app

A web app where students complete the Ten-Item Personality Inventory (TIPI) and
see their Big Five percentiles compared with published norms, as a spider chart,
percentile strips, and a table.

It's a Shiny app written in R and exported with **Shinylive**, so R runs inside
each student's web browser (WebAssembly). The host only serves static files, so
300 students at once is no more work for it than 3, and no data comes back to you.

## Folder contents

| Path | What it is |
|---|---|
| `app/app.R` | The Shiny app: privacy notice, questions, results |
| `app/tipi_scoring.R` | Scoring key, norm lookup, percentiles (used by the app and the tests) |
| `app/tipi_plots.R` | Spider chart and percentile strips (base R graphics) |
| `app/norms.csv` | Norms typed in from `../TIPInormsFEMALE.pdf` and `../TIPInormsMALE.pdf` |
| `app/www/` | Styles and two small UI helpers (scroll, highlight unanswered items) |
| `tests/test_scoring.R` | Checks for the scoring and percentile math |
| `build.R` | Runs the tests, then exports the site to `docs/` |
| `docs/` | The finished website. This folder is what gets published |

## How scoring works

- **Scoring key** (from `../tipi.pdf`): each trait is the mean of two items; reversed
  items are scored as 8 − response. Extraversion 1, 6R · Agreeableness 2R, 7 ·
  Conscientiousness 3, 8R · Emotional Stability 4R, 9 · Openness 5, 10R.
  The tests confirm this matches `../excelscoreTIPI.xls` on 20,000 random response sets.
- **Percentiles** = `pnorm(score, mean, sd)` for the student's norm group (by sex and
  age group), i.e., assuming a normal distribution within each group.
- **Gender other than female/male, or not given**: the average of the female and male
  percentiles for that age group.
- **Age not given**: the 15–20 and 21–30 groups combined, weighted by sample size.
- **Bands** (same as the Excel scorer): Low < 16th, Medium low 16th–50th,
  Medium high 50th–84th, High > 84th percentile (mean ± 1 SD).
- `norms.csv` was checked number-by-number against the text of both norm PDFs
  (120 means/SDs and all 12 sample sizes match).

## Privacy

What the app does **not** do: save, send, or upload anything; set cookies; use
local or session storage; use analytics; load fonts, scripts, or R packages
from any server other than the host. Answers exist only in the open browser tab.

Checked on the exported site (Nov 22, 2026): a full network log of a page load
showed requests only to the host. After completing and clearing the form, there
were no cookies and no local or session storage. The R runtime's own IndexedDB
store and Shinylive's cache were both empty.

What the **host** does: GitHub Pages logs the IP address of every visitor for
security purposes (GitHub's documentation, "About GitHub Pages" → "Data
collection"). The app's privacy notice says so and states that using the app
means consenting to that. If you host elsewhere, change `HOST_NAME` near the
top of `app/app.R` and rebuild.

## Rebuild and preview on your computer

From this folder in PowerShell:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" build.R
```

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" -e "httpuv::runStaticServer('docs', port = 7451)"
```

Then open http://localhost:7451. Opening `docs/index.html` directly as a file
won't work; Shinylive needs to be served over http.

Always rebuild after editing anything in `app/`. Only `docs/` is published.

## Where it's published

This folder is its own git repository, `HeatherUrry/tipi`, kept separate from
the personal and lab website repositories. GitHub Pages serves the `docs/`
folder of the `main` branch (Settings → Pages → Deploy from a branch → `main`,
`/docs`). Because the account's user site has the custom domain
`heatherurry.io`, GitHub serves this project site at
**https://heatherurry.io/tipi/**.

To update the live app, from this folder:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" build.R
```

```powershell
git add -A; git commit -m "Update app"; git push
```

Pages redeploys automatically within a few minutes.

GitHub Pages limits (GitHub docs, "GitHub Pages limits"): sites up to 1 GB
(this one is about 69 MB) and a *soft* bandwidth limit of 100 GB per month.

## Load time and class use

A student's first visit downloads about 40 MB (mostly the WebAssembly build of
R), then R starts up in their browser. While that happens the page shows
"Site loading… it'll take 20–30 seconds the first time." (set in `build.R`;
it disappears as soon as the app appears). Served from this PC (so no download
wait), it took about 15 seconds to appear; expect longer over Wi-Fi and on
phones. 300 students is roughly 12 GB from GitHub, well
under the monthly limit. However, 300 people downloading 40 MB on the same
lecture-hall Wi-Fi at the same moment will be slow. Have students open the link
a few minutes before you need it, or assign it before class.

## License

- **Code written for this app** (`app/`, `tests/`, `build.R`): MIT License; see
  [LICENSE](LICENSE). Forks and pull requests are welcome.
- **TIPI items and scoring key**: Gosling, S. D., Rentfrow, P. J., & Swann, W. B., Jr.
  (2003). A very brief measure of the Big-Five personality domains. *Journal of
  Research in Personality, 37*(6), 504–528. https://doi.org/10.1016/S0092-6566(03)00046-1.
  [Sam Gosling's TIPI page](https://gosling.psy.utexas.edu/scales-weve-developed/ten-item-personality-measure-tipi/)
  says anyone can use the TIPI for any purpose; please cite the article.
- **Norms** (`app/norms.csv`): Gosling, S. D., Rentfrow, P. J., & Potter, J. (2014).
  *Norms for the Ten Item Personality Inventory* [Unpublished data], from the same
  page. They aren't covered by the MIT License; cite them as above.
- **`docs/shinylive/`**: generated by Shinylive. It contains webR, R, and R packages
  (including shiny), each under its own license; R itself, for example, is
  GPL-licensed.

## Changing things

- Wording, instructions, privacy notice: `app/app.R`
- Colors and layout: `app/www/styles.css`; chart colors at the top of `app/tipi_plots.R`
- Norms: `app/norms.csv` (keep the same columns), then run the tests via `build.R`
