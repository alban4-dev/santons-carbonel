const { chromium } = require('playwright');
// Ajout d'un santon ancien avec photo : catalogue de la famille, coche, page publique, retrait.
const { execSync } = require('child_process');
const S = (process.env.SCRATCH || '/tmp') + '/';  // captures et creche.jpg
const sqlv = q => execSync(`psql -h /tmp -p 54329 -U postgres -d app -tA -c "${q}"`).toString().trim();
(async () => {
  const b = await chromium.launch(); const errs = [];
  const mk = async (w, h) => { const p = await (await b.newContext({ viewport: { width: w, height: h } })).newPage(); p.on('pageerror', e => errs.push(e.message)); return p; };
  const signup = async (p, nom, mail) => { await p.click('[data-mode="up"]'); await p.fill('#a-nom', nom); await p.fill('#a-mail', mail); await p.fill('#a-pass', 'secret123'); await p.click('#auth-go'); await p.waitForSelector('#scr-app:not([hidden])'); await p.waitForTimeout(400); };
  const papa = await mk(1280, 900);
  await papa.goto('http://localhost:8766/index.html'); await papa.waitForSelector('#scr-auth:not([hidden])');
  await signup(papa, 'Papa', 'p@x.fr');
  await papa.click('#create-family'); await papa.fill('#fam-nom', 'Famille'); await papa.click('#family-form button[type=submit]'); await papa.waitForTimeout(400);
  await papa.click('[data-newlist]'); await papa.fill('#new-nom', 'Crèche de Léa'); await papa.click('#new-form button[type=submit]');
  await papa.waitForSelector('#view-list:not([hidden])'); await papa.waitForTimeout(300);
  console.log('bouton visible :', await papa.isVisible('#l-add'));
  await papa.click('#l-add');
  await papa.fill('#add-nom', 'Berger ancien à la houlette'); await papa.fill('#add-note', 'acheté en 1994, N°2');
  await papa.setInputFiles('#add-photo', S + 'creche.jpg'); await papa.waitForTimeout(500);
  await papa.screenshot({ path: S + 'aj-dialog.png' });
  await papa.click('#add-go'); await papa.waitForTimeout(1200);
  console.log('base :', sqlv("select id||' '||nom||' '||section||' '||coalesce(photo,'-') from modeles_famille"), '| coché :', sqlv("select statut from liste_items where santon_id >= 1000000"));
  console.log('groupes :', (await papa.locator('.sec h2').allTextContents()).slice(-2).join(' | '), '| prog', await papa.textContent('#prog-txt'));
  const card = papa.locator('.card .ajout').first();
  console.log('vignette famille :', await papa.locator('.card .ajout').count(), '| photo :', await papa.locator('.ph.photo').count());
  await papa.screenshot({ path: S + 'aj-grille.png' });
  await papa.locator('.ph.photo').first().click(); await papa.waitForTimeout(500);
  console.log('fiche :', (await papa.textContent('#item-body')).replace(/\s+/g, ' ').slice(0, 220));
  const imgOk = await papa.evaluate(() => { const i = document.querySelector('#item-body img'); return i && i.complete && i.naturalWidth > 0; });
  console.log('photo de la fiche chargée :', imgOk);
  // photo de dos, puis remplacement de la face
  await papa.click('#item-body [data-slot="1"]'); await papa.waitForTimeout(200);
  await papa.setInputFiles('#item-body input[data-up="1"]:not([capture])', S + 'creche.jpg'); await papa.waitForTimeout(1200);
  const avant = sqlv("select photos[1] from modeles_famille");
  await papa.click('#item-body [data-slot="0"]'); await papa.waitForTimeout(200);
  await papa.setInputFiles('#item-body input[data-up="0"]:not([capture])', S + 'creche.jpg'); await papa.waitForTimeout(1200);
  console.log('photos :', sqlv("select array_to_string(array(select coalesce(regexp_replace(x, '.*/', ''), '-') from unnest(photos) x), ' | ') from modeles_famille").replace(/[0-9a-f-]{36}/g, '…'),
    '| face remplacée', sqlv("select photos[1] from modeles_famille") !== avant, '| vignette = face', sqlv("select photo = photos[1] from modeles_famille"),
    '| cases', await papa.locator('#item-body .slot').count(), 'dont remplies', await papa.locator('#item-body .slot:not(.vide)').count());
  await papa.screenshot({ path: S + 'aj-fiche.png' });
  await papa.keyboard.press('Escape');
  // page publique
  await papa.click('#l-settings'); await papa.waitForTimeout(300); const visit = await papa.inputValue('#visit-link'); await papa.click('#dlg-settings [data-close]');
  const pub = await mk(390, 844); await pub.goto(visit); await pub.waitForSelector('#scr-app:not([hidden])'); await pub.waitForTimeout(500);
  await pub.click('[data-status="own"]'); await pub.waitForTimeout(200);
  await pub.locator('.ph.photo').first().click(); await pub.waitForTimeout(300);
  console.log('public, fiche : cases', await pub.locator('#item-body .slot').count(), '| boutons photo', await pub.locator('#item-body input[data-up]').count());
  await pub.screenshot({ path: S + 'aj-public-fiche.png' });
  await pub.keyboard.press('Escape');
  console.log('public, cochés :', (await pub.locator('.card .nm').allTextContents()).join(', '), '| bouton ajout :', await pub.isVisible('#l-add'));
  // Maman (membre) voit le modèle
  const join = 'http://localhost:8766/index.html#rejoindre=' + sqlv("select fi.code from famille_invitations fi join familles f on f.id = fi.famille_id join auth.users u on u.id = f.cree_par where u.email = 'p@x.fr'");
  const maman = await mk(390, 844); await maman.goto(join); await maman.waitForSelector('#scr-auth:not([hidden])'); await signup(maman, 'Maman', 'm@x.fr');
  await maman.click('.lcard[data-list]'); await maman.waitForTimeout(400);
  console.log('maman voit :', await maman.locator('.card .ajout').count(), '| bouton ajout :', await maman.isVisible('#l-add'));
  await maman.locator('.ph.photo').first().click(); await maman.waitForTimeout(300);
  await maman.click('#item-body [data-slot="2"]'); await maman.waitForTimeout(200);
  await maman.setInputFiles('#item-body input[data-up="2"]:not([capture])', S + 'creche.jpg'); await maman.waitForTimeout(1200);
  console.log('maman ajoute le côté :', sqlv("select photos[3] is not null from modeles_famille"));
  await maman.screenshot({ path: S + 'aj-maman.png' });
  await maman.keyboard.press('Escape');
  // Papa retire
  await papa.locator('.ph.photo').first().click(); await papa.waitForTimeout(300);
  await papa.click('[data-unmodel]'); await papa.click('[data-unmodel]'); await papa.waitForTimeout(1000);
  console.log('après retrait :', sqlv('select count(*) from modeles_famille'), sqlv('select count(*) from liste_items where santon_id >= 1000000'), '| vignettes famille :', await papa.locator('.card .ajout').count());
  // onglet « Autres » : un bâtiment d'artisan acheté sur un marché
  await papa.click('#cats [data-tab="autres"]'); await papa.waitForTimeout(300);
  console.log('autres, vide :', (await papa.textContent('#grid')).replace(/\s+/g, ' ').trim().slice(0, 70), '| bouton', await papa.textContent('#l-add'));
  await papa.click('[data-addautre]'); await papa.waitForTimeout(200);
  console.log('dialogue :', await papa.textContent('#add-title'), '| marque', await papa.inputValue('#add-marque'));
  await papa.fill('#add-nom', 'Moulin du marché de Noël'); await papa.selectOption('#add-type', 'decor'); await papa.fill('#add-note', 'artisan de Lourmarin, 2019');
  await papa.click('#add-go'); await papa.waitForTimeout(1000);
  console.log('autres :', sqlv("select nom||' '||marque||' '||section from modeles_famille where marque = 'Autre'"),
    '| catalogue', await papa.getAttribute('#cats [aria-pressed="true"]', 'data-tab'), '| rubrique', (await papa.locator('.sec h2').allTextContents()).join(', '),
    '| menu', await papa.textContent('#cats [aria-pressed="true"]'));
  await papa.click('#cats [data-tab="decor"]'); await papa.waitForTimeout(200);
  console.log('pas dans Décors Carbonel :', await papa.locator('.card .ajout').count() === 0);
  await papa.click('#cats [data-tab="autres"]'); await papa.waitForTimeout(200);
  await papa.screenshot({ path: S + 'aj-autres.png' });
  console.log('erreurs:', errs); await b.close();
})();
