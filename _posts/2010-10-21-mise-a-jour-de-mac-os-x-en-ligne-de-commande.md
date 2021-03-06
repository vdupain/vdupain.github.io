---
layout: post
title: Mise à jour de Mac OS X en ligne de commande
date: 2010-10-21
comments: true
categories: osx
---

Lorsque des mises à jour sont disponibles pour OS X, une fenêtre popup apparaît pour lister les mises à jour disponible et installer les mises à jour.

![](/assets/capture-d_ecran-2010-11-11-a-07-52-11.png)

Il est possible d'appliquer ces mises à jour depuis la ligne de commande.

Pour cela lancer un **Terminal** et exécuter la commande **softwareupdate -i -a** pour installer toutes les mises à jour:

```
MacBook-Pro-de-Vince:~ vince$ sudo softwareupdate -i -a
Password:
Software Update Tool
Copyright 2002-2009 Apple

Downloading Java for Mac OS X 10.6 Update 3
Waiting to install Java for Mac OS X 10.6 Update 3
   Checking packages…
Installing
   Waiting for other installations to complete…

   Writing files…
   Running package scripts…
   Optimizing system for installed software…
   Moving items into place…
   Registering updated applications…
   Writing package receipts…
   Cleaning up…
Installed Java for Mac OS X 10.6 Update 3
Done.
```

Voila c'est fini, votre machine est à jour!
Par la suite, il sera possible d'automatiser l'installation de ces mises à jour avec **cron** ou **launchd**.
