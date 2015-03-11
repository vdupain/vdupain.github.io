---
layout: post
title: Configurer un client OpenVPN vers HideMyAss (HMA) sous PFSense
date: 2013-09-24
comments: true
categories: network
---

## Introduction

L'objectif est de configurer le routeur/firewall [PFSense](http://www.pfsense.org) pour router le trafic de certaines adresses IP vers [HideMyAss](http://hidemyass.com/vpn/) (HMA) avec OpenVPN.

Ce tutoriel est plus ou moins valable pour d'autres fournisseurs VPN pour peu que l'on configure le client OpenVPN correctement.

**_Petit rappel_**:  un VPN permet d'établir un tunnel chiffré entre votre ordinateur et un serveur VPN qui vous sert de passerelle vers Internet. Le VPN est à ce jour la seule solution fiable contre le DPI (Deep Packet Inspection). Le VPN permet par exemple d'accéder à un service limité à une zone géographique en se basant sur la géolocalisation des adresses IP (Google Music à ces débuts, marketplace XBox/PS3, fournisseurs de contenu, etc...)

## Prérequis

*   Avoir un router PFSense sous la main, en version 2.1 dans le cas de ce tutoriel.
*   Une compte VPN HMA.
*   Récupérer le package de connexion HMA depuis [https://vpn.hidemyass.com/vpncontrol/signin](https://vpn.hidemyass.com/vpncontrol/signin). Ce package contient un répertoire **keys** avec les fichiers ca.crt, hmauser.crt, et hmauser.key. Ces fichiers sont uniques pour chaque utilisateur du VPN.
*   Télécharger les fichiers de configuration OpenVPN depuis [http://hidemyass.com/vpn-config/](http://hidemyass.com/vpn-config/).

## Configuration des certificats

*   Se connecter à l'interface Web du routeur PFSense, généralement [http://192.168.1.1](http://192.168.1.1)
*   Aller dans le menu **System > Cert Manager**.
*   Dans l'onget **Cert Manager**, cliquer sur le bouton (+) pour ajouter une autorité de certification (CA).
*   Donner un nom au CA, par exemple **HMA CA**.
*   Copier/Coller le contenu du fichier **_ca.crt_** dans la section **Certificate data**.
*   Cliquer sur **Save**.

![](/assets/pfsense_hma_1.png)

*   Une fois sauvegardé, le CA est visible sous le nom **HMA CA** comme ci-dessous:

![](/assets/pfsense_hma_2.png)

*   Cliquer sur l'onglet **Certificates** et cliquer sur le bouton (+) pour ajouter un certificat.
*   Donner un nom au certificat, par exemple **HMA OVPN**.
*   Copier/Coller le contenu du fichier _**hmauser.crt**_ dans la section **Certificate data**.
*   Copier/Coller le contenu du fichier _**hmauser.key**_ dans la section **Private key data**.
*   Cliquer sur **Save**.

![](/assets/pfsense_hma_3.png)

*   Une fois sauvegardé, le certificat est visible sous le nom **HMA OVPN** comme ci-dessous:

![](/assets/pfsense_hma_4.png)


## Compte de connexion VPN HMA

*   Aller dans le menu **Diagnostics > Edit File**.
*   Dans le champ **Save / Load from path**, mettre **_/conf/hmuser.conf_**.
*   Dans la zone de saisie, mettre votre login et mot de passe sur 2 lignes.
*   Cliquer sur **Save**.

![](/assets/pfsense_hma_5.png)


## Configuration du client OpenVPN

*   Aller dans le menu **VPN > OpenVPN**.
*   Cliquer sur l'onglet **Client**.
*   Cliquer sur le bouton (+) pour ajouter un client OpenVPN.
*   Sélectionner le protocole **TCP** (HMA fonctionne aussi en UDP).
*   Entrer l'adresse IP du serveur auquel se connecter, les IPs des serveurs VPN sont indiquées dans les fichiers de configuration OpenVPN téléchargés.
*   Entrer le numéro de port: **443 en TCP et 53 en UDP.**
*   Mettre une description pour le client OpenVPN, par exemple **HMA Pro VPN**.
*   Cocher l'option **Infinitely Resolve Server**.

![](/assets/pfsense_hma_6.png)

*   Décocher l'option **Enable Authentication of TLS Packets**.
*   Sélectionner **HMA CA** dans la combobox** Peer Certificate Authority**.
*   Sélectionner **HMA OVPN** dans la combobox **Client Certificate**.
*   Choisir l'algorithme de chiffrement **BF-CBC 128 bits**.

![](/assets/pfsense_hma_7.png)

*   Ajouter la configuration suivante dans la zone prévue à cet effet: _**verb 3;ns-cert-type server;auth-user-pass /conf/hmauser.conf;persist-key;persist-tun;route-nopull;**_

    *   l'option **route-nopull** permet de refuser les directives de routage des serveurs HMA. En effet par defaut les serveurs de HMA poussent des règles de routage dont la règle "redirect-gateway" qui refinit la route par défaut vers les serveurs HMA .

*   Cliquer sur **Save**.

![](/assets/pfsense_hma_82.png)

*   La configuration du client OpenVPN est terminée et elle est visible dans l'interface de PFSense. On peut voir l'IP du serveur VPN, le protocole et le port de connexion.

![](/assets/pfsense_hma_9.png)

*   Aller dans le menu **Satus > System logs**.
*   Sélectionner l'onglet **OpenVPN**.
*   Vérifier dans les logs que la connexion avec le serveur VPN est bien établie: _TCP connection established with..._

![](/assets/pfsense_hma_10.png)

*   Aller dans le menu **Status > OpenVPN**.
*   Vérifier que le statut de la connexion VPN est bien "**up**".

![](/assets/pfsense_hma_11.png)

## Configuration de l'interface

*   Aller dans le menu **Interfaces > (assign)**.
*   Cliquer sur le bouton (+) pour ajouter une nouvelle interface.
*   Pour la nouvelle interface créee **OPT1**, sélectionner l'interface réseau correspondant au client VPN: **ovpnc1 (HMA Pro VPN)** ou ovpnc2 (HMA Pro VPN).
*   Cliquer sur **Save**.

![](/assets/pfsense_hma_12.png)

*   Cliquer sur le nom de l'interface OPT1 créee précédement.
*   Cocher l'option **Enable Interface** afin d'activer l'interface.
*   Changer la description et mettre **HMA** par exemple.
*   Cliquer sur **Save**.

![](/assets/pfsense_hma_13.png)

## Configuration du firewall

*   Aller dans le menu **Firewall > NAT**.
*   Sélectionner l'onglet **Outbound**.
*   Cocher l'option **Manual Outbound NAT rule generation (<strong> AON - Advanced Outbound NAT)**.</strong>
*   Cliquer sur **Save**.
*   Cliquer ensuite sur le bouton **Apply changes** pour appliquer les modifications.

![](/assets/pfsense_hma_14.png)


*   Aller dans le menu **Firewall > Rules**.
*   Sélectionner l'onglet **LAN** pour ajouter une nouvelle règle.
*   Mettre **ips_vpn** comme adresse source. **ips_vpn** est un alias correspondant à 3 adresses IP.
*   Éventuellement donner une description à la règle.

![](/assets/pfsense_hma_15.png)

*   Changer la passerelle (Gateway) et sélectionner **HMA_VPN_VPNV4** au lieu de WAN.

![](/assets/pfsense_hma_16.png)

*   Attention à ce que la nouvelle règle créée soit bien au dessus de celle par défaut (Default allow LAN to any rule) afin que la nouvelle règle soit traitée en 1ère. Si ce n'est pas cas, la déplacer avec les boutons à droite de la règle.
*   Les IPs définies par l'alias **ips_vpn** seront routées vers **HMA** tandis que toutes les autres seront routées vers la route par défaut (**WAN**).

![](/assets/pfsense_hma_17.png)

## Vérification et géolocalisation de l'IP

*   Pour vérifier la configuration du routeur et le routage vers le serveur VPN HMA, plusieurs possibilités:

    *   Changer l'IP de la machine avec une adresse IP présente dans l'alias **ips_vpn**.
    *   A partir d'une machine virtuelle sous Virtualbox, avec l'interface réseau activée en mode pont (Bridged Adaptor) et en DHCP client pour récupérer son IP depuis le routeur PFsense.

*   Se connecter sur [http://whatismyipaddress.com/](http://whatismyipaddress.com/) pour vérifier l'IP et la géolocalisation.
*   Si cela ne fonctionne pas ou qu'il n'y a pas de connection à Internet, il est parfois nécessaire de redémarrer le routeur.
*   Pour ce tutoriel, le serveur VPN est localisé en Suède.

![](/assets/pfsense_hma_18.png)

## Références

* [PFSense Open Source Firewall](http://www.pfsense.org/)
* [Hide My Ass VPN](http://hidemyass.com/vpn/)
* [pfsense OpenVPN connection issues](http://forum.hidemyass.com/index.php/topic/6256-pfsense-openvpn-connection-issues/?hl=pfsense)
