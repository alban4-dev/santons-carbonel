const { chromium } = require('playwright');
// Plusieurs familles : Papa crée une deuxième famille (côté de ses parents) et y invite Tonton ;
// Tonton ne voit que celle-là, Maman que la première, Papa les deux.
const { execSync } = require('child_process');
const S = (process.env.SCRATCH || '/tmp') + '/';
const URL = 'http://localhost:8766/index.html';
const sqlv = q => execSync(`psql -h /tmp -p 54329 -U postgres -d app -tA -c "${q}"`).toString().trim();
(async () => {
  const b = await chromium.launch(); const errs = [];
  const mk = async (w, h) => { const p = await (await b.newContext({ viewport: { width: w, height: h } })).newPage(); p.on('pageerror', e => errs.push(e.message)); return p; };
  const signup = async (p, nom, mail) => { await p.click('[data-mode="up"]'); await p.fill('#a-nom', nom); await p.fill('#a-mail', mail); await p.fill('#a-pass', 'secret123'); await p.click('#auth-go'); await p.waitForSelector('#scr-app:not([hidden])'); await p.waitForTimeout(500); };
  const familles = async p => (await p.locator('.fam-head h2').allTextContents()).join(' + ');
  const papa = await mk(1280, 900);
  await papa.goto(URL); await papa.waitForSelector('#scr-auth:not([hidden])'); await signup(papa, 'Alban', 'alban@f.fr');
  await papa.click('#create-family'); await papa.fill('#fam-nom', 'Famille de Dorothée'); await papa.click('#fam-go'); await papa.waitForTimeout(500);
  await papa.click('[data-newlist]'); await papa.fill('#new-nom', 'Crèche de Lucie'); await papa.click('#new-form button[type=submit]'); await papa.waitForTimeout(500);
  await papa.click('#back'); await papa.waitForTimeout(300);
  // une autre famille
  console.log('bouton autre famille :', await papa.textContent('#create-family'));
  await papa.click('#create-family'); console.log('titre :', await papa.textContent('#fam-title'));
  await papa.fill('#fam-nom', 'Famille Martin'); await papa.click('#fam-go'); await papa.waitForTimeout(600);
  await papa.locator('[data-newlist]').nth(1).click(); await papa.fill('#new-nom', 'Crèche du beau-frère'); await papa.click('#new-form button[type=submit]'); await papa.waitForTimeout(500);
  await papa.click('#back'); await papa.waitForTimeout(300);
  // renommer
  await papa.locator('[data-renfam]').nth(1).click(); await papa.fill('#fam-nom', 'Famille Martin (côté Alban)'); await papa.click('#fam-go'); await papa.waitForTimeout(500);
  console.log('papa voit :', await familles(papa), '| crèches', (await papa.locator('.lcard[data-list] h3').allTextContents()).join(', '));
  await papa.screenshot({ path: S + 'fam-papa.png', fullPage: true });
  const code = nom => sqlv(`select i.code from famille_invitations i join familles f on f.id = i.famille_id where f.nom = '${nom}'`);
  const tonton = await mk(390, 844);
  await tonton.goto(URL + '#rejoindre=' + code('Famille Martin (côté Alban)')); await tonton.waitForSelector('#scr-auth:not([hidden])'); await signup(tonton, 'Tonton', 'tonton@f.fr');
  console.log('tonton voit :', await familles(tonton), '| crèches', (await tonton.locator('.lcard[data-list] h3').allTextContents()).join(', '));
  const maman = await mk(390, 844);
  await maman.goto(URL + '#rejoindre=' + code('Famille de Dorothée')); await maman.waitForSelector('#scr-auth:not([hidden])'); await signup(maman, 'Dorothée', 'doro@f.fr');
  console.log('maman voit :', await familles(maman), '| crèches', (await maman.locator('.lcard[data-list] h3').allTextContents()).join(', '));
  // Ajouts séparés par famille
  const cherche = async (p, tab, q) => { await p.click('#tab-' + tab); await p.fill('#q', q); await p.waitForTimeout(400); const n = await p.locator('.card').count(); await p.fill('#q', ''); await p.waitForTimeout(200); return n; };
  const ouvre = async (p, nom) => { await p.goto(URL); await p.waitForSelector('#view-home:not([hidden])'); await p.waitForTimeout(500); await p.click(`.lcard[data-list]:has-text("${nom}")`); await p.waitForTimeout(500); };
  await ouvre(papa, 'Crèche de Lucie');
  await papa.click('#l-add'); await papa.fill('#add-nom', 'Berger de Dorothée'); await papa.click('#add-go'); await papa.waitForTimeout(900);
  await ouvre(tonton, 'Crèche du beau-frère');
  await tonton.click('#tab-autres'); await tonton.waitForTimeout(200); await tonton.click('[data-addautre]');
  await tonton.fill('#add-nom', 'Moulin Martin'); await tonton.selectOption('#add-type', 'decor'); await tonton.click('#add-go'); await tonton.waitForTimeout(900);
  console.log('tonton, sa crèche : Berger de Dorothée', await cherche(tonton, 'santons', 'Berger de Dorothée'), '| Moulin Martin', await cherche(tonton, 'autres', 'Moulin Martin'));
  await ouvre(maman, 'Crèche de Lucie');
  console.log('dorothée, sa crèche : Berger de Dorothée', await cherche(maman, 'santons', 'Berger de Dorothée'), '| Moulin Martin', await cherche(maman, 'autres', 'Moulin Martin'));
  await ouvre(papa, 'Crèche du beau-frère');
  console.log('alban, crèche Martin : Berger de Dorothée', await cherche(papa, 'santons', 'Berger de Dorothée'), '| Moulin Martin', await cherche(papa, 'autres', 'Moulin Martin'));
  await ouvre(papa, 'Crèche de Lucie');
  console.log('alban, crèche Lucie : Berger de Dorothée', await cherche(papa, 'santons', 'Berger de Dorothée'), '| Moulin Martin', await cherche(papa, 'autres', 'Moulin Martin'));
  const lit = mail => sqlv(`select set_config('request.jwt.claim.sub', (select id::text from auth.users where email = '${mail}'), false); set role authenticated; select string_agg(nom, ', ' order by nom) from modeles_famille`).split('\n').pop();
  console.log('base, lisible par Tonton :', lit('tonton@f.fr'), '| par Dorothée :', lit('doro@f.fr'), '| par Alban :', lit('alban@f.fr'));
  console.log('onglet :', (await papa.textContent('#tab-autres')).replace(/\s+/g, ' ').trim());
  console.log('erreurs:', errs); await b.close();
})();
