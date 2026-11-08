const { chromium } = require('playwright');
const { execSync } = require('child_process');
const S = (process.env.SCRATCH || '/tmp') + '/';  // dossier des captures et de creche.jpg
const URL = 'http://localhost:8766/index.html';
const sqlv = q => execSync(`psql -h /tmp -p 54329 -U postgres -d app -tA -c "${q}"`).toString().trim();
const log = (...a) => console.log(...a);
async function page(b, name, w = 1280, h = 900) {
  const ctx = await b.newContext({ viewport: { width: w, height: h } });
  const p = await ctx.newPage();
  p.on('pageerror', e => log(`[${name}] PAGEERR`, e.message));
  p.on('console', m => { if (m.type() === 'error' && !/realtime|websocket|404/i.test(m.text())) log(`[${name}] console`, m.text()); });
  return p;
}
async function signup(p, nom, mail) {
  await p.click('[data-mode="up"]');
  await p.fill('#a-nom', nom); await p.fill('#a-mail', mail); await p.fill('#a-pass', 'secret123');
  await p.click('#auth-go'); await p.waitForSelector('#scr-app:not([hidden])', { timeout: 10000 });
  await p.waitForTimeout(500);
}
(async () => {
  const b = await chromium.launch();
  // ---- Papa
  const papa = await page(b, 'papa');
  await papa.goto(URL); await papa.waitForSelector('#scr-auth:not([hidden])');
  await papa.screenshot({ path: S + 'e-auth.png' });
  await signup(papa, 'Papa', 'papa@x.fr');
  log('papa accueil:', (await papa.textContent('#view-home')).replace(/\s+/g, ' ').slice(0, 120));
  await papa.click('#create-family'); await papa.fill('#fam-nom', 'Famille Dupont'); await papa.click('#family-form button[type=submit]');
  await papa.waitForTimeout(600);
  await papa.click('[data-newlist]'); await papa.fill('#new-nom', 'Crèche de Léa'); await papa.click('#new-form button[type=submit]');
  await papa.waitForSelector('#view-list:not([hidden])'); await papa.waitForTimeout(400);
  await papa.locator('.card .ic.o').nth(0).click(); await papa.locator('.card .ic.o').nth(1).click(); await papa.locator('.card .ic.w').nth(4).click();
  await papa.waitForTimeout(500);
  log('items en base:', sqlv("select count(*) from liste_items"), '| prog', await papa.textContent('#prog-txt'));
  // photo de la crèche installée
  log('papa : invitation photo', await papa.isVisible('#cover.empty'));
  await papa.setInputFiles('#cover-roll', S + 'creche.jpg'); await papa.waitForTimeout(1200);
  log('photo en base:', sqlv("select photo from listes where nom='Crèche de Léa'").replace(/[0-9a-f-]{36}/g, '…'),
      '| affichée:', await papa.evaluate(() => { const i = document.querySelector('#cover-img'); return !!i && i.complete && i.naturalWidth > 0; }));
  await papa.screenshot({ path: S + 'e-list.png' });
  // réglages : lien visiteur
  await papa.click('#l-settings'); await papa.waitForTimeout(300);
  const visit = await papa.inputValue('#visit-link'); log('lien visite:', visit.replace(/[0-9a-f]{20,}/, '…'));
  await papa.screenshot({ path: S + 'e-settings.png' });
  await papa.click('#dlg-settings [data-close]');
  const join = URL + '#rejoindre=' + sqlv('select code from famille_invitations');
  // ---- Maman rejoint
  const maman = await page(b, 'maman', 390, 844);
  await maman.goto(join); await maman.waitForSelector('#scr-auth:not([hidden])');
  log('bandeau maman:', await maman.textContent('#auth-invite'));
  await signup(maman, 'Maman', 'maman@x.fr');
  log('maman accueil:', (await maman.textContent('#view-home')).replace(/\s+/g, ' ').slice(0, 160));
  await maman.click('.lcard[data-list]'); await maman.waitForTimeout(400);
  log('maman badge:', await maman.textContent('#l-badge'), '| boutons ✓ actifs:', await maman.locator('.card .ic.o:not([disabled])').count(),
      '| photo vue', await maman.locator('#cover-img').count(), '| peut la changer', await maman.locator('#cover-cam').count());
  // Papa ajoute Maman gérante
  await papa.click('#l-settings'); await papa.waitForTimeout(300);
  const mamanId = sqlv("select id from auth.users where email='maman@x.fr'");
  await papa.check(`[data-gerant="${mamanId}"]`); await papa.waitForTimeout(800);
  await papa.click('#dlg-settings [data-close]');
  await maman.reload(); await maman.waitForSelector('#view-list:not([hidden])'); await maman.waitForTimeout(500);
  log('maman après ajout gérante:', await maman.textContent('#l-badge'), await maman.locator('.card .ic.o:not([disabled])').count());
  await maman.locator('.card .ic.o').nth(10).click(); await maman.waitForTimeout(500);
  log('maman a coché ->', sqlv("select p.nom from liste_items i join profils p on p.id=i.modifie_par order by updated_at desc limit 1"));
  await maman.screenshot({ path: S + 'e-maman.png' });
  // ---- Mamie : page publique, sans compte
  const mamie = await page(b, 'mamie', 390, 844);
  await mamie.goto(visit); await mamie.waitForSelector('#scr-app:not([hidden])', { timeout: 10000 }); await mamie.waitForTimeout(500);
  log('mamie sans compte : écran connexion ?', await mamie.isVisible('#scr-auth'), '| crèche :', await mamie.textContent('#l-name'),
      '|', await mamie.textContent('#l-who'), '|', await mamie.textContent('#l-badge'));
  log('mamie : ✓ actifs', await mamie.locator('.card .ic.o:not([disabled])').count(), '| cochés visibles', await mamie.locator('.card.own').count(),
      '| réglages', await mamie.isVisible('#l-settings'), '| photo crèche', await mamie.evaluate(() => { const i = document.querySelector('#cover-img'); return !!i && i.naturalWidth > 0; }), '| boutons photo', await mamie.locator('#cover-cam').count(), '| espace famille', await mamie.isVisible('#famille-link'));
  await mamie.screenshot({ path: S + 'e-mamie.png' });
  // lien changé : l'ancien ne marche plus
  await papa.click('#l-settings'); await papa.waitForTimeout(300); await papa.click('#new-visit'); await papa.waitForTimeout(500);
  await papa.click('#dlg-settings [data-close]');
  const vieux = await page(b, 'vieux-lien', 390, 844);
  await vieux.goto(visit); await vieux.waitForTimeout(1500);
  log('ancien lien :', (await vieux.textContent('#scr-config')).replace(/\s+/g, ' ').trim());
  // ---- Papa : accueil avec activité
  await papa.click('#back'); await papa.reload(); await papa.waitForTimeout(800);
  await papa.screenshot({ path: S + 'e-home.png', fullPage: true });
  log('papa : vignette sur la carte', await papa.locator('.lcard .lthumb').count());
  log('papa activité:', (await papa.textContent('.feed')).replace(/\s+/g, ' ').slice(0, 200));
  await b.close();
})().catch(e => { console.error('ECHEC', e); process.exit(1); });
