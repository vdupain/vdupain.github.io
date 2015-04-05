---
layout: post
title: Migration de Svn vers Git
comments: true
permalink: "migration-svn-git"
---

Etant actuellement en train de réaliser une migration de Subversion vers Git dans mon entreprise, cette article vise à expliquer la démarche ainsi que le mode opératoire.

  
## Pourquoi changer de gestionnaire de source?
Plusieurs raisons nous ont poussé à changer de gestionnaire de source et plus particulièrement à choisir Git:

* mode distribué favorisant la collaboration entre les développeurs
* modernisation de l’usine logicielle
* puissance de Git notamment dans les flux de travail
* besoin d’une meilleure gouvernance sur cette usine logicielle et notamment le cloisonnement des données entre projets: cloisonnement  des dépôts de code source, regroupement de ces dépôts par application, gestion des habilitations par groupe sur ces dépôts, normalisation du flux de travail avec le gestionnaire de source.
 
## Contexte organisationnel et technique
L'activité de développement était apparavant réalisée par les équipes etudes. Aujourd'hui des centres de services ont été mis en place pour réaliser les développements, alors que les équipes études sont désormais en charge des spécifications.

Ces centres de services peuvent sous-traités à des prestataires externes. Enfin une fois les développements terminés, le code est validé et intégré par les équipes études.

On voit donc émerger des besoins de code review, de process de validation/approbation et d'un workflow nécessaire dans ce contexte.

Le contexte technique est le suivant:

* usine logicielle s'appuyant sur les outils Atlassian Crowd, JIRA, Confluence, Fisheye/Crucible
* Subversion, Nexus, Jenkins (2 masters, 12 slaves)
* principalement des projets Java/JEE 6 avec stack Spring/Hibernate
* outil de build maven 3.x.
* IDE Eclipse, IntelliJ et ligne de commande
* environ. 150-200 développeurs impactés par cette migration
* layout standard svn (trunk/branches/tags) pas toujours respecté
(généralement des features ou release branches, des branches de maintenances et un trunk pour le développement)
* demande de la Production à virtualiser l’usine logicielle

Quelques métriques:

* 7 serveurs (4 physiques et 3 virtuels)
* 22 Go de code sources (plus de 10 ans d’historique dans SVN)
plus de 200 dépôts dans SVN
* 1,2 To de binaires snapshots et release dans le dépôt de binaires Nexus
* 560 jobs d’intégration continue et 170 jobs Sonar
* 18 millions de lignes de code analysé par Sonar et 175 projets dans Sonar
* indexation des dépôts de code source avec Fisheye

## Les contraintes

Les impacts et la coupure de service doivent être minimes pour les développeurs mais il y a forcément une coupure de service à prévoir lors de la bascule.
La migration doit être la plus transparente possible et ne doit pas perturber le fonctionnement actuel de l'usine, ni bloquer les développements en cours: releasing, commit sur subversion, jobs CI, etc...

## Procédure de migration
l'objectif est donc de migrer les dépôts de code source actuellement dans Subversion vers le gestionnaire de source décentralisé Git.
Cette migration aura donc lieu en plusieurs étapes:

1. Etape préparatoire à la migration
2. Etape intermédiaire: Câblage de certains services de l'Usine sur Git. Pas d'impact pour les développeurs
3. Etape finale: bascule vers Git. Impact pour les développeurs

Ces différentes étapes de migration sont décrites plus en détail ci-dessous.
La migration des dépôts Subversion se fera a fil de l'eau, dépôt par dépôt.

## Etape 1: préparation à la migration
La 1ère étape ne modifie en rien le fonctionnement de l'usine logicielle, du poste développeur ainsi que des composants techniques 
(pom parent maven utilisé par tous les projets Java).

Les habitudes de travail des développeurs ne sont donc pas modifiées et ils continuent à utiliser Subversion.

![](/assets/migration-svn-git/avant_migration_svn_git.png)

Cette étape est l'étape préparatoire, elle consiste à lever les incertitudes et à préparer l'usine à s'interfacer avec Git:

* analyse d'impact: état des lieux de l'utilisation de Subversion de bout en bout (outillage, serveurs, services, pom maven, plugins, etc...) pour identifier tous les impacts et les composants concernés
* installation d'un serveur Git Stash (GitHub like) qui hébergera les dépôts Git. Le choix s'est porté naturellement sur Git Stash étant donné que nous avons déjà tous logiciels Atlassian
* installation de client Git en version 1.9.x sur les différents serveurs (RHEL 5.x et 6.x) de l'usine qui auront besoin d'un client Git: noeuds de build Jenkins notamment.
* conversion des commiters SVN en users Git
* script de conversion et de mirroring d'un dépôt SVN vers un dépôt Git (pas de synchronisation bi-directionnelle).

La mise en oeuvre de Subversion au sein de l'usine logicielle est standard:

* 2 serveurs SVN:
1. un serveur SVN principal utilisé par les développeurs et par l'intragration continue (jobs Jenkins). Les dépôts SVN de ce serveur sont en lecture/écriture.
2. un serveur SVN mirroir (synchronisation toutes les 10mn, dépôt en lecture seule) sur lequel Fisheye est connecté: cela évite une trop forte sollicitation du serveur SVN principal lors de l'indexation des dépôts de code source.
* sur le poste développeur: client Subversion intégré à Eclipse et IntelliJ, un client GUI/CLI TortoiseSVN.
* socle technique JEE : un pom parent maven dans lequel les plugins maven maven-release-plugin et maven-buildnumber-plugin sont compatibles et configurés pour fonctionner avec Subversion (1.7.x et 1.8.x)
* release via maven et le plugin maven-release-plugin. Les releases sont exécutées depuis l'usine et non sur le poste développeur.


### Conversion des commiters SVN en users Git
Il faut s'assurer de récupérer tous les commiters SVN pour le mapping avec les commiters Git.
L'import initial (git svn clone) doit être lancé avec le fichier ( --authors-file $AUTHORS_FILE) des commiters Git qui mappent donc les commiters svn.

En effet ce fichier sera utilisé pour les commentaires de commit Git lors de la reprise de l'historique ou pour la synchro svn git.
Le fichier authors attendu par Git a le format suivant:

```
SVN-USERNAME = Author name <email>
```

Un script a été installé sur le serveur Crowd (connecté à un annuaire LDAP également utilisé pour les comptes SVN) pour exécuter une requête sur la base de données Crowd afin de lister tous les users et réaliser la conversion dans le format attendu par Git:

```bash
#!/bin/bash
mysql -h localhost -u crowd -p**** CROWD --skip-column-names -e \
"SELECT CONCAT(user_name,\" = \",user_name,\" \",'<',lower_email_address,'>') FROM cwd_user WHERE TRIM(IFNULL(lower_email_address,'')) <> '' ORDER BY created_date DESC" \
> /data1/www/crowd/htdocs/crowd-users.txt
```

Ce script est exécuté automatiquement avec cron toutes les heures.
Ce fichier est ensuite acessible et téléchargeable en http et sera  utilisé par le script de mirroring des dépôts SVN vers Git.

### Script de conversion et de mirroring d'un dépôt SVN vers un dépôt Git
Le script de mirroring des dépôts SVN vers Git est finalement assez simple:

* en paramètre du script:
	1. répertoire pour stocker le dépôt mirroir Git
	2. URL du dépôt SVN (serveur SVN mirroir)
	3. URL du dépôt Git distant (serveur Git Stash)
	4. En option le layout SVN (trunk/branches/tags par défaut)

* Clonage du dépôt SVN en un dépôt Git (git clone svn). Si le dépôt Git mirroir existe déjà on le synchronise (git svn fetch). Attention au layout SVN et au credential svn si besoin.

```bash
if [ ! -d "${SVN_CLONE}" ];
then
  echo "First run, doing a full git-svn clone, this may take a while..."
  git svn clone --no-metadata --prefix="svn/" "${SVN_REPO}" -A "${AUTHORS_FILE}" ${SVN_LAYOUT} "${SVN_CLONE}"
  cd "${SVN_CLONE}"
else
  echo "git-svn clone already exists, doing a rebase..."
  cd "${SVN_CLONE}"
  git remote rm bare || echo "failed to delete remote:bare, proceeding anyway"
  git svn fetch --fetch-all -A "${AUTHORS_FILE}"
fi
```

* Création d’un dépôt Git nu (bare) pour y pousser le code du dépôt Git mirroir du SVN

```
cd "${GIT_BARE}"
git init --bare .
git symbolic-ref HEAD refs/heads/svn/trunk
```

* Le dépôt Git mirroir est poussé dans le dépôt nu Git

```
cd "${SVN_CLONE}"
git push bare
```

* Renommage de la branche trunk en master pour respecter les conventions Git

```
git branch -m svn/trunk master
```

* Transformation des tags SVN en tag au sens Git (annotated tag), en effet lors d’un clonage d’un dépôt SVN en dépôt Git avec la commande git svn clone, les tags SVN deviennent des branches Git et non des tags.

```bash
git for-each-ref --format='%(refname)' refs/heads/svn/tags | cut -d / -f 5 |  while read ref; do
  echo "converting "$ref" to proper git tag \"refs/heads/svn/tags/$ref\"";
  git tag -a "$ref" -m "Convert "$ref" to proper git tag." "refs/heads/svn/tags/$ref";
  git branch -D "svn/tags/$ref"
done
```

* Renommage des branches, notamment pour supprimer le préfixe « svn » lié au préfixe positionné lors du git svn clone (d’ailleurs en Git 2.x le préfixe vaut « origin » et non plus "" (pas de préfixe).
 
* Nettoyage des tags et des branches inexistantes dans le dépôt SVN cloné. Récupérer des tags ou branches supprimés de Subversion ne nous intéresse pas.

```bash
git tag -l | while read tag ; do
  set -e
  echo "check tag '"${tag}"'" 
  set +e
  svn ls ${SVN_REPO}/${SVN_TAGS}/${tag} > /dev/null 2>&1 
  if [ "$?" -ne 0 ]; then
    echo "Tag '"${tag}"' doesn't exist anymore, will remove it from git repository."
    set -e
    git tag -d ${tag}
  fi
done
...
git branch --list "svn/*" | cut -d / -f 2 | while read branch ; do
  set -e
  echo "renaming and checking branch '"${branch}"'" 
  git branch -m "svn/${branch}" "${branch}"
  set +e
  svn ls ${SVN_REPO}/${SVN_BRANCHES}/${branch} > /dev/null 2>&1 
  if [ "$?" -ne 0 ]; then
    set -e
    echo "Branch '"${branch}"' doesn't exist anymore, will remove it from git repository."
    git branch -D ${branch}
  fi
done
```

* Appel au git gc pour faire le ménage et compresser le dépôt Git

```
git gc --aggressive --prune=now;
```

* Enfin le dépôt nu Git est poussé sur le serveur Git, avec le paramètre —force car des branches ou tags ont pu être supprimés depuis la dernière synchronisation:

```bash
git remote add origin "${GIT_REPO}"
git push origin --force --all --prune # pushes all refs under refs/heads
git push origin --force --tags --prune # pushes all refs under refs/tags
```

Voila à ce stade, la synchro one-way fonctionne correctement, il n'y a plus qu'à automatiser la synchro de quelques dépôts et passer à l'étape suivante pour vraiment commencer à utiliser nos dépots Git.

## Etape 2: Câblage de certains services de l'Usine sur Git
Git est mis en place dans l'usine logicielle et est opérationnel. On commence à câbler certains services de l'Usine vers Git.
Il n'y a pas d'impact pour les développeurs: ils utilisent le gestionnaire de source SVN comme d'habitude.
Les dépôts de code source SVN sont clonés en dépôts Git et sont synchronisés tous les heures.

![](/assets/migration-svn-git/etape_intermediaire_migration_svn_git.png)

* Les jobs Sonar sont configurés pour extraire le code depuis les dépots Git et non plus SVN.
* Fisheye indexe les dépôts Git mirroir plutôt que les dépôts SVN.

Cela permet de tester l'infrastucture, les outils et commencer à roder la mécanique et voir les problèmes que l'on peut rencontrer (par exemple jobs Sonar en échec à cause d'un un build maven qui utilise le plugin maven-buildnumer-plugin qui récupére la révision de SVN, et qui donc ne fonctionne plus depuis Git).

Une fois la validation terminée, on passe à l'étape finale: la bascule complète vers Git.

## Etape 3: bascule vers Git
Le jour de la bascule, la procédure à suivre est la suivante:

1. code freeze
2. dernier commit dans le dépôt SVN
3. dernière synchronisation de svn vers le dépôt Git
4. nettoyage du dépôt Git final (suppression de branches ou tags)
5. mettre les habilitations du dépôts Git sur le serveur Git Stash
6. recâblage des outils vers le dépôt Git (git clone sur les postes  développeurs et modif des SCM dans les jobs jenkins)
7. validation d'un build de release: présence du tag dans Git, pom maven mis à jour
8. l'ancien dépôt SVN est mis en lecture seule (plus de commit possible). 
9. formation pour certaines équipes de développeurs

![](/assets/migration-svn-git/etape_finale_bascule_git.png)

## Retour d'expérience et Conclusion
TODO

## Références

* [Script svn2git sur GitHub](https://github.com/vdupain/svn2git)
* [Kevin Menard's svn2git](https://github.com/nirvdrum/svn2git)
* [Arnaud Heritier's script](https://gist.github.com/aheritier/8824148)
* [Atlassian Blogs: Moving Confluence from Subversion to git](http://blogs.atlassian.com/2012/01/moving-confluence-from-subversion-to-git)
