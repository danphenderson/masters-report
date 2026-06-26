const {themes: prismThemes} = require('prism-react-renderer');

const githubUrl = 'https://github.com/danphenderson/masters-report';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Masters Report',
  tagline: 'Stenotic hemodynamics documentation and reproducibility guides',
  url: 'https://danphenderson.github.io',
  baseUrl: '/masters-report/',
  organizationName: 'danphenderson',
  projectName: 'masters-report',
  trailingSlash: false,
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          path: 'public/docs',
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
          editUrl: ({docPath}) => `${githubUrl}/edit/main/public/docs/${docPath}`,
          breadcrumbs: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      },
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'Masters Report',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          href: githubUrl,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Documentation index',
              to: '/',
            },
            {
              label: 'Publication readiness',
              to: '/publication-readiness',
            },
            {
              label: 'Docs site publishing',
              to: '/docs-site-publishing',
            },
          ],
        },
        {
          title: 'Repository',
          items: [
            {
              label: 'GitHub',
              href: githubUrl,
            },
            {
              label: 'References',
              href: `${githubUrl}/tree/main/public/references`,
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Masters Report.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
    tableOfContents: {
      minHeadingLevel: 2,
      maxHeadingLevel: 2,
    },
  },
};

module.exports = config;
