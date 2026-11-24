/**
 * Конфигурация Lighthouse CI.
 *
 * URL не перечислены статически: модели каталога появляются и переименовываются,
 * поэтому список собирается из готового `public/` — главная, корень каталога и
 * по одной карточке из каждой коллекции (`/catalog/<collection>/<model>/`).
 * Полный обход всех страниц сборки: `LHCI_ALL_PAGES=1 npx @lhci/cli autorun`.
 *
 * Аудиты `is-on-https` и `redirects-http` пропущены: в CI сайт отдаётся по http://localhost.
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const DIST_DIR = path.join(__dirname, 'public');
const BASE_URLS = ['/', '/catalog/'];
const SKIPPED_AUDITS = ['is-on-https', 'redirects-http'];

/**
 * Подпапки каталога, отсортированные по имени.
 * @param {string} directory
 * @return {string[]}
 */
function subdirectories(directory) {
  return fs
    .readdirSync(directory, {withFileTypes: true})
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .sort();
}

/**
 * По одной карточке из каждой коллекции: `/catalog/<collection>/<model>/`.
 * @param {string} distDir каталог сборки Hugo
 * @return {string[]}
 */
function modelUrls(distDir) {
  const catalogDir = path.join(distDir, 'catalog');
  if (!fs.existsSync(catalogDir)) return [];

  return subdirectories(catalogDir).flatMap(collection => {
    const collectionDir = path.join(catalogDir, collection);
    const model = subdirectories(collectionDir).find(name =>
      fs.existsSync(path.join(collectionDir, name, 'index.html'))
    );
    return model ? [`/catalog/${collection}/${model}/`] : [];
  });
}

const collect = {
  staticDistDir: './public',
  numberOfRuns: 1,
  settings: {
    preset: 'desktop',
    skipAudits: SKIPPED_AUDITS,
    chromeFlags: '--headless --no-sandbox --disable-dev-shm-usage',
  },
};

if (process.env.LHCI_ALL_PAGES === '1') {
  // Полный обход: карточки лежат на глубине catalog/<collection>/<model>/.
  collect.staticDirFileDiscoveryDepth = 3;
  collect.maxAutodiscoverUrls = 0;
  collect.autodiscoverUrlBlocklist = ['/404.html'];
} else {
  if (!fs.existsSync(path.join(DIST_DIR, 'index.html'))) {
    process.stderr.write(
      `[lighthouserc] Нет сборки в ${DIST_DIR} — сначала выполните: hugo --minify --gc\n`
    );
  }
  collect.url = [...BASE_URLS, ...modelUrls(DIST_DIR)];
}

module.exports = {
  ci: {
    collect,
    assert: {
      assertions: {
        'is-on-https': 'off',
        'redirects-http': 'off',
        'categories:performance': ['warn', {minScore: 0.9}],
        'categories:accessibility': ['warn', {minScore: 0.95}],
        'categories:seo': ['warn', {minScore: 0.95}],
      },
    },
    upload: {
      target: 'filesystem',
      outputDir: '.lighthouseci',
    },
  },
};
