const githubUrl = 'https://github.com/danphenderson/masters-report';

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    {
      type: 'category',
      label: 'Start here',
      collapsed: false,
      items: [
        'index',
        {
          type: 'link',
          label: 'README',
          href: `${githubUrl}/blob/main/README.md`,
        },
        {
          type: 'link',
          label: 'Agent guidelines',
          href: `${githubUrl}/blob/main/AGENTS.md`,
        },
        {
          type: 'link',
          label: 'Contributing',
          href: `${githubUrl}/blob/main/CONTRIBUTING.md`,
        },
      ],
    },
    {
      type: 'category',
      label: 'Build and validation',
      collapsed: true,
      items: ['report-builds', 'ops-tooling', 'julia-cli-workflows'],
    },
    {
      type: 'category',
      label: 'Artifacts and data',
      collapsed: true,
      items: ['artifact-policy', 'report-assets-and-provenance', 'resolved3d-workflows', 'benchmark-pipeline'],
    },
    {
      type: 'category',
      label: 'Handoffs and release',
      collapsed: true,
      items: ['agent-workflows', 'publication-readiness', 'policy-vocabulary', 'docs-site-publishing', 'executive-assessment'],
    },
    {
      type: 'category',
      label: 'StenoticHemodynamics',
      collapsed: true,
      items: [
        'stenotic-hemodynamics/workflows',
        'stenotic-hemodynamics/web-visualization',
        'stenotic-hemodynamics/native-resolved-fsi-design',
        'stenotic-hemodynamics/native-resolved-fsi-section-4-1-reproduction',
        'stenotic-hemodynamics/native-resolved-fsi-restart-resume-design',
        'stenotic-hemodynamics/section-4-1-production-validation-plan',
        'stenotic-hemodynamics/canic-2024-replication',
      ],
    },
  ],
};

module.exports = sidebars;
