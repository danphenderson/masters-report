# Docs Site Publishing

This repository publishes the Markdown documentation under
`public/docs/markdown/**` as a Docusaurus site at
`https://danphenderson.github.io/masters-report/`. The Docusaurus application
source also lives under `public/docs/`, including `package.json`,
`docusaurus.config.js`, `sidebars.js`, `src/css/custom.css`, and
`static/.nojekyll`.

## Local Commands

Install the docs dependencies from the repository root:

```sh
npm --prefix public/docs ci
```

For the production preview, use:

```sh
pipenv run docs-serve
```

Then open `http://localhost:3025/masters-report/`. The explicit port keeps the
preview stable for browser screenshots and avoids colliding with other local
development servers. The root `docs-serve` wrapper runs the production build
and then serves `public/docs/build/`. For live-editing instead of the built
preview, use:

```sh
npm --prefix public/docs run docs:start
```

The Docusaurus build reads `public/docs/markdown/**.md` directly. It does not
copy the whole `public/` tree, so ignored simulation data, local logs, private
reference mirrors, and release PDFs remain outside the Pages artifact.

## GitHub Pages Workflow

The `.github/workflows/docs-pages.yml` workflow validates pull requests and
deploys pushes to `main`. Pull requests run `npm ci` and `npm run docs:build`
from `public/docs/` without deploying. Pushes to `main` upload the generated
`public/docs/build/` directory as a GitHub Pages artifact and deploy it to the
`github-pages` environment.

The repository must have GitHub Pages configured with **Build and deployment >
Source: GitHub Actions**. No `gh-pages` branch or custom domain is required for
the default project site.

After the first successful push to `main`, check:

- the workflow build job completed `npm ci` and `npm run docs:build`;
- the deploy job ran only for the push, not for pull request validation;
- `https://danphenderson.github.io/masters-report/` loads the documentation
  index;
- at least one nested page under `/masters-report/stenotic-hemodynamics/`
  loads without a 404;
- browser developer tools show no missing local assets from copied `public/`
  paths.

## Search Follow-Up

Search is intentionally deferred for the first publish. After the Pages site is
public and crawlable, request Algolia DocSearch indexing for the
`danphenderson.github.io/masters-report/` URL and add the resulting Docusaurus
`algolia` theme configuration in a separate patch.
