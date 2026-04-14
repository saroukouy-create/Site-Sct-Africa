# SCT Africa

Site vitrine et scripts de deploiement pour SCT Africa.

## Contenu principal

- `index.html`, `style.css`, `script.js` : version locale maitre du site.
- `prepare_deploy.ps1` : prepare le package de publication.
- `Executer-Mise-En-Ligne.cmd` : lance le flux de mise en ligne.
- `Publier-Site-Final.cmd` : publication finale vers l'hebergement.
- `Images/` : images locales necessaires au site.

## Dossiers exclus de Git

Les elements suivants ne sont pas sauvegardes dans Git pour eviter les secrets et les artefacts volumineux :

- `.secrets/`
- `deploy/`
- `public_html/`
- `downloaded_site_full_latest_cfe/`

## Deploiement

Pour publier le site :

1. Executer `Executer-Mise-En-Ligne.cmd`
2. Verifier le site publie sur `https://sct-africa.site/`

## Sauvegarde GitHub

Le depot distant configure est :

- `https://github.com/saroukouy-create/Site-Sct-Africa.git`

Pour sauvegarder rapidement vos modifications :

1. Ouvrir `Sauvegarder-GitHub.cmd`
2. Entrer un message de commit ou laisser le message automatique
3. Le script fait `add`, `commit` et `push`

Vous pouvez aussi lancer le script depuis le terminal :

```bat
Sauvegarder-GitHub.cmd
Sauvegarder-GitHub.cmd Mise a jour du site
```