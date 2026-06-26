# Docs Site Publishing

This repository publishes the Markdown documentation under `public/docs/**` as a
Docusaurus site at `https://danphenderson.github.io/masters-report/`.

## Local Commands

Run the docs site from the repository root:

```sh
npm ci
npm run docs:build
```

For local inspection, use:

```sh
npm run docs:serve -- --port 3025
```

Then open `http://localhost:3025/masters-report/`. The explicit port keeps the
preview stable for browser screenshots and avoids colliding with other local
development servers. `npm run docs:start` remains useful for live-editing the
site, but the production preview should use the built `build/` directory.

The Docusaurus build reads `public/docs/**.md` directly. It does not copy the
whole `public/` tree, so ignored simulation data, local logs, private reference
mirrors, and release PDFs remain outside the Pages artifact.

## GitHub Pages Workflow

The `.github/workflows/docs-pages.yml` workflow validates pull requests and
deploys pushes to `main`. Pull requests run `npm ci` and `npm run docs:build`
without deploying. Pushes to `main` upload the generated `build/` directory as a
GitHub Pages artifact and deploy it to the `github-pages` environment.

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
