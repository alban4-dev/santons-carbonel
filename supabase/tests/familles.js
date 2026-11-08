const { chromium } = require('playwright');
// Plusieurs familles : Alban crée la famille Hugues (côté de sa femme) puis la famille Bavière
// (côté de ses parents) et passe de l'une à l'autre par le menu « Famille » ; Tonton (Bavière) et
// Dorothée (Hugues) ne voient que la leur ; les santons ajoutés restent dans leur famille.
const { execSync } = require('child_process');
const S = (process.env.SCRATCH || '/tmp') + '/';
const URL = 'http://localhost:8766/index.html';
const sqlv = q => execSync(`psql -h /tmp -p 54329 -U postgres -d app -tA -c "${q}"`).toString().trim();
(async () => {
  const b = await chromium.launch(); const errs = [];
  const mk = async (w, h) => { const p = await (await b.newContext({ viewport: { width: w, height: h } })).newPage(); p.on('pageerror', e => errs.push(e.message)); return p; };
  const signup = async (p, nom, mail) => { await p.click('[data-mode="up"]'); await p.fill('#a-nom', nom); await p.fill('#a-mail', mail); await p.fill('#a-pass', 'secret123'); await p.click('#auth-go'); await p.waitForSelector('#scr-app:not([hidden])'); await p.waitForTimeout(500); };
  const vue = async p => ({ famille: (await p.locator('.fam-head h2').allTextContents()).join(' + '), menu: await p.locator('#fam-sel').count() ? (await p.locator('#fam-sel option').allTextContents()).join(' / ') : '-', creches: (await p.locator('.lcard[data-list] h3').allTextContents()).join(', ') });
  const choisir = async (p, nom) => { if (await p.locator('#fam-sel').count()) { const v = await p.$$eval('#fam-sel option', (os, n) => (os.find(o => o.textContent.includes(n)) || {}).value, nom); await p.selectOption('#fam-sel', v); await p.waitForTimeout(300); } };
  const ouvre = async (p, famille, creche) => { await p.goto(URL); await p.waitForSelector('#view-home:not([hidden])'); await p.waitForTimeout(500); await choisir(p, famille); await p.click(`.lcard[data-list]:has-text("${creche}")`); await p.waitForTimeout(500); };
  const cherche = async (p, tab, q) => { await p.click('#tab-' + tab); await p.fill('#q', q); await p.waitForTimeout(400); const n = await p.locator('.card').count(); await p.fill('#q', ''); await p.waitForTimeout(200); return n; };

  const alban = await mk(390, 844);
  await alban.goto(URL); await alban.waitForSelector('#scr-auth:not([hidden])'); await signup(alban, 'Alban', 'alban@f.fr');
  await alban.click('#create-family'); await alban.fill('#fam-nom', 'Famille Hugues'); await alban.click('#fam-go'); await alban.waitForTimeout(500);
  await alban.click('[data-newlist]'); await alban.fill('#new-nom', 'Crèche de Lucie'); await alban.click('#new-form button[type=submit]'); await alban.waitForTimeout(500);
  await alban.click('#back'); await alban.waitForTimeout(300);
  console.log('une seule famille : menu', await alban.locator('#fam-sel').count(), '| bouton', await alban.textContent('#create-family'));
  await alban.click('#create-family'); console.log('titre :', await alban.textContent('#fam-title'));
  await alban.fill('#fam-nom', 'Famille Martin'); await alban.click('#fam-go'); await alban.waitForTimeout(600);
  console.log('après création :', JSON.stringify(await vue(alban)));
  await alban.click('[data-newlist]'); await alban.fill('#new-nom', 'Crèche du beau-frère'); await alban.click('#new-form button[type=submit]'); await alban.waitForTimeout(500);
  await alban.click('#back'); await alban.waitForTimeout(300);
  await alban.click('[data-renfam]'); await alban.fill('#fam-nom', 'Famille Bavière'); await alban.click('#fam-go'); await alban.waitForTimeout(500);
  console.log('alban :', JSON.stringify(await vue(alban)));
  await choisir(alban, 'Hugues');
  console.log('alban, menu sur Hugues :', JSON.stringify(await vue(alban)));
  await alban.screenshot({ path: S + 'fam-menu.png' });
  await alban.reload(); await alban.waitForSelector('#view-home:not([hidden])'); await alban.waitForTimeout(500);
  console.log('après rechargement :', (await vue(alban)).famille);

  const code = nom => sqlv(`select i.code from famille_invitations i join familles f on f.id = i.famille_id where f.nom = '${nom}'`);
  const tonton = await mk(390, 844);
  await tonton.goto(URL + '#rejoindre=' + code('Famille Bavière')); await tonton.waitForSelector('#scr-auth:not([hidden])'); await signup(tonton, 'Tonton', 'tonton@f.fr');
  console.log('tonton :', JSON.stringify(await vue(tonton)));
  const doro = await mk(390, 844);
  await doro.goto(URL + '#rejoindre=' + code('Famille Hugues')); await doro.waitForSelector('#scr-auth:not([hidden])'); await signup(doro, 'Dorothée', 'doro@f.fr');
  console.log('dorothée :', JSON.stringify(await vue(doro)));

  // Ajouts séparés par famille, et nom de l'onglet « sans marque »
  await ouvre(alban, 'Hugues', 'Crèche de Lucie');
  console.log('onglet :', (await alban.textContent('#tab-autres .type')), '| rubrique', await alban.evaluate(() => document.querySelector('#tab-autres').textContent.replace(/\s+/g, ' ').trim()));
  await alban.click('#tab-autres'); await alban.click('[data-addautre]');
  console.log('dialogue :', await alban.textContent('#add-title'), '|', await alban.$eval('#add-marque', e => e.selectedOptions[0].textContent));
  await alban.fill('#add-nom', 'Berger artisan'); await alban.click('#add-go'); await alban.waitForTimeout(900);
  console.log('rubrique :', (await alban.locator('.sec h2').allTextContents()).join(', '));
  await alban.screenshot({ path: S + 'fam-pauvres.png' });
  await ouvre(tonton, 'Bavière', 'Crèche du beau-frère');
  await tonton.click('#tab-autres'); await tonton.click('[data-addautre]');
  await tonton.fill('#add-nom', 'Moulin Bavière'); await tonton.selectOption('#add-type', 'decor'); await tonton.click('#add-go'); await tonton.waitForTimeout(900);
  console.log('tonton, sa crèche : Berger artisan', await cherche(tonton, 'autres', 'Berger artisan'), '| Moulin Bavière', await cherche(tonton, 'autres', 'Moulin Bavière'));
  await ouvre(doro, 'Hugues', 'Crèche de Lucie');
  console.log('dorothée, sa crèche : Berger artisan', await cherche(doro, 'autres', 'Berger artisan'), '| Moulin Bavière', await cherche(doro, 'autres', 'Moulin Bavière'));
  await ouvre(alban, 'Bavière', 'Crèche du beau-frère');
  console.log('alban, crèche Bavière : Berger artisan', await cherche(alban, 'autres', 'Berger artisan'), '| Moulin Bavière', await cherche(alban, 'autres', 'Moulin Bavière'));
  const lit = mail => sqlv(`select set_config('request.jwt.claim.sub', (select id::text from auth.users where email = '${mail}'), false); set role authenticated; select string_agg(nom, ', ' order by nom) from modeles_famille`).split('\n').pop();
  console.log('base, lisible par Tonton :', lit('tonton@f.fr'), '| par Dorothée :', lit('doro@f.fr'), '| par Alban :', lit('alban@f.fr'));
  console.log('erreurs:', errs); await b.close();
})();
